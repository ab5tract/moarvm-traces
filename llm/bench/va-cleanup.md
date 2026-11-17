# va full-cleanup runs: base 120 of 120; stress --stress 116 of 120, 2 of 60 on each side (C and Zig alike)

```
va full-cleanup record (Task 8, Step 7; spec 7 item 6)
Date:          2026-11-17 14:12:54-14:14:10 CET (fourth stage of va-evidence-master.sh)
MoarVM:        zig-vmarray at bea13d101; prefixes built at 472cf7e92 (va-prefixes.md, Task 8)
Prefixes:      va-c-base, va-n-base (defaults; c = -Dzig-reprs=false), va-c-stress, va-n-stress
               (-Dgc-debug=1 -Dnursery-size=524288)
Runner:        nqp of /tmp/claude-1000/tune-zig-prefix, share/nqp/lib
Command:       tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/<P> --runs=20 on the two base prefixes, and
               with --stress (each inner loop bound x20) on the two stress prefixes, in the order va-c-base,
               va-n-base, va-c-stress, va-n-stress; each run systemd-run --user --scope -q -p MemoryMax=8G timeout 60
               <P>/bin/moar --full-cleanup --libpath=<nqp lib> <nqp lib>/nqp.moarvm <program>
Load:          1-minute load before each prefix 1.57, 1.82, 1.96, 1.97 (runs.tsv; cleanup.sh does not wait within a
               prefix)
Raw:           va-cleanup-raw/{c,n}-{base,stress}.out (the script's per-run table and total), runs.tsv,
               failing-{c,n}-stress/blocked-<run>.out (the failing runs' output), coredumps.txt (coredumpctl info
               of the four cores: PID, signal, the crashing thread's stack)
```

| prefix | programs | running.nqp | blocked.nqp | three.nqp | total |
|---|---|---:|---:|---:|---:|
| va-c-base | plain | 20/20 | 20/20 | 20/20 | 60/60 |
| va-n-base | plain | 20/20 | 20/20 | 20/20 | 60/60 |
| va-c-stress | --stress | 20/20 | **18/20** (runs 4, 12) | 20/20 | 58/60 |
| va-n-stress | --stress | 20/20 | **18/20** (runs 1, 10) | 20/20 | 58/60 |

## The four failures

All four are the same: `blocked.nqp --stress` (an app-lifetime thread that
sleeps 1 ms in a loop and allocates 4,000 hashes between sleeps) prints its
last line `main returning`, and the process then dies of SIGSEGV (exit 139,
"timeout: the monitored command dumped core") during `--full-cleanup`'s
global destruction. The cores (systemd-coredump, `coredumps.txt`) show the
crashing thread (not the main thread) at an unmapped address (`n/a + 0x0`),
called from libmoar at `MVM_interp_run+0x16aa0`, itself from
`MVM_interp_run+0x102` (the nearest exported symbols, the builds being
stripped), **at the same offsets on the C-array and the Zig-array build**:
the background thread is still running interpreted code when global
destruction frees what it runs.

**Verdict: the base runs pass (120 of 120); the stress runs do not (116 of
120).** The failure is the control's as much as the head's (2 of 60 on each
side, the same program, the same crash site), so it is not caused by the
Zig array, and nothing in it involves the array; but it is a miss of spec 7
item 6 ("all runs clean") as written, which campaign 7's stress run of the
same script met (`cb-cleanup.md`: cb-n-stress --stress 60 of 60, at
gc-call-boundary 11a2e2e84, an ancestor of this branch; no control was run with --stress
there). **Reported to the controller (BLOCKED by ruling 9);
no code was changed and nothing was built for diagnosis.** Whether it is
new since campaign 7 (a change on `zig-hash-engine` or this branch outside
the array) or an intermittent campaign 7's single 60-run sample missed is
not established here.
