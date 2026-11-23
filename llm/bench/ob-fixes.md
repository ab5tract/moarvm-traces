# ob-fixes: fixing the open bugs (OB1-OB20) in the port

```
Branch:    zig-open-bugs, from zig-hash-engine 99f7ce8cd, in P (local only, not pushed)
Plan:      traces/llm/plans/2026-11-23-open-bugs-port-fixes.md
Spec:      traces/llm/specs/2026-11-20-open-bugs-port-fixes-design.md
Bug list:  traces/llm/bench/cfix-open-bugs.md
Before:    /tmp/claude-1000/vf-c-base (-Dzig-reprs=false, the C array) and /tmp/claude-1000/vf-n-base (defaults,
           the Zig array), built at 282b04734 (identical in src/ to 99f7ce8cd; cfix-mirror-raw/build/), not modified
After:     /tmp/claude-1000/ob-c and /tmp/claude-1000/ob-n, built by ob-repro/build-prefixes.sh (not built yet)
Runners:   nqp-m of /tmp/claude-1000/tune-zig-prefix (read only) and the rakudo checkout's rakudo-m, with
           RAKUDO_NO_PRECOMPILATION=1 and -I<rakudo>/lib; only the libmoar swapped through LD_LIBRARY_PATH
Raw:       ob-fixes-raw/before/ (reproducer outputs and benchmark lines on the before prefixes)
Toolchain: Zig 0.17.1
```

## Reproducers and scripts

`traces/llm/bench/ob-repro/`, one program per bug id (and two for area K). Each prints labelled lines and
catches what it can, so that a build where its bug is fixed prints a stable, complete output; a line that
depends on JIT timing or heap contents prints only none/some/all or zero/non-zero.

| file | what it does |
|---|---|
| `run.sh -p PREFIX [-m MEM] [-t SECS] [-o OUTDIR] PROGRAM [ARGS]` | cfix-mirror-raw/run-port.sh for one prefix: probe (the libmoar mapped), command, output, exit status in `OUTDIR/<file>[.<args>].<PREFIX>.txt`; an `OB3-*` program also runs with `MVM_JIT_DISABLE=1` into `<file>[.<args>].nojit.<PREFIX>.txt`, and with `MVM_SPESH_BLOCKING=1` and `MVM_SPESH_LOG` into `<file>[.<args>].jitlog.<PREFIX>.txt`, which ends with the JIT evidence lines (see "JIT evidence") |
| `run-all.sh -p PREFIX -o OUTDIR` | every program, 2G cap for OB2 and OB18, 4G for the rest |
| `cmp.sh DIR PREFIX_A PREFIX_B` | `c=n` / `C!=N` per output after cfix-mirror-raw/cmp-repro.sh's normalisation (12+-digit numbers kept) |
| `run-bench.sh [-n RUNS] -o OUTDIR PREFIX...` | the push benchmark, RUNS rounds with the prefixes alternating, load below 2.0 before each run, medians in `bench-medians.txt` |
| `build-prefixes.sh [ob-c] [ob-n]` | cfix-mirror-raw/build/build.sh from `git archive HEAD` copies (with 3rdparty at the recorded commits) under /tmp/claude-1000/ob-src-{c,n}; logs, builds.tsv and export lists in `ob-fixes-raw/build/` |
| `OB2-typeobj-splice.nqp` | cfix-P-raw/round1/typeobj/typeobj.nqp, plus the target's elems after |
| `OB2-buf-new-array.raku` | `Buf.new(array[int])` in a try |
| `OB3-readuint-jit.nqp flags_3\|flags_16` | cfix-B-raw/hand/jit-readuint-size16.nqp, one case per process |
| `OB3-writeint-jit.nqp writeint_flags_3\|writeint_flags_16\|writeuint_flags_3\|writeuint_flags_16` | the same shape for writeint/writeuint (OB3 (b), never run before) |
| `OB3-writenum-size.nqp` | cfix-B-raw/hand/writenum-size16.nqp for flags 16, 0, 3, 4, 8, 12, 15, and two readnum controls |
| `OB4-adopted-setelems.nqp` | cfix-E-raw/hand-unwritten-slot.nqp after a heap preparation (see Baseline) |
| `OB7-rejected-push.nqp`, `OB7-rejected-bindpos.nqp` | the list's programs, one case per register kind |
| `OB8-write-buf-growth.nqp`, `OB8-write-uint64.raku` | the list's programs, plus a uint32 case and a no-growth control |
| `OB9-normalize-empty.nqp` | the list's program, plus a non-empty normalizecodes control |
| `OB12-anon-recompose.nqp` | the list's program, plus a named-type control |
| `OB16-num-buf-message.nqp` | the list's program, plus readint, and a str array |
| `OB18-deserialize-size.nqp` | a crafted blob (the list gives none): see Baseline |
| `OB19-holes.nqp` | holes via atpos, pop, shift; a splice of holes into a gen2 and a nursery target |
| `K-compose-small.nqp` | compose, then push_i, for 4-, 2-, 1-bit signed and unsigned, and 8-bit controls |
| `K-smallnatives.raku` | the plan's program; the declaration compiled through EVAL inside its try |

