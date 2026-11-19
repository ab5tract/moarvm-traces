# cfix area N: the normalizer's output arrays (N1, N2) (Task 5)

```
Branch:    normalize-array-result, from origin/main f112c3998, in P (local only, not pushed)
Commits:   5d0367c85818e6f5a6b263cfa37a5f4b01fac208 "Set the ssize of nqp::normalizecodes's result in elements" (N1)
           4410fecc0a9dce36e15f8c521f206059b06b497e "Free the old slots of nqp::strtocodes's output array" (N2)
Diff:      src/strings/normalize.c +5 -1, two hunks (normalize.c:90 and before :200)
Prefixes:  /tmp/claude-1000/cfix-N (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-N-asan (--asan
           --no-mimalloc), from `git archive` copies /tmp/claude-1000/cfix-src-N{,-asan}
           (cfix-T-raw/build/export-build.sh, unchanged; driver cfix-N-raw/build/build-all.sh, commits made
           without checking the branch out by cfix-N-raw/build/mkcommit.sh, Task 4's with its own index
           file); the built normalize.c is byte-identical to the branch's; make exit 0, 10 s / 20 s, no
           warning in normalize.c (729 / 725 in all, as every earlier prefix)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b in cfix-base and /tmp/claude-1000/cfix-ws), only
           the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-N-raw/repro/ (run-all on both prefixes; the new program also on cfix-base and cfix-asan),
           cfix-N-raw/cmp.txt and cmp-repro.sh (Task 5's copy, also used for E, O, D), cfix-N-raw/pr-repro/
           (the PR text's program on the four builds), cfix-N-raw/E-perkind/ (section 3), cfix-N-raw/suites/,
           cfix-N-raw/build/
```

## 1. The fix, and both sites checked for both defects

normalize.c has two places that hand a freshly built code point buffer to the caller's array:
`MVM_unicode_normalize_codepoints` (behind `nqp::normalizecodes`, interp.c:4448) and
`MVM_unicode_string_to_codepoints` (behind `nqp::strtocodes`, interp.c:4458). Nothing else calls them
(`git grep` over src/; the JIT has no template for either op).

| | normalize_codepoints (normalizecodes) | string_to_codepoints (strtocodes) |
|---|---|---|
| capacity | **N1**: `ssize = result_pos * sizeof(MVMuint32)` (normalize.c:90), the element count in bytes; the buffer has `result_alloc` elements. **Fixed: `ssize = result_alloc`.** | `ssize = result_alloc` (203): right |
| old storage | freed before adopting (82-84): right | **N2**: overwritten without a free (200-203). **Fixed: freed first**, the same three lines as the sibling |
| start | reset to 0 (88) | reset to 0 (201) |
| elems | `result_pos` (89) | `result_pos` (202) |

How VMArray uses these fields (VMArray.c): `ssize` is the capacity in elements. `set_size_internal`
(404-475) reallocates only when `n > ssize`, so an `ssize` larger than the buffer lets push, bindpos and
setelems write past it. `start` is the offset of element 0 in the slots, and every access adds it, so it
has to be 0 for a buffer whose element 0 is at slot 0. Both sites set it. `elems` is the element count.
`ssize` is also reported, and N1 changes what these show: `VMArray_unmanaged_size` (1518) gives
`ssize * elem_size` to heap snapshots (four times too large before), and the debug server's
`vmarray_ssize` (debugserver.c:2654-2655). No other code outside VMArray.c reads an adopted array's ssize
(`git grep ssize`: the other hits are the sites that set it: Decoder.c:342, asyncsocket.c:50,
asyncsocketudp.c:113, io.c:140, procops.c:686, ops.c:1916).

What else changes. N1: an array that grows past `result_alloc` now reallocates, where before it wrote
past the buffer until it reached `4 * result_pos`. That is the fix. When `4 * result_pos < result_alloc`, the old ssize
understated the capacity. Only an output under a quarter of the input's length could do that. The array
then just reallocated earlier than it had to. N2: none beyond the free. The array's contents were already
replaced. Freeing is safe because an array's slots belong to that array alone (VMArray's
`gc_free` frees them the same way, VMArray.c:114). The free comes after the result is complete, so an
exception during the iteration leaves the array as it was, as before.

**Reach.** Both ops are reached from nqp. From Rakudo they are reached only through nqp ops: every
Rakudo caller passes a fresh array (`nqp::create(NFC)` and friends in Uni.rakumod:71-83 and
unicodey.rakumod:69-318, Str.rakumod:2773-2801, JSON.rakumod:405, core.e Fixups.rakumod:306), or a fresh
`my int32 @codes` (RakuAST/Fixups.rakumod:588/602, :1035, :1166; LegacyPodify.rakumod:19;
core.e/Formatter.rakumod:438). A fresh array has no storage, so nothing leaks (N2). The results of
`normalizecodes` are NFC/NFD/NFKC/NFKD objects (Uni.rakumod:71-83), and Raku cannot grow them. Checked on
cfix-asan: `Uni.new(101, 769, 97).NFC.push(5)` has no matching candidate, and `$n[5] = 1` dies with "Index
out of range". So N1 needs nqp ops to be hit. The search covers the core sources of nqp 305ff2f77 and
rakudo c6d6fc3c6b. It does not cover the ecosystem, or code that uses nqp ops on these objects.

