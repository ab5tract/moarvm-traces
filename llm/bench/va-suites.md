# va suites: unit tests, make test, stress runs, heap snapshot, devirt breakpoints (Task 8, Step 3 and rulings 3, 5)

```
MoarVM:    zig-vmarray at bea13d101 (unit tests); prefixes built at 472cf7e92 (va-prefixes.md, Task 8)
nqp:       the checkout at <MoarVM>/.. (git status --short empty before and after); rakudo: <MoarVM>/../..
           (empty before and after); roast fb1d87214
Hygiene:   1-minute load below 2.0 before every build and run (polled every 60 s; values below), no raku or moar
           process before each stage, everything under systemd-run --user --scope -q -p MemoryMax=8G; the caller's
           MVM_*, RAKUDO_*, NQP_*, RAKU_*, PERL6* variables and RAKULIB removed and a libmoar probe before every
           make test, stress and heap run
Raw:       va-suites-raw/{unit,make-test,stress,heap,devirt}/
```

## 1. MoarVM's unit tests, both switch settings

`zig build unit-test --summary all` and `zig build test --summary all`, each
after `rm -f src/gen/config.*` and the load wait, at bea13d101
(`va-suites-raw/unit/`; `run.sh` is the wrapper of the two
`-Dzig-reprs=false` runs, the default runs used the same steps inline):

| command | started (load) | result |
|---|---|---|
| `zig build unit-test` (the Zig array) | 13:25:15 (1.59) | exit 0; 93/93 steps; 227/239 tests passed, 12 skipped |
| `zig build unit-test -Dzig-reprs=false` (the C array) | 13:29:11 (1.32) | exit 0; 93/93 steps; 227/239 passed, 12 skipped |
| `zig build test` | 13:28:27 (1.39) | exit 0; 107/107 steps (`moar --version`, nqp stage0 smoke; repr-test cached from the run above) |
| `zig build test -Dzig-reprs=false` | 13:32:15 (1.77) | exit 0; 107/107 steps (1 s: the library of the run above, cached) |

Per root, the same on both settings: repr-test 51 pass (51 total),
gc-test 61 pass 5 skip, hash-str-test 103 pass 7 skip, shim-test 12 pass;
the build helpers' roots cached (unchanged inputs). The 12 skips are
gc-test's 5 and hash-str-test's 7, as at every earlier task. repr-test grew
from Task 7's 48 by three tests this task added: P6int's C table dumps every
default slot as `default` (a swap of same-typed defaults would show), a slot
declared `null`, and the paper check (P6int and MVMCode declared for
`repr.Ops` dump as their C tables). With `-Dzig-reprs=false` the vtable test
compares the C table with the recorded dump; by default the Zig table.

## 2. nqp and rakudo make test