Benchmark: `tools/bench/repr/vmarray-push-bench.nqp` in P (cases `int.push10m`, `obj.push10m`,
`int.pushpop8`, `obj.pushpop8`, one line `<case> <seconds>` each).

## Baseline

Run on 2026-11-23 with `run-all.sh -p vf-c-base` and `-p vf-n-base` into `ob-fixes-raw/before/`, 1-minute
load 0.6-0.8. `cmp.sh ob-fixes-raw/before vf-c-base vf-n-base`: all 35 outputs `c=n` (17 programs, the OB3
JIT programs with 2 and 4 cases, each OB3 output also as `.nojit` and `.jitlog`; the OB3 outputs were re-run
in fix round 1). The list expects C and Zig to differ
only in OB20 and OB15d; no program here reaches either (OB20's growth of a storage-less kind with storage is
not driven), so no difference was expected and none was seen.

Every program shows its bug on both builds:

| id | before (vf-c-base = vf-n-base) | fixed would print |
|---|---|---|
| OB2 nqp | `source is concrete: 0`, then exit 137 (the 2G cap) | `DIED MVMArray: Cannot splice from a type object`, elems 3 |
| OB2 Raku | `MoarVM panic: Memory allocation failed; could not allocate 264965122424860 bytes`, exit 1 | a caught exception |
| OB3 (a) readuint | flags 3: died some, returned some (JIT); flags 16: SIGSEGV, exit 139 (the record had "stack smashing detected" on cfix-base); `.nojit`: died all; `.jitlog`: the same, and every specialization holding readuint `compiled` | died all, with and without the JIT; `.jitlog`: every specialization holding readuint `not compiled; BAIL: ...` |
| OB3 (b) writeint/writeuint | all four cases: died some, returned some, element 0 1 (JIT); `.nojit`: died all, element 0 0; `.jitlog`: as the JIT run, every specialization holding the op `compiled` | died all, element 0 0; `.jitlog`: `not compiled; BAIL: ...` |
| OB3 (c) writenum | flags 16, 0, 3, 4 return with elems 16, 1, 1, 2 (with and without the JIT; `.jitlog`: no specialization of the file holds writenum, the op runs in the mainline, interpreted) | `Cannot write a num of N bytes` for sizes 16, 1, 2 |
| OB4 | `element 2 != 0 (bytes never written for this array)` | `element 2 = 0` |
| OB7 push | every rejected push leaves elems 3 | elems 2 |
| OB7 bind_pos | rejected bind at 5 leaves elems 6 (at 1: elems 2) | elems 2 |
| OB8 nqp | `elems 9: 1 1800 1286 772 258 0 0 0 0`; int64: `elems 8`; uint32 2-byte write: `elems 3` | elems 5, 1, 2 |
| OB8 Raku | `buf16.new(1,2,3).write-uint64(1, 1): elems 9`; buf32 write-uint16: elems 3 | 5; 2 |
| OB9 | `normalizecodes of empty input into 10 20 30: returned; elems 3: 10 20 30` | `elems 0:` |
| OB12 | `MVMArray: Type  is already composed ...` | `Type <anon> is` |
| OB16 | `write_buf requires an integer type`, `read_buf requires an integer type` | `integer or num type` |
| OB18 | control round trip right; the patched blob: SIGSEGV, exit 139 | `Unable to allocate an array of 2305843009213693953 elements` |
| OB19 | atpos `VMNull 1`; pop, shift `VMNull 0`; splice into gen2 then pop `VMNull 1`, into nursery `VMNull 0` | `VMNull 1` everywhere |
| K nqp | the six kinds compose; push_i `DIED MVMArray: Unhandled slot type` | compose dies with the area K message |
| K Raku | `declared, elems 0`, push `DIED MVMArray: Unhandled slot type`, `[]` | the declaration dies |

Differences from the bug list and decisions taken while writing the programs:

