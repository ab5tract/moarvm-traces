# va differential, final: exit 3, every listed line equal to the memmove model

```
Command:   tools/bench/repr/diff.sh --base=/tmp/claude-1000/va-c-base --head=/tmp/claude-1000/va-n-base \
               --out=/tmp/claude-1000/va/t8/diff
When:      2026-11-17 13:32:33 CET, 317 s; 1-minute load 1.14-1.94 before the 52 runs (load.log; each run waited
           for < 2.0)
MoarVM:    zig-vmarray at bea13d101 (diff.sh and memmove-model.py as of bfebdc43d); both prefixes built at 472cf7e92
           (va-prefixes.md, Task 8)
Runners:   /tmp/claude-1000/tune-zig-prefix/bin/nqp-m, /home/longwalker/code/raku/x.core/zmoarz/rakudo/rakudo-m
Raw:       va-differential-final-raw/ (diff.log: the script's whole stderr; libmoar.log, load.log, undefined-*.txt,
           model-*.txt; outputs.sha256: the SHA-256 of every output file, 28 MB not kept); tamper/ (the checks of
           the instrument fixes)
```

## The instrument, first (MoarVM bfebdc43d)

The three fixes deferred from Task 7's review, made before the prefixes were
built:

- `memmove-model.py` now models the 19 diff-raku listed lines:
  `<type>.nqp.splice.self` / `<type>.splice.self` (`nqp::splice($a, $a, 3, 0)`
  on the six values each type's section starts from: 0..5, 0.5..5.5, 1..6)
  and `array.reified.splice` (`nqp::splice(b, nqp::list(7, 8), 1, 2)` on
  1 2 3 4 5, then `nqp::splice(b, b, 2, 0)`). The model starts from those
  known values, not from the head's own line. No listed line is accepted
  without a model check any more.
- The model refuses a case name printed twice in the output, or a NAME given
  twice (exit 64; diff.sh then exits 1); its own case table is built through
  the same check.
- `diff.sh --compare-only` deletes the `undefined-*.txt` and `model-*.txt`
  files of an earlier pass before writing its own.

Tamper checks on copies of Task 7's run outside the repository
(`tamper/results.txt`): untouched 3 (390 of 390 model-checked); a wrong value
on a diff-raku listed line 1 (MISMATCH named); stale model/undefined files
deleted, verdict unaffected (the pre-fix diff.sh counted the stale line);
a duplicated case line 1. On Task 7's outputs the model gives memmove on all
19 diff-raku lines of the head and MISMATCH on all 19 of the C base, in both
settings. `sh -n` clean.

## Result: exit 3

> differs only in undefined self-splice lines, and equals memmove there (390
> differing lines over the programs and settings, all listed in
> tools/bench/repr/undefined-lines.txt; 390 of them equal to
> memmove-model.py's memmove result, 0 accepted without a model check, ...)

- Each side mapped its own library through both runners (`libmoar.log`);
  every program repeated three times per side and setting; no run wrote to
  stderr.
- diff-nqp: 176 listed lines differ per setting, each `memmove:` in
  `model-diff-nqp-*.txt`; diff-raku: 19 per setting, each `memmove:` in
  `model-diff-raku-*.txt`. Every other line of every program, the serialized
  bytes, the cross-reads and devirt are identical.
- Every output file of this run is byte-identical to the corresponding file
  of Task 7's run at a806a9da3 (both sides, all programs, settings and runs,
  and the cross-reads): the changes since (the repr.zig null slot, tests,
  instruments) changed no output.
- The base (C) output still equals Task 2's recorded control
  (`va-differential-raw/diff-nqp-spesh.out`).

**Verdict: exit 3 with every listed line model-checked**, the outcome the
controller's ruling expects. Neither a pass nor a failure: the Zig array
differs from the C array only where the C copies overlapping ranges with
`memcpy` (undefined), and there it gives memmove's result. It goes to the
user (plan Outcome).
