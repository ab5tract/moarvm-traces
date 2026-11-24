# Open Bugs Port Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Fix the fixable entries of `traces/llm/bench/cfix-open-bugs.md` (OB1 to OB20) in the port's tree, in
C and in Zig, keeping the C-versus-Zig differential gate at exit 0.

**Architecture:** One C commit per fix, followed by one Zig mirror commit where the Zig port owns the same
behaviour (the VMArray REPR under `src/zig/6model/reprs/vmarray/`). Bugs in shared C (JIT, interpreter,
normalizer, encode, MVMHash) are C commits only. Each fix has a reproducer program with recorded output
before and after, on a build with C REPRs and a build with Zig REPRs.

**Tech Stack:** C (MoarVM), Zig 0.17.1 (`zig build`), nqp and Raku programs as reproducers and differential
cases, bash harness under `tools/bench/repr/`.

**Spec:** `traces/llm/specs/2026-11-20-open-bugs-port-fixes-design.md` (approved 2026-11-20). The bug list
with locations, excerpts and existing reproducers: `traces/llm/bench/cfix-open-bugs.md`. Read both.

## Global Constraints

- Repository P = `/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM`. Branch `zig-open-bugs` off
  `zig-hash-engine` (99f7ce8cd). No git worktrees. No `git stash`, `reset --hard`, `clean`.
- Nothing is pushed, fetched or merged. No upstream PRs. No change to the eleven open PRs or their branches.
- Never add `.superpowers/` or `tools/lib/MAST/Ops.rakumod` to git.
- `traces/` is a submodule on branch `main`: commit there first, then commit the pointer in P.
- Commit messages end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.
- New and touched code uses explicit, descriptive names in snake_case. Untouched code is not renamed.
- Exception messages are identical in C and Zig, byte for byte. The exact new messages:
  - `MVMArray: Cannot compose an array of %d-bit integers, element types need at least 8 bits`
  - `MVMArray: Cannot splice from a type object`
  - `Cannot write a num of %d bytes`
  - `MVMArray: Type <anon> is already composed with another element kind`
  - the `read_buf` / `write_buf` message with `integer` replaced by `integer or num`
