# va-differential-raw

Raw material of `../va-differential.md`: what the C array (`/tmp/claude-1000/va-c-base`)
prints for the programs of `tools/bench/repr/`, and the coverage measurement.

| File | What |
|---|---|
| `diff-nqp-spesh.out`, `diff-nqp-nospesh.out` | `vmarray-diff.nqp`, run 1 of the base side in each setting (the three runs are identical; the two settings differ in the 66 `*.mega.*` lines) |
| `diff-raku.out` | `vmarray-diff.raku` (identical in both settings) |
| `serial.out` | `vmarray-serial.nqp` (identical in both settings) |
| `serial-read.out` | `vmarray-serial.nqp --read=` of that output, by the control (identical in both settings) |
| `devirt.out` | `vmarray-devirt.nqp` (identical in both settings) |
| `diff-self.log`, `load.log` | stderr of the `diff.sh` run of section 1, and the 1-minute load before each of its 52 runs |
| `selfsplice.py`, `selfsplice.tsv` | section 5: each small `selfsplice` case against a memmove model and a forward-copy model of `asplice` (`python3 selfsplice.py diff-nqp-spesh.out`) |
| `coverage/cov.py`, `cov.sh` | the gdb script (a breakpoint on every line of `VMArray.c` with code, disabled at its first hit) and its runner, as run from the session's scratch directory against `/tmp/claude-1000/va-c-syms` (`cov.sh <name> <program> ENV=VAL...`; `s1.out` beside it was the control's serial output) |
| `coverage/cov-<program>-<setting>.txt` | per run: `HIT <line>` / `MISS <line>` for the 541 lines with code |
| `coverage/sites.py`, `sites.tsv` | per throw site: function, message, the runs that hit it (`no code`: merged by the compiler with another arm); per function: lines with code, lines hit |
| `coverage/messages.py`, `messages.tsv` | per message format: number of sites, number of output lines carrying it, an example case |
| `coverage/bt.py`, `devirt-hits.txt` | breakpoints on lines 1568 and 1592 only, printing each hit; `vmarray-devirt.nqp` three times with `MVM_SPESH_BLOCKING=1`, three times with neither variable, once with `MVM_SPESH_DISABLE=1` |

`va-c-syms` is a scratch prefix (`-Dzig-reprs=false -Dstrip=false`, built with
`../va-prefixes-raw/build.sh "va-c-syms -Dzig-reprs=false -Dstrip=false"`); it
is not one of the campaign's prefixes and nothing else uses it.
