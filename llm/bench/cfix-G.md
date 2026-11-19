# cfix area G: VMArray growth that wraps the slot count (G1) (Task 2)

```
Branch:    vmarray-size-overflow, from origin/main f112c3998, in P (local only, not pushed)
Commit:    35f1559a1432fb75d0929855f385e6ae28d9d649
           "Throw instead of wrapping when growing a VMArray to near 2**64 elements"
Diff:      src/6model/reprs/VMArray.c, 1 hunk, +6 lines (set_size_internal, `ssize >= 8192` branch)
Prefixes:  /tmp/claude-1000/cfix-G (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-G-asan
           (--asan --no-mimalloc), built from `git archive vmarray-size-overflow` copies
           /tmp/claude-1000/cfix-src-G{,-asan} (cfix-G-raw/build/export-build.sh)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b in cfix-base and /tmp/claude-1000/cfix-ws),
           only the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-G-raw/repro/ (every reproducer, <file>[.<case>].cfix-G{,-asan}.txt),
           cfix-G-raw/n2-rerun/ (N2 noise check), cfix-G-raw/pr-repro/ (the PR text's
           reproducer and its outputs on cfix-base, cfix-asan, cfix-G, cfix-G-asan), cfix-G-raw/suites/ (make test), cfix-G-raw/build/
G2:        dropped (not a bug, cfix-baseline.md section 3); not touched
```

## 1. The fix

In set_size_internal, once `ssize >= 8192` the new size is `(n + 0x1000) & ~0xfff`. For
`n >= 2**64 - 4096` the addition wraps and the rounded size is 0, which passes the limit check; the
slots are realloc'ed to 0 bytes and zero_slots memsets `(0 - elems)` slots. The fix, right after the
rounding:

```c
        /* n within 4096 of the top of the range wraps the rounding to 0;
         * that is over the limit below too */
        if (ssize < n)
            MVM_exception_throw_adhoc(tc,
                "Unable to allocate an array of %"PRIu64" elements",
                n);
```

Checked against the C before writing it:
- `ssize < n` is exactly the wrap: without a wrap, the rounding gives a value of at least n. With a wrap
  (n >= 2**64 - 4096) it gives a value below 4096, and n is far above that.
- The `ssize < 8192` branch cannot wrap. `ssize * 2 < 16384`, and a huge n sets `ssize = n`, which
  the existing limit check catches.
- `n + start` in the compaction test (line 415) can also wrap for `start > 0`. That only decides
  whether the elements are moved down first, and the growth then throws as above (or in the limit
  check). The array keeps its elements in both cases. Nothing to change there.
- The message prints `n`, as ruled. The existing limit check keeps printing the rounded `ssize`, as
  before. `setelems(-4097)` (n = 2**64 - 4097, no wrap, rounded to 2**64 - 4096) still prints "... of
  18446744073709547520 elements" from that check: unchanged upstream behaviour, not touched.
- Throwing here leaves the array as it was. Nothing has been reallocated, and `body->elems` /
  `body->ssize` are untouched. This is the same state the existing limit exception leaves.

Defined behaviour, flagged for the maintainers: the existing catchable "Unable to allocate an array of N
elements" exception, as every other too-large size gets (the neighbouring check's choice).

## 2. Reproducer, before and after

`cfix-repro/G1-size-wrap.nqp` (`run.sh -m 2G -t 60`):

| build | output |
|---|---|
| cfix-base (before) | `setelems(2**64 - 4096): returned, elems -4096`, `still alive: elems -4096`, then SIGSEGV (exit 139) |
| cfix-asan (before) | `AddressSanitizer: negative-size-param: (size=-65536)` in memset (set_elems → set_size_internal → zero_slots) |
| cfix-G (after) | `setelems(2**64 - 4096): DIED Unable to allocate an array of 18446744073709547520 elements`, `still alive: elems 8192`, `element 1000000000: 0`, exit 0 |
| cfix-G-asan (after) | identical to cfix-G, no ASAN report, exit 0 |

