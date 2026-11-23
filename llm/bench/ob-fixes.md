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
| `Z-splice-clear-setelems.nqp` | a splice at offset 0 removing every element, then setelems / bindpos past the end (the removed elements came back); added in Task 5 |
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

- `deserialize_repr_data`'s throw: by reading only (no crafted blob with a 4-bit element type).
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
  MVMNull REPR's own error; not run.
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

## Z (BLOCKED by the benchmark)

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
