# cfix mirror: the VMArray C fixes carried into the Zig port (Task 6)

```
Branch:    zig-vmarray-c-fixes, from zig-hash-engine d23749ada, in P (local only, not pushed)
Range:     d23749ada..d5999adfa (31 commits: 21 cherry-picks of upstream fixes, 10 of the port), then one
           commit updating the traces pointer to the commit of this record
Library:   282b04734 is the last commit that changes anything compiled into libmoar; the two after it touch
           tools/bench/repr and docs only
Prefixes:  /tmp/claude-1000/vf-c-base (-Dzig-reprs=false, the C array) and /tmp/claude-1000/vf-n-base (defaults,
           the Zig array), both at 282b04734 (cfix-mirror-raw/build/)
Runners:   nqp-m of /tmp/claude-1000/tune-zig-prefix (nqp 41e7210ba, read only) and the rakudo checkout's
           rakudo-m (042608fb82), only the libmoar swapped through LD_LIBRARY_PATH; nothing rebuilt
Raw:       cfix-mirror-raw/{unit,build,gate,differential,suites,repro}/, the drivers beside them
Toolchain: Zig 0.17.1; every build and test run under systemd-run --user --scope -q -p MemoryMax=8G (4G for the
           single program runs), after rm -f src/gen/config.{h,c,o} and a 1-minute load below 2.0
```

## 1. Commits

Cherry-picked with `git cherry-pick -x`, upstream author and message kept; every pick applied without a
conflict (git reported "Auto-merging src/6model/reprs/VMArray.c" for the picks after the first, nothing to
resolve). Each area's C picks are followed by its Zig commit.