`sh traces/llm/bench/va-maketest-driver.sh /tmp/claude-1000/va/t8/ev/suites`
(second stage of va-evidence-master.sh; `make-test/summary.tsv`, per-file
verdict lists `*.list`, the Test Summary Reports `*.summary`, probes
`*.probe`: each run mapped its own prefix's libmoar.so):

| project | prefix | finished | load before | exit | Files / Tests | Result |
|---|---|---|---:|---:|---|---|
| nqp | va-c-base | 13:54:42 | 1.05 | 0 | 150 / 13746 | PASS |
| nqp | va-n-base | 13:55:00 | 1.03 | 0 | 150 / 13746 | PASS |
| rakudo | va-c-base | 13:57:16 | 1.14 | 2 | 599 / 11162 | FAIL (1 file) |
| rakudo | va-n-base | 14:01:15 | 0.85 | 2 | 599 / 11162 | FAIL (1 file) |
| rakudo | va-c-stress | 14:05:40 | 0.81 | 2 | 599 / 11162 | FAIL (1 file) |
| rakudo | va-n-stress | 14:10:06 | 0.91 | 2 | 599 / 11162 | FAIL (1 file) |

- The per-file verdict lists are identical between c and n for each pair
  (nqp base; rakudo base; rakudo stress), and the rakudo base list equals the
  stress list and `gc-final-suites-raw/rakudo-c-base.list`.
- rakudo: the one failing file on all four is the pre-existing
  `t/04-nativecall/02-simple-args.t`, subtests 17-18 (Wstat 512), as under
  every prefix since Campaign 4 (`ngc-suites.md`); the Test Summary Reports
  of c and n are identical line for line (wallclock line excluded), with the
  same two TODO-passed files (`t/09-moar/Line_Break__LineBreak.t` 1-2,
  `t/12-rakuast/xx-fixed-in-rakuast.rakutest` 76).
- nqp: the three `t/hll/0[234]-*.t` read "notok" in the list on both sides:
  skipped by their own plan, as before.

**Verdict: same names and verdicts per pair, zero new failures: pass.**

## 3. crc-getter under the stress prefixes

`crc-getter.raku --volume=100000 --runs=5` (spesh and precompilation on),
three runs a side alternating c, n (third stage; `stress/runs.tsv`, `*.time`
from timev.py, `*.out`):

| run | va-c-stress: exit, wall, peak RSS kB, load | va-n-stress: exit, wall, peak RSS kB, load |
|---:|---|---|
| 1 | 0, 8.48 s, 271764, 0.93 | 0, 7.52 s, 242508, 1.10 |
| 2 | 0, 7.45 s, 246096, 1.17 | 0, 7.50 s, 242592, 1.30 |
| 3 | 0, 7.62 s, 251244, 1.36 | 0, 7.58 s, 252596, 1.54 |

Every run exits 0 and prints its five `RUN n:` lines. (Single runs with a
512 KiB nursery and gc-debug checks: a correctness run, not a timing gate.)
**Pass.**

## 4. Heap snapshot (ruling 5)

`rakudo-m --profile=heap --profile-filename=<out> -e 'my @a = 1..1000; my int @b = 1..1000; say @a.elems + @b.elems'`
as `va-switch-on-raw/t7-heap.sh`, twice a side alternating, each after a
probe (fifth stage; `heap/runs.tsv`, stdout, stderr, `snapshots.sha256`):

| run | side | maps | exit | stdout | stderr | snapshot bytes |
|---:|---|---|---:|---|---:|---:|
| 1 | va-c-base | va-c-base/lib/libmoar.so | 0 | 2000 | 190 | 2,161,785 |
| 1 | va-n-base | va-n-base/lib/libmoar.so | 0 | 2000 | 190 | 2,162,703 |
| 2 | va-c-base | va-c-base/lib/libmoar.so | 0 | 2000 | 190 | 2,158,669 |
| 2 | va-n-base | va-n-base/lib/libmoar.so | 0 | 2000 | 190 | 2,159,618 |

(2026-11-17 14:15:11-14:15:13, load 1.39-1.44.) stderr holds only Rakudo's
deprecation note for `--profile-filename` and the "Heap snapshot written
to" line on every run. **The snapshot size varies run to run on the same
side** (by 3,116 bytes on the C side, 3,085 on the Zig side), so Task 7's
2,161,848 vs 2,161,684 bytes across the sides is within one side's own
variation and says nothing about the array. Pass (completes, same output,
both sides).

## 5. The JIT's two direct functions reach their errors (ruling 3)

`vmarray-devirt.nqp`'s output cannot show which function printed "MVMArray:
Index out of bounds". Task 2 settled it for the C with breakpoints on an
unstripped C build (`va-differential-raw/coverage/devirt-hits.txt`: the two
throw lines of `vmarray_at_pos_int64` and `vmarray_bind_pos_int64` hit 4
times per run with spesh). The same check on the Zig array:

- Prefix `va-n-syms`: `va-prefixes-raw/build.sh "va-n-syms -Dstrip=false"`,
  2026-11-17 15:31:07 CET, 69 s, load 0.76, at bea13d101 (its library code
  is 472cf7e92's; a scratch prefix, not one of the six).
- The Zig build's two fast functions, from `nm`:
  `6model.reprs.vmarray.elements.Elements(6model.reprs.vmarray.storage.Storage(6model.reprs.VMArray.S__struct_0)).atPosKind(.i64).jit`
  and `....bindPosKind(.i64).jit` (local `t` symbols; `MVM_VMArray_find_fast_impl_for_jit` returns them).
  The throw is in `fromEnd`, inlined, so a line breakpoint would land in
  every function that inlines it; instead `devirt/bt-zig.py` breaks on each
  function's entry (counting calls, printing an index below -10, which cannot
  resolve on the program's 10-element arrays) and on
  `MVM_exception_throw_adhoc`, printing the message and the chain of calling
  frames, inlined frames included (the build has DWARF).
- Run: `LD_LIBRARY_PATH=/tmp/claude-1000/va-n-syms/lib <setting> gdb -q -batch -x bt-zig.py --args nqp-m tools/bench/repr/vmarray-devirt.nqp`,
  under MemoryMax=8G, after the load wait (`devirt/load.txt`), with the
  settings Task 2 used: `MVM_SPESH_BLOCKING=1` three times, the default
  (asynchronous spesh) three times, `MVM_SPESH_DISABLE=1` once
  (`devirt/devirt-zig-<setting>.txt`).

| setting | runs | throws from the JIT functions | throws from elsewhere | calls at / bind (per run) | program output |
|---|---:|---:|---:|---|---|
| `MVM_SPESH_BLOCKING=1` | 3 (15:34:47, 15:37:49, 15:39:33; load 1.99, 1.19, 1.22) | 4 each | 0 | 441,351 / 442,029 each | equal to the diff run's head output, each |
| default (asynchronous spesh) | 3 (15:41:17, 15:47:02, 15:52:32; load 1.51, 1.10, 1.16) | 4 each | 0 | 1,527,027 / 1,528,006; 1,473,027 / 1,474,016; 705,150 / 706,006 | equal, each |
| `MVM_SPESH_DISABLE=1` | 1 (15:34:47 series; load below 2.0) | 0 | 4 (`atPos`, `bindIndex <- bindPos`, from `MVM_interp_run`) | 0 / 0 | equal |

So, with spesh, the four "Index out of bounds" lines of the program
(`i64.devirt.at_i.-11`, `bind_i.-11` and their `.again`) are thrown from
inside the two JIT functions (`fromEnd <- atPosKind(.i64).read <-
atPosKind(.i64).jit`, and `fromEnd <- bindIndex <- bindPosKind(.i64).jit`),
each entered with index -11, exactly as the C's two functions did under the
same program; with spesh disabled the same lines come from `atPos` and
`bindPos` through the interpreter and the two functions are not called.
**The Zig JIT functions' error paths are hit.**