Boundary check by hand on cfix-G (setelems on an 8192-element int array, inside a try):
- `-1` → "... of 18446744073709551615 elements". This is n, from the new check.
- `-4096` → "... of 18446744073709547520 elements". This is n, from the new check.
- `-4097` and `-8192` → "... of 18446744073709547520 elements". This is the rounded size, from the
  existing check.
- In every case the array still has 8192 elements.

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-G -o cfix-G-raw/repro` and `-p cfix-G-asan` (34 program/case pairs each, 68 outputs).
They were compared file by file with Task 1's `cfix-baseline-raw/repro/` (`.base` ↔ `.cfix-G`, `.asan` ↔
`.cfix-G-asan`) by `cfix-G-raw/cmp-repro.sh`. Before comparing it removes:
- the probe/run lines;
- hex addresses;
- ASAN PIDs, BuildIds and the shadow-byte dump;
- prefix names;
- 12+-digit decimals.

63 of 68 identical. The 5 that differ:

- `G1-size-wrap.nqp` plain and ASAN: the expected flip (section 2).
- `B1-read-buf-past-storage.raku` plain (`past1`/`past4`) and `O1-procasync-buf-type.nqp int64` plain
  (`element 99`): both print bytes read past the block (the B1 and O1 bugs themselves). They vary
  between runs of unmodified cfix-base too. Three reruns on cfix-base gave `past1: 8/8/104` and
  `element 99: 256/5310563549536/2986180870496`; the baseline file has `past1: 40` (S's raw dir
  `cfix-S-raw/base-rerun/`). Noise, not a change.
- `N2-strtocodes-leak.nqp` ASAN: `RSS grew by 397 MB` vs 396. Three reruns each
  (`cfix-G-raw/n2-rerun/`) gave cfix-asan 396/396/396 and cfix-G-asan 397/396/396. Noise of 1 MB.

## 4. Suites

`cfix-maketest-driver.sh cfix-G-raw/suites cfix-G` (probes map `/tmp/claude-1000/cfix-G/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 1.95) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (128 s, load 1.87) | identical (`diff` empty) |

## 5. Draft PR text

Title: **Throw instead of wrapping when growing a VMArray to near 2\*\*64 elements**

Body:

> When a VMArray with 8192 or more slots grows, set_size_internal rounds the new size up to the next
> multiple of 4096 with `(n + 0x1000) & ~0xfff`. For a requested size `n >= 2**64 - 4096` that
> addition wraps and the new slot count becomes 0. Zero passes the size limit check, so the slots were
> reallocated to 0 bytes and zero_slots then cleared from the old size up to 0, a memset over
> `(0 - elems)` slots.
>
> It is reachable from nqp code: `nqp::setelems` takes a 64-bit count and hands it on as unsigned, so
> a count of -4096 is `n = 2**64 - 4096`:
>
> ```
> my $a := nqp::list_i();
> nqp::setelems($a, 8192);
> my $r;
> try { nqp::setelems($a, -4096); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
> say("setelems(2**64 - 4096): $r");
> say("still alive: elems " ~ nqp::elems($a));
> say("element 1000000000: " ~ nqp::atpos_i($a, 1000000000));
> ```
>
> Before, on a plain build, setelems returns with elems -4096 over a buffer of no size, and the read
> of a high index crashes:
>
> ```
> setelems(2**64 - 4096): returned, elems -4096
> still alive: elems -4096
> (SIGSEGV)
> ```
>
> With AddressSanitizer it stops in the memset: `negative-size-param: (size=-65536)` in set_elems →
> set_size_internal → zero_slots.
>
> This change treats a rounded size that wrapped as over the limit. It throws the existing "Unable to
> allocate an array of N elements" exception before anything is reallocated, so the array is left
> as it was. That is the same exception every other too-large size gets; if another behaviour is
> preferred for this corner, it is a one-line change. The message gives the requested size `n`,
> because the wrapped value would read "an array of 0 elements". After:
>
> ```
> setelems(2**64 - 4096): DIED Unable to allocate an array of 18446744073709547520 elements
> still alive: elems 8192
> element 1000000000: 0
> ```
>
> The same output with AddressSanitizer, without a report. `make test` of nqp and Rakudo gives the
> same per-file results as before.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