- OB4: the list's program alone printed `element 2 = 0` on both port builds (the slot happened to be zero;
  on cfix-base the record saw a non-zero value). The program now first makes 200 normalizecodes results of
  `97 98 99` (12-byte buffers, all three slots written) garbage and runs two full collections; the next
  12-byte malloc then reuses one, and element 2 is non-zero on both builds. Only zero/non-zero is printed.
- OB3: one process ran both readuint cases, and four writeint cases, at first. Then which sub was compiled
  depended on the order and on timing (the flags 16 readuint was never compiled; writeint cases differed
  between C and Zig). With one case per process, the loop inside `sub MAIN` and each case's sub called by
  name in its own branch (the readuint program's shape; fix round 1 reshaped the writeint program to it,
  see "JIT evidence") the outcome was the same in every run on each build. The counts still depend on when
  the JIT takes over, so the programs print none/some/all. The plain and `.nojit` runs leave
  `MVM_SPESH_BLOCKING` unset (spesh/JIT defaults, as the plan says); the `.jitlog` run sets it.
- OB3 readuint flags 16 ends in SIGSEGV on both builds, not in glibc's stack-protector abort the record saw
  on cfix-base (a Perl/Configure build of upstream).
- OB3 writeint/writeuint (b) is shown for the first time: the JIT path writes where the interpreter throws,
  for flags 3 and for flags 16. The 15 bytes read past the 8-byte register for flags 16 are not printed
  (their values vary).
- OB18: the list gives no blob. The program serializes (`nqp::serializetobuf`) an SC with an int64 array
  `0x7EADBEEFCAFEF00D 1 2`, finds the 10 bytes "count 3 (1 byte), first element (9-byte varint)" exactly
  once, and replaces them with "count 2**61 + 1 (9-byte varint), element 0 (1 byte)", so the blob keeps its
  length and its tables stay right; then base64-encodes and deserializes it under `-m 2G`. The wrapped
  `malloc(8)` is overrun and the process dies (SIGSEGV) on both builds.
- OB19: a NULL from pop bound to a variable and passed to a sub crashed the VM (SIGSEGV, first draft); the
  program applies `nqp::eqaddr(..., nqp::null())` to the op's result directly.
- K-smallnatives.raku: `my uint4 @a` inside a `try` would scope `@a` to the try block, and the fixed build may
  throw while compiling the declaration; the declaration is therefore `EVAL 'my uint4 @a; @a'` inside its
  try, and the later statements are skipped (with a line saying so) when it failed.

### JIT evidence (fix round 1)

The plain run's "died all" after a fix would be indistinguishable from "the JIT never compiled the frame"
(it is byte-identical to the `.nojit` output). So `run.sh` runs each `OB3-*` program a third time with
`MVM_SPESH_BLOCKING=1` (what is compiled no longer depends on thread timing) and
`MVM_SPESH_LOG=<temporary file>`, and appends to `<x>.jitlog.<PREFIX>.txt` one line per specialization of a
frame of the program's own file whose final code holds readuint, writeint, writeuint or writenum:

    jit: specialization of '<frame>' holding <ops>: compiled | not compiled[; BAIL: <comment>]

Source of each part, by reading: `MVMSpeshCandidate.c` (around lines 304-334) runs
`MVM_jit_try_make_graph` and then prints the "After:" dump of the spesh graph and "JIT was [not]
successful"; the JIT's bail-outs in `src/jit/graph.c` leave a "BAIL: op <...>" comment on the instruction
(`MVM_spesh_graph_add_comment`), which that After dump prints. The log is deleted after extraction. The
port's build supports this as upstream (`MVM_SPESH_LOG` in src/moar.c; `MVM_JIT_DEBUG` only adds spill and
dump details, not used).

Before, on both builds (the `.jitlog` lines; C and Zig equal):

    OB3-readuint-jit flags_3 and flags_16:
      jit: specialization of '' holding readuint: compiled
      jit: specialization of 'read_flags_<N>' holding readuint: compiled
    OB3-writeint-jit <case> (all four):
      jit: specialization of '' holding writeint|writeuint: compiled
      jit: specialization of '<case>' holding writeint|writeuint: compiled
    OB3-writenum-size:
      jit: no specialization of this file holds the op

('' is the try block of the loop, into which spesh inlined the case's sub.) In the same runs the bug shows:
readuint flags 3 and every writeint/writeuint case "died some, returned some", readuint flags 16 SIGSEGV.
There is no inline fast path to tell apart: with known flags the JIT emits a C call, to
`MVM_repr_read_buf`/`MVM_repr_write_buf` or (with a known concrete type, graph.c 2395-2406 and 2442-2452)
the REPR's `read_buf`/`write_buf`, with the size taken from the flags and none of the interpreter's checks.

A caution found while doing this: the first writeint program called the case's sub through a variable; with
`MVM_SPESH_BLOCKING=1` spesh inlined it into `MAIN`, whose specialization the JIT did not compile, so the
op ran interpreted ("died all") although the line for the sub's own specialization said `compiled`. One
`compiled` line therefore does not prove the op ran compiled; the counts in the same `.jitlog` run do. The
writeint program now has the readuint program's shape (each case's sub called by name in its own loop), and
its `.jitlog` runs show the bug.

