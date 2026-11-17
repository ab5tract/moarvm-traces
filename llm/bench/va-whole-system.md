# va whole-system check: an nqp build's 45 .moarvm files, byte-identical under the C array twice and under the Zig array

```
va whole-system record (spec 7 item 3; run at the final review's fix wave, 2026-11-17)
MoarVM:      libmoar of zig-vmarray 584d21d02 on both sides: /tmp/claude-1000/va-c-base (-Dzig-reprs=false, the
             C array) and /tmp/claude-1000/va-n-base (defaults, the Zig array), both rebuilt at that commit
             (va-fix-wave.md, C2)
nqp:         checkout at 41e7210ba (zig-hash-strategies), `git status --short` empty before and after
Driver:      va-whole-system-raw/build-nqp.sh NAME PREFIX, run as c1 and c2 (va-c-base) and n1 (va-n-base), in that
             order; va-whole-system-raw/compare.sh A B for the pairs
Raw:         va-whole-system-raw/{c1,c2,n1}/ (info.txt: prefix, libmoar SHA-256 of source and copy, moar --version,
             nqp commit, make start/end and load; probe.txt; configure.log; make.log; sha256.txt of every .moarvm),
             cmp-c1-c2.txt, cmp-c1-n1.txt, cmp-c2-n1.txt (one line per file), driver.log
```

The spec's wording: "As a whole-system check, the builder tries comparing
the `.moarvm` files of an nqp build made with each moar; this counts only if
the control repeats itself byte for byte, and if it does not, that is
recorded and the per-kind comparison stands alone." It was placed at Task 7
and not attempted there or at Task 8; it was run here, at the fix wave.

## How each build was made

Each build, one at a time, at the same two paths, so that nothing that embeds
a path (the nqp configuration, the runner) can differ between builds:

1. `/tmp/claude-1000/va-ws/moar`: a `cp -a` copy of the side's prefix. The
   copy's libmoar.so has the source prefix's SHA-256 (`info.txt`:
   f48899c1... for va-c-base, 97fbb7af... for va-n-base). The copied `moar`
   finds it first through its RUNPATH (`$ORIGIN/../lib:<original prefix>/lib`).
2. `/tmp/claude-1000/va-ws/nqp`: a `cp -a` copy of every top-level entry of
   the nqp checkout except `MoarVM` and `.git`: Configure.pl runs git (its
   submodule update) only where `.git` exists, so nothing could touch the
   checkout or a remote; `git describe` finds no repository either, the same
   for all three builds.
3. In the copy, with `MVM_*`, `NQP_*`, `RAKUDO_*`, `RAKU_*`, `PERL6*`,
   `RAKULIB` and `LD_LIBRARY_PATH` removed from the environment:
   `perl Configure.pl --backends=moar --with-moar=/tmp/claude-1000/va-ws/moar/bin/moar --prefix=/tmp/claude-1000/va-ws/moar`
   ("Found ... moar version 2026.09-332-g584d21d02, which is new enough"),
   `make clean`, then, at 1-minute load below 2.0,
   `systemd-run --user --scope -q -p MemoryMax=8G make`: a full stage 1 and
   stage 2 build (`make.log`), no `make install`.
4. Probe: the built `./nqp-m` prints the libmoar.so it maps
   (`/proc/self/maps`): `/tmp/claude-1000/va-ws/moar/lib/libmoar.so` in all
   three builds, which is the copy of that build's side.
5. Every `.moarvm` under the copy is kept with its relative path, and
   hashed.

| build | side | make start | load before (1/5/15 min) | make | .moarvm files |
|---|---|---|---|---|---:|
| c1 | va-c-base (C array) | 2026-11-17 16:53:19 CET | 0.66 1.40 1.24 | exit 0, 18 s | 45 |
| c2 | va-c-base (C array) | 2026-11-17 16:53:37 CET | 0.90 1.41 1.24 | exit 0, 18 s | 45 |
| n1 | va-n-base (Zig array) | 2026-11-17 16:53:56 CET | 1.22 1.45 1.26 | exit 0, 17 s | 45 |

The 45 files: 11 in `gen/moar/stage1`, 11 in `gen/moar/stage2`, 12 at the
top (11 copies of the stage 2 files and `NQPP5QRegex.moarvm`), and the 11
bootstrap files of `src/vm/moar/stage0`, which are inputs (equal to the
checkout's, unchanged by the build). So 23 distinct files are produced by
the build; the comparison covers all 45.

## Result

| pair | same | differ | only in one |
|---|---:|---:|---:|
| c1 vs c2 (control vs control) | 45 | 0 | 0 |
| c1 vs n1 (control vs Zig) | 45 | 0 | 0 |
| c2 vs n1 (control vs Zig) | 45 | 0 | 0 |

(`cmp -s` per file; the three `sha256.txt` lists are equal.)

**Verdict.** The control repeats: two nqp builds under the C array give
byte-identical `.moarvm` files, all 45. So the check counts, and under the
Zig array the same build gives the same 45 files, byte for byte. That is
one repeat of the control and one build per side, at one commit of nqp, with
the moar at its defaults (spesh and the JIT on); it shows that nothing the
array does while nqp compiles itself (its own serialization contexts
included) changes a byte of the output, for this build. It is not a test of
the array's kinds one by one: the per-kind serialization comparison
(`va-differential-final.md`, `vmarray-serial.nqp`) stays the one that covers
every kind.

An aside, not a controlled comparison: the nqp checkout's own top-level
files (built earlier against `tune-zig-prefix`, a different moar at a
different prefix path) equal the copies' in 5 of 12, which is why all three
builds here used the same paths.