| area | upstream (branch tip) | on this branch | the port's commit |
|---|---|---|---|
| S | b2cbdc57c, 6ee35f98a, 5febdef32 (vmarray-self-splice-memmove) | 1ee33198f, 23e13f57c, 8ec451aa6 | c74f4306c VMArray: a self-splice as the fixed C; undefined-lines.txt empty |
| G | 52aa25019 (vmarray-size-overflow) | f7417f244 | 730da6877 VMArray: refuse a growth that wraps near 2**64 elements, as the fixed C |
| P | 007382664, 98a84053a, f8a955192 (vmarray-splice-guards) | a413f6c92, d4eefd67c, 32dae23af | 15a43ab00 VMArray: refuse the splices the fixed C refuses, with its messages |
| T | 27ebea0b8, fd53df2e0 (vmarray-stale-slots) | bf7aa193a, f044b7c4b | 2fc72ecfc VMArray: a rejected pop or unshift leaves the array, as the fixed C |
| B | 156957654, 2acff2df5, f3ff57945 (vmarray-buf-bounds) | 3e974e20b, a02b72734, 6775d4e32 | fa67271bc VMArray: read_buf and write_buf bounds as the fixed C |
| R | 40b448381 (vmarray-recompose) | 105684bcc | 607c25b36 VMArray: refuse recomposing a type to another element kind, as the fixed C |
| M | e9dee2a3e (vmarray-mark-presize) | d1746fc09 | 28c4cc3d0 gc: the worklist counts are 64-bit in the Zig collector too |
| N | 5d0367c85, 4410fecc0 | 5c3f435bb, 5cf04cb15 | (C only) |
| E | d218f764e, bf768a9cb | 4d0094926, df9c81440 | (C only) |
| O | 4bad6ad49 | 09936a267 | (C only) |
| D | edc33817c, 830eb45e2 | c35d54018, dc190be8f | (C only) |
| - | | | 282b04734 VMArray: explicit names in the code the cfix mirror added or touched (no behaviour change; the repository owner's naming rule, given mid-task) |
| - | | | b04b110f3 tools/bench/repr: drive what the C fixes made drivable; no recompose to another kind |
| - | | | d5999adfa docs: the REPRs section and the worklist row after the cfix mirror |

N, E, O and D are the ids of `.superpowers/sdd/2026-11-19-vmarray-c-fixes/task-5-final.txt` (present when
this task reached them), not the branch names. Their files (normalize.c, strings/ops.c, io/procops.c,
serialization.c) are C in both builds of the port (`build/sources.list` has no Zig for them).

## 2. What changed in the Zig, per area

Lines are those of the branch tip.

- **S** (`src/zig/6model/reprs/vmarray/elements.zig`). `copyElements` (624): the block path was already
  a `@memmove` (the documented difference from the C's overlapping memcpy, which the C fix removes); the
  element loop now runs from the last element down when `src == dest and d_offset > s_offset` (654-662),
  as the C's `backwards`. `asplice` (725): the offset-0 start adjustment is skipped when `from == root`.
  Doc comments that said the C is undefined there, or that the start adjustment is kept, are corrected.
- **G** (`storage.zig` `grow`, 169): after the `(n + 0x1000) & ~0xfff` rounding, `ssize < n` throws
  "Unable to allocate an array of <n> elements", before anything is changed, as the C.
- **P** (`elements.zig` `asplice`, 707-721; helpers `kindToElementsName` 358 and `spliceKindsFit` 370):
  after the offset check and before `enterSingleUser`, for a source with elements: not a VMArray ->
  "MVMArray: Can only splice from a VMArray, got a <REPR name>"; a kind without storage on either side
  (the source's REPR data read first, then the target's, as the C's `||`) -> "MVMArray: Unhandled slot
  type"; a pair of register kinds other than equal, STR into OBJ, int with uint -> "MVMArray: Cannot
  splice from an array of <kind> into an array of <kind>" with the C's names. The paths of
  `copyElements` that faulted or aborted on such sources stay (aslice cannot reach them either, its
  destination has the source's type) and their comments say so.
- **T** (`elements.zig`): `pop` (545) decrements `elems` after the register-kind check; `unshift` (572)
  stores into `start - 1` and only then moves `start` and increments `elems`. The front room made at
  `start == 0` before the check stays, as in the C. The module doc's list of side effects before a
  throw is updated.
- **B** (`elements.zig`): `writeBuf` (840-847) refuses `elem_size == 0` at the integer-type gate and
  compares `offset > elems or (elems - offset) * elem_size < count`; `readBuf` (872) checks
  `offset < 0 or offset > elems or (elems - offset) * elem_size < count` (no more `start` added). The
  kinds without storage: the Zig array never held a zero-byte block (it keeps `slots` NULL, the
  documented difference), so B3's write into one could not happen in it, but the throw is now at the
  same point with the same message.
- **R** (`serial.zig` `compose`, 271-292): the kind is worked out into a local (`specToReprData` on an
  OBJ-initialised `MVMArrayREPRData`) before anything is stored; then, with the C's first read through
  the REPR data pointer at that point, a type with an element type whose kind would change throws
  "MVMArray: Type <debug name> is already composed with another element kind"; then the element type
  (write barrier) and the kind. `assignElemType` (which faulted after the barrier for a NULL REPR data
  pointer) is gone: the fault is now at the `elem_type` read, where the C's is.
- **M** (`src/zig/gc/worklist.zig`, `collect.zig`, `vmarray/mark.zig`, `moar.zig`): translate-c gives
  the collector the header's new `MVMuint64` fields. `worklist.zig`'s layout check now says items at 8,
  alloc at 16, include_gen2 at 24, 32 bytes, and checks the field types (27-32); `presizeFor` takes
  `u64` (64) and the export `MVM_gc_worklist_presize_for` an `MVMuint64` (91); the eight per-phase debug
  logs of `collect.zig` print `items` with PRIu64 (302 ff.), as the C's GCDEBUG_LOG lines now do;
  `mark.zig` passes `elems` to the presize as it is (59; it truncated to the old MVMint32). The other
  readers (moar.zig's add helpers, `processWorklist`'s gen2count, roots.zig's count before a gen2 root's
  mark) take the field's type and needed only a comment change. Both collectors carry the widening: the C
  one by the pick, the Zig one by this commit; `-Dzig-gc=false` builds were not run (not part of the gate).

The one deliberate difference left (va-kind-differences.md section 3): for the six kinds without storage
the Zig array keeps `slots` NULL where the C holds `malloc(0)`'s block. The new throws for those kinds
(P2 in splice, B3 in write_buf) come before any allocation in both, so these two paths no longer reach
it. The fixes do not remove it elsewhere: `push`, `bind_pos` (index >= 0), `unshift`, `set_elems(n > 0)`
and a slice into such an array still grow first, and the C stores `MVM_malloc(8 * 0)` (or
`MVM_realloc(slots, 0)`) in `slots` before `zero_slots` throws "MVMArray: Unhandled slot type", while
the Zig array leaves `slots` as it was (NULL). Why that still cannot be seen from the VM, argued by
reading (not run): `ssize` and `elems` are set only after `zero_slots` in both, so they stay as they were
(0 for a fresh array); every operation that would read or copy the slots of such an array throws or
returns first (at_pos, pop and shift by kind or emptiness, serialize/deserialize, read_buf by its bounds,
write_buf, splice and slice by P2 and their bounds), copy_to copies nothing for `elems == 0`, the mark
and describe_refs do nothing for these kinds and unmanaged_size is `ssize * 0`, and the adopting sites
(encode, decode, normalize, I/O) refuse these kinds. The one place the pointer value itself leaves the
array is the one va-kind-differences.md section 3 already names: `MVM_nativecall_unmarshal_vmarray`
passes `slots + start * 0` to native code, NULL in the Zig array where the C passes the zero-byte block;
a failed push before that call is one more way to get there, not a new kind of difference.

## 3. Unit tests

All in `src/zig/6model/test/vmarray_elements_test.zig` but one in `src/zig/gc/test/worklist_test.zig`.
Throwing paths are new to repr-test: `childThrow` runs the call in a forked child (stdout and stderr on a
pipe, SIGSEGV default, non-dumpable, a 60 s alarm); the VM prints "Unhandled exception: <message>" and
exits 1, and an `atexit` handler prints the array's `elems start ssize` and live bytes (and, when set, a
type's REPR data), so a test checks message and state after the throw. The module doc says so.

| area | test | failing run before the Zig change (`cfix-mirror-raw/unit/<area>-before.log`) |
|---|---|---|
| S | "a splice from the array itself gives the splice from its clone, on the block and the element path" (replaces "... memmove for the copied kinds, the C's forward loop for STR and promoted OBJ", which pinned the forward copy for STR and gen2 OBJ) | `expected moar_c.struct_MVMString@..., found ...` |
| S | "a splice from the array itself at offset 0 leaves start alone: no shifted-off slot comes back, none is dropped" (T3 both directions, and shifted with count 2) | fails likewise (OBJ) |
| S | the twin-array test gains three self-splice steps (offset 0 with start > 0, overlapping at 2, count over elems): C against Zig under -Dzig-reprs=false (`S-after-creprs.log`, pass) | - |
| G | "growing to within 4096 of 2**64 elements throws instead of wrapping, and leaves the array" (I64, U8, OBJ; 2**64 - 1, - 4095, - 4096; - 4097 keeps the limit check's message; a shifted array) | child died of SIGSEGV |
| P | "a splice from a non-empty source that is not a VMArray throws before changing anything" | SIGSEGV |
| P | "a splice into or out of a kind without storage throws before changing anything" (the array made by a first compose over live elements) | SIGABRT |
| P | "a splice between kinds whose registers would be reinterpreted throws; the others copy" (the 73 refused of 144 pairs, messages and state; STR into OBJ) | "returned" (OBJ into STR) |
| P | changed: "where the C reads through NULL ..." drops its hash case (now a throw), keeps the NULL `from` | - |
| T | "a pop or unshift with the wrong register kind throws and leaves the array as it was" (every kind) | state `elems=2` where 3 was expected |
| B | "read_buf and write_buf compare the offset with elems first: ..." | "read 0 / returned" past the window |
| B | "write_buf on a kind without storage throws the integer-type message, even for 0 bytes" | "returned" |
| B | changed: "the kinds without storage: what does not throw ..." no longer calls writeBuf in-process (it throws now) | - |
| R | "a composed array type may not change its element kind; a failed compose changes nothing" | "returned", the element type replaced by an object type on an I64 array |
| M | worklist_test "the counts and the presize count are 64-bit: no wrap past 2**32 entries" (comptime type checks; a presize on counts set past 2**32 by hand) | against the widened header the old Zig does not compile: `worklist.zig` layout assert, `mark.zig` `@bitCast size mismatch` (`M-before.log`) |
| M | changed: every test comparing `items`/`alloc` with `u32`/`MVMuint32` now uses `u64` (in vmarray_elements_test.zig, moar.zig's tests, gc/test/roots_test.zig and gc/test/worklist_test.zig) | - |

Kept accidents of the C that tests or docs pinned and that are now gone: "a rejected pop has already
dropped the element" (rows 18c) and "a rejected unshift leaves the window one slot left" (19b) in
elements.zig's docs; the self-splice test's forward-copy expectation; row 32's "an Unsupported size
error leaves the new elem_type with the old kind" in serial.zig's doc. (row 32's throw cannot be driven
from a test: P6int and P6num refuse the widths first; the test says so.)

## 4. Harness (`tools/bench/repr/`)

- `undefined-lines.txt`: no entries, header kept and rewritten (the mechanism stays: with no entry every
  difference is exit 1; diff.sh's exit 3 path is unchanged and can only trigger on a listed line).
  `diff.sh`'s comments and the README say so.
- `memmove-model.py`: the offset-0 start adjustment is left out (the fixed asplice skips it for a
  self-splice, cfix-S.md section 5's patch), header says why and how to run it by hand; two new cases
  modelled (`shifted.over`, `shifted.over11`). On the gate's outputs all 372 `<kind>.selfsplice.*` lines
  of diff-nqp equal the model, on both sides (`differential/model-diff-nqp.txt`). Not modelled (named
  "accepted without a model check" if asked): Rakudo's own `.splice(..., @self)` lines and
  `<int type>.nqp.splice.self.front` (checked by hand in cfix-S.md section 5; the output is
  `0 1 2 3 4 5 2 3 4 5`).
- `vmarray-diff.nqp`, new `cfix_cases()` and additions (each a case campaign 8 left out because the C
  crashed; va-differential.md section 6):
  - `cfix.cross.<target>.from.<source>`: the reference kinds against OBJ, STR, I64, U64, I8, U8, N64,
    N32 in both directions (28 pairs; STR into OBJ and the same kind kept, the rest refused);
  - `cfix.<kind>.splice.fromhash.full`, `.badoffset`: a hash with an element as the source;
  - `cfix.<kind>.pop.rejected.regrow`, `cfix.<kind>.unshift.rejected.shifted` (with collections);
  - `cfix.<kind>.setelems.wrap.{-1,-4095,-4096,-4097}` on 9,000 slots;
  - `<kind>.buf.readint.shifted.beyond`, `<kind>.buf.readint{,4}.wrap.<offset>` at 2**61+1, 2**62+1,
    2**63-1, `<kind>.buf.writeint.wrap.<offset>` where offset + 8 is over the kind's size budget (inside
    it malloc would be asked for exabytes and the VM panics, so not driven);
  - `<kind>.selfsplice.shifted.{prepend,prepend20,replace}` for OBJ and STR too (they were excluded),
    and `shifted.over`, `shifted.over11` for every kind;
  - the `*.kind.*.state` lines of OBJ and STR now grow back over the slots too.
- `recomposed()` (R): it recomposed an int8 array type with a live array to 4- and 1-bit kinds, which now
  throws. Rewritten so that it still reaches the default arms on a non-empty array of a kind without
  storage: the array is an object array whose type is composed for the first time while it has elements
  (the route R leaves, R-first-compose-gap.nqp). Cases renamed `<kind>.recomposed.<op>` ->
  `<kind>.late.<op>` (same operations), plus `splice.into`, `splice.from`, `splice.self`,
  `splice.from.fresh`, `splice.into.fresh`, `writeint`, `writeint.past` (all reachable now). Retired:
  `recomposed.i8.u8`, `recomposed.i64.n64` (both refused now); added `recomposed.refused.<from>.<to>` over
  nine element kinds (81 cases: message, then the live and a new array used as the old kind) and
  `recomposed.same.kind`; `u4.recomposed.serialize` -> `u4.late.serialize`. `cross.splice.<int>.from.<num>`
  and the reverse (existing lines) now print the refusal on both sides.
- `vmarray-diff.raku`: `cfix.buf8.shifted.read.{last,past1,past4}`, `cfix.Buf[uint64|uint32|uint16].read.wrap`,
  `.write.wrap`, `cfix.shaped.{buf,strapp,intapp}` (a shaped native array as a splice source).
- Lines: diff-nqp 9,987 -> 10,447; diff-raku 2,475 -> 2,487; serial 196 and devirt 10 unchanged.

## 5. Gate

| item | how | result |
|---|---|---|
| fmt | `zig fmt --check src/zig build.zig build/zig tools/zig` | clean (`gate/fmt.txt`) |
| unit, default | `zig build unit-test --summary all` at b04b110f3 (docs uncommitted, not compiled) | 93/93 steps, 240/252 passed, 12 skipped; repr-test 63/63, gc-test 62 + 5 skip, hash-str-test 103 + 7 skip, shim-test 12 (`gate/unit-default.log`) |
| unit, C array | the same with `-Dzig-reprs=false` | 93/93, 240/252, 12 skipped, the same per root (`gate/unit-creprs.log`) |
| unit, gc-debug | the same with `-Dgc-debug=1` | 93/93, 245/252, 7 skipped; gc-test 67/67 (`gate/unit-gcdebug.log`) |
| exports | `nm -D --defined-only <P>/lib/libmoar.so \| awk '{print $3}' \| sort` | 2,850 names on each, c = n, and equal to `va-prefixes-raw/exports-base.txt`: no export added or removed (`build/exports-*.txt`) |
| differential | `tools/bench/repr/diff.sh --base=/tmp/claude-1000/vf-c-base --head=/tmp/claude-1000/vf-n-base --out=/tmp/claude-1000/vf/diff` (2026-11-19 20:42:48-20:47:07, load 1.24 at start) | **exit 0**: "identical (3 runs a side; lines: diff-nqp/spesh 10447 diff-nqp/nospesh 10447 diff-raku/spesh 2487 diff-raku/nospesh 2487 serial/spesh 196 serial/nospesh 196 devirt/spesh 10 devirt/nospesh 10; cross-read identical)"; every run's stderr empty, each side mapped its own libmoar (`differential/`) |
| serialization | part of diff.sh: `serial` outputs byte-identical, both cross-reads equal their expectation | identical |
| make test | `cfix-mirror-raw/maketest-driver.sh cfix-mirror-raw/suites` (va-maketest-driver.sh re-pointed at vf-*): `make test` in the nqp checkout (41e7210ba) and the rakudo checkout (042608fb82) with LD_LIBRARY_PATH=<prefix>/lib, after a probe that the runner maps that libmoar | nqp 150 files / 13,746 tests PASS on both; rakudo 599 / 11,162, FAIL on both in t/04-nativecall/02-simple-args.t only (tests 17-18, Wstat 512); per-file lists c = n and equal to the port's before this branch (`va-suites-raw/make-test/*-n-base.list`, -c- too) |
| reproducers | `cfix-mirror-raw/run-all-port.sh -p vf-c-base -o .../cfix-mirror-raw/repro`, then `-p vf-n-base` (21:06, loads 1.72 and 1.99), compared by `cfix-mirror-raw/cmp-repro.sh` (`repro-cmp.txt`) | all 62 program/case runs: C array = Zig array (normalised); 55 equal the output of their own area's fix branch, the other 7 equal the R branch's output, as they must (below) |

Prefix sizes: `.text` 2,382,021 (c) and 2,374,357 (n) bytes, files 11,338,064 and 11,330,640 (at the fix
wave: 2,380,325 and 2,372,325).

**Suites, in detail** (`suites/summary.tsv`): nqp c-base 20:54:17 (load 1.59) and n-base 20:54:36 (1.96),
exit 0, 18 s and 19 s; rakudo c-base 20:58:11 (1.39) and n-base 21:03:45 (1.58), exit 2, 155 s and 154 s.
The rakudo Test Summary Reports (`suites/rakudo-*.summary`, wallclock line dropped) are identical: the
pre-existing 02-simple-args.t 17-18 and the two TODO-passed files (`t/09-moar/Line_Break__LineBreak.t`
1-2, `t/12-rakuast/xx-fixed-in-rakuast.rakutest` 76), as in va-suites.md. nqp's `t/hll/0[234]-*.t` read
"notok" in the list on both sides (skipped by their own plan, as before). The nqp and rakudo checkouts'
`git status --short` was empty before and after.

**Reproducers, in detail.** How they were run on the port: `cfix-repro/run.sh` and `run-all.sh` are
written for upstream prefixes and upstream nqp and rakudo; `cfix-mirror-raw/run-port.sh` and
`run-all-port.sh` are copies with two changes only (their headers and `diff` against the originals say
so): the runners are the port's (`tune-zig-prefix`'s nqp-m, the rakudo checkout's rakudo-m with
`RAKUDO_NO_PRECOMPILATION=1`, as diff.sh runs them; upstream's bytecode is not for the port's moar), and
only the `-p` mode (no ASAN prefix exists for the port). Programs, cases, timeouts and memory caps are
run-all.sh's, unchanged; M1 and D1 are not run, as there. Each output's first line is the probe:
every run mapped its own prefix's libmoar.

`cmp-repro.sh` normalises as the area records' scripts did (probe and run lines, addresses, PIDs,
prefix names, 12+-digit numbers), and also the runner's install path in nqp backtraces (`cfix-base/share`
versus `tune-zig-prefix/share`: O1's two backtraces). The expected output of a program is its area's
fix-branch output (`cfix-<A>-raw/**/<x>.cfix-<A>.txt`; T3-* belongs to S; X1 to R). Result:
- C array against Zig array: equal in all 62.
- 55 equal their area's fixed output, including every program the records list as noise on an
  unfixed build (B1's `.raku` past reads and O1's element 99 are fixed here, so they no longer vary).
- 7 differ from their area's output, and equal the output of the R branch for the same program
  (`cfix-R-raw/repro/<x>.cfix-R.txt`): `B3-writeint-no-storage-kind.nqp`,
  `B3-write-no-storage-state.nqp live`, `P2-splice-no-storage-kind.nqp {source,target}`,
  `P2-splice-no-storage-same-kind.nqp {same-fit,same-grow,empty-into}`. Each makes its array of a kind
  without storage by recomposing a type that has an element type, which R refuses: the program now dies
  at that compose with "MVMArray: Type  is already composed with another element kind" (exit 1), as on
  cfix-R. The B3 and P2 paths themselves stay covered by `B3-write-first-compose.nqp`,
  `B3-write-no-storage-state.nqp fresh` (both "fixed" here), the unit tests and diff-nqp's
  `<kind>.late.*` lines.

## 6. Pending, deviations, notes

- Nothing pending: all eleven areas are picked; N, E, O and D from task-5-final.txt.
- Deviation: the gate's unit-test runs were taken at b04b110f3 with the docs edit not yet committed
  (the commit after only changes docs/zig-build.md); the library and the tests are those of the tip.
- Deviation: no AddressSanitizer runs (the port has no ASAN build); the reproducers' ASAN halves were
  not run.
- The naming rule (explicit snake_case names in new or touched code) arrived after S, G and P were
  committed; 282b04734 renames in one commit, as instructed, and the unit tests were run after it.
- One harness run of vmarray-diff.nqp on an old prefix (va-n-base, to check the program parsed) crashed
  as the old arrays do on `cfix.cross.obj.from.i64`; it was run without `ulimit -c 0` by mistake, and
  systemd-coredump stored that core (2026-11-19 20:27:01, pid 2549307, 9.4M; nothing in the tree).
</content>
</invoke>

## 7. Final fix wave (after the reviews)

P commit 0d759048a (comment and tests only; nothing compiled into libmoar changes, so the gate prefixes,
the differential, the suites and the reproducers were not re-run):
- `storage.zig` `grow`'s doc said a wrapped size throws "before anything is changed"; with `start > 0`
  and `n + start > ssize` (no wrap there) `setSize` has already moved the elements to start 0, as the C
  does. Now: before anything is reallocated, the elements unchanged. The G test pins it: a shifted
  array (start 3) grown to 2**64 - 4095 throws "Unable to allocate an array of 18446744073709547521
  elements" and is left with start 0, elems 8,997, ssize 12,288 and the same element bytes.
- repr-test's `composeWith` roots its two types and both info hashes (temp roots, a defer pops them).
- The gcMark test's `alloc` comparison is `u64` (it was the one `u32` left among the items/alloc
  comparisons of section 3).
- Section 2's last paragraph now gives the wider argument for the NULL-slots difference (above).

Unit tests at 0d759048a (`gate/wave-unit-*.log`; zig fmt --check clean): default 93/93 steps, 240/252
passed, 12 skipped; -Dzig-reprs=false 240/252, 12 skipped; -Dgc-debug=1 245/252, 7 skipped; repr-test
63/63 on all three (the new case is inside the existing G test). The last two runs show "dirty 1": the
traces submodule with this record's edit, not compiled.