Expected after the fix (design: "the JIT does not compile the fast path for flags it cannot prove safe and
falls back to the interpreter's op"). By reading graph.c, the JIT's only way to leave an op to the
interpreter is the bail-out it already uses for an endian switch or unknown flags: add a "BAIL: ..."
comment and `return 0` from `consume_ins`, which makes `MVM_jit_try_make_graph` give up on the whole
specialization; the specialized bytecode then runs in the interpreter, whose op checks the flags. So after
the fix every line of the readuint and writeint `.jitlog` files should read `not compiled; BAIL: op
<readuint|writeint|writeuint>, ...` (wording of the new comment set by Task 6), with "died all" in the same
run. A fix that instead emitted a call to a throwing C helper would give `compiled` with "died all"; that
is not the design's shape and would need its own evidence. writenum is unaffected (no JIT case; the
interpreter's op).

### Benchmark

`run-bench.sh -n 7 -o ob-fixes-raw/before vf-c-base vf-n-base`: 7 rounds, prefixes alternating,
`MVM_SPESH_BLOCKING=1`, 1-minute load 0.64-0.8 at the starts. Seconds; raw lines in
`ob-fixes-raw/before/bench-vf-{c,n}-base.txt`, medians in `bench-medians.txt`.

| prefix | case | runs 1-7 | median |
|---|---|---|---|
| vf-c-base | int.push10m | 0.2031 0.2069 0.2069 0.2057 0.2073 0.2174 0.2143 | 0.2069 |
| vf-c-base | obj.push10m | 0.2181 0.2137 0.2154 0.2191 0.2083 0.2081 0.2066 | 0.2137 |
| vf-c-base | int.pushpop8 | 0.0862 0.0887 0.0891 0.0865 0.0848 0.0854 0.0868 | 0.0865 |
| vf-c-base | obj.pushpop8 | 0.0943 0.0890 0.0875 0.0881 0.0933 0.0954 0.0890 | 0.0890 |
| vf-n-base | int.push10m | 0.2087 0.2089 0.2198 0.2028 0.2029 0.2067 0.1996 | 0.2067 |
| vf-n-base | obj.push10m | 0.1995 0.2066 0.2078 0.2046 0.2085 0.2074 0.2181 | 0.2074 |
| vf-n-base | int.pushpop8 | 0.0846 0.0832 0.0856 0.0862 0.0859 0.0834 0.0841 | 0.0846 |
| vf-n-base | obj.pushpop8 | 0.0863 0.0864 0.0887 0.0863 0.0877 0.0883 0.0856 | 0.0864 |

The spread within a case is up to about 9 % (vf-c-base obj.pushpop8: 0.0875 to 0.0954), larger than Task 5's
5 % stop rule on medians; the medians themselves moved little between rounds. Noted for Task 5.

### Not verified

- No program was run on a fixed build (none exists yet): that each prints the "fixed would print" column is
  by reading only.
- OB2 Raku's fixed output depends on how Rakudo reports the new exception; not predicted beyond "caught".
- build-prefixes.sh was checked with `sh -n`/`bash -n` and read against cfix-mirror-raw/build/build.sh; it
  was not run. It copies P's git-ignored `zig-pkg/` (translate_c, and aro which translate_c's own
  build.zig.zon names) into each copy. Checked in fix round 1 on a throw-away archive copy, configure stage
  only (`zig build --help`, 1 s): exit 0 with zig-pkg copied; also exit 0 without it, zig then re-creating
  zig-pkg/ from the global cache's tarballs (~/.cache/zig/p/*.tar.gz), so the copy is a safeguard rather
  than a necessity on this machine. The full build in a copy, and the version string (from VERSION without
  `.git`, by reading build/zig/version.zig), were not tried.
- OB18's fixed path: the throw comes from inside lazy deserialization (`nqp::scgetobj` demanding the
  object); whether the program then reaches its "done" line cleanly, and with which message wrapping, is
  not known until a fixed build runs it.
- OB4 after the fix: `element 2 = 0` cannot be told from a slot that happens to be zero except by the
  "heap prepared" line (element 2 of the filler results is 99) and by the before output showing `!= 0` with
  the same preparation.
