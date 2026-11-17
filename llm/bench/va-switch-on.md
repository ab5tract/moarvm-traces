# va switch-on: the first whole-program runs of the Zig VMArray

```
Head:     /tmp/claude-1000/va-n-base  (default options, so -Dzig-reprs=true: the Zig array, VMArray.c not compiled)
Control:  /tmp/claude-1000/va-c-base  (-Dzig-reprs=false: the C array), rebuilt at the same commit
MoarVM:   zig-vmarray at a806a9da3 ("VMArray: serialization, compose, spesh and JIT hooks; the array goes Zig"),
          on c139c3aff (the diff.sh fixes below)
Runner:   tools/bench/repr/diff.sh at c139c3aff; nqp at the checkout of va-prefixes.md; rakudo/rakudo-m
Raw:      va-switch-on-raw/
Hygiene:  every build and run after the 1-minute load was below 2.0 (polled every 60 s), pgrep -a -x raku / moar
          empty before each long run, builds and runs under systemd-run --user --scope -q -p MemoryMax=8G
```

## 0. The instrument, settled first

Before any base/head run, `diff.sh` got the two fixes deferred from Task 2's
review, in their own commit (c139c3aff):

- Exit 3 now also requires that the head prints, on each listed differing
  line, what memmove gives: `tools/bench/repr/memmove-model.py`, a copy of the
  model of `va-differential-raw/selfsplice.py` extended to start from given
  slots (so it covers `<kind>.selfsplice.twice`, two splices) and to render a
  whole line as `d()` prints it. A head value off the model is exit 1. The 19
  diff-raku entries have no model and are named in the output as "accepted
  without a model check". Validation on the control's recorded output: the
  model reproduces the 150 self-splice lines where copy order does not matter
  (SHA-1 forms included) and differs on exactly the 176 listed diff-nqp lines
  plus the 16 STR cases (forward copy, defined).
- A difference that is only a missing final newline no longer exits 1
  silently; `first_diff` names the file without it.

Tamper checks with `--compare-only` on copies of the control's
self-comparison (`va-switch-on-raw/tamper/`, `results.txt`): untouched 0;
head without final newline 1 (named); one head run without it 2 (named);
listed lines set to the model 3; one listed line off the model by one element
1 (`MISMATCH` printed with both values); model lines plus a changed diff-raku
line 3, that line named as not model-checked. `sh -n` clean.

## 1. Prefixes

From `va-prefixes-raw/build.sh "va-n-base" "va-c-base -Dzig-reprs=false"`
(`va-switch-on-raw/builds.tsv`, the last two rows):

| prefix | built (completion) | options | load before | `moar --version` |
|---|---|---|---|---|
| va-n-base | 2026-11-17 12:39:36 CET, 48 s | (defaults) | 1.63 | This is MoarVM version 2026.09-324-ga806a9da3 built with JIT support |
| va-c-base | 2026-11-17 12:41:17 CET, 41 s | `-Dzig-reprs=false` | 1.56 (after waits at 2.12-2.29) | the same |

va-c-base was rebuilt (it had been built at 6b45869d9) because this task
changed files a `-Dzig-reprs=false` build compiles: `src/zig/root.zig` (the
import inside the comptime-false `zig_reprs` block) and `build/sources.list`
(the section that build leaves out). The rebuilt library has the old one's
size and `.text` size (2,380,325 bytes) and the same export list; its bytes
differ, in `.rodata` (128,401 bytes), `.rela.dyn` and 32 bytes of `.text`,
consistent with the version string 311-g6b45869d9 -> 324-ga806a9da3 moving
merged strings (`libmoar-md5.txt`). Head and control are now same-commit.
va-c-oracle and va-c-stress were not touched.

- Exports: `nm -D --defined-only <P>/lib/libmoar.so | awk '{print $3}' | sort`
  gives 2,850 names on both, identical, and identical to
  `va-prefixes-raw/exports-base.txt`.
- The ten array symbols are defined (`T`) in va-n-base: `MVMArray_initialize`,
  `MVM_VMArray_at_pos`, `_at_pos_s/_i/_u/_n/_o`, `_bind_pos`, `_push`,
  `_find_fast_impl_for_jit`. VMArray.c is not linked (both would be
  duplicate definitions). va-n-base `.text` is 2,372,325 bytes (8,000 fewer
  than the control), file 11,328,016 bytes.

## 2. The differential: exit 3, memmove where the C is undefined

    tools/bench/repr/diff.sh --base=/tmp/claude-1000/va-c-base \
        --head=/tmp/claude-1000/va-n-base --out=<workspace>/diff-1