- A C commit that depends on a cherry-picked PR names it in its message (OB8 on #2080, OB9 on #2083, OB12
  on #2081).
- Nothing is changed before a throw: every new check sits before the first mutation of the array.
- No drive-by fixes. A new defect seen on the way goes into the task report and `ob-fixes.md`, not the code.
- Unreachable code left by area K (the `Unhandled slot type` arms, the storage-less guards of #2079 and
  #2080, Zig `grow`'s NULL-slots case) stays.
- Builds: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before every `zig build`; run under
  `systemd-run --user --scope -q -p MemoryMax=8G`; start only when the 1-minute load is below 2.0;
  `ulimit -c 0` before anything that may crash. Kill processes by PID only.
- Prefixes: "before" = `/tmp/claude-1000/vf-c-base` (C REPRs) and `/tmp/claude-1000/vf-n-base` (Zig REPRs),
  built at 282b04734, identical in `src/` to 99f7ce8cd; never modified. "After" = `/tmp/claude-1000/ob-c`
  and `/tmp/claude-1000/ob-n`, built by Task 1's script. `/tmp/claude-1000/tune-zig-prefix` is read only.
- Runners for programs: `/tmp/claude-1000/tune-zig-prefix/bin/nqp-m` and the rakudo checkout's `rakudo-m`
  (with `-Ilib` for `use experimental`, `RAKUDO_NO_PRECOMPILATION=1`), with `LD_LIBRARY_PATH=<prefix>/lib`;
  each run first proves which libmoar it mapped, as `traces/llm/bench/cfix-mirror-raw/run-port.sh` does.
- Unit tests: `zig build unit-test --summary all`, also with `-Dzig-reprs=false` and with `-Dgc-debug=1`.
  Baseline at 99f7ce8cd: 240/252 passed (12 skipped), 240/252, 245/252 (7 skipped).
- Records wrap at about 110 columns, plain technical English.

## Review Focus

Inputs the spec implies but no task's own test would otherwise exercise; each has a test in the task named.

1. An existing compiled file (the nqp and Rakudo core settings) whose array types pass through
   `deserialize_repr_data` after area K: all must still load. Task 2 runs both suites after K, not only at
   the end.
2. `nqp::splice` with a type object as source where the caller meant "delete" (count > 0, nothing inserted):
   after area Y this throws. Task 3 greps nqp and Rakudo sources for splice calls whose source can be a type
   object and runs both suites after Y.
3. `bind_pos` with a negative index and the wrong register kind: the index is normalised before the kind
   check, and an index that stays negative still gives its own existing error. Task 3 tests which error
   wins and that C and Zig agree.
4. `write_buf` with a byte count that is not a multiple of the element size at an offset past the end, on a
   buffer adopted from `nqp::encode` (spare room not zeroed before area Z): the spare bytes of the last
   element read as zero. Task 4 tests it after Task 5's zeroing exists only if Task 5 has run; otherwise
   Task 5 owns the test. (Order: Task 4 writes the test as skipped-with-reason, Task 5 enables it.)
5. `pop` / `shift` of a hole from an object array in the second generation, followed by a store of the
   result into another gen2 array (write barrier on VMNull). Task 4 tests it under `-Dgc-debug=1`.

---

## File Structure

| File | Responsibility | Tasks |
|---|---|---|
| `src/6model/reprs/VMArray.c` | C side of K, M, Y, Q, W, Z, V, H, OB1 | 2, 3, 4, 5, 6 |
| `src/zig/6model/reprs/vmarray/serial.zig` | Zig compose, deserialize (K, M, V) | 2, 4 |
| `src/zig/6model/reprs/vmarray/elements.zig` | Zig asplice, push, bind_pos, pop, shift, read/write_buf (Y, Q, W, H) | 3, 4 |
| `src/zig/6model/reprs/vmarray/storage.zig` | Zig `setSize` (Z) | 5 |
| `src/zig/6model/test/vmarray_elements_test.zig` | unit tests, existing helpers `childThrow`, `expectThrew`, `composeWith`, `stateOf` | 2 to 5 |
| `src/jit/graph.c`, `src/core/interp.c` | OB3 | 6 |
| `src/6model/reprs/MVMHash.c` | OB5 | 6 |
| `src/strings/normalize.c`, `src/strings/ops.c` | OB9, OB10 | 6 |
| `tools/bench/repr/vmarray-diff.nqp`, `.raku`, `README.md` | differential cases for each area | 2 to 5 |
| `tools/bench/repr/vmarray-push-bench.nqp` (new) | push throughput benchmark for area Z | 1, 5 |
| `traces/llm/bench/ob-repro/` (new) | one reproducer per bug id, `run.sh`, `run-all.sh`, `build-prefixes.sh` | 1 |
| `traces/llm/bench/ob-fixes.md` (new), `ob-fixes-raw/` | the record | every task appends its section |
| `traces/llm/bench/cfix-open-bugs.md` | a status line per entry | 7 |
| `docs/zig-build.md` | REPRs section: the storage-less refusal, the OB11 gap | 7 |

---

### Task 1: Reproducers, benchmark, prefix script, baseline

**Files:**
- Create: `traces/llm/bench/ob-repro/{run.sh,run-all.sh,build-prefixes.sh}` and one program per bug id:
  `OB2-typeobj-splice.nqp`, `OB2-buf-new-array.raku`, `OB3-readuint-jit.nqp`, `OB3-writeint-jit.nqp`,
  `OB3-writenum-size.nqp`, `OB4-adopted-setelems.nqp`, `OB7-rejected-push.nqp`, `OB7-rejected-bindpos.nqp`,
  `OB8-write-buf-growth.nqp`, `OB8-write-uint64.raku`, `OB9-normalize-empty.nqp`, `OB12-anon-recompose.nqp`,
  `OB16-num-buf-message.nqp`, `OB18-deserialize-size.nqp`, `OB19-holes.nqp`, `K-smallnatives.raku`,
  `K-compose-small.nqp`
- Create: `tools/bench/repr/vmarray-push-bench.nqp`
- Create: `traces/llm/bench/ob-fixes.md`, `traces/llm/bench/ob-fixes-raw/before/`

**Interfaces:**
- Produces: `ob-repro/run.sh -p PREFIX_NAME [-m MEM] [-t SECS] [-o OUTDIR] PROGRAM [ARGS]` (same contract as
  `cfix-mirror-raw/run-port.sh`: probe, command, output, exit status in
  `OUTDIR/<file>[.<args>].<PREFIX_NAME>.txt`); `ob-repro/run-all.sh -p PREFIX_NAME -o OUTDIR`;
  `ob-repro/build-prefixes.sh` builds the checked-out tree into `/tmp/claude-1000/ob-c`
  (`-Dzig-reprs=false`) and `/tmp/claude-1000/ob-n` (default) from `git archive HEAD` copies, the way
  `cfix-mirror-raw/build/` built `vf-*` (read its script and reuse it).
- Produces: `vmarray-push-bench.nqp` printing one line per case, `<case> <seconds>`, cases
  `int.push10m`, `obj.push10m`, `int.pushpop8`, `obj.pushpop8`.

- [ ] **Step 1:** Create branch `zig-open-bugs` from `zig-hash-engine`. Verify `git status --short` shows only
  the two allowed untracked entries.
- [ ] **Step 2:** Write `run.sh`, `run-all.sh`, `build-prefixes.sh` by adapting
  `traces/llm/bench/cfix-mirror-raw/{run-port.sh,run-all-port.sh}` and its build script. Each program run is
  done with spesh/JIT defaults and, for the OB3 programs, also with `MVM_JIT_DISABLE=1` (a second output
  file, suffix `.nojit`).
- [ ] **Step 3:** Write the programs. For each bug take the program from `cfix-open-bugs.md` (its section
  names the record a program came from) and make it print labelled lines and catch exceptions, so that a fixed
  build gives a stable, complete output and never a crash. OB3's JIT programs must run their op in a loop hot
  enough to be JIT-compiled (the bug list's section says how the record reached the JIT path).
  OB18's program builds its crafted blob as the record's section describes; if the section gives none, write
  a program that serializes a small native array, patches the element count in the bytes to `2**61 + 1`, and
  deserializes it under `-m 2G`. `K-smallnatives.raku` is
  `use experimental :smallnatives; my uint4 @a; say "declared, elems {@a.elems}"; @a.push(3); say @a`, each
  statement in its own `try` with the message printed.
- [ ] **Step 4:** Run `run-all.sh -p vf-c-base` and `-p vf-n-base` into `ob-fixes-raw/before/`. Expected: each
  program shows its bug as `cfix-open-bugs.md` describes, and the C and Zig outputs are equal except where
  the list says Zig differs (OB20, OB15d). Any other difference, or a bug that does not show: record it in
  `ob-fixes.md` section "Baseline" and say so in the report.
- [ ] **Step 5:** Write `vmarray-push-bench.nqp`: (a) push 10,000,000 elements one at a time into a fresh
  array; (b) on a 1,000-element array, 1,000,000 rounds of push 8 then pop 8; each for `nqp::list_i()` and
  `nqp::list()`; time with `nqp::time` around each case.
- [ ] **Step 6:** Run the benchmark 7 times per prefix on `vf-c-base` and `vf-n-base` with
  `MVM_SPESH_BLOCKING=1`, load below 2.0. Record all 7 values and the median per case in `ob-fixes.md`
  "Baseline" and the raw lines in `ob-fixes-raw/before/bench-*.txt`.
- [ ] **Step 7:** Commit: P (`tools/bench/repr/vmarray-push-bench.nqp`), traces (repro dir, record), P pointer.

### Task 2: Area K (kinds without storage refused at compose) and area M (`<anon>`)

**Files:**
- Modify: `src/6model/reprs/VMArray.c` (`spec_to_repr_data` or `compose`, and `deserialize_repr_data`; the
  #2081 check near line 1398)
- Modify: `src/zig/6model/reprs/vmarray/serial.zig` (`compose` near 271-291, `deserializeReprData`)
- Test: `src/zig/6model/test/vmarray_elements_test.zig`
- Modify: `tools/bench/repr/vmarray-diff.nqp` (`odd_kinds()` near line 965, the `<kind>.late.*` cases, the
  six kinds' rows), `tools/bench/repr/README.md`

**Interfaces:**
- Produces: after this task no array type with a 1-, 2- or 4-bit integer element type can exist; later
  tasks' tests must not build one.

- [ ] **Step 1: Failing unit tests.** Add tests named
  `"compose refuses integer element types narrower than 8 bits"` (for each of bits 1, 2, 4, signed and
  unsigned: `composeWith` in a `childThrow`; `expectThrew` with
  `MVMArray: Cannot compose an array of 4-bit integers, element types need at least 8 bits` and the bit count
  varied; the array type's REPR data unchanged afterwards) and
  `"recompose message names an anonymous type <anon>"` (a type with no debug name, composed to int64 then to
  int32: message `MVMArray: Type <anon> is already composed with another element kind`; a type with a debug
  name still prints the name). Also: on a type already composed to int64, a compose to a 4-bit type gives the
  narrow-bits message, not the recompose message.
- [ ] **Step 2:** Run `zig build unit-test --summary all`. Expected: the new tests fail (no throw, or the old
  message).
- [ ] **Step 3: C fix, area K.** In the function that maps the element type's storage spec to REPR data,
  throw the K message when the spec is an integer boxed primitive with `bits < 8`. The check runs before the
  #2081 recompose check. `deserialize_repr_data` throws the same message for a stored slot type of one of the
  six kinds. Commit: "Refuse composing a VMArray with an element type narrower than 8 bits".
- [ ] **Step 4: Zig mirror, area K.** Same checks, same order, same message in `serial.zig`. Existing unit
  tests that build storage-less arrays are rewritten to expect the compose throw, or removed when they only
  tested behaviour of such arrays; list each in the report. Commit.
- [ ] **Step 5: C fix, area M.** The #2081 message prints `<anon>` when the debug name is NULL or empty.
  Commit (message names #2081). **Step 6: Zig mirror, area M.** Commit.
- [ ] **Step 7:** Run the unit tests on the three settings. Expected: all pass; the count is not below the
  baseline minus the tests removed in Step 4 (state the arithmetic in the report).
- [ ] **Step 8: Harness.** In `vmarray-diff.nqp`, move `odd_kinds()`'s composes inside `t()` wrappers so a
  throw prints a line and the program goes on; the six kinds' cases print the compose message; the
  `<kind>.late.*` cases (first compose with a live instance to a storage-less kind) print it too. Update
  `README.md`. Commit.
- [ ] **Step 9:** `ob-repro/build-prefixes.sh`, then `tools/bench/repr/diff.sh --base=/tmp/claude-1000/ob-c
  --head=/tmp/claude-1000/ob-n --out=/tmp/claude-1000/ob/diff-t2`. Expected: exit 0. Run `K-*` and `OB12-*`
  reproducers on both: C equals Zig, `K-smallnatives.raku` prints the compose message at the declaration.
- [ ] **Step 10 (Review Focus 1):** Run nqp and Rakudo `make test` on `ob-c` and `ob-n` with the driver
  `traces/llm/bench/cfix-mirror-raw/maketest-driver.sh` re-pointed at `ob-*`. Expected: per-file results equal
  to `cfix-mirror-raw/suites/` (nqp PASS; Rakudo failing only `t/04-nativecall/02-simple-args.t`).
- [ ] **Step 11:** Append section "K and M" to `ob-fixes.md` (the fix, before/after outputs, what OB6, OB17,
  OB18's second half, OB20 and OB15d become, tests removed). Commit traces, then the pointer.

### Task 3: Area Y (type object as splice source) and area Q (rejected push / bind_pos)

**Files:**
- Modify: `src/6model/reprs/VMArray.c` (`asplice` near 1045-1112; `MVM_VMArray_push` near 580;
  `MVM_VMArray_bind_pos` near 490)
- Modify: `src/zig/6model/reprs/vmarray/elements.zig` (`asplice` near 695; `push` near 526; `bindIndex`
  near 167)
- Test: `src/zig/6model/test/vmarray_elements_test.zig`; `tools/bench/repr/vmarray-diff.nqp`, `.raku`

- [ ] **Step 1: Failing unit tests.**
  `"asplice refuses a type object as source"`: sources = the target's own type object, a type object of
  another VMArray type, a type object of a non-VMArray REPR (`MVMHash`); for each, with count 0 and count 2,
  on an empty and a 5-element target: `expectThrew` with `MVMArray: Cannot splice from a type object`, target
  state unchanged.
  `"a rejected push leaves the array as it was"` and `"a rejected bind_pos leaves the array as it was"`: for
  each storable kind and each wrong register kind (use `refusedStackKind`): existing message kept, `stateOf`
  equal before and after; `bind_pos` at index `elems + 3` (past the end) and at an index inside.
  `"bind_pos with a negative index and the wrong kind"` (Review Focus 3): index -1 on a 3-element array, and
  index -5 (stays negative): record which message each gives in C by running the C-REPR build first, then
  assert that message.
- [ ] **Step 2:** Run the unit tests; the new ones fail.
- [ ] **Step 3: C fix, area Y.** `asplice` throws the Y message when the source is not concrete, as the first
  thing done with the source (before `elems` is read from it). Read `aslice` and every other VMArray entry
  point that takes a second array (`grep -n 'IS_CONCRETE\|REPR(from)\|REPR(dest)' src/6model/reprs/VMArray.c`
  and `src/core/interp.c` OP(splice), OP(slice)): list in the report which of them can read a type object's
  body; apply the same throw where one does, with `splice` in the message replaced by the operation's name.
  Commit. **Step 4: Zig mirror.** Commit.
- [ ] **Step 5 (Review Focus 2):** `grep -rn 'nqp::splice' ../../src ../src` (Rakudo and nqp sources) and
  check each call's source argument can not be a type object; list any that can in the report (they are
  callers that would now throw; `Buf.new(array[int])` is the known one and its new output goes in the
  record).
- [ ] **Step 6: C fix, area Q.** In `push` and `bind_pos`, check the register kind against the slot type
  before `set_size_internal` runs. Keep the messages. Read the JIT entry points
  (`vmarray_bind_pos_int64` and siblings, VMArray.c near 1559-1582) and state in the report whether they can
  be reached with a non-matching kind; change them only if they can. Commit. **Step 7: Zig mirror.** Commit.
- [ ] **Step 8:** Unit tests on three settings pass. Add differential cases `cfix.typeobj.splice.*`,
  `ob.push.rejected.*`, `ob.bindpos.rejected.*` to `vmarray-diff.nqp` and a `Buf.new(array[int])` line to
  `vmarray-diff.raku`. Rebuild prefixes; `diff.sh` exit 0; reproducers `OB2-*`, `OB7-*` fixed on both and
  equal.
- [ ] **Step 9:** Both suites on both prefixes, results as in Task 2 Step 10 (a type-object splice in the
  suites would show here).
- [ ] **Step 10:** Section "Y and Q" in `ob-fixes.md`. Commit traces and pointer.

### Task 4: Area W (write_buf growth, num message), area V (deserialize size), area H (holes)

**Files:**
- Modify: `src/6model/reprs/VMArray.c` (`write_buf` near 995-1007, `read_buf` near 1022-1024; `deserialize`
  near 1369-1372 and 1423-1424; `pop` near 663, `shift`)
- Modify: `src/zig/6model/reprs/vmarray/elements.zig` (`writeBuf` near 840-851, `readBuf` near 871-878,
  `pop`, `shift`), `serial.zig` (`deserialize` near 222-228)
- Test: unit test file; `vmarray-diff.nqp`, `.raku`; `vmarray-serial.nqp` if a serialized hole needs a case

- [ ] **Step 1: Failing unit tests.**
  `"write_buf grows by whole elements"`: for element sizes 2, 4, 8 and byte counts 1 to 9 at offsets
  `elems - 1`, `elems`, `elems + 2`: afterwards `elems == max(old_elems, offset + ceil(count / elem_size))`;
  bytes of the last element past the written ones are zero (for a fresh array). The #2077 and #2080 throws
  (offset past `elems`, sizes that wrap) are unchanged: reuse the existing B tests as they are.
  `"read_buf and write_buf name integer or num"`: on an object array and a string array the message is the
  old one with `integer` replaced by `integer or num` (take the old string from VMArray.c:1024 and 1052).
  `"deserialize refuses a size it cannot allocate"`: element counts `2**63`, `2**64 - 1`, and
  `(2**64 / elem_size) + 1` for each element size: message
  `Unable to allocate an array of <n> elements` with the count; nothing allocated.
  `"pop and shift return VMNull for a hole"`: object array with NULL slots (grown by `setElemsTo`), nursery
  and gen2: result is `tc.instance.VMNull`, and storing it into a gen2 array then running a collection with
  `-Dgc-debug=1` passes (Review Focus 5).
  `"write_buf into spare room of an adopted buffer"` (Review Focus 4): written, marked skipped with the
  reason "needs area Z"; Task 5 enables it.
- [ ] **Step 2:** Run; the new tests fail.
- [ ] **Step 3: C fix W.** Growth target `offset + (count + elem_size - 1) / elem_size`, computed so it cannot
  wrap under the existing checks; message text change. Commit (names #2080; states the visible change:
  `buf16.new(1,2,3).write-uint64(1,1)` leaves 5 elements, not 9). **Step 4: Zig mirror W.** Commit.
- [ ] **Step 5: C fix V.** Before allocating in `deserialize`: the limit `set_size_internal` uses and a
  wrap check on `elems * elem_size`; throw the existing "Unable to allocate" message. Commit.
  **Step 6: Zig mirror V.** Commit.
- [ ] **Step 7: C fix H.** `pop` and `shift` on an object array return VMNull for a NULL slot.
  `copy_elements` unchanged. Commit. **Step 8: Zig mirror H.** Commit. Check what a serialized NULL slot
  reads back as (`vmarray-serial.nqp` has object arrays; add a hole case if none) and record it.
- [ ] **Step 9:** Unit tests on three settings pass. Differential cases `ob.writebuf.growth.*`,
  `ob.holes.pop`, `ob.holes.shift`, a `write-uint64` on `buf16`/`buf32` line in `.raku`. Rebuild; `diff.sh`
  exit 0; reproducers `OB8-*`, `OB16-*`, `OB18-*`, `OB19-*` fixed and equal on both.
- [ ] **Step 10:** Both suites on both prefixes, as in Task 2 Step 10. `grep -rn 'write-u\?int\|write-num'
  ../../src/core.c/Buf.rakumod` and note in the record whether any Rakudo code depends on the old `elems`.
- [ ] **Step 11:** Section "W, V and H" in `ob-fixes.md`. Commit traces and pointer.

### Task 5: Area Z (growth within storage zeroes what it exposes)

**Files:**
- Modify: `src/6model/reprs/VMArray.c` (`set_size_internal`, the path that raises `elems` without realloc)
- Modify: `src/zig/6model/reprs/vmarray/storage.zig` (`setSize` near 130-131)
- Test: unit test file (enable Task 4's skipped test); `vmarray-diff.nqp`

**Interfaces:**
- Consumes: Task 1's `vmarray-push-bench.nqp` and its baseline medians in `ob-fixes.md`.

- [ ] **Step 1: Failing unit test** `"growth within storage zeroes the exposed slots"`: for each storable
  kind: an array whose storage past `elems` holds non-zero bytes (write them directly into
  `body.slots` beyond `elems`, within `ssize`), then `setElemsTo(elems + n)` with `start == 0` and
  `start > 0`: the exposed slots read as zero / hole. Enable Task 4's skipped test.
- [ ] **Step 2:** Run; both fail.
- [ ] **Step 3: C fix.** Zero `[old_elems, new_elems)` when `set_size_internal` grows without reallocating.
  The reallocating path is untouched. Commit. **Step 4: Zig mirror.** Commit.
- [ ] **Step 5:** Unit tests on three settings pass. Add differential case `ob.adopted.setelems` (encode into
  a fresh buffer, `setelems` up, read the exposed elements: all 0). Rebuild; `diff.sh` exit 0;
  `OB4-adopted-setelems.nqp` prints 0 on both.
- [ ] **Step 6: Benchmark.** 7 runs per prefix on `ob-c` and `ob-n`, same method as Task 1 Step 6. Record all
  values, medians and the change against the baseline per case. **If any median is more than 5 % worse on
  either build: stop, report the numbers with status BLOCKED, and do not try another design.**
- [ ] **Step 7:** Section "Z" in `ob-fixes.md` with the benchmark table. Commit traces and pointer.

### Task 6: Shared C fixes (OB1, OB3, OB5, OB9, OB10)

**Files:**
- Modify: `src/6model/reprs/VMArray.c` (`set_size_internal`: the `~0xfffUL` mask)
- Modify: `src/jit/graph.c` (near 2384-2476), `src/core/interp.c` (writenum near 5313-5354; readnum near
  5432 as the model)
- Modify: `src/6model/reprs/MVMHash.c` (`deserialize`, port lines 196-202)
- Modify: `src/strings/normalize.c` (`MVM_unicode_normalize_codepoints` near 52-53), `src/strings/ops.c`
  (`MVM_string_encode_to_buf_config` near 1909-1919)

One commit per bug id. No Zig changes; if a Zig file turns out to carry the same behaviour, stop and report.

- [ ] **Step 1: OB1.** `~0xfffUL` becomes `~(MVMuint64)0xfff`. No test possible here (Win64); the commit says
  found by reading. Commit.
- [ ] **Step 2: OB3.** In `graph.c`, the readuint, writeint and writeuint cases do not compile their fast
  path when `(flags & 3) == 3` or the size is over 8 (use the existing bail path, which leaves the frame to
  the interpreter). writenum in `interp.c`: sizes other than 4 and 8 throw `Cannot write a num of %d bytes`;
  for `(flags & 3) == 3` do exactly what readnum does for the same flags. Read the two "uncertain" points of
  the bug list's OB3 section (`MVM_SC_WB_OBJ` and `IS_CONCRETE` on the JIT paths; the `int` shift
  `1 << (flags >> 2)`): for each, state in the report whether it is a defect and why; fix it in this commit
  only if it is, and say so in the message. Run `OB3-*` with the JIT on and with `MVM_JIT_DISABLE=1` on
  rebuilt prefixes: both give the interpreter's exception, C and Zig builds equal. Commit.
- [ ] **Step 3: OB5.** Root `key` across `MVM_serialization_read_ref` with `MVMROOT`, as #2086 does in
  `read_hash_str_var`. Found by reading; no reproducer. Commit.
- [ ] **Step 4: OB9.** Empty input gives an empty output array (elems 0), consistent with #2083's handling of
  the non-empty path. `OB9-normalize-empty.nqp` shows it. Commit (names #2083).
- [ ] **Step 5: OB10.** Free the encoded buffer when the resize throws (compute and check the new size before
  the resize, or free on the exception path). Found by reading; the record states reachability is doubtful.
  Commit.
- [ ] **Step 6:** Rebuild prefixes. Unit tests on three settings pass. `diff.sh` exit 0. Both suites on both
  prefixes as before. Reproducers `OB3-*`, `OB9-*` fixed and equal.
- [ ] **Step 7:** Section "Shared C" in `ob-fixes.md`. Commit traces and pointer.

### Task 7: Full gate, record, docs

**Files:**
- Modify: `traces/llm/bench/ob-fixes.md` (section "Gate"), `traces/llm/bench/cfix-open-bugs.md` (status
  lines), `docs/zig-build.md` (REPRs section)

- [ ] **Step 1:** Rebuild `ob-c` and `ob-n` from the branch tip. Run the whole acceptance list of the spec:
  `zig fmt --check src/zig build.zig build/zig tools/zig`; unit tests on three settings; exported symbols
  (`nm -D --defined-only <P>/lib/libmoar.so | awk '{print $3}' | sort`) equal between the two and compared
  with `cfix-mirror-raw/build/exports-*.txt` (any added or removed name listed); `diff.sh` exit 0 with
  `undefined-lines.txt` empty; both suites, per-file lists equal on both builds and to
  `cfix-mirror-raw/suites/`; `ob-repro/run-all.sh` on both, compared with `ob-fixes-raw/before/` (every bug
  shown before, absent after, C equals Zig); `cfix-repro` through `cfix-mirror-raw/run-all-port.sh`
  re-pointed at `ob-*`, compared with `cfix-mirror-raw/repro/` (differences explained one by one: area K
  changes the storage-less programs).
- [ ] **Step 2:** `ob-fixes.md` "Gate": a table of each check, command, result, raw file. A section "Not
  verified" (no ASAN, no Win64, no `-Dzig-gc=false`, anything else).
- [ ] **Step 3:** `cfix-open-bugs.md`: under each entry's heading one line
  `Status 2026-11-23: fixed in the port (<commit ids>), see ob-fixes.md <section>` or
  `not fixed: <reason>` (OB11, OB13, OB14, OB15a-c) or `gone with area K` (OB6, OB17, OB20, OB15d).
- [ ] **Step 4:** `docs/zig-build.md` REPRs section: arrays of integer types narrower than 8 bits are refused
  at compose; the remaining first-compose gap (OB11: composing a type that already has instances to `str`
  or a native kind is undefined). Commit P, traces, pointer.

### Task 8: Final review and hand-back (controller)

Whole-branch review on the most capable model; one fix wave; ledger preserved as
`traces/llm/bench/ob-ledger.md`; this plan's Outcome filled; report to the owner: what was fixed (commit per
bug id, ready to become PRs, with dependencies on #2076-#2086), what was not and why, visible behaviour
changes, every ruling with its cost if wrong. The branch is handed back unmerged and unpushed.

## Outcome

Finished 2026-11-24. Branch `zig-open-bugs`, 99f7ce8cd..a2fc519a4 (last src commit 96a9a1a07), local, not
merged, not pushed. Ledger: `traces/llm/bench/ob-ledger.md`. Record: `traces/llm/bench/ob-fixes.md` (per
area, Gate, Not verified, Commits by bug id, Decisions for the owner). Bug list with a status line per entry:
`traces/llm/bench/cfix-open-bugs.md`.

**Fixed in the port (C and Zig):** K (OB6, OB17, OB20, OB15d, OB18 second half gone: integer element types
narrower than 8 bits refused at compose), M (OB12), Y (OB2, plus nqp::slice on a type object), Q (OB7), W
(OB8, OB16), V (OB18 first half), H (OB19), Z (OB4, and OB21 found on the way).
**Fixed in shared C:** OB1, OB3 (with the SC write barrier, the concreteness check and the size helper),
OB5, OB9, OB10.
**Not fixed:** OB11 (first-compose gap, type-confusion case remains, documented), OB13, OB14, OB15a-c (not
in this campaign), and the bugs found on the way: OB22 (P6opaque slice hands its body to the delegate
array's slice), OB23 (JIT generic repr calls skip the concreteness check), OB24 (deserialization holds its
object unrooted; by reading), OB25 (strtocodes "" calls malloc(0)).

**Gate at the final tip:** fmt clean; unit tests 253/265, 253/265 (-Dzig-reprs=false), 258/265
(-Dgc-debug=1); exports equal and unchanged; diff.sh exit 0 with an empty undefined-lines list; ob-repro
41/41 equal between C and Zig. At d68a0ec8c (library byte-identical to the tip): nqp PASS on both, rakudo
failing on both only t/04-nativecall/02-simple-args.t 17-18; cfix-repro 62/62 equal.
**Not verified:** no ASAN build of the port, no Win64, no -Dzig-gc=false; OB1, OB5, OB10 by reading.

**Deviations from the plan:** area Z's mechanism (zero by default, push and unshift opt out) after the
benchmark stop rule fired twice; the review then found the move-then-reallocate path unzeroed and it was
fixed; C push restructured to one dispatch; a sixth new message (`Cannot slice from a type object`); OB3
grew by three fixes. **Open for the owner:** the nine decisions in ob-fixes.md, first among them the net
cost on the C array's push/pop path (obj.pushpop8 +7.1 % / +5.4 % in two runs against the build before
the campaign, cause unverified; the Zig array is faster on all four cases).
