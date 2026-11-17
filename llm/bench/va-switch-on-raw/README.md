# va-switch-on-raw

Raw material of `../va-switch-on.md`.

| File | What |
|---|---|
| `builds.tsv` | `va-prefixes-raw/build.sh`'s record of every prefix build so far; the last two rows are va-n-base and the rebuilt va-c-base at a806a9da3 |
| `libmoar-md5.txt` | the old va-c-base library (6b45869d9), the rebuilt one and va-n-base's |
| `diff-1.log`, `diff-1.when` | stderr of the base/head `diff.sh` run (exit 3, 498 s) |
| `diff-1/load.log`, `diff-1/libmoar.log` | the load before each of its 52 runs; the library each side mapped through each runner |
| `diff-1/undefined-<program>-<setting>.txt` | every differing line with both values |
| `diff-1/model-<program>-<setting>.txt` | `memmove-model.py`'s verdict on each of the head's differing lines |
| `diff-1/head-*.out` | the head's outputs (run 1) of diff-nqp (both settings), diff-raku and serial, and the cross-reads; the base's equal `../va-differential-raw/` |
| `tamper/` | the `--compare-only` checks of the diff.sh fixes (`run.sh`, helpers, one log per case, `results.txt`) |
| `t7-nqp-test.sh`, `nqp-test/` | nqp `make test` per side: summary, libmoar probe, tail of the output, sorted per-file verdicts |
| `t7-heap.sh`, `heap/` | the heap-snapshot run per side: summary and stderr (the snapshots themselves are not kept) |
| `waitload.sh` | the load gate the scripts call |
| `unit-test-default.txt`, `unit-test-switches.txt` | `zig build unit-test --summary all` at the default, `-Dzig-reprs=false` and `-Dgc-debug=1` |
