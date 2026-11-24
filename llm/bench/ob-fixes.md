# ob-fixes: fixing the open bugs (OB1-OB20) in the port

```
Branch:    zig-open-bugs, from zig-hash-engine 99f7ce8cd, in P (local only, not pushed)
Plan:      traces/llm/plans/2026-11-23-open-bugs-port-fixes.md
Spec:      traces/llm/specs/2026-11-20-open-bugs-port-fixes-design.md
Bug list:  traces/llm/bench/cfix-open-bugs.md
Before:    /tmp/claude-1000/vf-c-base (-Dzig-reprs=false, the C array) and /tmp/claude-1000/vf-n-base (defaults,
           the Zig array), built at 282b04734 (identical in src/ to 99f7ce8cd; cfix-mirror-raw/build/), not modified
After:     /tmp/claude-1000/ob-c and /tmp/claude-1000/ob-n, built by ob-repro/build-prefixes.sh (first built in Task 2)
Runners:   nqp-m of /tmp/claude-1000/tune-zig-prefix (read only) and the rakudo checkout's rakudo-m, with
           RAKUDO_NO_PRECOMPILATION=1 and -I<rakudo>/lib; only the libmoar swapped through LD_LIBRARY_PATH
Raw:       ob-fixes-raw/before/ (reproducer outputs and benchmark lines on the before prefixes); per task
           ob-fixes-raw/after-*, suites-*, diff-*.log; the final gate in ob-fixes-raw/gate-t7/ (section "Gate")
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
| `run-bench.sh [-n RUNS] -o OUTDIR PREFIX...` | the push benchmark, RUNS rounds with the prefixes alternating, load below 2.0 before each run, medians (and from Task 5 p25/p75) in `bench-medians.txt` |
| `build-prefixes.sh [ob-c] [ob-n]` | cfix-mirror-raw/build/build.sh from `git archive HEAD` copies (with 3rdparty at the recorded commits) under /tmp/claude-1000/ob-src-{c,n}; logs, builds.tsv and export lists in `ob-fixes-raw/build/` |
| `maketest-driver.sh OUTDIR [project:prefix ...]` | cfix-mirror-raw/maketest-driver.sh re-pointed at /tmp/claude-1000/ob-{c,n} (default `nqp:c nqp:n rakudo:c rakudo:n`); added in Task 2 |
| `OB2-typeobj-splice.nqp` | cfix-P-raw/round1/typeobj/typeobj.nqp, plus the target's elems after |
| `OB2-buf-new-array.raku` | `Buf.new(array[int])` in a try |
| `OB2-typeobj-slice.nqp` | `nqp::slice` of a VMArray type object (the slice side of OB2); added in Task 3 |
| `OB3-readuint-jit.nqp flags_3\|flags_16` | cfix-B-raw/hand/jit-readuint-size16.nqp, one case per process |
| `OB3-writeint-jit.nqp writeint_flags_3\|writeint_flags_16\|writeuint_flags_3\|writeuint_flags_16` | the same shape for writeint/writeuint (OB3 (b), never run before) |
| `OB3-writenum-size.nqp` | cfix-B-raw/hand/writenum-size16.nqp for flags 16, 0, 3, 4, 8, 12, 15, and two readnum controls |
| `OB4-adopted-setelems.nqp` | cfix-E-raw/hand-unwritten-slot.nqp after a heap preparation (see Baseline) |
| `OB7-rejected-push.nqp`, `OB7-rejected-bindpos.nqp` | the list's programs, one case per register kind |
| `OB7-negative-bindpos.nqp` | bindpos with the wrong register kind at -1 and -5 on three elements (which error wins); added in Task 3 |
| `OB8-write-buf-growth.nqp`, `OB8-write-uint64.raku` | the list's programs, plus a uint32 case and a no-growth control |
| `OB9-normalize-empty.nqp` | the list's program, plus a non-empty normalizecodes control |
| `OB12-anon-recompose.nqp` | the list's program, plus a named-type control |
| `OB16-num-buf-message.nqp` | the list's program, plus readint, and a str array |
| `OB18-deserialize-size.nqp` | a crafted blob (the list gives none): see Baseline |
| `OB19-holes.nqp` | holes via atpos, pop, shift; a splice of holes into a gen2 and a nursery target |
| `OB19-hole-to-sub.nqp` | a hole popped and shifted into a variable and passed to a sub (the crash Task 1 saw); added in Task 4 |
| `OB19-serialized-hole.nqp` | an object array with a hole and an `nqp::null()` element, serialized and read back, then atpos/pop/shift; added in Task 4 |
| `Z-splice-clear-setelems.nqp` | OB21: a splice at offset 0 removing every element, then setelems / bindpos past the end (the removed elements came back); added in Task 5 |
| `Z-shift-realloc.nqp` | OB21 through a reallocation: the same splice, a push and a shift, then setelems 20 / bindpos 19 (the move to start 0 plus a reallocation); the review's program, added in Task 5 fix round 1 |
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
| OB3 (a) readuint | flags 3: died some, returned some (JIT); flags 16: SIGSEGV, exit 139 (the record had "stack smashing detected" on cfix-base); `.nojit`: died all; `.jitlog`: the same, and every specialization holding readuint `compiled` | died all, with and without the JIT; `.jitlog`: died all, and the lines `not compiled; BAIL: ...` (a bail) or `compiled` (a checked call), see JIT evidence |
| OB3 (b) writeint/writeuint | all four cases: died some, returned some, element 0 1 (JIT); `.nojit`: died all, element 0 0; `.jitlog`: as the JIT run, every specialization holding the op `compiled` | died all, element 0 0; `.jitlog`: died all, lines as for readuint |
| OB3 (c) writenum | flags 16, 0, 3, 4 return with elems 16, 1, 1, 2 (with and without the JIT; `.jitlog`: no specialization of the file holds writenum: the op is in the body of a top-level `for` loop that runs 7 times, too few for spesh, so it runs interpreted) | `Cannot write a num of N bytes` for sizes 16, 1, 2 |
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
(`MVM_spesh_graph_add_comment`), which that After dump prints. The log is deleted after extraction. A frame counts as the program's when the path in its
`file: <path>:<line>` header is the path the runner was given or ends in `/<basename>` (fix round 2: the
first version compared the bare basename only, and gave "no specialization" for a program passed with a
directory; run-all.sh passes bare names from inside ob-repro/, so the before outputs were not affected,
and their re-run differs only in the temporary log's name on the `run:` line). The
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
run. That expectation holds only if the fix adds a bail. A fix that instead emits a checked call (a C
helper that applies the interpreter's checks and throws) would honestly show `compiled` with "died all".
Either is acceptable evidence of the fix, as long as the `.jitlog` run's counts say "died all" (and returned
none) under `MVM_SPESH_BLOCKING=1`: `not compiled` shows the op left to the interpreter, `compiled` shows the
compiled code itself refusing. What is not acceptable is "died all" with no line for the op at all (`jit: no
specialization of this file holds the op`), which would mean the op was never specialized. writenum is
unaffected (no JIT case; the interpreter's op).

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

## K and M

### The fix

Commits in P (zig-open-bugs): ce6393516 (C, area K), 75e171c31 (Zig mirror), 02289298c (C, area M, names
#2081), a1fa9aed7 (Zig mirror), 9b511d4e3 (tools/bench/repr harness).

- K: `spec_to_repr_data` (VMArray.c) and `specToReprData` (serial.zig), at the top of the integer branch
  (`BP_INT`, `BP_UINT64`), before the signedness switch: `spec->bits < 8` throws `MVMArray: Cannot compose
  an array of %d-bit integers, element types need at least 8 bits`. Before the fix the 4-, 2- and 1-bit
  widths (the only ones below 8 that P6int accepts, P6int.c:154-156) mapped to `MVM_ARRAY_U4` .. `I1` with
  `elem_size` 0; no other storage spec gives `elem_size` 0 (`BP_NUM` 32/64, `BP_STR` 8, other box kinds
  leave the object kind). In `compose` the function writes into a local kind, so the throw comes before the
  #2081 recompose check and before anything is stored: a fresh type stays an object array, a composed type
  keeps its kind and element type. `deserialize_repr_data` calls the same function and so throws the same
  message for a serialized type naming such an element type (by reading; no program drives it, as the
  design expects: no compiled file holds such a type). There, as before for any throw of that function,
  the new REPR data (object kind, the element type stored) is already in `st->REPR_data`.
- M: the #2081 message prints `<anon>` when `MVM_6model_get_stable_debug_name` gives `""` (no debug name, or
  an empty one).
- Left as they are (unreachable now): the `Unhandled slot type` arms, the storage-less guards of #2079 and
  #2080, Zig `setInt`'s `kinds.unstored` arm, Zig `grow`'s NULL-slots case.

### What the list entries become

- OB6 (at_pos default arm's name table) and OB17 (storage spec and debugger misreport): not fixed separately;
  no array of such a kind can exist, so neither is reachable.
- OB18 second half (storage-less kinds cannot be deserialized): such a type is refused at
  `deserialize_repr_data` with the compose message, before any array of it is read.
- OB20 (growth of a storage-less kind stores realloc's result, then throws): unreachable.
- OB15d (NULL slots in Zig, `malloc(0)` in C): unreachable; the one documented pointer-value difference
  can no longer be observed.
- OB12: fixed (M).

### Reproducers, before and after

`run.sh -p ob-c|ob-n -o ob-fixes-raw/after-t2 ob-repro/<file>`; `cmp.sh ob-fixes-raw/after-t2 ob-c ob-n`:
`c=n` for all three.

| program | before (vf-c-base = vf-n-base) | after (ob-c = ob-n) |
|---|---|---|
| K-compose-small.nqp | 4/2/1 bits: `compose: returned`, `push_i: DIED MVMArray: Unhandled slot type; elems 0` | `compose: DIED MVMArray: Cannot compose an array of N-bit integers, element types need at least 8 bits`, `push_i: DIED MVMArray: push expected object register; elems 1`; 8-bit controls unchanged |
| K-smallnatives.raku | `declared, elems 0`, `push 3: DIED MVMArray: Unhandled slot type`, `[]` | `declare: DIED MVMArray: Cannot compose an array of 4-bit integers, element types need at least 8 bits`, `push 3 and say: skipped, no array` |
| OB12-anon-recompose.nqp | `DIED [MVMArray: Type  is already composed with another element kind]` | `DIED [MVMArray: Type <anon> is already composed with another element kind]`; named control unchanged |

K-smallnatives.raku: the message comes at the declaration (`my uint4 @a`, compiled through EVAL).
K-compose-small.nqp's `elems 1` after the refused `push_i` is OB7 (push grows before the kind check),
area Q's subject, not K's.

### Unit tests

`zig build unit-test --summary all` (1-minute load 1.82, 1.93, 1.96 at the starts):

| setting | baseline at 99f7ce8cd | after | arithmetic |
|---|---|---|---|
| default | 240/252 (12 skipped) | 239/251 (12 skipped) | 240 - 3 removed + 2 new = 239 |
| `-Dzig-reprs=false` | 240/252 | 239/251 (12 skipped) | the same |
| `-Dgc-debug=1` | 245/252 (7 skipped) | 244/251 (7 skipped) | 245 - 3 + 2 = 244 |

Floor (baseline minus removed): 237, 237, 242; all above it. New tests (vmarray_elements_test.zig):
"compose refuses integer element types narrower than 8 bits" (bits 4, 2, 1, signed and unsigned, on a fresh
type and on a type composed to int64: the message, REPR data unchanged) and "recompose message names an
anonymous type <anon>" (no debug name, an empty one, a named control). Both failed before the fix (compose
returned; `Type  is`).

Removed, because their subject (an array of a kind without storage) can no longer be made:
- "the kinds without storage: what does not throw does nothing and keeps slots NULL"
- "a splice into or out of a kind without storage throws before changing anything"
- "write_buf on a kind without storage throws the integer-type message, even for 0 bytes"

Rewritten (kept): "specToReprData maps each storage spec to the C's slot type and element size"
(vmarray_serial_test.zig) loses its twelve rows for 4, 2 and 1 bits, which now throw in-process; "a composed
array type may not change its element kind; a failed compose changes nothing" expects `Type <anon> is`.
The storage-level tests with `elem_size` 0 (vmarray_storage_test.zig: alloc of 0 bytes, free of a
zero-capacity buffer) test the kept dead code and stay.

### Harness

`vmarray-diff.nqp`: `odd_kinds()` composed outside `t()`; the compose is now made inside each case
(`odd_array`, until one succeeds), so each `<kind>.odd.*` line prints the compose message, plus a new
`<kind>.odd.compose` line. The `<kind>.late.*` cases, `u4.late.serialize` and the `recomposed.refused.*`
pairs with `u4` already composed inside `t()` and print the message unchanged in structure.
`vmarray-serial.nqp` also needed a change (not in the brief's file list): `write_case('u4', ...)` built
its type outside the `try`, which would have ended the program before `done: 1` (diff.sh exit 4); the type
is now made inside the `try` (`u4.0.blob: DIED <message>`, roundtrip and read `DIED no blob`). README.md
records both.

`diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t2`:
exit 0, `diff.sh: identical (3 runs a side; lines: diff-nqp/spesh 10453 diff-nqp/nospesh 10453
diff-raku/spesh 2487 diff-raku/nospesh 2487 serial/spesh 196 serial/nospesh 196 devirt/spesh 10
devirt/nospesh 10; cross-read identical)` (log: ob-fixes-raw/diff-t2.log). undefined-lines.txt unchanged
(empty). Exported symbols: exports-ob-c.txt = exports-ob-n.txt.

### Prefixes and suites

`build-prefixes.sh` (first run): ob-c and ob-n both exit 0 at 9b511d4e3, 60 s each, load 1.81 and 1.63;
builds.tsv in ob-fixes-raw/build/. It worked unchanged.

`ob-repro/maketest-driver.sh ob-fixes-raw/suites-t2`: nqp PASS on both (Files=150, Tests=13746); Rakudo
FAIL on both (Files=599, Tests=11162) with only `t/04-nativecall/02-simple-args.t` (tests 17-18, OB15a)
not ok. The per-file lists equal cfix-mirror-raw/suites/ for all four runs.

### Not verified

- `deserialize_repr_data`'s throw: by reading only in this task. Run since (Task 2's review, and again in
  Task 7): `vmarray-serial.nqp --read=` on the pre-fix blob file `va-differential-raw/serial.out`, which holds a
  serialized `u4` array type. On ob-c and ob-n: `u4.0.read: DIED MVMArray: Cannot compose an array of 4-bit
  integers, element types need at least 8 bits`, then `done: 65`, exit 0. On vf-c-base and vf-n-base: `u4.0.read:
  DIED MVMArray: Unhandled slot type`. Every other line is the same on the four. Outputs:
  ob-fixes-raw/gate-t7/probes/out/vmarray-serial.nqp.--read=*.txt. No kept test drives it (diff.sh's
  cross-read uses blobs written by the same builds).
- The new check uses `bits < 8`; widths 0, 3, 5, 6 and 7 would now get the new message instead of
  "Unsupported int size", but P6int refuses them at its own compose, so no type with such a spec is known.

## Y and Q

### The fix

Commits in P (zig-open-bugs): 771b359b6 (C, area Y), 14b817180 (Zig mirror), 981c4a8f2 (C, area Q),
7ff607fd1 (Zig mirror), a8a712e6c (tools/bench/repr harness).

- Y, splice: `asplice` (VMArray.c) and `asplice` (elements.zig) throw `MVMArray: Cannot splice from a type
  object` when `from` is not concrete, whatever its REPR, as the first thing done with the source: before
  `REPR(from)->elems` is read, so before the offset check, #2079's REPR check and the cross-kind check,
  and before the target is changed. Zig's `objectOrFault` (only asplice uses it) now faults for a NULL
  `from` at the offset of `header.flags1`, the C's first read (`IS_CONCRETE`); both still die of SIGSEGV.
- Y, slice: `OP(slice)` (interp.c), `MVM_repr_pos_slice` (reprconv.c, the JIT's path) and P6opaque's
  `oslice` never check that the array sliced from is concrete, and `aslice` read `elems` from the type
  object's missing body (nqp: a segfault on both builds before). `aslice` now throws `MVMArray: Cannot
  slice from a type object` before that read (after `STABLE(dest)->REPR_data` is loaded, as declared; the
  destination is the fresh object OP(slice) allocated, left empty).
- Entry points checked for a second array (`grep -n 'IS_CONCRETE\|REPR(from)\|REPR(dest)'` and the
  callers): `copy_elements` is reached only from `asplice` and `aslice`, both now guarded; `copy_to`'s
  destination is a fresh clone; `OP(splice)` checks only its target (`CHECK_CONC`), the source is the
  guarded `from`; `OP(slice)`'s destination comes from `MVM_repr_alloc_init`. No other VMArray function
  takes a second object.
- Q: `MVM_VMArray_push` and `MVM_VMArray_bind_pos` check the register kind in a switch of their own before
  `set_size_internal`, with the same conditions and messages per slot type (push's eight integer arms and
  bind_pos's two num arms share a case label now; the texts are the old ones), and store without a check
  after the growth. bind_pos resolves a negative index first, as before. Zig: `Arm(op).check` dispatched
  with `Otherwise.nothing` before `setSize`/`bindIndex`, then `storeElem` dispatched with the old
  `unhandled`. A slot type with no arm passes the check switch and is refused by the store switch after
  the growth, as before (unreachable since area K).
- JIT entry points: `MVM_VMArray_find_fast_impl_for_jit` returns `vmarray_bind_pos_int64` only for
  `bindpos_i` with an int64 register on an I64 array and `bindpos_u` with a uint64 register on a U64
  array (jit/graph.c derives the kind from the opcode); both kinds are accepted there. Not changed (Zig
  `bindPosKind` likewise). The harness confirms the generic path in compiled code: `i64.hot.sub.after` and
  `i8.hot.sub.after` (a hot sub's rejected `bindpos_u` at 40000 under spesh) changed their SHA-1 because
  the array no longer grows to 40001.

### Negative index (Review Focus 3)

Before the fix, on ob-c and ob-n at 9b511d4e3 (ob-fixes-raw/before-t3/negidx.nqp.*, the program now
`ob-repro/OB7-negative-bindpos.nqp`, also run on vf-c-base and vf-n-base): `bindpos_i` at -1 on a 3-element
object array gives `MVMArray: bindpos expected object register`, at -5 `MVMArray: Index out of bounds`; the
same order on an int array (`bindpos I64 expected int register` / `Index out of bounds`). The fix keeps the
negative-index fix-up before the kind check (it changes nothing), so the order is the same after; the unit
test "bind_pos with a negative index and the wrong kind" asserts it for every kind.

### Callers that can pass a type object (Review Focus 2)

`grep -rn 'nqp::splice' ../../src ../src`: 155 hits. All but these pass a literal or fresh list, a
module-level `$empty`, a `:D`-typed parameter, a value whose `nqp::elems` is taken first (OP(elems) does
`CHECK_CONC`), or an internal list that is concrete by construction (Metamodel HOW lists, QAST, NFA,
Backend, Str/Iterator/Internals buffers). The ones that can pass a type object, all in Buf.rakumod, all the
`int @values` candidates without `:D`:

| caller | route | after |
|---|---|---|
| `Blob.new(int @values)` (410) | `Buf.new(array[int])` | `DIED MVMArray: Cannot splice from a type object` |
| `Buf.STORE(int @values)` (1193) | `$buf.STORE(array[int])` | the same; buffer unchanged |
| `Buf.append(int @values)` (1411) | `$buf.append(array[int])` | the same |
| `Buf.prepend(int @values)` (1428) | `$buf.prepend(array[int])` | the same |
| `Buf.splice(..., int @values)` (1369, via `!splice-native`: `nqp::islist` is true for a VMArray type object) | `$buf.splice(1, 0, array[int])` | the same |

All five are `ob.typeobj.buf.*` lines in vmarray-diff.raku. `Blob.allocate(n, int @values)` calls
`nqp::elems` on the type object first (CHECK_CONC throws), so it never reaches the splice. Before the fix
`Buf.new(array[int])` panicked ("MoarVM panic: Memory allocation failed; could not allocate 264965122424860
bytes", not catchable); the others were not run before (the same route). The suites (below) hit no
type-object splice.

### What the list entries become

- OB2: fixed for splice (any REPR's type object) and for slice (found here: the same gap in `aslice`).
- OB7: fixed. K-compose-small.nqp's line after the refused `push_i` now shows `elems 0` (was `elems 1`):
  the refused push no longer grows the (object) array.

### Reproducers, before and after

`run.sh -p ob-c|ob-n -o ob-fixes-raw/after-t3 ob-repro/<file>`; `cmp.sh ob-fixes-raw/after-t3 ob-c ob-n`:
`c=n` for all seven. Before: ob-fixes-raw/before-t3/ (ob-c and ob-n at 9b511d4e3; the two new programs also
on vf-c-base and vf-n-base); before was equal on both builds for every program.

| program | before | after (ob-c = ob-n) |
|---|---|---|
| OB2-typeobj-splice.nqp | `source is concrete: 0`, then killed by the 2G cap (exit 137) | `DIED MVMArray: Cannot splice from a type object`, `target elems after: 3` |
| OB2-buf-new-array.raku | `MoarVM panic: Memory allocation failed; could not allocate 264965122424860 bytes` (exit 1) | `DIED MVMArray: Cannot splice from a type object`, `done` |
| OB2-typeobj-slice.nqp | segfault (exit 139) | `DIED MVMArray: Cannot slice from a type object` |
| OB7-rejected-push.nqp | the messages, `elems 3` in every case | the same messages, `elems 2` |
| OB7-rejected-bindpos.nqp | the messages, `elems 6` past the end (`element 5 isnull: 1`), `elems 2` inside | the same messages, `elems 2` everywhere (`no element 5`) |
| OB7-negative-bindpos.nqp | kind message at -1, `Index out of bounds` at -5, `elems 3` | unchanged |
| K-compose-small.nqp | 4/2/1 bits: `push_i: DIED MVMArray: push expected object register; elems 1` | `...; elems 0`; 8-bit controls unchanged |

### Unit tests

`zig build unit-test --summary all` (1-minute load 1.65, 1.92, 1.99 at the starts):

| setting | before (Task 2) | after | arithmetic |
|---|---|---|---|
| default | 239/251 (12 skipped) | 244/256 (12 skipped) | 239 + 5 new |
| `-Dzig-reprs=false` | 239/251 | 244/256 (12 skipped) | the same |
| `-Dgc-debug=1` | 244/251 (7 skipped) | 249/256 (7 skipped) | 244 + 5 |

New tests (vmarray_elements_test.zig): "asplice refuses a type object as source" (the target kind's own
type object, another VMArray type's and BOOTHash's; count 0 and 2; an empty and a 5-element target, OBJ and
I64; plus an offset the offset check would refuse: the type-object message wins), "aslice refuses a type
object as source", "a rejected push leaves the array as it was" (every stored kind, every register kind of
obj/str/int64/num64/uint64 its push refuses, which includes `refusedStackKind`; 3 elements and 8 = ssize),
"a rejected bind_pos leaves the array as it was" (every stored kind and refused register kind, at elems + 3
and at 2), "bind_pos with a negative index and the wrong kind". Each compares `stateOf` (elems, start, ssize,
bytes) before and after in a forked child. Before the fixes the first four failed (a splice: "Unable to
allocate an array of 18446744069414584321 elements"; a slice: "Slice index out of bounds", read from the
garbage elems; push: `elems=4`; bind: `elems=9 ssize=16`); the fifth passed (it pins today's order). No test
removed. The Zig tests exercise elements.zig directly; the C side is covered by the prefixes (reproducers,
diff.sh, suites).

### Harness

`vmarray-diff.nqp` gets `ob_cases()` (after `cfix_cases()`): `ob.typeobj.splice.<kind>.<own|other|hash>.<0|2>`
and `.empty`, `ob.typeobj.slice.<kind>`, `ob.push.rejected.<kind>.<class>.<3|8|shifted>`,
`ob.bindpos.rejected.<kind>.<class>.<6|1|-1|-5>` (440 lines, every one a DIED line with the array as it
was). `vmarray-diff.raku` gets `ob.typeobj.buf.{new,append,prepend,splice,store}`. README.md records them.
Lines that changed against the Task 2 output (same base build kind, ob-c at 9b511d4e3 vs a8a712e6c):
nqp `i64.hot.sub.after`, `i8.hot.sub.after` (above); Raku `<int type>.nqp.push.wrong.after` for the eight
integer types (`elems=6 [0 1 2 3 4 0]` -> `elems=5 [0 1 2 3 4]`) and `num32`/`num64`/`str.nqp.wrongkind.after`.
The `<kind>.kind.*.state` lines did not change (they `setelems(6)` first).

`diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t3`:
exit 0, `diff.sh: identical (3 runs a side; lines: diff-nqp/spesh 10893 diff-nqp/nospesh 10893
diff-raku/spesh 2492 diff-raku/nospesh 2492 serial/spesh 196 serial/nospesh 196 devirt/spesh 10
devirt/nospesh 10; cross-read identical)` (log: ob-fixes-raw/diff-t3.log). undefined-lines.txt unchanged.

### Prefixes and suites

`build-prefixes.sh`: ob-c and ob-n exit 0 at a8a712e6c (60 s and 61 s, load 1.57 and 1.83).

`ob-repro/maketest-driver.sh ob-fixes-raw/suites-t3`: nqp PASS on both (Files=150, Tests=13746); Rakudo
FAIL on both (Files=599, Tests=11162) with only `t/04-nativecall/02-simple-args.t` (tests 17-18, OB15a)
not ok. The per-file lists equal cfix-mirror-raw/suites/ for all four runs (the nqp lists' three
`t/hll/0[234]-*.t notok` entries are in the baseline lists too). No output of any suite contains either
new message, so no suite file splices or slices from a type object.

### Not verified

- P6opaque's `oslice`/`osplice` and all other positional delegations pass the delegate's body on without a
  concreteness check; a delegate attribute holding a type object would reach `aslice`/`asplice` (and every
  other VMArray op) as a type-object *target* body. Not this area's subject (a target, not a source), not
  reached by any known program; not changed.
- `nqp::null` (VMNull, a type object) as a splice source now gets the type-object message instead of the
  MVMNull REPR's own error. Not run in this task. Task 3's reviewer ran it (/tmp/claude-1000/rv3/out/), and
  Task 7 re-ran it (program ob-fixes-raw/gate-t7/probes/vmnull-splice.nqp, outputs in probes/out/). Three
  splices from `nqp::null()` into a 3-element list (offset 1 count 0, offset 1 count 2, an int list at 0):
  - before, vf-c-base and vf-n-base: `DIED This representation (Null) does not support elems (for type
    VMNull) elems 3`;
  - now, ob-c and ob-n: `DIED MVMArray: Cannot splice from a type object elems 3`.

  It threw before and after, and the target was unchanged both times. `nqp::slice(nqp::null(), 0, 0)` gives
  `Cannot create an instance of null type` on all four (OP(slice) allocates dest first). No nqp or Rakudo
  caller passes `nqp::null` to splice (the reviewer's grep).
- The slice fix's message was adapted from the brief's rule ("splice" replaced by "slice"); it is not in the
  global constraints' list of exact messages.

## W, V and H

### The fix

Commits in P (zig-open-bugs): 48fd69052 (C, area W), 1c80e9440 (Zig mirror), ec2ad02f7 (C, area V),
63a911508 (Zig mirror), bb0eda68f (C, area H), 922bbfb4d (Zig mirror), 3393c5932 (tools/bench/repr harness).

- W, growth: `write_buf` (VMArray.c) and `writeBuf` (elements.zig) grow a write that does not fit to
  `offset + ceil(count / elem_size)` elements, computed as `count / elem_size + (count % elem_size != 0)`
  (no `count + elem_size - 1`, which can wrap). Before, the target was `offset + count`, count being bytes.
  The growth condition of #2080 (`offset > elems || (elems - offset) * elem_size < count`) and the #2077
  bounds rules are unchanged; the C commit names #2080. Visible change: `elems` after a write into a wide
  Buf. `buf16.new(1,2,3).write-uint64(1,1)` leaves 5 elements, not 9; an 8-byte `writeint` into an empty
  int64 array leaves 1, not 8. The spare bytes of the last element are zero, because growth that
  reallocates zeroes (growth inside existing storage does not until area Z: Review Focus 4 below).
- W, wrap: no wrap is possible under the checks before the growth, for the callers there are. `offset` is
  in [0, 2**63 - 1], because a negative offset throws first. `ceil(count / elem_size) <= ceil((2**64 - 1) /
  elem_size)`, which is at most 2**63 for `elem_size >= 2`, so the sum is at most 2**64 - 1. For
  `elem_size == 1` the sum is `offset + count`, as before; it can wrap only for `count > 2**64 - 1 -
  offset`, that is `count >= 2**63`. No caller passes that: OP(writeint)/writeuint/writenum pass 1 to 8
  bytes, the JIT passes the op's size, and `nqp::serializetobuffer` passes the blob's length. It is not
  checked: that would be a new check, beyond the brief.
- W, message: the gate is unchanged (only OBJ and STR are refused, plus the storage-less kinds, which no
  longer exist). The texts change from `MVMArray: write_buf requires an integer type` / `MVMArray: read_buf
  requires an integer type` to `MVMArray: write_buf requires an integer or num type` / `MVMArray: read_buf
  requires an integer or num type`.
- V: `deserialize` reads the count into a local and throws `Unable to allocate an array of <count>
  elements` before it stores anything in the body or allocates. It throws when the count is over the limit
  `set_size_internal` applies, or when `count * elem_size` would wrap. That limit is 2**60 elements of 8
  bytes, 2**61 of 4, 2**62 of 2, 2**63 of 1, compared with `>`, as `set_size_internal` does. The wrap check
  is already implied by the limit, but kept as the brief asks. The limit moved into `slot_budget()` (C) /
  `storage.slotBudget` (Zig), which `set_size_internal` / `grow` now call. `deserialize` reads its count
  with `MVM_serialization_read_int`, the bounds-checked varint reader, as before; the unit test feeds the
  count through the library's `MVM_serialization_write_int`.
- H: `pop` and `shift` give `tc->instance->VMNull` for a NULL slot of an object array, as `at_pos` does
  (C: in their OBJ arms; Zig: `Arm(op).load`). `copy_elements` is not changed.
- H, other paths: every pop/shift path calls the REPR's `pos_funcs.pop`/`.shift`, so none returns the raw
  slot. That covers OP(pop_o)/OP(shift_o) (interp.c), `MVM_repr_pop_o`/`shift_o` (reprconv.c), the JIT's
  devirtualized path (jit/graph.c, the function pointer taken from the REPR), its `op_to_func` fallback
  (`MVM_repr_pop_o`) and the expression templates `pop_o!`/`shift_o!` (core_templates.expr, a `callv` of
  `pos_funcs.pop`/`.shift`). Spesh has no fast path for pop or shift (optimize.c only lists them among the
  ops that read facts), and `find_fast_impl_for_jit` offers none.
- H, serialized hole: a NULL slot serializes as `REFVAR_NULL` and reads back as NULL; an `nqp::null()`
  element is written as `REFVAR_VM_NULL` and reads back as VMNull (serialization.c `write_ref`/`read_ref`).
  So a deserialized array holds its hole as a NULL slot again, and every read now gives VMNull. Shown by
  `OB19-serialized-hole.nqp`: before, `pop (the hole): VMNull 0`; after, `1`. vmarray-serial.nqp already
  has a hole: its `obj.3` case is `'first'`, a setelems hole, then a list. That case's lines did not change
  (it reads through atpos).

### What the list entries become

- OB8: fixed. Rakudo: the `write-*` methods of Buf.rakumod (1209-1308,
  `grep -rn 'write-u\?int\|write-num' ../../src/core.c/Buf.rakumod`) pass `$offset` and the size flags
  straight to `nqp::writeint`/`writeuint`/`writenum`. Nothing in them reads `elems` after the write.
  `write-int128`/`write-uint128` write two 64-bit halves at `$offset` and `$offset + 8`: a byte offset,
  meaningful for a buf8, where nothing changes. On a wider Buf the elems after such a write change too
  (buf16 at 0: 12 elements, was 16). No Rakudo code relies on the old count, as far as the grep shows. The
  nqp compiler's own `nqp::writeuint` calls (QASTCompilerMAST.nqp, QASTOperationsMAST.nqp) write into byte
  buffers (elem_size 1), where nothing changes. The suites (below) agree.
- OB16: fixed (message only, as the spec decided; the nums stay accepted).
- OB18, first half: fixed. Task 1 left open whether the fixed path throws from inside lazy deserialization
  and the program then reaches its last line. It does, on both prefixes: `deserialize of the patched blob:
  DIED Unable to allocate an array of 2305843009213693953 elements`, then `done`, exit 0.
- OB19: fixed for pop and shift. Task 1's observation is gone: a hole popped into a variable and passed to
  an nqp sub no longer segfaults (`OB19-hole-to-sub.nqp`: exit 139 on vf-c-base, vf-n-base and the Task 3
  ob-c/ob-n before; `isnull 1` twice and exit 0 after).

### Reproducers, before and after

`run.sh -p ob-c|ob-n -o ob-fixes-raw/after-t4 ob-repro/<file>`; `cmp.sh ob-fixes-raw/after-t4 ob-c ob-n`:
`c=n` for all seven. Before: ob-fixes-raw/before-t4/. Those are ob-c and ob-n at a8a712e6c (Task 3's
builds) for every program. The two new programs also ran on vf-c-base and vf-n-base, `c=n` there too.

| program | before (C = Zig) | after (ob-c = ob-n) |
|---|---|---|
| OB8-write-buf-growth.nqp | `elems 9: 1 1800 1286 772 258 0 0 0 0`; `elems 8: 7 0 0 0 0 0 0 0`; uint32 `elems 3: 1 258 0`; control `elems 3` | `elems 5: 1 1800 1286 772 258`; `elems 1: 7`; `elems 2: 1 258`; control unchanged |
| OB8-write-uint64.raku | `elems 9: 1 1 0 0 0 0 0 0 0`; buf32 `elems 3: 1 258 0` | `elems 5: 1 1 0 0 0`; `elems 2: 1 258` |
| OB16-num-buf-message.nqp | `... requires an integer type` (4 lines); num array accepted | `... requires an integer or num type`; num array unchanged |
| OB18-deserialize-size.nqp | control line, then a segfault (exit 139) | control, `DIED Unable to allocate an array of 2305843009213693953 elements`, `done` (exit 0) |
| OB19-holes.nqp | pop, shift and the young-target splice `VMNull 0` | `VMNull 1` on every line |
| OB19-hole-to-sub.nqp (new) | segfault, exit 139 (also on vf-*-base) | `isnull 1` twice, `done` |
| OB19-serialized-hole.nqp (new) | `pop (the hole): VMNull 0` (vf-*-base) | `VMNull 1`; the other lines unchanged |

### Unit tests

`zig build unit-test --summary all` at 922bbfb4d (1-minute load 1.86, 1.88, 1.88 at the starts):

| setting | before (Task 3) | after | arithmetic |
|---|---|---|---|
| default | 244/256 (12 skipped) | 248/261 (13 skipped) | 244 + 4 new passing; 1 new skipped |
| `-Dzig-reprs=false` | 244/256 (12 skipped) | 248/261 (13 skipped) | the same |
| `-Dgc-debug=1` | 249/256 (7 skipped) | 253/261 (8 skipped) | 249 + 4; 1 new skipped |

New tests (vmarray_elements_test.zig):
- "write_buf grows by whole elements": every 2-, 4- and 8-byte numeric kind, 1 to 9 bytes at elems - 1,
  elems and elems + 2 of a 3-element array. Checks elems, the bytes written, the old bytes kept, and every
  other new byte zero.
- "read_buf and write_buf name integer or num": OBJ and STR, array unchanged. It restores the message
  coverage Task 2 removed, with the new text.
- "deserialize refuses a size it cannot allocate": every stored kind; counts 2**63, 2**64 - 1,
  2**64 / elem_size + 1 and limit + 1; body left at `elems=0 start=0 ssize=0 bytes=null`.
- "pop and shift return VMNull for a hole": a nursery and a gen2 holey array; the results stored into a
  gen2 array, then two nursery collections and, in the `-Dgc-debug=1` build, a forced full one (Review
  Focus 5); the stored slots are VMNull.
- "write_buf into spare room of an adopted buffer" (Review Focus 4): skipped with the reason "needs area
  Z". It is a 3-element array given a malloc'd 8-slot buffer full of 0xaa, then a 1-byte write at elems;
  Task 5 enables it.

Each of these tests runs through `E` and through the library's table, so the `-Dzig-reprs=false` run tests
the C functions too. Two existing tests pinned the old growth and now expect the new counts: "writeBuf and
readBuf copy bytes for the integer kinds" and "read_buf and write_buf compare the offset with elems
first". In the latter the #2080 throws still throw but name `offset + 1` and `offset + 2` elements
(2305843009213693954, 2**63 + 1), and the append at elems gives 5 elements, not 12. Before the fixes the
four new tests and those two failed.

Exception: 2**63 one-byte elements is the limit itself (`>`), so it is not refused. The allocation fails
instead, with `MoarVM panic: Memory allocation failed; could not allocate 9223372036854775808 bytes`
(exit 1), as a setelems of that size does, and the test pins that. The brief listed 2**63 for every
element size; this follows the spec's "the same limit as set_size_internal" instead.

### Harness

`vmarray-diff.nqp` `ob_cases()` gains:
- `ob.writebuf.growth.<kind>.f<1|5|9|13>.<at2|at3|at5|empty>`: every numeric kind, 160 lines.
- `ob.holes.pop`, `ob.holes.shift`: the hole compared with `nqp::null()` before it is bound.
- `ob.holes.stored`: the results pushed into an old array across a collection.

`vmarray-diff.raku` gains `ob.writebuf.{buf16.write-uint64, buf16.write-uint32, buf32.write-uint64,
buf32.write-uint16, buf64.write-num32}`. README.md records them.

Lines that changed against the Task 3 output (the base side, ob-c at a8a712e6c vs 3393c5932):
- nqp, the wide kinds: the `<kind>.buf.*` writes that need growth (`writeint.f*`, `.neg`, `.grow`, `.end`,
  `.empty`, `.shifted`, `writeuint`, `writenum.*`). i8 and u8 are unchanged.
- nqp, `<kind>.buf.writeint.wrap.*`: the refused size in the message.
- nqp, obj and str: the new message text.
- Raku: `Buf[uint16]`/`Blob[uint16].nqp.writeint` (elems 9 -> 5); `cfix.Buf[uint{64,32,16}].write.wrap`
  (the refused size); `str.nqp.readint`, `str.nqp.writeint`, `list.nqp.readint`, `array.reified.readint`
  (the message).
- serial: no line changed.

`diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t4`: exit
0, `diff.sh: identical (3 runs a side; lines: diff-nqp/spesh 11056 diff-nqp/nospesh 11056 diff-raku/spesh
2497 diff-raku/nospesh 2497 serial/spesh 196 serial/nospesh 196 devirt/spesh 10 devirt/nospesh 10;
cross-read identical)` (log: ob-fixes-raw/diff-t4.log). undefined-lines.txt unchanged.

### Prefixes and suites

`build-prefixes.sh`: ob-c and ob-n exit 0 at 3393c5932 (61 s and 59 s, load 1.50 and 1.95); export lists
equal.

`ob-repro/maketest-driver.sh ob-fixes-raw/suites-t4`: nqp PASS on both (Files=150, Tests=13746); Rakudo
FAIL on both (Files=599, Tests=11162) with only `t/04-nativecall/02-simple-args.t` (OB15a) not ok. The
per-file lists equal cfix-mirror-raw/suites/ for all four runs. No suite output contains the new message
texts or "Unable to allocate", so no suite file writes into an object or string array or hits a refused
growth or deserialize. The Rakudo setting, its precompiled modules and the nqp stage files load (they
deserialize every VMArray they hold through the changed deserialize).

### Not verified

- `write_buf` with `count >= 2**63` on a 1-byte kind can still wrap `offset + count`, as before. No caller
  passes such a count; it is not checked.
- Area V is not driven by diff.sh (no crafted blob in vmarray-serial.nqp). It is covered by the unit test
  (both implementations) and by OB18-deserialize-size.nqp on both prefixes.
- 2**63 one-byte elements from a crafted blob still ends the VM with the allocator's panic, as a setelems of
  that size does (see Unit tests).

## Z, first mechanism (rejected)

Status: the fix is committed and correct by the tests, but the benchmark's stop rule fired on every case of
both builds. Per the plan, no other design was tried and the fix was not tuned. The controller decides
whether the commits stay.

### The fix

Commits in P (zig-open-bugs): 3f4dd1c69 (benchmark, longer cases, before the fix), 591f3c20b (C),
8223cc952 (Zig mirror, with the tests), ec2e4f080 (tools/bench/repr harness).

- `set_size_internal` (VMArray.c) / `setSize` (storage.zig) take `old_window_end = start + elems` before
  anything changes. In the `n <= ssize` branch, if `body->start + n > old_window_end`, slots
  `old_window_end .. body->start + n` (absolute indices) are zeroed with `zero_slots` / `zeroSlots`, then
  `elems = n` as before. Without a move this is the old elements' end to the new end. After the move to
  start 0, the move has already zeroed `elems .. old start + elems`, so only `old start + elems .. n` is
  zeroed (nothing twice). A shrink never satisfies the condition. The reallocating path (`grow`) is not
  touched. C and Zig zero the same range. The unit test checks that slots past the new end keep their
  bytes.

### Which growth paths can expose non-zero slots (reading)

Correction (fix round 1): the reading below is wrong where it says that a reallocation together with the
move keeps the slots zero. After the move to start 0, a reallocation zeroed the new room only from the old
ssize, so the slots from the old window's end to the old ssize came into the window unzeroed. The first two
rounds missed this; the review found it (see "Z, fix round 1"). The original text follows.

The REPR keeps slots past the window zero by itself in these places: pop zeroes the slot it leaves, a
shrink zeroes the dropped slots, a reallocation zeroes the new room, and the move to start 0 zeroes the
vacated part. shift does not zero the slot it leaves, but that slot is before `start`. Only the move can
bring it back, and the move zeroes it. Two sources break the invariant, and `set_size_internal` cannot tell
them from a clean array:
- the adopting sites (OB4): normalize.c twice, procops.c, asyncsocket.c and asyncsocketudp.c set
  `ssize > elems` over memory never written. encode (ops.c), Decoder.c and io.c adopt with
  `ssize == elems`, so there is no room to expose there;
- new, found here: `asplice` at offset 0 with `count - elems1 >= elems` (a splice that removes every
  element) sets `start = 0, elems = 0` without clearing the removed elements' slots. `ob-repro/Z-splice-
  clear-setelems.nqp`: on vf-*-base and pre-Z ob-c/ob-n, `setelems 4` after `splice($a, [], 0, 4)` gives
  back `11 22 33 44`, and a bindpos at 2 of an emptied object array gives back `a b`. Those are pointers the
  collector no longer marks, so this is memory unsafety, not only a wrong result. It is not in the bug list
  (OB1-OB20). After the fix: `0 0 0 0` and `<null> <null> z` on both prefixes.

The callers that raise `elems` within the storage:
- setelems (`set_elems`) can expose old bytes (OB4, the splice case), so the zeroing is needed.
- bind_pos past the end (`MVM_VMArray_bind_pos`, the JIT's `vmarray_bind_pos_int64`, Zig `bindIndex`)
  exposes `elems .. index - 1` unwritten, so the zeroing is needed.
- write_buf past the end exposes the gap before the offset and the spare bytes of the last element, so the
  zeroing is needed (Task 4's skipped test, enabled now).
- asplice exposes `elems0 .. offset` when offset > elems0, so the zeroing is needed there. When the offset
  is within elems, everything exposed is then written by the tail memmove and copy_elements, and the zeroing
  is redundant.
- push exposes one slot and writes it right after `set_size_internal`, so the zeroing is redundant there. It
  is the hot path the benchmark measures.
- unshift at start 0 grows by n, then moves the elements up and zeroes `0 .. n`, so everything exposed is
  written and the zeroing is redundant.
- aslice: the destination is written over `0 .. elems` by copy_elements, so the zeroing is redundant.
- asplice's offset-0 adjustment (`start - n`, n > 0) and unshift's `elems = live` set `elems` directly. The
  slots they expose (before the old start) are then written by copy_elements / the unshift store, so they
  need no zeroing.

The design asks for one place (`set_size_internal`), and that place cannot tell a push from a setelems.
Not zeroing on push would need a variant or a flag at the callers that write the slot right away, which
is another design and was not tried.

### Benchmark

The cases were lengthened first (controller's ruling; 3f4dd1c69). pushpop8 runs 10,000,000 rounds, and
push10m is done 3 times into fresh arrays and summed. `run-bench.sh` now also prints p25/p75 (rank
(n+1)/4 and 3(n+1)/4: the 4th and 12th of 15). There were 15 runs per case per prefix, prefixes alternating,
`MVM_SPESH_BLOCKING=1`, and the load below 2.0 at every start:
- pre: `run-bench.sh -n 15 -o ob-fixes-raw/bench-z-pre vf-c-base vf-n-base ob-c ob-n`, with ob-c/ob-n
  built at 3f4dd1c69 (2e32a3191 plus the benchmark commit; src identical to 3393c5932). Loads 1.09-1.52.
- post: `-o ob-fixes-raw/bench-z-post ob-c ob-n`, with ob-c/ob-n at ec2e4f080. Loads 1.61-1.94.
- control: the post loads were higher, so the post run was repeated interleaved with the unchanged vf
  prefixes (`-o ob-fixes-raw/bench-z-post-control vf-c-base vf-n-base ob-c ob-n`, started at load < 1.3,
  loads 1.39-1.98). vf moved by -0.7 to +2.7 %, and ob moved as in the post run. So the slowdown is the
  fix, not the machine.

The raw lines are in `bench-<prefix>.txt` and the values in `bench-medians.txt` of each directory. Seconds
are shown as median (p25-p75). The rule: worse when the post median is > 5 % above the pre median and above
the pre p75.

| build | case | vf baseline | pre-Z | post-Z | post vs pre | verdict | control run: post-Z, and vf vs its baseline |
|---|---|---|---|---|---|---|---|
| ob-c | int.push10m | 0.5816 (0.5769-0.5854) | 0.5931 (0.5870-0.6077) | 0.7033 (0.6882-0.7289) | +18.6 % | worse | 0.6922 (+16.7 %); vf 0.5927 (+1.9 %) |
| ob-c | obj.push10m | 0.5878 (0.5838-0.5941) | 0.6313 (0.6034-0.6378) | 0.7174 (0.6930-0.7269) | +13.6 % | worse | 0.6979 (+10.5 %); vf 0.6001 (+2.1 %) |
| ob-c | int.pushpop8 | 0.8457 (0.8299-0.8614) | 0.8997 (0.8810-0.9781) | 1.1259 (1.1120-1.1588) | +25.1 % | worse | 1.1170 (+24.2 %); vf 0.8395 (-0.7 %) |
| ob-c | obj.pushpop8 | 0.8620 (0.8449-0.8940) | 0.9299 (0.9123-1.0274) | 1.1838 (1.1414-1.2674) | +27.3 % | worse | 1.1485 (+23.5 %); vf 0.8804 (+2.1 %) |
| ob-n | int.push10m | 0.5848 (0.5757-0.5890) | 0.5456 (0.5432-0.5494) | 0.6619 (0.6470-0.6853) | +21.3 % | worse | 0.6555 (+20.1 %); vf 0.5939 (+1.6 %) |
| ob-n | obj.push10m | 0.5807 (0.5786-0.5908) | 0.5585 (0.5533-0.5641) | 0.6944 (0.6612-0.7101) | +24.3 % | worse | 0.6729 (+20.5 %); vf 0.5963 (+2.7 %) |
| ob-n | int.pushpop8 | 0.8106 (0.8095-0.8156) | 0.7359 (0.7317-0.7635) | 0.9448 (0.9338-1.0203) | +28.4 % | worse | 0.9494 (+29.0 %); vf 0.8178 (+0.9 %) |
| ob-n | obj.pushpop8 | 0.8244 (0.8236-0.8304) | 0.8050 (0.7560-0.8088) | 1.1036 (1.0393-1.1517) | +37.1 % | worse | 1.0331 (+28.3 %); vf 0.8373 (+1.6 %) |
Every case is worse on both builds, by +13.6 % to +37.1 % (worst: ob-n obj.pushpop8, pre 0.8050, p75 0.8088;
post 1.1036). The likely cost is one out-of-line `zero_slots` / `zeroSlots` (a switch and a one-slot
memset) on every push into spare room, a slot that push overwrites at once. This is by reading; not
profiled.

The vf column is context only. vf and pre-Z differ by Tasks 2-4's fixes. On the pushpop8 cases pre-Z ob-c
is 6-8 % slower than vf-c-base, and ob-n 9 % faster than vf-n-base, measured in the same interleaved run.
Not investigated.

### Tests and reproducers

- Unit tests at 8223cc952 (load 1.72, 1.90, under 2.0 for the gc-debug run):
  - default 250/262 (12 skipped);
  - `-Dzig-reprs=false` 250/262 (12 skipped);
  - `-Dgc-debug=1` 255/262 (7 skipped).

  That is Task 4's 248/261 (13), 248/261 (13), 253/261 (8), plus the new test and the enabled one. Before
  the fix (default) both failed: 248/262, 2 failed.
- New test "growth within storage zeroes the exposed slots", run through E and the library's table: every
  stored kind, three cases on 8 slots with 0xa5 past the window:
  - start 0, elems 3 -> 6;
  - start 1, elems 2 -> 5 (no move);
  - start 1, elems 2 -> 8 (move).

  It checks elems, ssize, start, the live bytes, the exposed slots being zero and the slots past the new end
  being kept. It clears every slot before any check can return.
- "write_buf into spare room of an adopted buffer" is enabled (the `growth_within_storage_zeroes` switch is
  removed).
- OB4-adopted-setelems.nqp (ob-fixes-raw/before-z, after-z):
  - before, on vf-c-base, vf-n-base, ob-c and ob-n: `heap prepared ... = 99` and `element 2 != 0`;
  - after, on ob-c and ob-n: `heap prepared ... = 99` and `element 2 = 0`.

  cmp.sh gives c=n.
- Harness ec2e4f080: `ob.adopted.setelems.normalizecodes`, `ob.adopted.setelems.encode` (a control: encode
  adopts with ssize = elems, so it reallocates; the brief named encode), and `ob.splice.clear.{setelems,
  bindpos}.<kind>`.

### Not run (stopped by the rule)

The following were not run: diff.sh, the suites, and the rest of run-all.sh. The new diff cases have
never run. Until diff.sh runs, nothing shows that C and Zig agree beyond the unit test and the two
reproducers.

## Z, second mechanism (accepted by the controller)

The controller ruled on the first block as follows. Growth within the storage still only exposes zeroed
slots by default. The callers that write every slot they expose grow through an entry that does not zero.
The splice defect is OB21. The pre-Z gap is to be localised only.

### The change

Commits in P: 963665442 (C), 8b1ff900c (Zig mirror with the tests). These are follow-ups on
top of 591f3c20b / 8223cc952; history is not rewritten.

- C: the body of `set_size_internal` becomes `set_size_internal_with(..., MVMuint8 zero_exposed_slots)`,
  which applies the first mechanism's zeroing only when the flag is set. `set_size_internal` passes 1, and
  every caller keeps it. `set_size_internal_caller_writes` passes 0 and is used only by push and unshift.
  All three are plain `static`.
- Zig: `setSize` (true) and `setSizeCallerWrites` (false) both go through `inline fn setSizeWith(...,
  comptime zero_exposed_slots: bool)`. push and unshift use `setSizeCallerWrites`.
- Which callers opt out:
  - push opts out. It checks the register kind before growing (981c4a8f2; Zig `Arm(.push).check` before
    `setSize`). Between the growth and the store nothing can throw except the store switch's default arm,
    which serves only slot types without storage. Area K makes those impossible to compose, and they have
    no bytes to expose. `MVM_ASSIGN_REF` does not throw. The exposed slot `start + elems - 1` is stored.
  - unshift at start 0 opts out. The growth to `elems + n` is followed by the memmove of the elements to
    `n .. n + elems` and by `zero_slots(0, n)`. That covers `0 .. n + elems`, the whole exposed range. Only
    `zero_slots`' default arm (no storage, as above) can throw in between. The register-kind check comes
    after `elems` is set back. Slots past `n + elems` keep what they held, still past the window, and a
    later zeroing growth starts from that window's end.
  - aslice does not opt out. `copy_elements` can throw after the growth: the element path calls bind_pos
    with the destination's kind, and aslice does not compare kinds, so the C API can hand it a destination
    of another kind. Its callers (interp OP(slice), MVM_repr_pos_slice, the JIT's call of that) pass a
    fresh `alloc_init` destination (ssize 0), so its growth always reallocates and the zeroing default
    costs nothing there.
  - bind_pos, `vmarray_bind_pos_int64` (JIT), set_elems, write_buf and asplice stay on the default.

### OB21 (found in Task 5)

`asplice` at offset 0 with `count - elems1 >= elems` sets `start = 0, elems = 0` without clearing the
removed elements' slots (VMArray.c asplice, the `n <= -(MVMint64)elems0` arm; Zig asplice the same). Growth
within the storage then brought them back; for an object array they are pointers the collector no longer
marks. Area Z's zeroing default covers it, and there is no second fix at the reset (ruling).
`ob-repro/Z-splice-clear-setelems.nqp`:

| prefix | int: setelems 4 after splice(0, 4) | obj: bindpos 2 after splice(0, 3) |
|---|---|---|
| vf-c-base, vf-n-base (before-z) | `11 22 33 44` | `a b z` |
| ob-c, ob-n pre-Z at 3f4dd1c69 (before-z) | `11 22 33 44` | `a b z` |
| ob-c, ob-n first mechanism at ec2e4f080 (after-z) | `0 0 0 0` | `<null> <null> z` |

Unit test "OB21: a splice at offset 0 removing every element leaves nothing for growth to bring back":
- an int and an object array, through E and the library;
- the object array's elements are fresh nursery objects, with two nursery collections between the splice
  and the growth (and a forced full one under -Dgc-debug=1);
- after setelems 3: NULL slots, VMNull from at_pos, and zeros for the int array.

Differential: `ob.splice.clear.setelems.<kind>` and `ob.splice.clear.bindpos.<kind>` (ec2e4f080). They have
not run yet (see below).

### Tests

Unit tests at 8b1ff900c (loads 1.94, 1.77, 1.84):
- default 252/264 (12 skipped);
- -Dzig-reprs=false 252/264 (12 skipped);
- -Dgc-debug=1 257/264 (7 skipped).

That is the first mechanism's totals plus the two new tests:
- "push, unshift and aslice into dirty spare room leave no stale slot observable": every stored kind, E and
  the library. The spare room is dirtied with 0xa5, then a push into 8 slots, an unshift at start 0 into 16
  slots and an aslice into a destination with 8 slots, each staying within ssize. Every element is read,
  then a setelems over the rest reads holes.
- the OB21 test above.

Probe (not committed): with the Zig default turned to "no zeroing" temporarily, the four Z tests failed on
their E pass. The new push/unshift/aslice test failed at the follow-up setelems, which read 0xa5... as an
object pointer. The OB21 test read 11. So the tests see stale slots.

### Benchmark

`run-bench.sh -n 15 -o ob-fixes-raw/bench-z2-post vf-c-base vf-n-base ob-c ob-n`, with ob-c/ob-n at 8b1ff900c,
started at load 1.24 (loads at the starts 1.24-1.99). Compared with the pre-Z numbers of
ob-fixes-raw/bench-z-pre (same method); the vf prefixes ran alongside as the machine control.

| build | case | vf baseline (pre run) | pre-Z | post-Z (second mechanism) | post vs pre | verdict | vf in this run vs its pre run |
|---|---|---|---|---|---|---|---|
| ob-c | int.push10m | 0.5816 (0.5769-0.5854) | 0.5931 (0.5870-0.6077) | 0.6018 (0.5933-0.6217) | +1.5 % | not worse | 0.5921 (+1.8 %) |
| ob-c | obj.push10m | 0.5878 (0.5838-0.5941) | 0.6313 (0.6034-0.6378) | 0.6212 (0.6149-0.6301) | -1.6 % | not worse | 0.6025 (+2.5 %) |
| ob-c | int.pushpop8 | 0.8457 (0.8299-0.8614) | 0.8997 (0.8810-0.9781) | 0.9375 (0.9011-0.9699) | +4.2 % | not worse | 0.8422 (-0.4 %) |
| ob-c | obj.pushpop8 | 0.8620 (0.8449-0.8940) | 0.9299 (0.9123-1.0274) | 0.9865 (0.9347-1.0320) | +6.1 % | not worse | 0.8652 (+0.4 %) |
| ob-n | int.push10m | 0.5848 (0.5757-0.5890) | 0.5456 (0.5432-0.5494) | 0.5628 (0.5559-0.5737) | +3.2 % | not worse | 0.5925 (+1.3 %) |
| ob-n | obj.push10m | 0.5807 (0.5786-0.5908) | 0.5585 (0.5533-0.5641) | 0.5875 (0.5758-0.5980) | +5.2 % | worse | 0.5972 (+2.8 %) |
| ob-n | int.pushpop8 | 0.8106 (0.8095-0.8156) | 0.7359 (0.7317-0.7635) | 0.7437 (0.7103-0.7861) | +1.1 % | not worse | 0.8184 (+1.0 %) |
| ob-n | obj.pushpop8 | 0.8244 (0.8236-0.8304) | 0.8050 (0.7560-0.8088) | 0.8295 (0.7986-0.8890) | +3.0 % | not worse | 0.8343 (+1.2 %) |
One case is worse under the rule: ob-n obj.push10m, pre 0.5585 (p75 0.5641), post 0.5875, +5.2 %. In the
same run vf-n-base obj.push10m was +2.8 % against its own pre run, so the machine accounts for part of it.
The rule was applied as it stands. ob-c obj.pushpop8 is +6.1 % but below the pre-Z p75 (1.0274), so it is
not worse. Every other case is within +4.2 %. Status at that point: BLOCKED. The remaining steps were then
run in the third round (below).

Controller's ruling A, against the letter of the stop rule: area Z's second mechanism is accepted as
committed (963665442, 8b1ff900c). The reasons given:
- the single case over the rule (ob-n obj.push10m, +5.2 %) had a machine drift of +2.8 % (vf-n-base) in the
  same run;
- push no longer zeroes;
- Task 4's int.pushpop8 change of +6.7 % in the C build, with no source change on that path (below), shows
  that code layout alone moves these cases by more than the 5 % threshold.

### The pre-Z gap (ruling 4, localisation only)

C-REPR prefixes were built from `git archive` copies (scratch script `build-c-at.sh`, the
build-prefixes.sh steps for one commit): /tmp/claude-1000/ob-c-t2 at d6dcc43e3 (after Task 2), ob-c-t3 at
cd2826682 (after Task 3) and ob-c-t4 at 2e32a3191 (after Task 4, = pre-Z src). The run was `run-bench.sh -n
15 -o ob-fixes-raw/bench-z-gap vf-c-base ob-c-t2 ob-c-t3 ob-c-t4`, interleaved, starting at load 1.24 (1.24-1.96).
Medians (p25-p75), and the change against vf-c-base in the same run:

| case | vf-c-base | ob-c-t2 (Task 2) | ob-c-t3 (Task 3) | ob-c-t4 (Task 4) |
|---|---|---|---|---|
| int.push10m | 0.6022 (0.5925-0.6051) +0.0 % | 0.5916 (0.5900-0.5958) -1.8 % | 0.6029 (0.5994-0.6162) +0.1 % | 0.6074 (0.5990-0.6120) +0.9 % |
| obj.push10m | 0.5998 (0.5983-0.6050) +0.0 % | 0.5991 (0.5970-0.6023) -0.1 % | 0.6327 (0.6204-0.6528) +5.5 % | 0.6280 (0.6117-0.6462) +4.7 % |
| int.pushpop8 | 0.8447 (0.8366-0.8656) +0.0 % | 0.8625 (0.8363-0.8684) +2.1 % | 0.8531 (0.8388-0.8824) +1.0 % | 0.9016 (0.8910-0.9395) +6.7 % |
| obj.pushpop8 | 0.8644 (0.8535-0.8698) +0.0 % | 0.8984 (0.8672-0.9177) +3.9 % | 0.9935 (0.9482-1.0507) +14.9 % | 0.9815 (0.9200-1.0396) +13.5 % |
- obj.pushpop8 (+14.9 %) and obj.push10m (+5.5 %): the change comes with Task 3. ob-c-t2 is at +3.9 %
  and +0 %.
- int.pushpop8 (+6.7 %): the change comes with Task 4. ob-c-t3 is at +1.0 %.

Likely reasons, by reading the diffs only (the libraries are stripped; not profiled):
- Task 3, 981c4a8f2 split `MVM_VMArray_push` into a register-kind switch before `set_size_internal` and a
  store switch after it: two dispatches on `slot_type` where there was one. For OBJ the store is
  `MVM_ASSIGN_REF`, which reloads `body->start`/`body->elems` and `root` after the call. Why OBJ pays more
  than the int kinds is not explained by the source alone; code layout or inlining is likely to have changed
  with the larger function.
- Task 4, bb0eda68f (pop/shift OBJ arm: `found ? found : VMNull`) touches only the OBJ arm, so it does not
  explain int.pushpop8. The other VMArray.c changes in Task 4 are outside push/pop: write_buf (48fd69052),
  and deserialize plus `slot_budget` in set_size_internal's reallocating path (ec2ad02f7). So no source
  change on the int push/pop path explains the +6.7 %, and code layout (alignment) of the push/pop loop is
  the likely cause. This is not verified.

### Push follow-up (controller's ruling B: one attempt, C only)

Task 3's 981c4a8f2 split the C push into a register-kind switch before the growth and a store switch
after it. The localisation above puts the object push/pop slowdown of the C build at that task. The single
attempt was the "expected kind lookup" form. The register-kind check became one compare against a static
table indexed by slot type (`push_register_kinds`: the register kind and the word of the message, for the
12 slot types with a store arm). Slot types without an entry are not checked and are refused by the store,
as before. The store switch is the only dispatch, on the slot type read once at entry. The messages are
byte-identical (`"MVMArray: push expected %s register"` with object/string/int/num). Nothing is grown
before the throw. This form was chosen over a check-grow-store arm per slot type because it keeps one call
of set_size_internal_caller_writes and one store switch, the simpler code for the compiler.

Measured: the attempt built from a `git archive` copy of 8b1ff900c with the changed VMArray.c
(/tmp/claude-1000/ob-c-push, scratch), with `run-bench.sh -n 15 -o ob-fixes-raw/bench-z-push vf-c-base
ob-c-t2 ob-c ob-c-push`, interleaved, starting at load 1.27 (1.27-1.94). Medians (p25-p75):

| case | vf-c-base | ob-c-t2 (after Task 2) | ob-c (8b1ff900c) | attempt | attempt vs ob-c-t2 | attempt vs ob-c |
|---|---|---|---|---|---|---|
| int.push10m | 0.5992 (0.5913-0.6075) | 0.5891 (0.5875-0.5970) | 0.6019 (0.5985-0.6091) | 0.5850 (0.5833-0.5887) | -0.7 % | -2.8 % |
| obj.push10m | 0.6033 (0.6004-0.6056) | 0.6024 (0.5970-0.6110) | 0.6265 (0.6080-0.6443) | 0.6061 (0.6011-0.6101) | +0.6 % | -3.3 % |
| int.pushpop8 | 0.8441 (0.8362-0.8546) | 0.8434 (0.8354-0.8532) | 0.8959 (0.8868-0.9393) | 0.8262 (0.8199-0.8679) | -2.0 % | -7.8 % |
| obj.pushpop8 | 0.8987 (0.8675-0.9067) | 0.8635 (0.8610-0.9018) | 0.9986 (0.9391-1.0463) | 0.8974 (0.8816-0.9475) | +3.9 % | -10.1 % |
The acceptance test: obj.pushpop8 and obj.push10m within 5 % of ob-c-t2 (+3.9 %, +0.6 %), and no int case
more than 5 % worse than the current C build (-2.8 %, -7.8 %: both faster). Accepted and committed as
b87b79815 "VMArray push: one dispatch on the slot type" (C only). Before the build, the C-REPR unit run on
the attempt passed 252/264 (12 skipped), with Task 3's rejected-push tests and area Z's dirty-spare-room
test unchanged.

Zig is not changed. Zig's push has the same order (`kinds.dispatch(..., Arm(.push).check)` before
`setSizeCallerWrites`, then the store dispatch). But its check is the port's comptime per-kind arm, which
pop, unshift and bind_pos use too, and it is not a C-style switch. The two sides are parallel in order and
behaviour (diff.sh identical, the same unit tests), not in the dispatch mechanism, which already differs
everywhere. The Zig build has no slowdown to recover: pre-Z ob-n was 6-9 % faster than vf-n-base on the
pushpop8 cases. Rewriting only Zig's push to a table would make it unlike its siblings and is not needed
for parallelism, so no Zig measurement was taken.

### Third round: the remaining steps on the final tree (b87b79815)

- Unit tests (loads 1.53, 1.94, 1.79):
  - default 252/264 (12 skipped);
  - -Dzig-reprs=false 252/264 (12 skipped);
  - -Dgc-debug=1 257/264 (7 skipped).

  `zig fmt --check src/zig build.zig` is clean.
- `build-prefixes.sh`: ob-c and ob-n exit 0 at b87b79815 (60 s and 61 s, load 1.86 and 1.74); export lists
  equal.
- `diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t5`:
  exit 0, `diff.sh: identical (3 runs a side; lines: diff-nqp/spesh 11082 diff-nqp/nospesh 11082
  diff-raku/spesh 2497 diff-raku/nospesh 2497 serial/spesh 196 serial/nospesh 196 devirt/spesh 10
  devirt/nospesh 10; cross-read identical)` (log: ob-fixes-raw/diff-t5.log).

  The new cases ran for the first time; they account for the 26 new nqp lines (11056 -> 11082):
  - `ob.adopted.setelems.encode: elems=6 [97 98 99 0 0 0]`;
  - `ob.adopted.setelems.normalizecodes: elems=3 [233 97 0]`;
  - `ob.splice.clear.setelems.<kind>`: four holes or zeros;
  - `ob.splice.clear.bindpos.<kind>`: four holes or zeros, then the bound value.

  undefined-lines.txt is unchanged.
- Reproducers: `run-all.sh -p ob-c|ob-n -o ob-fixes-raw/after-t5` and `cmp.sh`: c=n for all 41 outputs.
  - OB4: `heap prepared ... = 99` and `element 2 = 0` on both.
  - Z-splice-clear-setelems: `0 0 0 0` and `<null> <null> z` on both.
  - Every other output equals its latest earlier run: after-t4, after-t3 or after-t2. For OB3 and OB9 that
    is the baseline, because their areas come later.
- Suites (`ob-repro/maketest-driver.sh ob-fixes-raw/suites-t5`):
  - nqp PASS on both (Files=150, Tests=13746);
  - Rakudo FAIL on both (Files=599, Tests=11162), only `t/04-nativecall/02-simple-args.t` 17-18 (OB15a).

  The four per-file lists equal suites-t4's.
- The scratch prefixes ob-c-t2, ob-c-t3, ob-c-t4 and ob-c-push, with their -src copies and build logs, are
  removed.

## Z, fix round 1 (review)

### The gap

The review ran /tmp/claude-1000/rv5/prog/Zgap-shift-realloc.nqp (now `ob-repro/Z-shift-realloc.nqp`). The
program splices a 4-element list down to empty at offset 0, pushes 5, shifts it off (start 1, elems 0, the
removed elements still in slots 1-3), then grows past ssize with setelems 20 or bindpos 19.

`set_size_internal` moved the window to start 0 and zeroed the slots the old window held, then set its
clear point to the old ssize. The reallocation then zeroed from there. Slots from the old window's end to
the old ssize were never zeroed. This was safe only while every slot past the window was zero, and area Z
gave that up. The first two rounds' path analysis missed it, because it took "a reallocation zeroes the new
room" as enough.

| prefix | int: setelems 20 / bindpos 19 (slots 0-7) | obj: setelems 20 (0-3) |
|---|---|---|
| vf-c-base, vf-n-base (before-z-fix1) | `0 22 33 44 0 0 0 0` (both) | `<null> b c <null>` |
| ob-c, ob-n at b87b79815 (before-z-fix1; the reviewer's /tmp/claude-1000/rv5/out/ are the same) | `0 22 33 44 0 0 0 0` | `<null> b c <null>` |
| ob-c, ob-n at bf39c32cc (after-z-fix1) | `0 0 0 0 0 0 0 0` | `<null> <null> <null> <null>` |

### The fix

Commits: eb98fd0ba (C), 30ce0ba0a (Zig mirror with tests), bf39c32cc (harness).

What can be non-zero, re-derived (C and Zig alike), with the old window [s, s + e) in an ssize-slot
buffer:
- before the move: [0, s) (shift's slots, asplice's adjustment) and [s + e, ssize) (adopted spare room,
  OB21);
- the move writes [0, e) with the elements and zeroes [e, s + e), so after it only [s + e, ssize) may be
  non-zero.

The reallocation must therefore zero from s + e (= old_window_end, taken at entry) to the new ssize. It
used to start at the old ssize. Without a move the reallocation runs with start 0, so old_window_end ==
elems, as before:
- start > 0 with n + start <= ssize stays within the storage;
- an n + start that wraps (n >= 2**64 - start) makes the new size exceed the limit, so it throws before
  anything changes.

Two more cases were checked:
- "n below the old ssize but the rounding sends it to reallocation" cannot happen: the branch is chosen by
  `n <= ssize` before any rounding.
- When the move ends within the storage, its zeroing plus the zeroing from old_window_end to the new
  window's end cover everything exposed.

C: the `elems = ssize` clear point in the move branch is gone, and the reallocation zeroes from
old_window_end. Zig: `clear_from` is gone, and `grow` gets old_window_end. A comment at
`set_size_internal_with` / `setSizeWith` states the invariant. The caller-writes comments now say that
push's and unshift's guarantee rests on area K.

push cannot reach the changed case. With start > 0, elems + start <= ssize, so push's n = elems + 1 <=
ssize: after the move it stays within the storage. A reallocation from push has start 0, where the clear
point is elems as before.

### The path analysis again, with the invariant

Each path below was checked. None has the shape of this gap.
- grow's rounding branches only compute the new ssize; they zero nothing else. The `ssize < n` and limit
  throws come before the reallocation; at most the move has happened, which keeps the elements.
- The compaction test's `n + start` wrap throws in the size checks, before any change (above).
- copy_to (C and Zig) gives the destination ssize = elems and start 0: no room past the window. deserialize
  sets ssize = elems.
- asplice:
  - the tail move left comes before a shrink (which zeroes the dropped slots), and the tail move right comes
    after a zeroing growth;
  - the offset-0 adjustment with n > 0 brings slots below start into the window; they are [0, n) of the new
    window, and copy_elements writes [0, elems1) with n <= elems1 - count. Nothing in between collects:
    at_pos and bind_pos of VMArrays do not allocate, and the kinds were checked before;
  - the n < 0 adjustment and the reset leave slots outside the window, which the invariant allows.
- write_buf grows with the zeroing default, then memcpys into the window. The trailing bytes of the last
  element were zeroed by the growth.
- The JIT bind entry (`vmarray_bind_pos_int64`, Zig `bindPosKind.jit`) and bind_pos use the zeroing
  default.
- unshift:
  - at start 0 it grows through caller-writes and then writes all of [0, n + elems); a reallocation there
    has start 0;
  - at start > 0 it writes slot start - 1 (possibly a shift's leftover) before `start--`.
- push: proven above.
- pop zeroes the slot it leaves. shift's leftover is below start and is covered by the move.
- at_pos past elems returns zero without reading slots. The collector marks only the window.
- Other C users of the body (nativecall's unmarshal, the io and Decoder readers, encode, loadbytecode) read
  only the window or adopt with ssize = elems.

### Tests

Both tests failed before the fix (default 251/265, 2 failed: the obj case "exposed slots not zero" and "expected
0, found 22"):
- "growth within storage zeroes the exposed slots" gains the case start 1, elems 2, dirty spare room, grow to
  9 in 8 slots (move plus reallocation to 16). Slots 2-15 must be zero, for every stored kind, through E and
  the library.
- New "OB21 through a reallocation: a shift before the growth leaves nothing to bring back":
  - an int array, and an object array of fresh nursery objects;
  - collected before the growth, fully under -Dgc-debug=1;
  - all 20 elements read as holes or zeros afterwards.

After the fix (bf39c32cc tree, loads 1.63, 1.74, 1.83):
- default 253/265 (12 skipped);
- -Dzig-reprs=false 253/265 (12 skipped);
- -Dgc-debug=1 258/265 (7 skipped).

Differential: `ob.splice.clear.shift.setelems.<kind>` and `ob.splice.clear.shift.bindpos.<kind>`. These are
24 new lines, all holes or zeros (bindpos: the bound value at 19).

### Gates on bf39c32cc

- `zig fmt --check` is clean. `build-prefixes.sh`: ob-c and ob-n exit 0 (60 s each, load 1.66 and 1.91);
  export lists equal.
- `diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t5-fix1`:
  exit 0, `diff.sh: identical (3 runs a side; lines: diff-nqp/spesh 11106 diff-nqp/nospesh 11106
  diff-raku/spesh 2497 diff-raku/nospesh 2497 serial/spesh 196 serial/nospesh 196 devirt/spesh 10
  devirt/nospesh 10; cross-read identical)` (log: ob-fixes-raw/diff-t5-fix1.log).
- `run-all.sh` on both into ob-fixes-raw/after-z-fix1: 41 of 42 outputs c=n.
  - The exception is `OB3-writeint-jit.nqp.writeint_flags_16` (the plain run, spesh and JIT at their
    defaults): ob-n printed `died all, returned none ... element 0 0`, ob-c `died some, returned some`.
  - That is OB3 (not yet fixed; Task 6). Its plain-run outcome depends on whether the JIT takes over in time,
    and the `.jitlog` run under `MVM_SPESH_BLOCKING=1` is c=n.
  - Five re-runs on each prefix all gave `died some, returned some`, so this was a one-off timing outlier
    and not area Z.
  - Every other ob-c output equals after-t5's, and Z-shift-realloc is fixed (above).
- Suites (`maketest-driver.sh ob-fixes-raw/suites-t5-fix1`):
  - nqp PASS on both;
  - Rakudo FAIL on both, only 02-simple-args.t 17-18 (OB15a).

  The per-file lists equal suites-t4's.

### Benchmark sanity check

`run-bench.sh -n 15 -o ob-fixes-raw/bench-z-fix1 vf-c-base vf-n-base ob-c ob-n`, started at load 1.24
(1.12-1.35). The previous round is the push attempt's numbers for C (bench-z-push, ob-c-push, the same code
as b87b79815) and bench-z2-post for Zig. The rule was: stop if a median is more than 5 % above the previous
round's p75.

| build | case | previous round, median (p25-p75) | now | change | check |
|---|---|---|---|---|---|
| ob-c | int.push10m | ob-c-push 0.5850 (0.5833-0.5887) | 0.5746 (0.5709-0.5854) | -1.8 % | ok |
| ob-c | obj.push10m | ob-c-push 0.6061 (0.6011-0.6101) | 0.5910 (0.5839-0.5969) | -2.5 % | ok |
| ob-c | int.pushpop8 | ob-c-push 0.8262 (0.8199-0.8679) | 0.8158 (0.8140-0.8434) | -1.3 % | ok |
| ob-c | obj.pushpop8 | ob-c-push 0.8974 (0.8816-0.9475) | 0.8920 (0.8752-0.9258) | -0.6 % | ok |
| ob-n | int.push10m | ob-n 0.5628 (0.5559-0.5737) | 0.5457 (0.5404-0.5530) | -3.0 % | ok |
| ob-n | obj.push10m | ob-n 0.5875 (0.5758-0.5980) | 0.5625 (0.5583-0.5942) | -4.3 % | ok |
| ob-n | int.pushpop8 | ob-n 0.7437 (0.7103-0.7861) | 0.7168 (0.7129-0.8089) | -3.6 % | ok |
| ob-n | obj.pushpop8 | ob-n 0.8295 (0.7986-0.8890) | 0.7902 (0.7564-0.8993) | -4.7 % | ok |
| vf-c-base (control) | int.push10m | 0.5992 | 0.5809 (0.5795-0.5843) | -3.1 % | |
| vf-c-base (control) | obj.push10m | 0.6033 | 0.5858 (0.5843-0.5941) | -2.9 % | |
| vf-c-base (control) | int.pushpop8 | 0.8441 | 0.8448 (0.8325-0.8662) | +0.1 % | |
| vf-c-base (control) | obj.pushpop8 | 0.8987 | 0.8597 (0.8500-0.8908) | -4.3 % | |
| vf-n-base (control) | int.push10m | 0.5925 | 0.5774 (0.5745-0.5836) | -2.5 % | |
| vf-n-base (control) | obj.push10m | 0.5972 | 0.5818 (0.5775-0.5839) | -2.6 % | |
| vf-n-base (control) | int.pushpop8 | 0.8184 | 0.8120 (0.8114-0.8170) | -0.8 % | |
| vf-n-base (control) | obj.pushpop8 | 0.8343 | 0.8286 (0.8245-0.8367) | -0.7 % | |
No case moved above the bound. All are 0.6-4.7 % faster, in line with the vf controls (-4.3 to +0.1 %), so the
machine was quieter.

### Seen on the way (not verified, not fixed; to be OB22)

- P6opaque.c `oslice` passes the `dest` that interp's OP(slice) made with `MVM_repr_alloc_init` of the
  P6opaque source on to the positional delegate's `slice`. The delegate is a VMArray, so `aslice` then
  treats the P6opaque's body as an `MVMArrayBody` (`set_size_internal` and `copy_elements` on it). This is
  type confusion if `nqp::slice` is ever applied to a P6opaque with a positional delegate. By reading only;
  a candidate for the bug list.

## Shared C

OB1, OB3, OB5, OB9 and OB10: C that both builds share; the port has no Zig version of any of it (checked:
no Zig file defines the JIT, the interpreter's ops, reprconv.c, MVMHash, normalize.c or encode; the only
Zig mentions of normalize.c and encode are comments in storage.zig and vmarray_storage_test.zig). No Zig
file was changed; Zig's readBuf/writeBuf stay as they are (controller's ruling).

### The fix

Commits in P (zig-open-bugs), one per bug id:

| id | commit | file(s) |
|---|---|---|
| OB1 | 30134b931 | VMArray.c `set_size_internal_with`: `~0xfffUL` becomes `~(MVMuint64)0xfff` |
| OB3 | f2c32559a | jit/graph.c, core/interp.c, 6model/reprconv.c |
| OB5 | fd8f245f5 | MVMHash.c `deserialize`: `MVMROOT(tc, key)` around `MVM_serialization_read_ref` |
| OB9 | a8bfc11fd | normalize.c `MVM_unicode_normalize_codepoints`: empty input empties the output |
| OB10 | 2c7d1dfb9 | strings/ops.c `MVM_string_encode_to_buf_config`: the encoded buffer has an owner across the resize |

- OB1: found by reading, not run (it needs 64-bit Windows). storage.zig already masks with
  `~@as(u64, 0xfff)`.
- OB3, JIT (readuint, writeint, writeuint): with the flags a known value, the JIT compiles only sizes 1, 2,
  4 and 8 with a valid byte order. Any other known flags (`(flags & 3) == 3` or `flags >> 2 > 3`, the
  test made on the flags as `MVMuint64`, before the size is computed) add the comment `BAIL: op <%s>, -
  invalid flags (%"PRIu64"), left to the interpreter` and `return 0` from `consume_ins`, so the
  specialization runs in the interpreter, whose op throws. Unknown flags already bailed (`no known value
  for writeint flags` / `for readint flags`), so that path was checked before and is unchanged. readint
  has no case in `consume_ins` at all (the default arm bails). The buffer ops have no expression
  templates, so `consume_ins` is the only JIT path.
- OB3, writenum: sizes other than 4 and 8 throw `Cannot write a num of %d bytes`, after the type-object
  check, before anything is written (as readnum). readnum does not refuse `(flags & 3) == 3`: only
  `MVM_SWITCHENDIAN` (2 on little-endian) swaps, so flags 3 reads in native order. writenum already did
  the same and still does (`writenum flags 15 (size 8): returned`).
- OB3, the bug list's two open points, both defects, both fixed in the OB3 commit:
  - `MVM_SC_WB_OBJ` / `IS_CONCRETE`. The SC write barrier: every other mutating op the JIT compiles
    calls `jg_sc_wb` after its write (push, unshift, bindpos, bindkey, bindattr ...), the JIT's writeint
    did not, so a JIT-compiled write to an SC-owned buffer was not repossessed. It now calls `jg_sc_wb`
    after either call. Concreteness: the direct-REPR branch requires `MVM_SPESH_FACT_CONCRETE`, but the
    other branch called `MVM_repr_write_buf` / `MVM_repr_read_buf`, which passed a type object's missing
    body to the REPR (a type object is `sizeof(MVMObject)`, gc/allocation.c). Shown before the fix (probe
    `typeobj-buffer-jit.nqp`, buffer from `nqp::atpos` of a list, last 3 of 200,000 calls on the type
    object; ob-c at bf39c32cc, default settings): readuint ended in `MVMArray: read_buf out of bounds
    offset 0 start 9007199254740993 elems 0 count 1` (a garbage read), writeint in SIGSEGV. The two
    functions, called only by the JIT (`grep -rn MVM_repr_read_buf src`), now throw the interpreter's
    `Cannot read from a %s type object` / `Cannot write to a %s type object`; after the fix the probe
    gives those messages in all modes on both builds.
  - `1 << (flags >> 2)`. An int shift, undefined for shifts of 31 and over, and truncated to an unsigned
    char from shift 8 on (size 0, which `size > 8` let through). Shown before (probe `size-shift.nqp`,
    interpreted): flags 32 and 136 returned, 128 read as size 1, and 34, 130, 138 made `switch_endian`
    panic (`MoarVM panic: Invalid size (0|1|4) when attempting to switch endianness of 1`; sizes 1 and 4
    are handled there, so that is the undefined shift miscompiled). The four ops now take the size from
    `buffer_op_size_from_flags` (interp.c), which gives 0 for any shift over 7, and readint/readuint and
    writeint refuse 0 with the sizes over 8 (readnum and writenum refuse it as not 4 or 8). After: every
    such flags value throws the op's own message. The JIT computes its size only for shifts up to 3.
- OB5: see "OB5 and OB10 by reading" below.
- OB9: the empty path frees the output's slots and leaves it with slots NULL, start 0, elems 0, ssize 0
  (a freshly created array's state), as the non-empty path replaces the storage (with #2083's ssize in
  elements). The commit names #2083 (5c3f435bb here). Checked afterwards: the emptied output takes push and
  setelems (`elems 4: 5 0 0`), and an empty array normalized into itself stays empty.
- OB10: there is no hook that frees a C buffer on a throw (threadcontext.h has only the ex_release mutex
  and atomic), and a size check before the resize could only copy the REPR's limits and rounding (C and
  Zig). So in the append branch an empty array of buf's type (`MVM_repr_alloc` of `STABLE(buf)->WHAT`,
  with buf rooted) owns the encoded buffer (`slots.u8 = encoded`) from before the resize until the copy;
  it is rooted with buf across the resize and the copy, then its slots are set to NULL and the buffer
  freed. On a throw it is garbage, and both collectors call VMArray's gc_free (C and Zig free
  `slots.any`) for a dead nursery object (gc/collect.c 594-599, zig/gc/collect.zig 709-715). Cost: one
  small allocation per append; a fresh, empty target is handed the buffer as before.
- OB10, a caller of the append branch: nqp's compiler. `add-internal` in QASTCompilerMAST.nqp (nqp 41e7210ba,
  lines 2499-2501, checked in Task 7) takes `nqp::elems($!strings)`, does `nqp::setelems($!strings, $prev + 4)`
  and then `nqp::encode($s, ..., $!strings)`. `$!strings` then has storage, so every string added to the string
  heap takes the append branch and pays the owner's allocation, once per heap string. The extra cost on nqp's
  compile path is unmeasured (controller's ruling in Task 6: named, not measured).

### OB5 and OB10 by reading

OB5, every statement between the read of `key` and its last use:
1. `MVM_str_hash_key_is_valid(tc, key)`: null, REPR and concreteness tests; no allocation.
2. `MVM_str_hash_key_throw_invalid`: throws; `key` is not used after it.
3. `MVM_serialization_read_ref`: can block on another SC's reentrant mutex (`MVM_sc_get_object` →
   `MVM_serialization_demand_object`), during which another thread's collection can run with this
   thread's work stolen (#2086's argument): now inside `MVMROOT(tc, key)`.
4. `MVM_str_hash_insert_nocheck(tc, hashtable, key)` (the port's Zig hash engine, str_exports.zig →
   `str.insertNocheck`): the last use. It hashes the key (`MVM_string_hash_code` /
   `MVM_string_compute_hash_code`, ops.c 3124, a stack grapheme iterator, no allocation) and may grow the
   table with the C allocator; no GC allocation, so no collection.
`root` (and `hashtable`, `data`, pointers into it) is not rooted, as the brief asks only for `key`. It
cannot be freed (it is in the SC's root_objects, marked through the SC). It cannot move when stub_object
allocated it, because deserialization runs with gen2 as the allocation default (`MVM_gc_allocate_gen2_
default_set` in the demand functions and MVM_serialization_deserialize; read_ref asserts it), and gen2
does not move. A repossessed object comes from another SC, whose objects were deserialized into gen2 too;
that no repossessed object can still be in the nursery is not proven here.

OB10, every exit after `encoded` is allocated (`MVM_string_encode_config` returns it):
1. The end of the `MVMROOT2(tc, buf, s)` block: no throw.
2. Append branch, `MVM_repr_alloc` of the owner: may collect (buf rooted, `encoded` is C heap); it panics
   on out of memory rather than throwing. Before this, `encoded` has no owner and nothing throws.
3. Append branch, `MVM_repr_pos_set_elems` throws (the size limits, or `Array may not be used
   concurrently` with `MVM_ARRAY_CONC_DEBUG`): the owner holds `encoded`; the exception pops the temp roots
   (`MVM_gc_root_temp_pop_all`, exceptions.c 1018), the owner is garbage and its gc_free frees the buffer.
4. Append branch, success: memmove and memset (no throw), the owner's slots set to NULL, `MVM_free(encoded)`.
5. Else branch (no storage): `MVM_realloc` (panics, does not throw) and the buffer is handed to buf.
6. `return buf`: after 4 or 5.
Not covered: a throw inside `MVM_string_encode_config` itself (its own buffer before it returns) is the
encoder's, not this function's, and was not checked. Reachability of 3 stays doubtful: the limit is 2**60
elements or more, and 64-bit Windows or a debug build is needed for the other throws.

### Reproducers, before and after

Before: ob-fixes-raw/after-z-fix1 (ob-c and ob-n at bf39c32cc, src identical to 8f5516a20). After:
ob-fixes-raw/after-t6 (ob-c and ob-n at 2c7d1dfb9). `cmp.sh ob-fixes-raw/after-t6 ob-c ob-n`: all 41
outputs `c=n`. Against after-z-fix1 only the OB3 outputs (plain and `.jitlog`; the readuint and writeint
`.nojit` outputs were already "died all") and OB9 changed.

| program | before (plain / .jitlog; .nojit) | after, ob-c = ob-n, plain, .nojit and .jitlog |
|---|---|---|
| OB3-readuint-jit flags_3 | died some, returned some; nojit died all | died all, returned none, `Invalid flags value for readuint` |
| OB3-readuint-jit flags_16 | SIGSEGV (exit 139); nojit died all | died all, returned none, the same message |
| OB3-writeint-jit (4 cases) | died some, returned some, element 0 1; nojit died all, element 0 0 | died all, returned none, `Invalid flags (3) or size (1)` / `(16) or size (16) value for writeint`, element 0 0 |
| OB3-writenum-size | flags 16, 0, 3, 4 returned (elems 16, 1, 1, 2) | `DIED Cannot write a num of 16|1|1|2 bytes; elems 0`; flags 8, 12, 15 return (elems 4, 8, 8); readnum controls unchanged |
| OB9-normalize-empty | `elems 3: 10 20 30` | `elems 0:`; controls unchanged |

The `.jitlog` lines after, on both builds (before: every line `compiled`, see Baseline):

    OB3-readuint-jit flags_N (N = 3, 16):
      jit: specialization of '' holding readuint: not compiled; BAIL: op <readuint>, - invalid flags (N), left to the interpreter
      jit: specialization of 'read_flags_N' holding readuint: not compiled; BAIL: op <readuint>, - invalid flags (N), left to the interpreter
    OB3-writeint-jit <op>_flags_N (op = writeint, writeuint):
      jit: specialization of '' holding <op>: not compiled; BAIL: op <<op>>, - invalid flags (N), left to the interpreter
      jit: specialization of '<op>_flags_N' holding <op>: not compiled; BAIL: op <<op>>, - invalid flags (N), left to the interpreter
    OB3-writenum-size: jit: no specialization of this file holds the op (as before; no JIT case)

with "died all, returned none" in the same runs, as Baseline's "JIT evidence" asks. The plain run of
writeint_flags_16, which differed between the builds in Task 5 fix round 1, is now "died all" on both.

Probes (ob-fixes-raw/adhoc-t6-ob3/probes/, results in probes.txt): `OB3-valid-control.nqp` (writeint and
readuint with flags 9, 200,000 calls) is still compiled (`jit: ... compiled` for MAIN, read_flags_9,
write_flags_9) and gives the same sum and bytes in all three modes on both builds; `typeobj-buffer-jit.nqp`
and `size-shift.nqp` as above; `encode-append.nqp` (20,000 appends of "abc" into [7], uint8/16/32) gives
the expected elems and bytes on both builds after OB10. adhoc-t6-ob3/ also holds the OB3 runs on the
prefixes built at f2c32559a (the OB3 commit alone), with the same outputs as after-t6.

### Unit tests and gates

- No Zig file changed and no unit test was added. Unit tests on 2c7d1dfb9 in P (loads 0.89, 1.76, 1.82):
  default 253/265 (12 skipped), -Dzig-reprs=false 253/265 (12 skipped), -Dgc-debug=1 258/265 (7 skipped),
  as at 8f5516a20.
- How the JIT is built: graph.c, interp.c and the other changed files are ordinary C sources; the generated
  JIT files (DynASM's emit.c from src/jit/x64/emit.dasc and tiles.dasc, the expression template and tiler
  tables from core_templates.expr and tile_pattern.tile) are produced by build/zig/jit.zig at build time
  into the zig cache, from those inputs only. None of them changed, and nothing needed regenerating.
- `build-prefixes.sh` at 2c7d1dfb9: ob-c and ob-n exit 0 (58 s each, loads 0.29 and 1.58), no warnings in
  the logs, export lists equal. (Built once before at f2c32559a for the OB3 runs.)
- `diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t6`:
  exit 0, `diff.sh: identical (3 runs a side; lines: diff-nqp/spesh 11106 diff-nqp/nospesh 11106
  diff-raku/spesh 2497 diff-raku/nospesh 2497 serial/spesh 196 serial/nospesh 196 devirt/spesh 10
  devirt/nospesh 10; cross-read identical)` (log: ob-fixes-raw/diff-t6.log); undefined-lines.txt unchanged
  (no entries).
- `run-all.sh` on both prefixes into ob-fixes-raw/after-t6: 41 of 41 outputs `c=n` (above).
- Suites (`maketest-driver.sh ob-fixes-raw/suites-t6`, loads 1.95-1.97): nqp PASS on both (150 files,
  13746 tests); Rakudo FAIL on both, only t/04-nativecall/02-simple-args.t 17-18 (OB15a). The per-file
  lists equal suites-t5-fix1's.

### Not verified

- OB1 was not run (no Windows build).
- OB5 and OB10 were not reproduced; the arguments above are by reading. OB5's `root` in the nursery after
  a repossession is not ruled out (above). The OB10 throw path (an owner collected with the buffer) was not
  driven: no target near the limit can be built.
- The SC write barrier now emitted by the JIT's writeint was not observed (that needs a JIT-compiled write
  to an object of a compiling SC); it is the call every other mutating JIT op makes.
- The JIT checks were run on x86-64 only; `MVM_BIGENDIAN` paths are untouched and not run.

### Seen on the way (not fixed; candidates for the bug list)

- OB23 candidate: the JIT's generic repr-op calls do not check concreteness either. Probe
  `typeobj-bindpos-jit.nqp` (`nqp::bindpos_i` on `nqp::atpos($list, $k)`, the last 3 of 200,000 on a type
  object): SIGSEGV on both builds, before and after; with `MVM_JIT_DISABLE=1` or `MVM_SPESH_DISABLE=1`
  `bindpos_i requires a concrete object (got a  type object instead)`. The JIT's `op_to_func` fallbacks
  (`MVM_repr_bind_pos_*` and the like, reprconv.c) pass the type object to the REPR, as the buffer ops
  did. Only bindpos_i was run; the other ops on that path are presumed the same by reading.
- The JIT's readuint direct-call branch takes the type facts of operand 0, the destination register, not
  the buffer (graph.c, already in OB3 (a) of the bug list); left as is, so readuint always goes through
  `MVM_repr_read_buf`, which now checks concreteness.
- `MVM_unicode_string_to_codepoints` (strtocodes) of an empty string calls `MVM_malloc(0)`, which panics
  on a C library whose malloc(0) returns NULL (MVM_malloc treats NULL as out of memory). Not on glibc.

## Gate (Task 7)

Final tip (final fix wave): 96a9a1a07. It adds two src commits after d68a0ec8c: 4d962a5f0 (Zig test: the
rejected push and bind_pos tests also run through the library) and 96a9a1a07 (C: designated initialisers
and a compile-time check for push_register_kinds). The table below is the gate at d68a0ec8c. "Final tip" (after
the table) lists what was re-run at 96a9a1a07 and what was not.

The table: on the branch tip d68a0ec8c. No source change since 2c7d1dfb9 (`git log --oneline d68a0ec8c..HEAD -- src` is
empty); Task 7 changes only docs and records. The raw column gives paths relative to `ob-fixes-raw/`.

Loads: the builds, unit-test runs and suite runs started at a 1-minute load below 2.0 (values in the table).
diff.sh waits for a load below 2.0 before each run and logs the value at the start in its load.log
(gate-t7/diff-t7-load.log: 1.44 to 1.95). Its progress lines in diff-t7.log print the load before that wait,
and four of them show 2.01 to 2.54 (`base diff-nqp spesh run 1 (load 2.54)`). The reproducer and probe batches
waited for a load below 2.0 once per batch, not before each program.

| # | check | command | result | raw |
|---|---|---|---|---|
| 1 | prefixes | `ob-repro/build-prefixes.sh` (ob-c, ob-n) | both exit 0 at d68a0ec8c (59 s, 61 s; loads 1.05, 1.63); no warnings in the logs | build/builds.tsv, build/ob-{c,n}.out |
| 2 | format | `zig fmt --check src/zig build.zig build/zig tools/zig` | exit 0, no file listed | gate-t7/fmt.txt |
| 3 | unit tests | `zig build unit-test --summary all` in P, under `systemd-run ... MemoryMax=8G` | 253/265 (12 skipped), exit 0 | gate-t7/unit-default.log |
| 4 | | the same with `-Dzig-reprs=false` | 253/265 (12 skipped), exit 0 | gate-t7/unit-creprs.log |
| 5 | | the same with `-Dgc-debug=1` | 258/265 (7 skipped), exit 0 | gate-t7/unit-gcdebug.log |
| 6 | exported symbols | `nm -D --defined-only <prefix>/lib/libmoar.so \| awk '{print $3}' \| sort` (build-prefixes.sh) | ob-c = ob-n, 2,850 names; both equal to cfix-mirror-raw/build/exports-vf-{c,n}-base.txt (`diff`: no name added or removed) | build/exports-ob-{c,n}.txt |
| 7 | differential | `tools/bench/repr/diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t7` | exit 0, `identical (3 runs a side; lines: diff-nqp 11106, diff-raku 2497, serial 196, devirt 10, spesh and nospesh each; cross-read identical)`, as after Task 6; `undefined-lines.txt` has no entry (comments only, unchanged) | diff-t7.log, gate-t7/diff-t7-load.log |
| 8 | suites | `ob-repro/maketest-driver.sh ob-fixes-raw/suites-t7` | nqp PASS on both (Files=150, Tests=13746; loads 1.27, 1.17). Rakudo FAIL on both (Files=599, Tests=11162; loads 1.12, 1.07), only `t/04-nativecall/02-simple-args.t` 17-18 (OB15a). The four per-file lists equal cfix-mirror-raw/suites/{nqp,rakudo}-{c,n}-base.list (the baseline at 99f7ce8cd's src, with the same three nqp `t/hll/0[234]-*.t notok` entries) and suites-t6's. Probes: each run mapped its prefix's libmoar.so | suites-t7/ |
| 9 | reproducers, after | `ob-repro/run-all.sh -p ob-c\|ob-n -o ob-fixes-raw/after-t7`; `cmp.sh after-t7 ob-c ob-n` | 41 of 41 outputs `c=n`, including Z-splice-clear-setelems, Z-shift-realloc and the OB3 programs in all three modes (plain, `.nojit`, `.jitlog`); every output equals its after-t6 counterpart (82 of 82, probe and run lines dropped) | after-t7/, gate-t7/cmp-after-t7.txt |
| 10 | reproducers, before against after | each after-t7 ob-c output against the vf-c-base output of before/, before-t3, before-t4, before-z or before-z-fix1 | 34 changed, 7 unchanged: the six OB3 `.nojit` runs (the interpreter refused before and after; they are the controls) and OB7-negative-bindpos (it pins an order the fix keeps). Every before output was `c=n` on vf-c-base / vf-n-base | gate-t7/before-after.txt |
| 11 | OB3, three modes | (in 9) | readuint flags 3 and 16, writeint and writeuint flags 3 and 16: `died all, returned none` in the plain, `.nojit` and `.jitlog` runs on both; every `.jitlog` line `not compiled; BAIL: op <op>, - invalid flags (N), left to the interpreter`; writenum: `Cannot write a num of 16\|1\|1\|2 bytes` in all three modes, flags 8, 12, 15 return | after-t7/OB3-* |
| 12 | cfix-repro | `cfix-mirror-raw/run-all-port.sh -p ob-c\|ob-n -o ob-fixes-raw/gate-t7/cfix-repro`; `gate-t7/cmp-cfix-repro.sh` | 62 outputs, all `c=n`; 47 equal to cfix-mirror-raw/repro/ on both builds, 15 differ, each explained below | gate-t7/cfix-repro/, gate-t7/cmp-cfix-repro.txt |
| 13 | push benchmark at the tip | `ob-repro/run-bench.sh -n 15 -o ob-fixes-raw/bench-t7 vf-c-base vf-n-base ob-c ob-n` (Task 5's method; fix round 1), then `-o ob-fixes-raw/bench-t7-gap vf-c-base ob-c-t5 ob-c` | the last benchmark had run at bf39c32cc (Task 5 fix round); Task 6 changed src after it. Seven cases within the bound. **ob-c int.pushpop8 is +5.6 % on Task 5's last median and above its p75 (control -1.4 %, so +7.0 % after the control's drift); in an interleaved run against a C build of bf39c32cc it is +5.9 %.** See "Benchmark at the tip" | bench-t7/, bench-t7-gap/ |

### Final tip (96a9a1a07)

Re-run at 96a9a1a07, raw in ob-fixes-raw/gate-final/ unless named otherwise:

| check | command | result | raw |
|---|---|---|---|
| format | `zig fmt --check src/zig build.zig build/zig tools/zig` | exit 0 | gate-final/fmt.txt |
| unit tests | `zig build unit-test --summary all` [`-Dzig-reprs=false`, `-Dgc-debug=1`] | 253/265 (12 skipped), 253/265 (12 skipped), 258/265 (7 skipped): the totals do not change, since the two tests gained cases, not tests; loads 1.47, 1.63, 1.63 | gate-final/unit-*.log |
| prefixes | `ob-repro/build-prefixes.sh` | ob-c and ob-n exit 0 at 96a9a1a07 (59 s each; loads 1.83, 1.81), no warnings | build/builds.tsv |
| generated code | `stat` and `sha256sum` of each libmoar.so, before (d68a0ec8c builds) and after | byte-identical: ob-c 11,339,152 bytes, ob-n 11,331,472 bytes, the same SHA-256 before and after | gate-final/libmoar-{before,after}.txt |
| exports | build-prefixes.sh's lists | ob-c = ob-n; unchanged from d68a0ec8c (2,850) | build/exports-ob-{c,n}.txt |
| differential | `diff.sh --base=/tmp/claude-1000/ob-c --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-final` | exit 0, identical (nqp 11106, raku 2497, serial 196, devirt 10, spesh and nospesh each; cross-read identical); run-start loads 1.37-1.96; `undefined-lines.txt` unchanged (no entries) | diff-final.log, gate-final/diff-final-load.log |
| reproducers | `run-all.sh -p ob-c\|ob-n -o ob-fixes-raw/after-final`; `cmp.sh` | 41 of 41 outputs `c=n`; all 82 outputs equal to after-t7's (probe and run lines dropped) | after-final/, gate-final/cmp-after-final.txt |

Not re-run at 96a9a1a07: the suites, cfix-repro, the probes and the benchmark. The C change produces a
byte-identical libmoar.so for both builds, and the other change is a unit test. So nothing a suite, a probe or
the benchmark runs has changed since d68a0ec8c, where they ran.

Test change (4d962a5f0): "a rejected push leaves the array as it was" and "a rejected bind_pos leaves the
array as it was" now run every case through E and through the library's table, as the W, V, H and Z tests do.
Under `-Dzig-reprs=false` the library is the C REPR, so area Q's C side is pinned on that setting. The refused
register kinds include a uint64 register into push on every integer kind (push takes int64 only), which only
the C API can pass. The C and the Zig arrays gave the same messages and left the arrays unchanged (the
`-Dzig-reprs=false` run, which runs both). It was first run on that setting alone before commit (load 0.05):
253/265.

C change (96a9a1a07): the jit/expr.h macro `MVM_STATIC_ASSERT` exists, but it typedefs one fixed name. That
name is already defined in every file through moar.h, and C99 does not allow a typedef to be defined twice. So
the check uses the same negative-size-array idiom under its own name. It also uses designated initialisers
(`[MVM_ARRAY_OBJ] = ...`). Checked on a stand-alone copy of the table: it compiles with gcc and zig cc in c99,
gnu99 and gnu11 with -Wall -Wextra -pedantic, and fails to compile when MVM_ARRAY_U8 is changed.

### Benchmark at the tip (fix round 1)

The last benchmark ran at bf39c32cc (Task 5 fix round, "Benchmark sanity check", ob-fixes-raw/bench-z-fix1).
Task 6 then changed src in five commits (30134b931 OB1's mask in set_size_internal_with, f2c32559a, fd8f245f5,
a8bfc11fd, 2c7d1dfb9). So the first gate's row 13 ("not re-run, no source change since") was false. It was
re-run on ob-c and ob-n as built from d68a0ec8c. No src changed after that commit (`git log --oneline
d68a0ec8c..HEAD -- src` is empty). Task 5's method: `run-bench.sh -n 15` with `MVM_SPESH_BLOCKING=1`, the four
prefixes interleaved, vf-c-base and vf-n-base as the machine control, and the load below 2.0 before each run
(loads at the starts 0.19-1.45). Nothing else ran during the run. Seconds, median (p25-p75).

| build | case | Task 5's last (bench-z-fix1) | tip (bench-t7) | change | above Task 5's p75 | control now (vs its bench-z-fix1 median) | change less the control's | tip vs control, same run |
|---|---|---|---|---|---|---|---|---|
| ob-c | int.push10m | 0.5746 (0.5709-0.5854) | 0.5872 (0.5774-0.6015) | +2.2 % | above | 0.5789 (-0.3 %) | +2.5 % | +1.4 % |
| ob-c | obj.push10m | 0.5910 (0.5839-0.5969) | 0.5942 (0.5879-0.5983) | +0.5 % | not above | 0.5932 (+1.3 %) | -0.7 % | +0.2 % |
| ob-c | int.pushpop8 | 0.8158 (0.8140-0.8434) | 0.8614 (0.8604-0.8643) | **+5.6 %** | above | 0.8331 (-1.4 %) | **+7.0 %** | +3.4 % |
| ob-c | obj.pushpop8 | 0.8920 (0.8752-0.9258) | 0.9213 (0.8718-0.9426) | +3.3 % | not above | 0.8742 (+1.7 %) | +1.6 % | +5.4 % |
| ob-n | int.push10m | 0.5457 (0.5404-0.5530) | 0.5468 (0.5421-0.5601) | +0.2 % | not above | 0.5863 (+1.5 %) | -1.3 % | -6.7 % |
| ob-n | obj.push10m | 0.5625 (0.5583-0.5942) | 0.5798 (0.5617-0.5949) | +3.1 % | not above | 0.5860 (+0.7 %) | +2.4 % | -1.1 % |
| ob-n | int.pushpop8 | 0.7168 (0.7129-0.8089) | 0.7312 (0.7066-0.7721) | +2.0 % | not above | 0.8099 (-0.3 %) | +2.3 % | -9.7 % |
| ob-n | obj.pushpop8 | 0.7902 (0.7564-0.8993) | 0.7825 (0.7470-0.8104) | -1.0 % | not above | 0.8307 (+0.3 %) | -1.2 % | -5.8 % |

This is a report, not a stop rule. One case is more than 5 % above Task 5's last median and above its p75, also
after the control's drift: **ob-c int.pushpop8, +5.6 % (+7.0 % less the control)**. To tell a Task 6 change
from the difference between two runs, a C-REPR prefix was built at bf39c32cc (/tmp/claude-1000/ob-c-t5, from a
`git archive` copy as build-prefixes.sh does; load 0.77, exit 0, no warnings, log in bench-t7-gap/). It was
then run interleaved with the tip's ob-c and vf-c-base (`run-bench.sh -n 15 -o ob-fixes-raw/bench-t7-gap
vf-c-base ob-c-t5 ob-c`, loads 1.01-1.26):

| case | vf-c-base | ob-c-t5 (bf39c32cc) | ob-c (tip) | tip vs t5 | t5 vs vf | tip vs vf |
|---|---|---|---|---|---|---|
| int.push10m | 0.5780 (0.5764-0.5831) | 0.5737 (0.5704-0.5829) | 0.5813 (0.5791-0.5849) | +1.3 % | -0.7 % | +0.6 % |
| obj.push10m | 0.5865 (0.5852-0.5954) | 0.5891 (0.5858-0.5963) | 0.5930 (0.5878-0.5993) | +0.7 % | +0.4 % | +1.1 % |
| int.pushpop8 | 0.8320 (0.8296-0.8441) | 0.8141 (0.8128-0.8629) | 0.8619 (0.8610-0.8644) | **+5.9 %** | -2.2 % | +3.6 % |
| obj.pushpop8 | 0.8632 (0.8511-0.8941) | 0.9060 (0.8867-0.9450) | 0.9245 (0.8929-0.9546) | +2.0 % | +5.0 % | +7.1 % |

What was measured: in this one interleaved run of 15, the tip's ob-c median is +5.9 % on the bf39c32cc build's,
with the control (vf-c-base) where it was in bench-t7. One run cannot separate a Task 6 change from run-to-run
spread: the bf39c32cc build's p75 (0.8629) reaches the tip's median (0.8619), and its runs split into two
groups (eleven from 0.808 to 0.833, four from 0.863 to 0.880). The cause is unverified. The tip is +3.6 % on vf-c-base, the before build,
in the same run. By reading, no Task 6 change is on that loop's path. pushpop8 keeps 8
elements, so set_size_internal_with never reaches OB1's mask (the `ssize >= 8192` branch). The other four
commits touch the JIT's buffer ops, interp.c's buffer ops, MVMHash deserialize, normalize.c and encode. Code
layout of libmoar is the likely cause, as for Task 4's +6.7 % on the same case with no change on its path
("The pre-Z gap"). Not verified: the libraries are stripped and it was not profiled. The Zig build (ob-n) did
not move on that case (+2.0 %, not above p75). The scratch prefix ob-c-t5 and its source copy were removed
afterwards.

### Unit-test count against the baseline

| setting | 99f7ce8cd | tip | arithmetic (passed) |
|---|---|---|---|
| default | 240/252 (12 skipped) | 253/265 (12 skipped) | 240 - 3 + 2 (T2) + 5 (T3) + 4 (T4) + 2 (T5 first: 1 new, 1 enabled) + 2 (T5 second) + 1 (T5 fix round) + 0 (T6) = 253 |
| `-Dzig-reprs=false` | 240/252 (12 skipped) | 253/265 (12 skipped) | the same |
| `-Dgc-debug=1` | 245/252 (7 skipped) | 258/265 (7 skipped) | 245 - 3 + 2 + 5 + 4 + 2 + 2 + 1 = 258 |

Totals: 252 - 3 + 2 + 5 + 5 (T4: 4 passing, 1 skipped until T5) + 1 + 2 + 1 = 265. The skipped counts are
back at the baseline's: Task 4's skipped test ("write_buf into spare room of an adopted buffer") was enabled in Task 5.
The three tests removed in Task 2 are listed in "K and M", "Unit tests". Their subject, an array of a kind
without storage, can no longer be made. Floor (the baseline minus those three): 237, 237, 242. Per-task numbers
are from the task sections above; the tip totals are from this task's runs.

### cfix-repro: the differences against the campaign's outputs

`cmp-cfix-repro.sh` compares each output with cfix-mirror-raw/repro/ (vf-c-base for ob-c, vf-n-base for ob-n),
normalised as cfix-mirror-raw/cmp-repro.sh does. The 15 that differ, on both builds the same way:

| program (case) | what changed | why |
|---|---|---|
| B3-writeint-no-storage-kind, B3-write-no-storage-state live, P2-splice-no-storage-kind source and target, P2-splice-no-storage-same-kind same-fit, same-grow, empty-into | the second compose (to uint4) gave `Type  is already composed ...`; it now gives `Cannot compose an array of 4-bit integers, element types need at least 8 bits` | area K: the uint4 compose is refused before #2081's recompose check |
| B3-write-no-storage-state fresh, P2-splice-no-storage-same-kind empty-src | the program composed a fresh uint4 type outside a `try` and went on; it now dies there, with the compose message and a backtrace (the rest of the program does not run) | area K (these programs are storage-less by subject) |
| B3-write-first-compose | `first compose to uint4 with live array: returned` becomes `died: ... Cannot compose an array of 4-bit integers ...`; the three writes' `write_buf requires an integer type` becomes `... integer or num type` (elems 3 both times) | area K; OB16's message (area W) |
| R1-recompose-object-type, R-recompose-matrix, X1-recompose-wider-kind | `Type  is already composed` becomes `Type <anon> is already composed` | area M (OB12) |
| N-adopt-state | `normalizecodes of empty input into 10 20 30: elems 3: 10 20 30` becomes `elems 0:` | OB9 |
| B-buf-grid | 1,309 of its lines changed. 835 have access size 0 (flags 32): reads that returned a value or `read_buf out of bounds ...` now `DIED Invalid flags value for readuint`; writes now `DIED Invalid flags (32) or size (0) value for writeint`, array unchanged. 474 have sizes 2, 4 or 8, on the 16-, 32- and 64-bit and num kinds: a write that grows leaves `offset + ceil(size / elem_size)` elements (e.g. int16 at 5, 8 bytes: elems 9, was 13), and the refused growths name that count in `Unable to allocate an array of N elements`. The 8-bit kinds' lines changed only at size 0 | OB3's size helper (Task 6: a shift of 8 or more gives size 0, refused); area W (OB8) |

Every other output (47) is unchanged on both builds.

### Probes run in Task 7

`ob-repro/run.sh` (port prefixes) and `cfix-repro/run.sh` (cfix-base and cfix-asan, origin/main f112c3998), with
`ulimit -c 0`, 2G or 4G caps and timeouts. Programs in gate-t7/probes/; outputs in gate-t7/probes/out/ and
gate-t7/upstream/.
- VMNull as splice source (Y and Q, "Not verified"): as Task 3's reviewer saw. Before: the Null REPR's error;
  now: the type-object message. It threw both times and the target was unchanged.
- K's deserialize throw (K and M, "Not verified"): `u4.0.read: DIED MVMArray: Cannot compose an array of 4-bit
  integers, element types need at least 8 bits` on ob-c and ob-n, `Unhandled slot type` on the vf prefixes.
- OB21 on upstream: Z-splice-clear-setelems.nqp and Z-shift-realloc.nqp show the bug on cfix-base and cfix-asan
  (no ASAN report: the slots lie inside the allocation).
- OB22 (oslice-delegate.nqp): `MoarVM panic: Memory allocation failed; could not allocate 2251765453946888
  bytes` on the four port prefixes and cfix-base; ASAN on cfix-asan: allocation-size-too-big in `aslice`.
- OB23 (adhoc-t6-ob3/probes/typeobj-bindpos-jit.nqp `write`): SIGSEGV on the four port prefixes and
  cfix-base; ASAN on cfix-asan: a wild WRITE in `set_size_internal`.

### New and changed exception messages

Identical in C and Zig where both have the code (checked in Task 7 with `grep -rn` over src/*.c and src/**/*.zig
outside the tests):
- `MVMArray: Cannot compose an array of %d-bit integers, element types need at least 8 bits` (K; VMArray.c,
  serial.zig).
- `MVMArray: Cannot splice from a type object` (Y; VMArray.c asplice, elements.zig).
- `MVMArray: Cannot slice from a type object` (Y; VMArray.c aslice, elements.zig). It is the sixth message: not
  in the global constraints' list. It was derived by the plan's rule and accepted by the controller.
- `Cannot write a num of %d bytes` (OB3; interp.c writenum, shared C).
- `MVMArray: Type <anon> is already composed with another element kind` (M; a type without a debug name).
- `MVMArray: write_buf requires an integer or num type`, `MVMArray: read_buf requires an integer or num type`
  (W, OB16).

Existing messages in new places:
- `Cannot read from a %s type object` and `Cannot write to a %s type object` now also come from
  `MVM_repr_read_buf`/`MVM_repr_write_buf` (OB3; the JIT's path).
- `Invalid flags (N) or size (0) value for writeint` and the readint/readuint `Invalid flags value` now also
  for flags whose shift is 8 or more (OB3).
- `Unable to allocate an array of N elements` now also from deserialize (V).

## Not verified (the campaign)

- No AddressSanitizer build of the port (OB15c). The only ASAN runs in this campaign are Task 7's four
  programs on cfix-asan (Z-splice-clear-setelems, Z-shift-realloc, oslice-delegate, typeobj-bindpos-jit), which
  is upstream.
- No 64-bit Windows build: OB1's fix is by reading (LLP64 assumed).
- No `-Dzig-gc=false` build: every port prefix used the Zig collector. The C REPR builds (`-Dzig-reprs=false`)
  share it.
- By reading only: OB5 (no reproducer; `root` in the nursery after a repossession not ruled out, OB24) and
  OB10 (the throw path with an owner collected was never driven).
- The Perl build path (Configure.pl + make, OB15b) was not exercised for any of the changed C. The JIT changes
  were run on x86-64 only; `MVM_BIGENDIAN` paths untouched and not run.
- The SC write barrier the JIT's writeint now emits was not observed.
- OB10's extra allocation on nqp's compile path (QASTCompilerMAST.nqp 2499-2501) was not measured.
- Zig push keeps two dispatches on the kind. Its shape was not measured on its own: the Zig build showed no
  slowdown.
- The benchmark was re-run at the tip only in fix round 1 of Task 7 ("Benchmark at the tip"). The cause of
  ob-c int.pushpop8's +5.6 % (+5.9 % against a bf39c32cc C build) was not found; code layout is a guess.
- OB4's Raku route (a socket or process Buf, then `Buf.reallocate`) was not run. OB4 is fixed at the growth,
  not at the adopting sites.
- The five Rakudo Buf candidates (`int @values` without `:D`) now throw the VM's message for a type object.
  Only `Buf.new(array[int])` is a reproducer here; the other four are diff lines in vmarray-diff.raku.
- OB22: only the case where the garbage gives a huge size was seen; the write of an array body into the
  P6opaque (small garbage) was not. OB23: only bindpos_i was run. OB24: nothing was run.
- Everything ran on one machine (Linux x86-64, glibc).
- Added in fix round 1 of Task 7 (from the task reports and the sections above):
  - write_buf with a count of 2**63 or more on a 1-byte kind can still wrap `offset + count` (W, "Not
    verified"; no caller passes such a count; not checked).
  - strtocodes of `""` calls `MVM_malloc(0)`, which panics on a C library whose malloc(0) returns NULL (Task 6,
    "Seen on the way"); not on mimalloc or glibc. Now cfix-open-bugs.md OB25.
  - The JIT's readuint direct-call branch takes the type facts of operand 0, the destination (Task 6; already
    in cfix-open-bugs.md OB3 (a)); left as is, so that fast path is dead.
  - Area K: element-type widths 0, 3, 5, 6 and 7 would get the new compose message instead of "Unsupported
    int size"; P6int refuses them first, so no type with such a spec is known (K, "Not verified").
  - When deserialize_repr_data throws the compose message, `st->REPR_data` is already set (object kind,
    element type stored). That is the existing behaviour for any throw there; not changed (Task 2).
  - Areas V and K's deserialize throw are driven by no diff.sh case. V is covered by the unit test and
    OB18-deserialize-size.nqp, and K's throw by the run in "Gate (Task 7)" only.
  - A P6opaque positional delegate holding a type object, and `nqp::slice` of a P6opaque type object, reach
    the array ops unchecked through `oslice` and its siblings (Y and Q, "Not verified"; cfix-open-bugs.md OB2
    sibling, OB22). By reading; not run.
  - OB4-adopted-setelems.nqp depends on allocator reuse. On another allocator it may print `= 0` before the
    fix (Task 1).
  - The OB3 plain runs depend on spesh/JIT timing (no MVM_SPESH_BLOCKING); the `.jitlog` runs do not.
  - The hole test does not assert that the remaining holes are still NULL slots after pop/shift (Task 4
    review).
  - Zig aslice with a NULL `src` would panic in a safe build instead of faulting at `flags1`. Unreachable:
    both callers dereference `src` first (Task 3 review).
  - Before area Z, ob-n was about 9 % faster than vf-n-base on the pushpop8 cases. Not investigated (Task 5).

## Commits by bug id

`git log --oneline 99f7ce8cd..HEAD` on zig-open-bugs. Only C commits are meant for upstream; the Zig mirrors
belong to the port. "Applies to origin/main" was checked in Task 7 with `patch -p1 --dry-run` of each C commit's
`src` diff onto `git show origin/main:<file>` copies, alone and then all in branch order (fuzz and offsets
allowed). Files and functions are from `git show -U0`. Fix round 1 re-checked every ordering statement by reading
the hunks (`git show <commit> -- src/6model/reprs/VMArray.c`, with context) and by applying VMArray.c commits in
chosen orders onto origin/main's file: Q then Z (981c4a8f2, 591f3c20b, 963665442, eb98fd0ba) applies; Z without
981c4a8f2 fails at 963665442's push hunk; 981c4a8f2 then b87b79815 without Z fails; f7417f244 (#2077's commit
on this branch) then 30134b931 applies; ec2ad02f7 then 30134b931 without #2077 fails.

| bug ids | C commits | Zig commits | depends on a cherry-picked PR | shares hunks with |
|---|---|---|---|---|
| K: OB6, OB17, OB18 second half, OB20, OB15d (gone) | ce6393516 | 75e171c31 | none (applies) | - (spec_to_repr_data only) |
| OB12 (M) | 02289298c | a1fa9aed7 | #2081 (fails on origin/main: the hunk is #2081's compose check) | - |
| OB2 and its slice sibling (Y) | 771b359b6 | 14b817180 | none (applies) | - (asplice, aslice) |
| OB7 (Q) | 981c4a8f2, then b87b79815 (push restructured, C only), then 96a9a1a07 (the table's order pinned; no code change) | 7ff607fd1, 4d962a5f0 (tests through the library) | none for 981c4a8f2; b87b79815 needs 963665442 (its context is 963665442's `set_size_internal_caller_writes` call and comment) | push: 981c4a8f2, then 963665442, then b87b79815 |
| OB8, OB16 (W) | 48fd69052 | 1c80e9440 | #2080 (named in the message; 2 of 3 hunks fail on origin/main), also #2077's rules | - (write_buf, read_buf) |
| OB18 first half (V) | ec2ad02f7 | 63a911508 | none (applies) | set_size_internal, but no shared lines: Z's and OB1's hunks apply with or without it (their hunk headers name slot_budget only as the enclosing function) |
| OB19 (H) | bb0eda68f | 922bbfb4d | none (applies) | - (pop, shift) |
| OB4, OB21 (Z) | 591f3c20b (first mechanism), 963665442 (second mechanism), eb98fd0ba (fix round) | 8223cc952, 8b1ff900c, 30ce0ba0a | none. 963665442 needs 981c4a8f2: its push hunk sits on Q's check-before-grow switch (context `default: break; }` of that switch), and its message rests on that check ("push checks the register kind before growing (981c4a8f2)"). eb98fd0ba needs 591f3c20b and 963665442 | push: Q before Z, b87b79815 after; unshift: Z only |
| OB1 | 30134b931 | none (storage.zig already masks with 64 bits) | #2077 (its context is #2077's comment; fails without it) | none: the line is upstream's; the hunk header names set_size_internal_with (963665442's name) but the hunk applies to upstream's set_size_internal after #2077 alone |
| OB3 | f2c32559a | none (shared C) | none (applies) | - (graph.c, interp.c, reprconv.c) |
| OB5 | fd8f245f5 | none | none (applies; the message cites #2086 for the shape only) | - |
| OB9 | a8bfc11fd | none | #2083 (named; the empty path matches #2083's ssize-in-elements state; the patch applies textually) | - |
| OB10 | 2c7d1dfb9 | none | #2084 (the hunk rewrites #2084's append branch; fails on origin/main). The commit message does not name #2084 (not amended); the PR text must name it | - |

Traces pointer commits: 2912653aa, f70792a18, 0feb0de01 (Task 1), d6dcc43e3, cd2826682, 2e32a3191, 0e52acce3,
bef116732, 7de5d6a7a, 3c74bbf4c, 8f5516a20, d68a0ec8c. Harness commits (tools/bench/repr): 3c8556c9d, 9b511d4e3,
a8a712e6c, 3393c5932, 3f4dd1c69, ec2e4f080, bf39c32cc.

For PRs:
- Area Z becomes one PR: 591f3c20b + 963665442 + eb98fd0ba squashed. The first mechanism alone was
  rejected by the benchmark, and the fix round closes a gap the first two left. In the port, 8223cc952 +
  8b1ff900c + 30ce0ba0a are one change too.
- Area Q (981c4a8f2) must come before Z. Z cannot go first: 963665442's push hunk sits on 981c4a8f2's
  check-before-grow switch, and skipping the zeroing in push is safe only because of that check.
- b87b79815 (push restructured) comes after Z: its context is 963665442's `set_size_internal_caller_writes`
  call. So it cannot be squashed into Q's PR as it is. Either it goes as its own PR after Z, or into Z's PR.
  Or it is squashed into Q, rewritten against plain `set_size_internal`, and Z's push hunk is then rebased onto
  the table form.
- 96a9a1a07 only rewrites b87b79815's table, so it is squashed into whichever PR carries b87b79815.
- So the order where hunks meet is Q (981c4a8f2), then Z (591f3c20b, 963665442, eb98fd0ba), then b87b79815.
  V and OB1 are textually independent of Z. OB1 needs only #2077.
- W after #2080, M after #2081, OB9 after #2083, OB10 after #2084 (to be named in its PR text). K, Y, H, V,
  OB3 and OB5 apply to origin/main alone.

## Decisions for the owner

1. Deserialize's limit equals set_size_internal's (`>` against slot_budget), so 2**63 one-byte elements still
   reaches the allocator and aborts (`could not allocate 9223372036854775808 bytes`). Tightening both is one
   comparison each.
2. Area Z's second mechanism was accepted by the controller at +5.2 % on one case (ob-n obj.push10m) against a
   5 % rule, with +2.8 % control drift in the same run.
3. Push in C was restructured (b87b79815: one dispatch, the kind check through a table), while Zig's push keeps
   its two-step shape (check dispatch, then store dispatch). The facts: after Task 3 (981c4a8f2) object push
   in the C build was about 15 % slower (obj.pushpop8 +14.9 % against vf-c-base, "The pre-Z gap"). The
   restructure recovered most of that in Task 5's measurement ("Push follow-up"). The Zig build showed no
   such slowdown (pre-Z ob-n was faster than vf-n-base on pushpop8). Zig's shape was not measured on its own.
   For what the campaign costs in the end, see item 9.
4. The sixth message, `MVMArray: Cannot slice from a type object`, is not in the constraints' list.
5. Five Rakudo Buf candidates (`Blob.new`, `STORE`, `append`, `prepend`, `splice` with `int @values`) now throw
   an internal VM message for a type-object argument (`MVMArray: Cannot splice from a type object`). Before:
   `Buf.new(array[int])` panicked; the other four were not run before the fix.
6. OB10's design: an owner object for the encoded buffer, one allocation per append. Its cost on nqp's compile
   path (one per string-heap entry) is unmeasured.
7. Junk buffer-op flags (a size shift of 8 or more) now throw with `size (0)` (writeint) or `Invalid flags
   value` (readint/readuint), where some returned before and some panicked.
8. At the tip the C build's int.pushpop8 is +5.6 % on Task 5's last run (above its p75, the control flat). In
   one interleaved run against a C build of bf39c32cc it is +5.9 %, within that build's spread (its p75 reaches
   the tip's median). Cause unverified: no Task 6 change is on that loop's path by reading, and one run cannot
   tell a change from spread. The Zig build did not move ("Benchmark at the tip").
9. The campaign's net cost on the push/pop path against the builds before it, at the tip, medians of 15
   interleaved runs:
   - C array (ob-c against vf-c-base, bench-t7-gap): int.push10m +0.6 %, obj.push10m +1.1 %, int.pushpop8
     +3.6 %, obj.pushpop8 +7.1 %. In bench-t7: +1.4 %, +0.2 %, +3.4 %, +5.4 %.
   - Zig array (ob-n against vf-n-base, bench-t7): int.push10m -6.7 %, obj.push10m -1.1 %, int.pushpop8
     -9.7 %, obj.pushpop8 -5.8 % (faster).

   The choice: accept this, or ask for a profile of an unstripped build of the C array before the upstream
   PRs.