2026-11-17 12:41:56 CET, 1-minute load 0.92-1.99 before the 52 runs, as
`diff-1/load.log` records it (each run waited for < 2.0; corrected at Task 8:
this line first gave 1.15-2.14, which mixed in the loads of the driver's own
stderr progress lines), **exit 3 after 498 s**:

> differs only in undefined self-splice lines, and equals memmove there (390
> differing lines over the programs and settings, all listed in
> tools/bench/repr/undefined-lines.txt; 352 of them equal to
> memmove-model.py's memmove result, 38 accepted without a model check,
> named below; everything else and the cross-read identical).

- Both sides mapped their own library through both runners (`libmoar.log`);
  every program repeated three times on each side in each setting; no run
  wrote to stderr.
- diff-nqp: in each setting exactly the 176 listed lines differ, every one of
  them (`undefined-diff-nqp-*.txt`), and in every one the head prints the
  memmove model's value (`model-diff-nqp-*.txt`: 176 `memmove:` each). The
  other 9,811 lines are byte-identical, including every `DIED` message, every
  `*.kind.*.state`, `*.limit.*`, `*.mega.*` and `gc.*` line.
- diff-raku: in each setting exactly the 19 listed lines differ; accepted
  without a model check by `diff.sh`. Checked by hand afterwards: each head
  value is the memmove result of its splice (`nqp::splice($a, $a, 3, 0)` on
  six elements gives `v[0..2] v v[3..5]`; `array.reified.splice` gives
  `1 7 1 7 8 4 5 8 4 5` from `1 7 8 4 5` at offset 2) where the control
  printed a forward copy. This check takes the spliced-in run from the head's
  own line, so it shows the memmove shape, not the original values; the
  other 2,456 lines, which include the arrays' contents before the splice in
  the other cases, are identical.
- serial: identical bytes on both sides in both settings (196 lines, the 65
  cases' hex, string heaps and round trips; the base output also equals the
  recorded `va-differential-raw/serial.out`).
- Serialization cross-read: each side `--read`s the other's output and prints
  exactly the writer's `.roundtrip` contents, both settings ("cross-read
  identical").
- devirt: identical (the two JIT fast functions' "Index out of bounds").
- The control printed what Task 2 recorded (`diff-nqp-spesh.out`,
  `diff-raku.out` equal byte for byte).

So the Zig array differs from the C array only where the C's result is
undefined (memcpy over overlapping ranges), and there it gives memmove's.
**Per the Task 2 ruling this is recorded and put to the user; it is neither a
pass nor a failure.**

## 3. nqp make test, per side

In the nqp checkout, the same command per side (`va-switch-on-raw/t7-nqp-test.sh`):
`LD_LIBRARY_PATH=<P>/lib make test`, caller's MVM_*/RAKUDO_*/NQP_*/RAKU_*/PERL6*/RAKULIB removed,
after a probe that `./nqp-m` maps `<P>/lib/libmoar.so`.

| side | start | load | exit | time | result |
|---|---|---|---|---|---|
| base (va-c-base) | 2026-11-17 12:50:56 | 0.87 | 0 | 18 s | Files=150, Tests=13746, Result: PASS |
| head (va-n-base) | 2026-11-17 12:51:14 | 1.18 | 0 | 18 s | Files=150, Tests=13746, Result: PASS |

Each run recompiled `NQPP5QRegex.moarvm` first (the Makefile considers it out
of date), the same on both. The 150 per-file verdict lines, sorted, are
identical (`nqp-test/*-verdicts.txt`; three files skipped on both, by the
tests' own plan).

## 4. Heap snapshot (`describe_refs` in a whole run)

`LD_LIBRARY_PATH=<P>/lib rakudo-m --profile=heap --profile-filename=<out> -e 'my @a = 1..1000; my int @b = 1..1000; say @a.elems + @b.elems'`
(`va-switch-on-raw/t7-heap.sh`), 2026-11-17 12:51:57 and 12:51:58, load 0.86:
both exit 0, print `2000`, and write a snapshot (control 2,161,848 bytes,
head 2,161,684 bytes); stderr holds only Rakudo's deprecation note for
`--profile-filename` and the "Heap snapshot written to" line, on both.

## 5. Unit tests at the code commit

`zig build unit-test --summary all` (`unit-test-default.txt`,
`unit-test-switches.txt`): default (the Zig array) 93/93 steps, 224/236 tests
passed, 12 skipped (repr-test 48/48); `-Dzig-reprs=false` 224/236, 12
skipped; `-Dgc-debug=1` 229/236, 7 skipped. The vtable test passes on both
switch settings: the Zig table dumps exactly as `vmarray_vtable_c.tsv`.
