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
| `run-bench.sh [-n RUNS] -o OUTDIR PREFIX...` | the push benchmark, RUNS rounds with the prefixes alternating, load below 2.0 before each run, medians in `bench-medians.txt` |
| `build-prefixes.sh [ob-c] [ob-n]` | cfix-mirror-raw/build/build.sh from `git archive HEAD` copies (with 3rdparty at the recorded commits) under /tmp/claude-1000/ob-src-{c,n}; logs, builds.tsv and export lists in `ob-fixes-raw/build/` |
| `maketest-driver.sh OUTDIR [project:prefix ...]` | cfix-mirror-raw/maketest-driver.sh re-pointed at /tmp/claude-1000/ob-{c,n} (default `nqp:c nqp:n rakudo:c rakudo:n`); added in Task 2 |
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