## 2. Reproducers, before and after

| program | cfix-base / cfix-asan (before) | cfix-N / cfix-N-asan (after) |
|---|---|---|
| `N1-normalize-ssize-bytes.nqp` | plain: `normalized: elems 100`, `pushed: elems 300, element 299 = 299, sum ok`, exit 0 (the overrun is silent here); ASAN: heap-buffer-overflow WRITE in `MVM_VMArray_push`, 0 bytes after the 528-byte region allocated in `MVM_unicode_normalize_codepoints` | the same two lines on both builds, exit 0, no ASAN report |
| `N2-strtocodes-leak.nqp` | plain: `case: ... RSS grew by 416 MB`, control 18 MB; ASAN: case 396 MB, control 280 MB (ASAN's quarantine) | plain: case **18 MB**, control 18 MB; ASAN: case 280 MB = control 280 MB |
| `N-adopt-state.nqp` (new) | plain: `normalizecodes into fresh` gives `elems 2: 233 97`, then 300 pushes read back **WRONG**; then SIGSEGV (exit 139) in the next case; ASAN: heap-buffer-overflow WRITE in `MVM_VMArray_push`, 0 bytes after the 12-byte region (3 elements, ssize 8) at the first case | every case: the result alone (`elems 2: 233 97` for normalizecodes, `elems 3: 101 769 97` for strtocodes) into fresh, filled and shifted targets, and `read back ok` after 300 pushes; both builds exit 0, no ASAN report |

`N-adopt-state.nqp` also prints two lines that do not change (both builds, before and after; section 5):
`normalizecodes of empty input into 10 20 30: elems 3: 10 20 30` and
`strtocodes of '' into 10 20 30: elems 0:`.

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-N -o cfix-N-raw/repro` and `-p cfix-N-asan`. run-all now also runs this task's
programs: N-adopt-state, E-encode-state, E-fresh-partial, and O-buf-type-cases in five modes. That makes
62 program/case pairs, 124 outputs. `cfix-N-raw/cmp-repro.sh cfix-N-raw/repro N` writes
`cfix-N-raw/cmp.txt`: 115 same, 9 differ.
- The 5 expected flips: N1 ASAN, N2 plain and ASAN, N-adopt-state plain and ASAN.
- 3 noise: B1's raku program, B-buf-grid (plain) and O1 `int64` (plain), all bytes read past a block.
- E-encode-state (plain). Upstream's E2 overruns a buffer in its `emptied` cases, and the program then
  crashes at a point that varies from run to run, on cfix-base itself too. Two cfix-base runs per kind
  stopped at different places: `cfix-E-raw/base-perkind`, `base-perkind-rerun`. Its result lines agree with
  upstream's as far as both go: `cfix-E-raw/prefix-cmp.py`, whole program 156 lines, and every kind
  separately (`cfix-N-raw/E-perkind/`, results in `cfix-E-raw/prefix-cmp.txt`).

## 4. Suites

`cfix-maketest-driver.sh cfix-N-raw/suites cfix-N` (probes map `/tmp/claude-1000/cfix-N/lib/libmoar.so`;
run on the branch's final tree):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 0.52) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (125 s, load 0.78) | identical (`diff` empty) |

## 5. Seen on the way (reported, not fixed)

- **normalizecodes of an empty input leaves the output as it was.** `MVM_unicode_normalize_codepoints`
  returns before touching `out` when the input has no elements (normalize.c:52-53). An output that held
  10 20 30 still holds them, where strtocodes of '' empties its output. Every Rakudo caller passes a fresh
  output, so it shows only from nqp. Not part of N1/N2.
- **The adopted buffers' room past elems is never written.** Both normalize.c sites `malloc`/`realloc`
  `result_alloc` elements and fill `result_pos` of them. The asynchronous socket and process reads adopt
  a libuv buffer the same way: ssize is the buffer's length, elems the bytes read (asyncsocket.c:48-51,
  asyncsocketudp.c:111-114, procops.c:684-687). VMArray assumes that the slots past elems are zero:
  `set_size_internal` grows within ssize without zeroing, and pop, shift and shrinking keep the
  invariant (zero_slots). So `nqp::setelems` on such an array exposes uninitialized heap memory. Program
  `cfix-E-raw/hand-unwritten-slot.nqp`: normalizecodes of 101 769 97 (result 233 97 in a 3-element
  buffer), then setelems 3, then element 2: cfix-base `1450128640`, cfix-asan/cfix-N-asan/cfix-E-asan
  `3200171710` (0xbebebebe, ASAN's fill of new blocks). It is an information leak and a wrong result,
  with no memory unsafety. It spans normalize.c, procops.c, asyncsocket.c and asyncsocketudp.c, so it is
  not fixed on this branch. A candidate for one small PR: zero the tail at each adoption site, or zero
  `[elems, n)` in set_size_internal when growing within ssize. The encode append (area E) zeroes the spare
  bytes it creates itself for this reason.

## 6. Draft PR text

Title: **Fix the output arrays of nqp::normalizecodes and nqp::strtocodes**

Body:

> Two fixes in src/strings/normalize.c, where the normalizer hands its result buffer to the caller's
> array. One commit each.
>
> 1. `MVM_unicode_normalize_codepoints` (nqp::normalizecodes) set the array's ssize to
>    `result_pos * sizeof(MVMuint32)`, the number of code points produced counted in bytes. The buffer
>    holds `result_alloc` elements. Since ssize is the capacity in elements, the array claimed about four
>    times the storage it had. A later push, bindpos or setelems below that claimed size then wrote past
>    the buffer without reallocating. ssize is now `result_alloc`, as `MVM_unicode_string_to_codepoints`
>    already sets it. Apart from the array now reallocating when it really runs out of room, this shows
>    only where ssize is reported: the size a heap snapshot gives for the array's storage, and the debug
>    server's `vmarray_ssize`.
> 2. `MVM_unicode_string_to_codepoints` (nqp::strtocodes) put its result buffer into the array without
>    freeing the buffer the array already had, so that storage leaked. It now frees it first, as
>    `MVM_unicode_normalize_codepoints` does.
>
> Both sites already reset start and elems. Rakudo always passes a fresh array to these ops, and its NFC/NFD
> objects cannot be grown from Raku, so as far as I can see both bugs need nqp ops to show:
>
> ```
> sub u32_array() {
>     my $int := nqp::newtype(nqp::null(), 'P6int');
>     nqp::composetype($int, nqp::hash('integer', nqp::hash('bits', 32, 'unsigned', 1)));
>     my $t := nqp::newtype(nqp::null(), 'VMArray');
>     nqp::composetype($t, nqp::hash('array', nqp::hash('type', $int)));
>     $t
> }
> sub rss_kb() {
>     for nqp::split("\n", slurp('/proc/self/status')) {
>         return +nqp::substr($_, 6) if nqp::eqat($_, 'VmRSS:', 0);
>     }
>     0
> }
> my $u32 := u32_array();
>
> # normalizecodes: e, combining acute, a -> NFC é a
> my $in := nqp::create($u32);
> nqp::push_i($in, 101); nqp::push_i($in, 769); nqp::push_i($in, 97);
> my $out := nqp::create($u32);
> nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $out);
> say("normalized: " ~ nqp::elems($out) ~ " elements: " ~ nqp::atpos_i($out, 0) ~ " " ~ nqp::atpos_i($out, 1));
> my int $i := 0;
> while $i < 300 { nqp::push_i($out, $i); $i++ }
> my int $ok := 1;
> $i := 0;
> while $i < 300 { $ok := 0 unless nqp::atpos_i($out, $i + 2) == $i; $i++ }
> say("after 300 pushes: " ~ nqp::elems($out) ~ " elements, " ~ ($ok ?? "all read back" !! "some read back wrong"));
>
> # strtocodes into an array that already has storage
> my $a := nqp::create($u32);
> nqp::force_gc();
> my int $before := rss_kb();
> $i := 0;
> while $i < 100 {
>     nqp::setelems($a, 1000000);
>     nqp::strtocodes('abc', nqp::const::NORMALIZE_NFC, $a);
>     nqp::force_gc();
>     $i++;
> }
> say("strtocodes: " ~ nqp::elems($a) ~ " elements; 100 rounds grew RSS by " ~ nqp::div_i(rss_kb() - $before, 1024) ~ " MB");
> ```
>
> Before (plain build; here the overrun shows only as wrong values, and the RSS growth varies a little from
> run to run):
>
> ```
> normalized: 2 elements: 233 97
> after 300 pushes: 302 elements, some read back wrong
> strtocodes: 3 elements; 100 rounds grew RSS by 408 MB
> ```
>
> With AddressSanitizer the first push past the third element is a heap-buffer-overflow WRITE in
> `MVM_VMArray_push`, 0 bytes after the 12-byte region allocated in `MVM_unicode_normalize_codepoints`.
>
> After:
>
> ```
> normalized: 2 elements: 233 97
> after 300 pushes: 302 elements, all read back
> strtocodes: 3 elements; 100 rounds grew RSS by 16 MB
> ```
>
> With AddressSanitizer the program now runs clean. Its RSS line means little there: ASan's quarantine
> holds freed blocks, so it reads about 280 MB even when nothing leaks (about 400 MB before).
> `make test` of nqp and Rakudo gives the same per-file results as before.
>
> Found while auditing, for the port of the VMArray REPR to Zig, the places outside the REPR that build or
> adopt an array's storage directly.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
