# cfix area E: nqp::encode into an existing array (E1, E2, and the adopting branch's rounding) (Task 5)

```
Branch:    encode-append-offset, from origin/main f112c3998, in P (local only, not pushed)
Commits:   d218f764ea4e6eb2506494a25a331cdb30750fa9 "Append nqp::encode's bytes after the last element, in whole elements" (E1, E2)
           bf768a9cbc176d696ad8483b230ff5283e17ed8d "Keep the last partial element when nqp::encode adopts its buffer" (the same rounding in the other branch)
           (the prefixes were built from 147a54c68 / bf7a9a864, identical trees 226450e6f / 7954cb1df: only the
           first message was corrected afterwards, twice, see section 1)
Diff:      src/strings/ops.c +19 -5, two hunks: the append branch and the adopting branch of
           MVM_string_encode_to_buf_config
Prefixes:  /tmp/claude-1000/cfix-E (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-E-asan (--asan
           --no-mimalloc), from `git archive` copies /tmp/claude-1000/cfix-src-E{,-asan}
           (cfix-T-raw/build/export-build.sh; driver cfix-N-raw/build/build-all.sh); the built ops.c is
           byte-identical to the branch's; make exit 0, 10 s / 20 s, no warning in ops.c (729 / 725 in all)
nqp/rakudo: Task 1's builds, only the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-E-raw/repro/ (run-all on both prefixes; the new programs also on cfix-base and cfix-asan),
           cfix-E-raw/base-perkind/ and base-perkind-rerun/ (E-encode-state one kind per process on
           cfix-base, twice, and on cfix-asan), cfix-E-raw/prefix-cmp.py and prefix-cmp.txt, ok-kept.py and
           ok-kept.txt (section 2), cfix-E-raw/hand-unwritten-slot.nqp (section 1), cfix-E-raw/pr-repro/,
           cfix-E-raw/cmp.txt, cfix-E-raw/suites/, cfix-E-raw/build/
```

## 1. The fix

`MVM_string_encode_to_buf_config` (ops.c:1871-1921) encodes a string and puts the bytes into the
caller's integer VMArray. It is behind `nqp::encode`, `encoderep`, `encodeconf` and `encoderepconf`. The
interpreter calls it at interp.c:1659, 4689, 5169 and 5174, and the JIT calls the same C function
(graph.c:265, 425; core_templates.expr:800, 2645, 2804, 2814). No other C code calls it. There are two
branches:
- **append**, when the array has storage (`slots.any != NULL`). E1 and E2 are here.
- **adopt**, when it has none: the array takes the encoded buffer.

**Append branch** (first commit). Old code:
`prev_elems` (MVMuint32) = elems; `set_elems(elems + output_size / elem_size)`;
`memmove(slots.i8 + prev_elems, encoded, output_size)`. New code:
- `prev_elems` is MVMuint64 (E1's truncation part).
- `new_elems = (output_size + elem_size - 1) / elem_size`, the byte count rounded **up** (E2).
- `set_elems(prev_elems + new_elems)`. set_elems goes through the REPR, and VMArray is checked at
  1880, so this is set_size_internal.
- Only after the resize: `dest = slots.u8 + (start + prev_elems) * elem_size`. set_size_internal may move
  the elements to the front and set start 0 (VMArray.c:414-425), or realloc the slots (464-470). Before
  the resize neither the pointer nor start can be trusted.
- `memmove(dest, encoded, output_size)`, then `memset(dest + output_size, 0, new_elems * elem_size -
  output_size)`: the spare bytes of the last element are zero.

Why the memset is needed. The ruling assumed that the resize zeroes new slots. That holds when the
resize reallocates (zero_slots from the old elems to the new ssize), and for slots that pop, shift and
shrinking left behind (they zero). It does not hold for room past elems in a buffer that was adopted:
normalizecodes and strtocodes results, asynchronous socket and process reads (cfix-N.md section 5).
Those slots were never written. `cfix-E-raw/hand-unwritten-slot.nqp` makes such an array (normalizecodes
of 101 769 97 gives 233 97 in a 3-element buffer), grows it with setelems 3, and reads element 2:
- cfix-base: `1450128640`
- cfix-asan: `3200171710` (0xbebebebe)

An append into that room would otherwise have taken whatever was there for the spare bytes. The grid's
`normalized` target checks the zeroing under ASAN (section 2).

**Adopt branch** (second commit). Old code: `ssize = elems = output_size / elem_size`, rounded down,
with no overrun (the buffer has output_size bytes), so the trailing bytes were silently dropped. This is
reachable from plain Raku: `Encoding::Encoder::Builtin.new('utf8', blob16).encode-chars('abc')` gives
`Blob[uint16]: elems 1: 6261`, and the 'c' is lost. Decision: **fixed, in its own commit**. It is the same
rounding as E2, applied to the same byte count. With E2 fixed to round up and this branch left alone,
the same encode would give a different number of elements depending on whether the target already had
storage:
- 'abc' into a fresh uint16 array: 1 element.
- 'abc' into a uint16 array with storage and no elements: 2 elements.

New code, when the count is not a whole number of elements: realloc the buffer to whole elements, zero
the spare bytes, `ssize = elems =` the rounded-up count. When it is a whole number (every encode into an
8-bit array; utf16 into 16-bit, utf32 into 32-bit), nothing changes and nothing is reallocated. The
commit can be dropped on its own if the maintainers prefer refusing such byte counts.

**The behaviour this defines, and its alternative.** When the byte count is not a multiple of the
element size, the array now gets one more element than the whole ones, holding the last bytes with the
spare bytes zero. That puts them in the high-order bytes on a little-endian machine. The alternative is to
refuse such a byte count with an exception in both branches. Nothing in nqp or Rakudo produces such
counts on purpose. Rakudo's encoders pick a buffer type of the encoding's unit
(`Encoding::Builtin!buf-type`).

**What else the hunks change** (all checked by the grid, section 2):
- An append into an array with start > 0 now lands after the last element. Before, it went `start` slots
  early, and also wrong for elem_size > 1. When the append grows past ssize, set_size_internal first moves
  the elements to the front, and the destination is computed after that.
- Every case upstream got right is unchanged. That is a 1-byte kind with start 0, or a byte count that is
  a multiple of the element size in the adopt branch. `ok-kept.py`: 96 of 96 upstream-correct result
  lines appear unchanged in the fixed output.
- The adopt branch reallocates only for a partial last element.
- `prev_elems` is 64-bit. Its 32-bit truncation needs an array of 2**32 elements or more, which was not
  driven (a 4 GiB array at least). I checked the arithmetic by reading only.

**Reach, checked by search** (core sources of nqp 305ff2f77 and rakudo c6d6fc3c6b; the ecosystem not
searched):
- The **append branch** is used by nqp itself. The MoarVM backend's string heap writer
  (QASTCompilerMAST.nqp:2499-2501) does setelems + 4 and then `nqp::encode(..., $!strings)` into a
  `MAST::Bytecode` (lib/MAST/Nodes.nqp:46: a VMArray of uint8). The buffer only grows, so start is 0, the
  one shape the old code got right. The fix gives the same bytes there (offset `(0 + prev) * 1`, no
  rounding, a 0-byte memset), and the nqp suite confirms it. No Rakudo core code appends: every
  `nqp::encode*` passes a fresh array (Encoder/Builtin.rakumod:24-31, IO/Path.rakumod:285 and 749,
  Raku/ast/var-lowering.rakumod:1388; nqp's IO.nqp:184 likewise). So E1 and E2 are reached from nqp and
  from Raku only through nqp ops.
- The **adopt branch's** rounding is reached from plain Raku through an encoder built for a wider buffer
  type (above).

**Commits.** E1 and E2 are two defects in the same three lines, fixed in one commit, which says so.
Fixing the offset first would make the rounding overflow whenever the storage is exactly full. Fixing
the rounding first cannot define the spare bytes while the offset is still wrong. The adopt branch is a
second, separable commit. The first commit's message was corrected after the build, twice. First, it had
claimed that pop leaves old values in slots, but pop zeroes them. Second, it said "the plain build
crashed" without saying that this depends on the heap layout. The trees are unchanged.

## 2. Reproducers, before and after

| program | cfix-base / cfix-asan (before) | cfix-E / cfix-E-asan (after) |
|---|---|---|
| `E1-encode-append-offset.nqp` | `u16: 1 97 98 0`, `u8s: 2 97 98 0`, `u8: 1 2 97 98`; both builds | `u16: 1 2 97 98`, `u8s: 2 3 97 98`, `u8: 1 2 97 98`; both builds, exit 0 |
| `E2-encode-append-rounding.nqp` | plain: SIGSEGV (exit 139) before printing; ASAN: heap-buffer-overflow WRITE of size 17, 0 bytes after the 16-byte region, in MVM_string_encode_to_buf_config | `elems 9`; both builds, exit 0 |
| `E-encode-state.nqp` (new; 8 kinds × 6 targets × 6-7 strings, 258 cases, self-checking) | plain: 233 result lines, then SIGSEGV after the overrunning `emptied` cases (where it stops varies run to run); ASAN: heap-buffer-overflow at the first overrunning case; per kind (`base-perkind/`): every kind but uint8/int8 has MISMATCH lines (5 to 28 per kind, the start-1 cases also for 8-bit kinds) | **258 ok, 0 MISMATCH**, `done`, exit 0, on both builds (no ASAN report, including the `normalized` cases, whose spare bytes come from a 0xbe-filled block under ASAN) |
| `E-fresh-partial.raku` (new, plain Raku) | `Blob[uint16] 'abc': elems 1: 6261`, `'abcd': elems 2: 6261 6463`, `Blob[uint32] 'abcde': elems 1: 64636261`, `Blob[uint64] 'abc': elems 0:`, `Blob[uint8] 'abc': elems 3: 61 62 63`; both builds | `'abc': elems 2: 6261 63`, `'abcd'` unchanged, `'abcde': elems 2: 64636261 65`, `Blob[uint64] 'abc': elems 1: 636261`, `Blob[uint8]` unchanged; both builds |

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-E -o cfix-E-raw/repro` and `-p cfix-E-asan` (124 outputs). `cfix-N-raw/cmp-repro.sh
cfix-E-raw/repro E` (`cfix-E-raw/cmp.txt`): 113 same, 11 differ.
- 8 expected flips: E1, E2, E-encode-state and E-fresh-partial, each on both builds.
- 3 noise: B1's raku program, B-buf-grid (plain), and O-buf-type-cases `rebind` (plain). The last one
  reads element 99 past the buffer and gets a different value each run.

**E-encode-state on builds without the E fix.** On cfix-N, cfix-O and cfix-D the program crashes, after
an overrunning case, at a different place than on cfix-base. cfix-base does the same between two of its
own runs. In the per-kind runs, uint16 crashed in one run and not the other, and so did int32
(`base-perkind/` vs `base-perkind-rerun/`). `prefix-cmp.py` checks that the result lines agree as far as
both outputs go, for the whole program and for each kind on cfix-N, cfix-O and cfix-D. They do in all 27
comparisons (`prefix-cmp.txt`).

## 4. Suites

`cfix-maketest-driver.sh cfix-E-raw/suites cfix-E` (probes map `/tmp/claude-1000/cfix-E/lib/libmoar.so`;
run on the branch's final tree):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 0.91) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (125 s, load 0.85) | identical (`diff` empty) |

## 5. Seen on the way (reported, not fixed)

- The room past elems in adopted buffers is never written, and `setelems` exposes it (cfix-N.md section
  5). This fix does not depend on it: it zeroes the spare bytes it creates itself.
- `MVM_repr_pos_set_elems` can throw ("Unable to allocate an array of N elements") after the encode. The
  encoded buffer is then leaked. This was so before as well; not changed.

## 6. Draft PR text

Title: **Fix how nqp::encode puts its bytes into an existing array**

Body:

> When `nqp::encode` (and `encoderep`, `encodeconf`, `encoderepconf`) is given an array that already has
> storage, `MVM_string_encode_to_buf_config` appends the encoded bytes to it. One behaviour choice comes
> first. When the number of bytes is not a multiple of the element size, the array now gets one more
> element for the last bytes, with its spare bytes zero (the high-order bytes on a little-endian machine).
> This applies to appending and to a fresh array. The other choice would be to refuse such a byte count
> with an exception. Byte counts that fill whole elements are not affected.
>
> 1. The append copied the bytes to `slots + prev_elems`, an element count used as a byte offset from the
>    start of the storage. That ignored both the element size and start, so the bytes landed on top of
>    existing elements, and the last new elements stayed zero. `prev_elems` was also a MVMuint32, so it
>    truncated the element count of arrays of 2**32 elements or more.
> 2. The append grew the array by `output_size / elem_size` elements, rounded down, but copied all
>    `output_size` bytes. When the storage was exactly full, the last bytes were written past it: a heap
>    overflow of up to elem_size - 1 bytes.
>
>    Both are fixed in the first commit. They are in the same three lines, and neither fix makes sense
>    without the other. The array grows by the rounded-up count. The destination,
>    `(start + prev_elems) * elem_size` bytes into the storage, is computed after the resize, because the
>    resize may move the elements to the front or reallocate. The spare bytes of the last element are
>    zeroed explicitly: slots past elems are not always zero, since an array whose buffer was adopted (a
>    normalizecodes result, or an asynchronous socket or process read) can have room there that was never
>    written.
> 3. When the array has no storage yet, the encoded buffer is adopted, and elems was the same rounded-down
>    count. The trailing bytes were not overrun but silently dropped. This is reachable from plain Raku:
>    `Encoding::Encoder::Builtin.new('utf8', blob16).encode-chars('abc')` gave one element, 0x6261, and
>    lost the 'c'. The second commit rounds up here too, so the result does not depend on whether the array
>    already had storage. It reallocates the buffer to whole elements and zeroes the spare bytes. It can be
>    dropped on its own if refusing such byte counts is preferred.
>
> NQP's own MoarVM backend uses the append path to build the string heap (a uint8 buffer at start 0, the
> one shape the old code got right); it gets the same bytes as before. In nqp:
>
> ```
> sub int_array(int $bits) {
>     my $int := nqp::newtype(nqp::null(), 'P6int');
>     nqp::composetype($int, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
>     my $t := nqp::newtype(nqp::null(), 'VMArray');
>     nqp::composetype($t, nqp::hash('array', nqp::hash('type', $int)));
>     $t
> }
> sub hex(int $n) {
>     my $s := ''; my $d := '0123456789abcdef';
>     while $n > 0 { $s := nqp::substr($d, $n % 16, 1) ~ $s; $n := nqp::div_i($n, 16) }
>     $s eq '' ?? '0' !! $s
> }
> sub show($what, $a) {
>     my @e; my int $i := 0;
>     while $i < nqp::elems($a) { nqp::push(@e, hex(nqp::atpos_i($a, $i))); $i++ }
>     say("$what: " ~ nqp::elems($a) ~ " elements: " ~ nqp::join(' ', @e));
> }
> my $u16 := int_array(16);
> my $u8  := int_array(8);
>
> my $a := nqp::create($u16);
> nqp::push_i($a, 1); nqp::push_i($a, 2);
> show('uint16 1 2, append "ab" as utf16', nqp::encode('ab', 'utf16', $a));
>
> my $b := nqp::create($u8);
> nqp::push_i($b, 1); nqp::push_i($b, 2); nqp::push_i($b, 3); nqp::shift_i($b);
> show('uint8 2 3 (after a shift), append "ab" as utf8', nqp::encode('ab', 'utf8', $b));
>
> show('fresh uint16, "abc" as utf8', nqp::encode('abc', 'utf8', nqp::create($u16)));
>
> my $c := nqp::create($u16);
> nqp::setelems($c, 8); nqp::setelems($c, 0);
> show('uint16 with room for 8, none used, append 17 bytes of utf8', nqp::encode('abcdefghijklmnopq', 'utf8', $c));
> ```
>
> Before (plain build):
>
> ```
> uint16 1 2, append "ab" as utf16: 4 elements: 1 61 62 0
> uint8 2 3 (after a shift), append "ab" as utf8: 4 elements: 2 61 62 0
> fresh uint16, "abc" as utf8: 1 elements: 6261
> uint16 with room for 8, none used, append 17 bytes of utf8: 8 elements: 6261 6463 6665 6867 6a69 6c6b 6e6d 706f
> ```
>
> In the last line the 17th byte went one byte past the 16-byte buffer. Whether that crashes the plain
> build depends on what follows the buffer. A program doing only that step crashed in each of four runs,
> but this one did not. With AddressSanitizer it is a heap-buffer-overflow WRITE of size 17, 0 bytes after
> the 16-byte region, in `MVM_string_encode_to_buf_config`.
>
> After (plain and AddressSanitizer builds alike):
>
> ```
> uint16 1 2, append "ab" as utf16: 4 elements: 1 2 61 62
> uint8 2 3 (after a shift), append "ab" as utf8: 4 elements: 2 3 61 62
> fresh uint16, "abc" as utf8: 2 elements: 6261 63
> uint16 with room for 8, none used, append 17 bytes of utf8: 9 elements: 6261 6463 6665 6867 6a69 6c6b 6e6d 706f 71
> ```
>
> I also checked a grid: every integer element kind, against fresh, filled, shifted, popped and emptied
> targets and normalizecodes results, with 0 to 5 bytes, plus one byte more than an emptied target's
> storage. Each result is compared with the target's elements followed by the bytes packed into
> zero-padded elements. After the fix 258 of 258 cases match, and every case that matched before is
> unchanged. `make test` of nqp and Rakudo gives the same per-file results as
> before.
>
> Found while auditing, for the port of the VMArray REPR to Zig, the places outside the REPR that build or
> adopt an array's storage directly.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
