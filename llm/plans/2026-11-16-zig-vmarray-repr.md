# VMArray REPR in Zig Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement VMArray in Zig behind the same C symbols and layouts, built by a comptime mechanism (a vtable builder and one generic body per operation over the slot kind), with every byte the array owns coming from one declared `std.mem.Allocator`, selectable against the C file and shown identical in behaviour and not worse in time or memory.

**Architecture:** A build switch `-Dzig-reprs` and a `[zig-reprs]` section select `src/zig/6model/reprs/VMArray.zig` in place of `src/6model/reprs/VMArray.c`; the control for every comparison is the same commit built with `-Dzig-reprs=false`. `src/zig/6model/repr.zig` holds the vtable builder; the array's implementation lives in export-free files under `src/zig/6model/reprs/vmarray/` (so unit tests can link them next to libmoar without interposing its symbols), and `VMArray.zig` is the thin file that declares the REPR, builds the table and exports the C names. The C array's behaviour is recorded first (a differential program, serialization bytes, a vtable dump) and the Zig array is held to those records.

**Tech Stack:** Zig 0.17.1 (`/usr/bin/zig`), the `translate_c` package, nqp and rakudo built by the Perl path against `/tmp/claude-1000/tune-zig-prefix`, the runners under `tools/bench/gc/` (`oracle.sh`, `ab.sh`, `cleanup.sh`, `profile.sh`), `tools/bench/timev.py`, the Campaign 6 drivers in `traces/llm/bench/` (`ngc-oracle-driver.sh`, `ngc-crc-ab-driver.sh`, `ngc-spectest-driver.sh`, `ngc-maketest-driver.sh`, `ngc-prefixes-raw/build9.sh`) as templates.

**Spec:** `traces/llm/specs/2026-11-16-zig-vmarray-repr-design.md` (section numbers below refer to it). Executors read it in full before their task.

## Global Constraints

- Branch `zig-vmarray` from `zig-hash-engine` at e1ec6b423 or later, in the main checkout `/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM`. **No git worktrees.** Address every repository with `git -C <absolute path>`. Records go in the `traces/` submodule under `llm/bench/va-*`; commit there first, then the pointer commit in MoarVM. Never add `.superpowers/` or `tools/lib/MAST/Ops.rakumod`. No `git stash`, `reset --hard` or `clean`. Nothing is pushed; nothing is merged.
- **Models (the user's instruction):** implementers Fable, every reviewer Opus.
- **Layouts are defined once, in C.** No file under `src/**/*.h` changes, and no C file changes except where a task says so (a C shim is allowed only for a symbol `translate_c` cannot expose, spec 10). `MVMArrayBody`, `MVMArray`, `MVMArrayREPRData` and `MVMREPROps` are used through `moar.c`; comptime asserts pin their sizes and field offsets.
- **No behaviour change.** Growth policy, error messages (byte-identical), serialization format, exported names and signatures are the C array's. A per-kind difference in the C is kept and listed in `va-kind-differences.md`, never smoothed.
- **Allocator rule (spec 5.4).** In `src/zig/6model/reprs/**` there is no direct `MVM_malloc`/`MVM_calloc`/`MVM_realloc`/`MVM_free` call; storage goes through the one declared allocator. A zero length is never passed to the allocator; an array without storage has `slots.any == NULL`.
- **Comptime documentation rule (spec 6).** Every comptime construct carries a doc comment saying what it generates in terms of the result (fields, switch arms, exported symbols, for which inputs), with a worked expansion where it helps; `repr.zig` and the kind table open with a prose explanation. No line-by-line translation: a per-kind `switch` written out by hand is a defect.
- **Builds:** `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before every `zig build`; 1-minute load under 2.0 before every build, test run or benchmark round (poll every 60 s; record the value); before a long run check `pgrep -a -x raku; pgrep -a -x moar; cat /proc/loadavg` for another session's work; everything that can grow under `systemd-run --user --scope -q -p MemoryMax=8G <cmd>`; kill by PID only, never `pkill -f`/`pgrep -f`.
- **Prefixes** under `/tmp/claude-1000/` (a reboot removed the old ones; Task 1 rebuilds), equal-length names within a comparison: `tune-zig-prefix` (the moar, nqp and rakudo every script runs), `va-c-oracle`, `va-c-base`, `va-c-stress` (`-Dzig-reprs=false`; with `-Dgc-debug=1`, defaults, `-Dgc-debug=1 -Dnursery-size=524288`), `va-n-oracle`, `va-n-base`, `va-n-stress` (head, same options without `-Dzig-reprs=false`). Scripts reach a side through `LD_LIBRARY_PATH=<P>/lib`.
- **Measurement:** interleaved rounds, rotated side order, medians of five runs per round, spread as the min and max of round medians, load recorded before every run, nothing judged from one run. Spectest recipe: `TEST_JOBS=24 python3 tools/bench/timev.py <out>.time make -o spectest_update spectest` in the rakudo checkout, roast at fb1d87214, `.precomp` removed before each run, order base head head base base head.
- **Gate (spec 7 and 8):** any differing differential, serialization or oracle output, a changed export set, a failing unit test or a new suite failure stops the campaign for a report. So does a crc-getter wall or RSS ratio head/control outside the control's spread after one re-run of that setting, or a spectest wall or RSS ratio outside the control's spread and above 1 percent.
- **Hygiene:** `zig fmt --check src/zig build.zig build/zig tools/zig` clean; `sh -n` on touched shell; test output pristine. Exports: `nm -D --defined-only <P>/lib/libmoar.so | awk '{print $3}' | sort` equal between head and control (2,850 names at the base).
- **Commit messages:** imperative subject, a body with the reasoning, then the attribution lines exactly as the dispatching session gives them.

## Review Focus

1. **A buffer adopted from outside, then grown or freed by the array.** I/O, decoder and string code `MVM_malloc` a buffer, store it in `slots`, set `ssize` (and sometimes `start`), and the array later reallocates or frees it. Expected: no crash, no leak, contents preserved across the growth. Test in Task 5 Step 3.
2. **Values at the edge of a slot's width.** Unsigned 64-bit values above `INT64_MAX`, negative values in unsigned kinds, values wider than a narrow kind, NaN and negative zero in the num kinds. Expected: exactly the C's truncation and extension on bind and read. Differential program (Task 2 Step 1) and unit tests (Task 6 Step 1).
3. **An array used as its own source.** `asplice` and `copy_elements`/`aslice` with source and destination the same array and overlapping ranges. Expected: the C's result. Differential program (Task 2 Step 1).
4. **A collection in the middle of an array's life with `start` non-zero.** After shifts (so `start > 0`) and unshifts, a collection must mark exactly the live range of object and string slots and nothing in the gaps. Test in Task 6 Step 1.
5. **An empty array deserialized, then used.** `deserialize` with zero elements leaves no storage; a following push, unshift, `set_elems` or copy must behave as on a fresh array, for every kind. Test in Task 7 Step 1.

---

### Task 1: Branch, prefixes and the `-Dzig-reprs` switch

**Files:**
- Modify: `build/zig/options.zig` (field `zig_reprs: bool`, option `zig-reprs`, function `zigReprs`, its test)
- Modify: `build/zig/sources.zig` (section `zig-reprs`, `Lists.zig_reprs`, `applyZig` gains the flag, tests)
- Modify: `build/zig/zigimpl.zig` (`zig_opts` gains `zig_reprs`; `checkRootImports` gains the flag)
- Modify: `build.zig` (pass the flag at the two call sites, lines 33 and 35)
- Modify: `build/sources.list` (the empty `[zig-reprs]` section with its comment)
- Modify: `src/zig/root.zig` (the header comment and an empty `if (@import("zig_options").zig_reprs) {}` block)
- Create: `traces/llm/bench/va-prefixes.md`, `traces/llm/bench/va-prefixes-raw/build.sh`

**Interfaces:**
- Produces: `options.zigReprs(zig_impl: bool, zig_gc: bool, given: ?bool) error{ZigReprsNeedsZigGc}!bool` (true by default when both are on; false by default when either is off; an explicit `true` with either off is the error); message constant `zig_reprs_needs_zig_gc_message = "-Dzig-reprs needs -Dzig-impl=true and -Dzig-gc=true (the Zig REPRs call the Zig collector)"`. `sources.applyZig(allocator, raw, zig_gc: bool, zig_reprs: bool)`; `Lists.zig_reprs: []const ZigEntry`. `zigimpl.checkRootImports(b, lists, zig_gc, zig_reprs)`. The `zig_options` module has `zig_reprs: bool`.
- Produces: prefixes `tune-zig-prefix`, `va-c-oracle`, `va-c-base`, `va-c-stress`.

- [ ] **Step 1: Branch.** `git -C <MoarVM> checkout -b zig-vmarray zig-hash-engine`.
- [ ] **Step 2: Failing tests** in `build/zig/options.zig` and `build/zig/sources.zig`:

```zig
test "zig-reprs needs the Zig collector" {
    try std.testing.expectEqual(true, try zigReprs(true, true, null));
    try std.testing.expectEqual(false, try zigReprs(true, true, false));
    try std.testing.expectEqual(false, try zigReprs(true, false, null));
    try std.testing.expectEqual(false, try zigReprs(false, false, null));
    try std.testing.expectError(error.ZigReprsNeedsZigGc, zigReprs(true, false, true));
    try std.testing.expectError(error.ZigReprsNeedsZigGc, zigReprs(false, false, true));
}
```

In `sources.zig`: a list text with a `[zig-reprs]` line `src/zig/6model/reprs/X.zig: src/6model/reprs/X.c` parses to `lists.zig_reprs.len == 1`; `applyZig(a, raw, true, false)` keeps `src/6model/reprs/X.c` in `core` and returns `zig_reprs.len == 0`; `applyZig(a, raw, true, true)` removes it from `core` and returns the entry. Run `zig build unit-test`; expected: compile errors for the missing names.
- [ ] **Step 3: Implement** the option, the section and the flag as in Interfaces, following the `zig_gc` code path line for line in each file. `std.process.fatal` with the message on the error, as `-Dzig-gc` does.
- [ ] **Step 4: Verify.** `zig build unit-test` passes. `zig build -Dzig-gc=false -Dzig-reprs=true` fails with the message. `zig fmt --check` clean.
- [ ] **Step 5: Rebuild the runner prefix.** `zig build install --prefix /tmp/claude-1000/tune-zig-prefix` from the branch tip; `make install` in `<MoarVM>/..` (nqp, branch `zig-hash-strategies`, configured against that prefix); in `<MoarVM>/../..` (rakudo) check `./rakudo-m -e 'say 42'`, else `make` and `make install`. Record commits, commands, durations and loads in `va-prefixes.md`. Pin roast: `git -C <rakudo>/t/spec rev-parse HEAD` is fb1d87214, else check it out.
- [ ] **Step 6: Build the control prefixes** with `va-prefixes-raw/build.sh` (copy `ngc-prefixes-raw/build9.sh`; list `va-c-oracle -Dzig-reprs=false -Dgc-debug=1`, `va-c-base -Dzig-reprs=false`, `va-c-stress -Dzig-reprs=false -Dgc-debug=1 -Dnursery-size=524288`). With the section empty a `-Dzig-reprs=true` build is the same library: build one to a scratch prefix `va-x-base`, check `cmp /tmp/claude-1000/va-c-base/lib/libmoar.so /tmp/claude-1000/va-x-base/lib/libmoar.so` or, if the config string differs, that the export lists and `.text` sizes are equal; record which; remove `va-x-base`.
- [ ] **Step 7: Sanity.** `tools/bench/gc/oracle.sh --base=/tmp/claude-1000/va-c-oracle --head=/tmp/claude-1000/va-c-oracle --volume=10000 --out=<workspace>/oracle-self` exits 0 (the rebuilt toolchain repeats). Export count is 2,850.
- [ ] **Step 8: Commit** (traces first, then MoarVM with the pointer).

### Task 2: The C array's records: differential program and serialization bytes

**Files:**
- Create: `tools/bench/repr/vmarray-diff.nqp`, `tools/bench/repr/vmarray-diff.raku`, `tools/bench/repr/vmarray-serial.nqp`, `tools/bench/repr/diff.sh`, `tools/bench/repr/README.md`
- Create: `traces/llm/bench/va-differential.md`, `traces/llm/bench/va-differential-raw/`

**Interfaces:**
- Produces: `tools/bench/repr/diff.sh --base=PREFIX --head=PREFIX --out=DIR [--runs=K (default 3)]`. For each side and each of the three programs it runs the program K times with `LD_LIBRARY_PATH=<P>/lib` (`MVM_SPESH_DISABLE` unset and again with `MVM_SPESH_DISABLE=1`; the nqp programs through `/tmp/claude-1000/tune-zig-prefix/bin/nqp-m`, the Raku one through `<rakudo>/rakudo-m` with `RAKUDO_NO_PRECOMPILATION=1`), writes `<DIR>/<side>-<program>-<spesh>-<i>.out`. Exit 2 "not repeatable" if a side's K outputs differ; exit 1 naming the first differing line if base and head differ; exit 0 identical; 64 misuse. Later tasks call it with base `va-c-base` and head a Zig-array prefix.
- Produces: `vmarray-serial.nqp` prints, for each case, the case name and the serialized blob as hex; with `--read=FILE` it deserializes blobs written by another run and prints the arrays' contents.

- [ ] **Step 1: Write the differential programs.** Every output line is `<case name>: <result>`; a caught exception prints `<case name>: DIED <message>`. Coverage, each over every slot kind reachable from the language (nqp: `nqp::list`, `nqp::list_i`, `nqp::list_n`, `nqp::list_s`; Raku: `array[int8]` to `array[uint64]`, `array[num32]`, `array[num64]`, `buf8` to `buf64`, `blob8`, plain `Array` internals via `nqp::` ops under `use nqp`):
  - `at_pos`, `bind_pos`, `push`, `pop`, `shift`, `unshift`, `set_elems` up and down, `elems`, `splice` (insert, delete, replace, from an array of another kind, from itself with overlap), `slice`/`copy` of ranges (including into itself), `write_buf`/`read_buf` paths (`nqp::writeint`/`readint`/`writenum`/`readnum` on a `buf8`, every size and both endiannesses), `nqp::atposref_*` and the atomic position ops (`nqp::cas`/`atomicload` on a positional), `nqp::clone`, the multi-dimensional ops on a VMArray (which throw), `get_elem_storage_spec` via `nqp::objprimspec`/`nqp::objprimbits` of the element type.
  - Boundaries: empty array; negative indices in and out of range; a read past `elems`; growth through each of the policy's branches (below 8, doubling below 8,192, the 4,096-rounding branch above it, growth after shifts so `start > 0`, shrinking then growing); the size-limit error (`set_elems` with a count above the budget).
  - Kind mismatches: every `at_pos`/`bind_pos`/`push`/`pop`/`shift`/`unshift` with a register kind the slot kind rejects (reach them with the typed nqp ops on the wrong array, for example `nqp::atpos_i` on a `list_s`).
  - Review Focus 2 values: for each integer kind its minimum, maximum, minimum minus one and maximum plus one, `-1`, `2**63`, `2**64 - 1`; for num kinds `NaN`, `-0e0`, `Inf`, the largest num32, a value num32 rounds.
  - Review Focus 3: self-splice and self-copy with overlapping ranges, forwards and backwards.
- [ ] **Step 2: Write `vmarray-serial.nqp`.** With `nqp::createsc`/`nqp::setobjsc`/`nqp::scsetobj`/`nqp::serialize` (the pattern of nqp's `t/serialization/01-basic.t`), serialize one SC per case: an empty and a 3-element and a 10,000-element array of each kind nqp can construct, plus typed arrays of the sized kinds made with `nqp::newtype(..., 'VMArray')` and `nqp::composetype` with an `array` hash naming a sized `P6int`/`P6num` element type (bits 8, 16, 32, 64, signed and unsigned; num 32, 64). Print hex. `--read` reverses it.
- [ ] **Step 3: Write `diff.sh`** as in Interfaces; `sh -n` clean.
- [ ] **Step 4: Record the control.** `diff.sh --base=/tmp/claude-1000/va-c-base --head=/tmp/claude-1000/va-c-base --out=<workspace>/diff-self` exits 0 (the C array repeats). If it exits 2, find the unrepeatable case (an address or a hash order in the output), remove that from the output, not the case, and rerun. Count the distinct `DIED` messages and check against `grep -c MVM_exception_throw_adhoc src/6model/reprs/VMArray.c`: every throw site in the C file is reached by at least one case, or the record names the unreachable site and why.
- [ ] **Step 5: Coverage check, by hand** (no coverage tool is set up for this build): for each of the array's own functions in `VMArray_this_repr` (18 positional, 17 others) and each group of `case MVM_ARRAY_*` arms, the record `va-differential.md` names a case that reaches it. A function or kind no case reaches is added to the program or listed with the reason.
- [ ] **Step 6: Commit** the programs and `va-differential.md` (the control's outputs kept under `va-differential-raw/`).

### Task 3: The adoption audit and the kind differences

**Files:**
- Create: `traces/llm/bench/va-adoption-audit.md`, `traces/llm/bench/va-kind-differences.md`

**Interfaces:**
- Produces: the two records Task 5 and Task 6 read. No code.

- [ ] **Step 1: Find every outside site.** `grep -rnE 'slots\.[a-z0-9]+ *=[^=]|\.ssize *=[^=]|->ssize *=[^=]|body\.start *=[^=]|body\.elems *=[^=]' src --include='*.c' --include='*.h' --include='*.dasc'` minus `src/6model/reprs/VMArray.c`, plus `grep -rnE 'MVM_free\([^)]*slots\.'`. For each hit decide whether the object is an `MVMArray` (not a `MVMMultiDimArray` or another body with a `slots` member).
- [ ] **Step 2: Write `va-adoption-audit.md`:** one row per site with file:line, what it does (adopts a buffer, frees the slots, replaces them, changes `start`/`elems` only), how the buffer was allocated and with what size, whether `ssize * elem_size` equals that size, and the element kind. Close with a list of sites where `ssize` misstates the allocation (reported, not fixed) and one paragraph on what a non-`malloc` allocator would have to change.
- [ ] **Step 3: Write `va-kind-differences.md`:** read `src/6model/reprs/VMArray.c` operation by operation and, for each operation, state whether the twelve arms are the same code with the type swapped. Every difference is a row: operation, kinds, what differs, "kept". A difference that looks like a bug is marked "report to the user" as well. Include the six kinds without storage (`U4`, `U2`, `U1`, `I4`, `I2`, `I1`): where each is accepted and what the C does with it.
- [ ] **Step 4: Commit** in traces, then the pointer.

### Task 4: The vtable builder

**Files:**
- Create: `src/zig/6model/repr.zig`, `src/zig/6model/repr_test.zig`, `src/zig/6model/test/repr_ops_test.zig`, `src/zig/6model/test/vmarray_vtable_c.tsv`
- Modify: `build.zig:152-160` (register the `repr-test` root next to `gc-test`, with the `zig_options` import; it runs with `-Dzig-reprs` on or off)

**Interfaces:**
- Produces, in `repr.zig`:
  - `pub fn Ops(comptime R: type) c.MVMREPROps`. `R` is a struct type whose public declarations are named after fields of `c.MVMREPROps`; the four nested tables are given as nested struct types `attr_funcs`, `box_funcs`, `pos_funcs`, `ass_funcs` whose declarations are named after the nested fields. `name` is `[:0]const u8`, `ID` is an integer. A declaration is a Zig function with the C calling convention, or a pointer to a C function, coerced to the field's type. Required: `name`, `ID`, `type_object_for`, `allocate`, `get_storage_spec`, `compose`. Every other undeclared field gets its default: the `MVM_REPR_DEFAULT_*` function the macros in `src/6model/reprs.h` name for that field, or null for fields with no default function.
  - `pub fn declError(comptime R: type) ?[]const u8`: null when `R` is valid; otherwise a message. `Ops` calls `@compileError(declError(R).?)`. Messages: `"<R>: unknown REPR function '<name>'"` for a declaration matching no field; `"<R>: '<name>' has the wrong type; the field is <type>"`; `"<R>: missing required '<name>'"`.
  - `pub fn dumpOps(ops: *const c.MVMREPROps, writer: anytype) !void`: one line per leaf field, `<path>\t<class>`, where path is like `pos_funcs.at_pos` and class is `default` (the pointer equals that field's default function), `null`, `own` (any other pointer), or for `name` and `ID` the value.
- Consumes: `c.MVMArray_initialize` (to dump the linked library's array table).

- [ ] **Step 1: Failing tests** in `repr_ops_test.zig`:
  - `"a REPR that declares only the required functions gets every default"`: a stub `R`; for every leaf field of `Ops(R)` not declared, the value equals the corresponding `c.MVM_REPR_DEFAULT_*` pointer or is null; check at least `pos_funcs.at_pos == c.MVM_REPR_DEFAULT_AT_POS`, `box_funcs.get_int == c.MVM_REPR_DEFAULT_GET_INT`, `ass_funcs.at_key == c.MVM_REPR_DEFAULT_AT_KEY`, `attr_funcs.get_attribute == c.MVM_REPR_DEFAULT_GET_ATTRIBUTE`, `initialize == null`, `gc_cleanup == null`.
  - `"a declared function replaces its default and no other"`: stub with `pos_funcs.push`; `dumpOps` output differs from the first stub's in exactly that line.
  - `"declError names an unknown, a mistyped and a missing declaration"`: three stubs, `expectEqualStrings` on the three messages, at comptime.
  - `"a C function can fill a slot"`: stub with `pub const allocate = &c.MVM_gc_allocate_object;`; the field equals `c.MVM_gc_allocate_object`.
  - `"the linked library's array table has the C table's shape"`: `dumpOps(c.MVMArray_initialize(tc), ...)` equals `@embedFile("vmarray_vtable_c.tsv")`.
  Run `zig build unit-test`; expected: fails to compile.
- [ ] **Step 2: Implement `repr.zig`.** The default for a field is found by a comptime table from field path to default pointer, written once; the walk over `c.MVMREPROps`'s fields is `@typeInfo`-driven. Open the file with the prose explanation and give each comptime function the doc comment the constraints require, with the expansion of the minimal stub shown.
- [ ] **Step 3: Record the C table.** Build against `va-c-base` (a `-Dzig-reprs=false` build), run the last test once with the embedded file empty to print the dump, save it as `vmarray_vtable_c.tsv`, and check it by eye against `VMArray_this_repr` in `src/6model/reprs/VMArray.c:1553` and above: 36 `own` lines (18 in `pos_funcs`, 17 other array functions, and `allocate`), `initialize`, `change_type`, `gc_cleanup` as `null`, the three default groups as `default`, `name\tVMArray`, `ID\t1`.
- [ ] **Step 4: Verify.** `zig build unit-test -Dzig-reprs=false` and `zig build unit-test` both pass (the section is still empty, so both link the C array). `zig fmt --check` clean.
- [ ] **Step 5: Commit.**

### Task 5: The slot kinds and the storage

**Files:**
- Create: `src/zig/6model/reprs/vmarray/kinds.zig`, `src/zig/6model/reprs/vmarray/storage.zig`, `src/zig/6model/test/vmarray_storage_test.zig`
- Modify: `src/zig/6model/repr_test.zig` (import the new test file)

**Interfaces:**
- Consumes: `va-adoption-audit.md`, `va-kind-differences.md`; `moar.mvm_allocator`.
- Produces, in `kinds.zig`:
  - `pub const Kind = enum(u8)` with the twelve stored kinds at their `MVM_ARRAY_*` values (`obj = 0` … `u8 = 11`).
  - `pub const kinds: [12]KindInfo`, the one table of per-kind facts: `kind`, `Elem` (the element type), the union member name, the register member (`.o`, `.s`, `.i64`, `.u64`, `.n64`), the accepted register `kind` constants, `holds_refs`, `elem_size`.
  - `pub fn slots(comptime k: Kind, body: *c.MVMArrayBody) [*]Elem(k)` and `pub inline fn dispatch(slot_type: u8, comptime f: anytype, args: anytype) ReturnOf(f)`: the one generated `switch` on the runtime slot type that calls `f(comptime k, args...)` for each stored kind and, for a value that is not a stored kind, does what the audit record says the C does.
  - `pub const slot_alignment: std.mem.Alignment` (the fixed alignment for all slot memory; at least the widest element's, at most 16).
- Produces, in `storage.zig`:
  - `pub fn Storage(comptime Source: type) type`, where `Source.get() std.mem.Allocator`; the returned namespace has `alloc(n_slots: u64, elem_size: usize) ?[*]u8` (null for zero), `free(body: *c.MVMArrayBody, elem_size: usize) void`, `setSize(tc, body, n: u64, repr_data: *const c.MVMArrayREPRData) void` (the growth policy of `set_size_internal`, including the shift back to `start == 0`, the zeroing and the size-limit throw with the C's message), `copyTo(src, dest, repr_data) void`, `createReprData() *c.MVMArrayREPRData`, `destroyReprData(*c.MVMArrayREPRData) void`.
  - `pub fn zeroSlots(body, from: u64, to: u64, slot_type: u8) void`.
  The implementer may reshape `Source` (spec 11) if the test allocator cannot be passed this way; the function names above stay.

- [ ] **Step 1: Failing tests** in `vmarray_storage_test.zig`, the storage instantiated over `std.testing.allocator`, bodies as plain stack values (no VM needed except for the throw-free paths):
  - `"the kind table matches the C header"`: for each entry, `@intFromEnum(kind)` equals the `c.MVM_ARRAY_*` constant, `elem_size == @sizeOf(Elem)`, and `@offsetOf`/`@sizeOf` of `c.MVMArrayBody`, `c.MVMArray`, `c.MVMArrayREPRData` equal the values a C probe gives (extend `src/zig/test/layout_probe.c` with `moar_probe_sizeof_array_body` and the offsets of `elems`, `start`, `ssize`, `slots`).
  - `"growth follows the C policy"`: from empty, `setSize` to 1, 8, 9, 17, 8191, 8192, 8193, 20000 in turn; after each call `ssize` equals the value computed by a test-local transcription of the C's two formulas (`ssize < 8192`: double, at least `n`, at least 8; otherwise `(n + 0x1000) & ~0xfff`); new slots are zero.
  - `"growth with start > 0 shifts back before reallocating"`: body with `start = 5`, `elems = 3`, `ssize = 8`; `setSize(…, 6)` gives `start == 0`, contents preserved, no reallocation (`slots.any` unchanged); `setSize(…, 9)` reallocates.
  - `"shrinking zeroes the dropped slots and keeps ssize"`.
  - `"copyTo copies the live range into storage of exactly elems slots; an empty source leaves slots null"`.
  - `"an empty array has no storage and frees nothing"`: `free` on a zeroed body is a no-op; `alloc(0, 8) == null`.
  - Review Focus 1, `"an adopted buffer can be grown and freed"`: the test allocates `n * elem_size` bytes itself at `slot_alignment` from the testing allocator, stores it in `slots.any` with `ssize = n`, `elems = n`, `start = 0` (and a second case with `start = 2`, `elems = n - 2`), then `setSize` beyond `ssize` and `free`; the testing allocator reports no leak and no size mismatch. A third case models each distinct adoption shape `va-adoption-audit.md` lists.
  - `"every kind round-trips through its slots view"`: for each kind via `inline for (kinds)`, write and read the kind's extreme values through `slots(k, body)`.
  Expected: fails to compile.
- [ ] **Step 2: Implement `kinds.zig` and `storage.zig`.** No per-kind `switch` written by hand anywhere: `dispatch` generates it with `inline for`/`inline else` over `kinds`. All slot memory is requested as bytes at `slot_alignment` with length `ssize * elem_size`. Growth calls the allocator's `realloc`/`remap` path where the C calls `MVM_realloc` and `alloc` where it calls `MVM_malloc`; the growth function is `noinline` (it is the slow path; spec 8). On allocator failure, panic as `MVM_malloc` does (check `moar.zig`'s `mvmAlloc` and keep one behaviour).
- [ ] **Step 3: Verify.** `zig build unit-test` passes with no leak report; `zig fmt --check` clean; `grep -n 'MVM_malloc\|MVM_realloc\|MVM_free\|MVM_calloc' src/zig/6model/reprs -r` prints nothing.
- [ ] **Step 4: Commit.**

### Task 6: The element operations, the mark and the heap-snapshot hook

**Files:**
- Create: `src/zig/6model/reprs/vmarray/elements.zig`, `src/zig/6model/reprs/vmarray/mark.zig`, `src/zig/6model/test/vmarray_elements_test.zig`
- Modify: `src/zig/6model/repr_test.zig`

**Interfaces:**
- Consumes: `kinds.dispatch`, `kinds.slots`, `kinds.kinds`, `storage.Storage(Source)`, `gc/worklist.zig` (the presize and the two no-check add functions), `moar.root`.
- Produces, in `elements.zig`, generic over `comptime S: type` (a `Storage` instantiation), one function per vtable slot with the field's exact C signature and calling convention: `atPos`, `bindPos`, `setElems`, `push`, `pop`, `unshift`, `shift`, `aslice`, `asplice`, `atPosMultidim`, `bindPosMultidim`, `dimensions`, `setDimensions`, `getElemStorageSpec`, `posAsAtomic`, `posAsAtomicMultidim`, `writeBuf`, `readBuf`, `elems`, `getStorageSpec`, `copyTo`, `gcFree`, `unmanagedSize`; and the per-kind entry points `atPosKind(comptime k)`, `bindPosKind(comptime k)` from which Task 7 takes `MVM_VMArray_at_pos_s/_i/_u/_n/_o` and the two JIT fast functions.
- Produces, in `mark.zig`: `gcMark`, `describeRefs`, `gcMarkReprData` with the fields' C signatures.

- [ ] **Step 1: Failing tests** in `vmarray_elements_test.zig`, on a booted VM (pattern of `src/zig/gc/test/small_test.zig`: `MVM_vm_create_instance`, roots through `moar.rootN`), calling the Zig functions directly on arrays the linked library allocated (`MVM_repr_alloc_init(tc, instance.boot_types.BOOTArray)`, `BOOTIntArray`, `BOOTNumArray`, `BOOTStrArray`, and typed arrays composed in the test for the sized kinds), with `S` over `moar.mvm_allocator` so the library can free what the Zig code allocated. Only non-throwing paths (spec 7.1):
  - one test per operation, each run over every kind with `inline for (kinds.kinds)`: push then pop returns the value; unshift then shift; `bindPos` beyond `elems` grows and zero-fills the gap; `atPos` past `elems` gives the kind's null or zero; negative index within range resolves from the end; `setElems` up and down; `aslice`; `asplice` insert, delete, replace, from another kind where the C converts, from itself with overlap (Review Focus 3); `writeBuf`/`readBuf` for the integer kinds.
  - Review Focus 2: for each integer kind bind its extreme and out-of-range values through a wider register and read back; expected values written as the C's rule (truncate to the element width on bind; sign- or zero-extend on read by the kind's signedness).
  - `"an object bind into a gen2 array triggers the write barrier"`: array allocated with `MVM_gc_allocate_gen2_default_set`, value in the nursery; after `bindPos`, `view.flags2(array).in_gen2_root_list`.
  - Review Focus 4, `"a collection marks exactly the live range"`: an object array and a string array, 10 pushes, 3 shifts, 2 unshifts (so `start > 0`), every element a fresh nursery object; `c.MVM_gc_enter_from_allocator(tc)`; every live element has moved and reads back intact through the updated slots; a second array with `elems == 0` and non-null slots survives.
  - `"gcMark presizes and adds in index order"`: a worklist created by hand (`c.MVM_gc_worklist_create`), `gcMark` on a 5-element object array; the worklist holds the 5 slot addresses in order; on an int array it holds nothing.
  - `"describeRefs reports each object and string element with its index"` against a heap-snapshot state, or, if a state cannot be built in a unit test, this is left to Task 7's whole-run check and the ledger says so.
  Expected: fails to compile.
- [ ] **Step 2: Implement.** Each operation is one generic function over the kind, reached through `kinds.dispatch`; what differs per kind comes from the `KindInfo` entry (register member, accepted register kinds, `holds_refs` for the barrier and the mark). Each row of `va-kind-differences.md` is implemented as a comptime branch on the kind with a comment citing the row. Throws use `c.MVM_exception_throw_adhoc` with the C's format strings copied exactly. `enter_single_user`/`exit_single_user` are comptime-empty at `c.MVM_ARRAY_CONC_DEBUG == 0`. Rooting where the C uses `MVMROOT`, with `moar.root`.
- [ ] **Step 3: Verify.** `zig build unit-test` passes; `zig build unit-test -Dgc-debug=1` passes; `zig fmt --check` clean.
- [ ] **Step 4: Commit.**

### Task 7: Serialization, compose, spesh and JIT hooks; the array goes Zig

**Files:**
- Create: `src/zig/6model/reprs/vmarray/serial.zig`, `src/zig/6model/reprs/vmarray/spesh.zig`, `src/zig/6model/reprs/VMArray.zig`, `src/zig/6model/test/vmarray_serial_test.zig`
- Modify: `build/sources.list` (the line `src/zig/6model/reprs/VMArray.zig: src/6model/reprs/VMArray.c` under `[zig-reprs]`), `src/zig/root.zig` (`_ = @import("6model/reprs/VMArray.zig");` inside the `zig_reprs` block), `src/zig/6model/repr_test.zig`
- Create: `traces/llm/bench/va-switch-on.md`

**Interfaces:**
- Consumes: everything from Tasks 4 to 6; `tools/bench/repr/diff.sh`; `va-c-base`.
- Produces, in `serial.zig` (generic over `S`): `serialize`, `deserialize`, `serializeReprData`, `deserializeReprData`, `deserializeStableSize`, `compose`, `specToReprData`, `typeObjectFor`. In `spesh.zig`: `spesh` (the `elems` rewrite) and `findFastImplForJit`.
- Produces, in `VMArray.zig`: `const allocator: std.mem.Allocator = moar.mvm_allocator;` (the one declaration of spec 5.4); the REPR struct handed to `repr.Ops`; the static table; and the exports with the header's exact names: `MVMArray_initialize`, `MVM_VMArray_at_pos`, `MVM_VMArray_at_pos_s`, `_i`, `_u`, `_n`, `_o`, `MVM_VMArray_bind_pos`, `MVM_VMArray_push`, `MVM_VMArray_find_fast_impl_for_jit`. `allocate` is `&c.MVM_gc_allocate_object` and `initialize` is left undeclared (`serialization.c` relies on both).
- Produces: prefix `va-n-base`.

- [ ] **Step 1: Failing tests** in `vmarray_serial_test.zig` (non-throwing; the reader and writer driven as `src/6model/serialization.c` drives them, or, where a reader cannot be built in a unit test, by serializing through the library and deserializing through the Zig function on the resulting buffer):
  - `"specToReprData maps each storage spec to the C's slot type and element size"`: a table of (boxed primitive, bits, is_unsigned) → (`slot_type`, `elem_size`) written out from `spec_to_repr_data` in the C, all rows.
  - Review Focus 5, `"an empty array deserialized has no storage and then behaves as a fresh one"`: for every kind, deserialize zero elements; `slots.any == null`, `ssize == 0`; then push, unshift, `setElems(3)`, `copyTo` each give the same body state as on a freshly allocated array.
  - `"typeObjectFor gives an object array type"`: `slot_type == MVM_ARRAY_OBJ`, `elem_size == 8`, `elem_type == null`, `st.size == @sizeOf(c.MVMArray)`.
  Expected: fails to compile.
- [ ] **Step 2: Implement `serial.zig` and `spesh.zig`.** Serialization writes and reads the same sequence of `MVM_serialization_write_*`/`read_*` calls per kind as the C (the per-kind call comes from the kind table: add the reader and writer functions to `KindInfo` if that keeps it in one place). `spesh` emits the same instruction and operands (`offsetof(MVMArray, body.elems)` as `@offsetOf`). `findFastImplForJit` returns the instantiations for the same (op, kind) pairs as the C and null otherwise.
- [ ] **Step 3: Write `VMArray.zig`,** add the sources.list line and the root import. `zig build unit-test` passes with the default options (now the Zig array) and with `-Dzig-reprs=false`; the vtable test of Task 4 passes on both (the Zig table has the C table's shape).
- [ ] **Step 4: Build `va-n-base`** (`zig build install --prefix /tmp/claude-1000/va-n-base`), and check: export lists of `va-n-base` and `va-c-base` are equal (2,850); `nm -D` shows the ten array symbols defined; `/tmp/claude-1000/va-n-base/bin/moar --version` runs.
- [ ] **Step 5: Whole-run checks, recorded in `va-switch-on.md`.**
  - `tools/bench/repr/diff.sh --base=/tmp/claude-1000/va-c-base --head=/tmp/claude-1000/va-n-base --out=<workspace>/diff-1` exits 0.
  - Serialization across builds: `vmarray-serial.nqp` under each prefix gives identical hex; each side `--read`s the other's output and prints identical contents.
  - nqp `make test` in `<MoarVM>/..` with `LD_LIBRARY_PATH=/tmp/claude-1000/va-n-base/lib`: same verdicts as with `va-c-base`.
  - A heap snapshot: `LD_LIBRARY_PATH=<P>/lib <rakudo>/rakudo-m --profile=heap --profile-filename=<out> -e 'my @a = 1..1000; my int @b = 1..1000; say @a.elems + @b.elems'` completes on both sides (the `describeRefs` whole-run check).
  Any difference: stop, find the cause, fix it in the Zig, never in the program or the record.
- [ ] **Step 6: Commit** (code; then traces and the pointer).

### Task 8: Evidence, gate, paper check and docs

**Files:**
- Create: `traces/llm/bench/va-oracle.md`, `va-suites.md`, `va-spectest.txt`, `va-crc-ab.md`, `va-cleanup.md`, `va-mechanism-check.md`, the drivers `va-oracle-driver.sh`, `va-crc-ab-driver.sh`, `va-spectest-driver.sh`, `va-maketest-driver.sh` (copies of the `ngc-` drivers with the prefixes changed), raw data beside them
- Modify: `docs/zig-build.md` (a section on the REPR mechanism: how a REPR declares itself, what the builder fills in, how to add a kind, how to change the allocator, the `-Dzig-reprs` switch), `tools/bench/repr/README.md`
- Modify: the spec (`Errata`, if anything was built differently) and this plan (`Outcome`)

**Interfaces:**
- Consumes: all prefixes; every earlier record.

- [ ] **Step 1: Build `va-n-oracle` and `va-n-stress`;** append to `va-prefixes.md`. Rebuild `va-n-base` if the tip moved since Task 7.
- [ ] **Step 2: The collector's oracle.** Group a, 8 cells (`crc-sequential.raku` at 10,000 and 100,000, plain and `--bad-packages`, tiers 1 and 2), base `va-c-oracle`, head `va-n-oracle`: 8 of 8 exit 0. Record in `va-oracle.md`.
- [ ] **Step 3: Suites.** `zig build test` and `zig build unit-test` on the tip, with and without `-Dzig-reprs=false`; nqp `make test` and rakudo `make test` under each of `va-c-base`, `va-n-base`; rakudo `make test` and `crc-getter.raku --volume=100000` under each of the stress prefixes. Same lists of names and verdicts per pair. Record in `va-suites.md`.
- [ ] **Step 4: Spectest A/B.** Six runs, order base head head base base head, control `va-c-base`, head `va-n-base`. Wall and peak RSS ratio of medians, the control's min-max, the list of failures per run. A file that fails on one side only is re-run alone 20 times on both sides and classified. Record in `va-spectest.txt`.
- [ ] **Step 5: crc-getter A/B.** `tools/bench/gc/ab.sh --base=/tmp/claude-1000/va-c-base/lib --head=/tmp/claude-1000/va-n-base/lib --rounds=7 --runs=5 --volume=100000 --out=…`, plain and `--bad-packages`. Report head/control wall and RSS beside the control's spread. A reading outside the spread: one re-run of that setting, both reported.
- [ ] **Step 6: If a gate reading misses,** stop and report before changing code; with the controller's ruling, build `va-c-syms` and `va-n-syms` (`-Dstrip=false`), run `tools/bench/gc/profile.sh --record` on both, and compare the sizes (`nm -S`) and call shapes (`objdump -d`) of the array's `at_pos`, `bind_pos`, `push`, growth and the two JIT fast functions between the builds.
- [ ] **Step 7: Cleanup.** `tools/bench/gc/cleanup.sh --prefix=<P> --runs=20` on `va-c-base` and `va-n-base`, and with `--stress` on the two stress prefixes; all runs pass. Record in `va-cleanup.md`.
- [ ] **Step 8: The paper check** (`va-mechanism-check.md`, spec 5.5): what `P6int` and one REPR with reference fields in its body would declare for `repr.Ops`, written as the Zig struct each would be (declarations only, no bodies), and a verdict: nothing in `repr.zig` must change, or the list of changes. A small change is made now with its test; a large one is recorded as the next campaign's first item.
- [ ] **Step 9: Docs and outcome.** The `docs/zig-build.md` section; this plan's Outcome table (each gate, its number, pass or miss); the spec's Errata.
- [ ] **Step 10: Commit** (traces, then MoarVM).

### Task 9: Final whole-branch review and hand-back (controller)

- [ ] **Step 1: Whole-branch review** (Opus) of `zig-hash-engine..zig-vmarray` and the traces range, against the spec: the constraints above, the anti-goals of spec 2, every record's arithmetic.
- [ ] **Step 2: The comprehension check** (Opus, a fresh agent given only `src/zig/6model/repr.zig` and `src/zig/6model/reprs/**`, no spec, plan or C file): for each comptime construct, write what it produces. The controller compares each answer with the code's actual output; a wrong or missing answer is a documentation finding.
- [ ] **Step 3: Fix wave** for Critical and Important findings and the documentation findings; scoped re-review.
- [ ] **Step 4: Preserve** the ledger and the review as `traces/llm/bench/va-ledger.md` and `va-final-review.md`; report to the user with the Outcome table. No merge, no push.

## Outcome

(filled at Task 8, 2026-11-17. Prefixes: all six `va-{c,n}-{base,oracle,stress}` built at MoarVM 472cf7e92, the
last commit that changes libmoar; evidence taken at bea13d101 (a test-only commit after it). Records in
`traces/llm/bench/va-*`.)

| gate | result | pass |
|---|---|---|
| differential program, head vs control | `diff.sh` exit 3: 390 differing lines over the programs and settings, all on the 195 listed undefined self-splice lines, all 390 equal to the memmove model (none accepted unchecked); everything else byte-identical, every output equal to Task 7's (`va-differential-final.md`) | recorded outcome, to the user (below); not a pass or a failure by the Task 2 ruling |
| serialization bytes, both directions | identical bytes for the 65 cases in both settings; each side reads the other's output as the writer does (same run) | pass |
| collector oracle, 8 cells | 8 of 8 exit 0, raw logs byte-identical (`va-oracle.md`) | pass |
| exports equal | 2,850 (base) and 2,852 (gc-debug) names, c = n in each of the three pairs (`va-prefixes.md`) | pass |
| unit tests, both switch settings | `unit-test` 93/93 steps, 227/239 passed, 12 skipped, both settings; `test` 107/107 both (`va-suites.md` 1) | pass |
| suites: same names and verdicts | nqp make test PASS both; rakudo make test base and stress: identical per-file lists, the one pre-existing failure (02-simple-args.t 17-18) on all four; stress crc-getter 6 of 6 exit 0; heap snapshot both sides (`va-suites.md`) | pass |
| spectest wall / RSS, head/control | wall 1.003 (head 288.08 s in the control's 280.93-290.00), RSS 0.994 (in range); zero failures in six runs (`va-spectest.txt`) | pass |
| crc-getter plain wall / RSS | wall 0.993 (spread 0.029, in range), RSS 1.000 (spread 0.025, in range) (`va-crc-ab.md`) | pass |
| crc-getter bad-packages wall / RSS | first: wall 0.999 in range, **RSS 1.016 outside the range** (348,584 kB vs the control's 338,636-346,640); the one re-run: wall 0.995, RSS 1.011, both in range | pass after the allowed re-run (both reported) |
| cleanup, plain and stress | base 120 of 120; **stress `--stress` 116 of 120**: `blocked.nqp` segfaults after `main returning` in global destruction, 2 of 20 on the C control and 2 of 20 on the Zig array, at the same code offsets (`va-cleanup.md`) | **miss, on both sides alike**; reported (BLOCKED by ruling 9) |

Also measured: the JIT's two direct functions reach their "Index out of bounds" throws under `vmarray-devirt.nqp`
with spesh, as the C's do (breakpoints on an unstripped Zig build, `va-suites.md` section 5). The paper check
(`va-mechanism-check.md`): P6int and MVMCode need nothing new from `repr.zig`; the one gap the 47 C tables showed
(an explicit NULL in a defaulted slot) is closed with a test. Ruling 4's defensive NULL test in `kinds.slots` stays:
the wall readings (spectest 1.003, crc-getter 0.993-0.999) show nothing to attribute to it.

### For the user (decisions and reports; nothing here was acted on)

1. **The differential's exit 3 needs a decision.** The Zig array copies overlapping ranges of a splice of an array
   from itself with memmove semantics, where the C uses `memcpy` (undefined for overlapping ranges) for the eleven
   memcpy kinds; it differs from the C exactly on the 195 listed lines (176 diff-nqp, 19 diff-raku, per setting) and
   equals the memmove model on every one. Accept memmove there, or replicate the C's `memcpy` behaviour (which is
   undefined, so "replicate" means a specific copy order chosen to match this build's libc).
2. **C bugs found and kept** (candidates for upstream reports). From Task 2 (`va-differential.md` section 6): growth
   to 2**64 - 4096 or more on an array with 8,192+ slots wraps to a 0-byte realloc and a crash; a size at or just
   under the limit panics in malloc (the check is `>`); a splice from a non-empty non-VMArray dereferences NULL REPR
   data; a splice copying into or out of a kind without storage reaches `abort()`; cross-kind splices between
   reference and numeric kinds reinterpret bits; growing an OBJ/STR array back over a slot a rejected `pop` left, or a
   self-splice at offset 0 with `start > 0`, resurrects pointers the collector stopped tracking; a `read_buf` the
   bounds check passes can read past the storage; `writeint` on a recomposed array without storage writes into the
   old storage. From Task 3 (`va-adoption-audit.md` section 3 and its report): `normalize.c:90` sets `ssize` in bytes,
   not elements (about 4x); `procops.c` does not check `buf_type` (a wider element type overstates `ssize`/`elems`);
   `normalize.c:200` leaks the old slots; `ops.c:1910`'s append ignores `start` and the element size (and truncates
   `elems` to 32 bits); a rejected `unshift` after a `shift` resurrects a pointer; a recompose ignores an object
   element type.
3. **One deliberate pointer-value difference:** for the six kinds without storage the C sometimes holds
   `MVM_malloc(0)` where the Zig holds NULL (`va-kind-differences.md` section 3); only the pointer value differs.
4. **Pre-existing, outside this campaign:** under `-Doptimize=ReleaseSafe` every VM-booting unit test aborts with
   "cast causes pointer to be null" (shim-test, hash-str-test, gc-test, repr-test's VM tests): some Zig code on the VM
   boot path casts a null C pointer to a non-optional pointer, hidden at ReleaseFast. A follow-up candidate.
5. **The allocator constraint for the planned nursery-lifetime allocator spike:** the lengths given back to the
   array's allocator cannot be trusted at the outside adoption sites, so a length-sensitive allocator needs those
   sites changed first (`va-adoption-audit.md` section 5).
6. **Housekeeping:** about ten `repr-test` core dumps from Task 6's early fork-test runs are in systemd-coredump, and
   four `moar` cores from this task's stress cleanup runs (`va-cleanup.md`); none was deleted.
7. **The stress cleanup miss** (gate table): `cleanup.sh --stress` on the stress prefixes fails 2 of 60 on both the C
   control and the Zig array, the same program and crash site, in global destruction with a background thread still
   running. Not caused by the array; whether it is new since campaign 7 (which passed 60 of 60 on its stress prefix)
   is not established. The controller rules on it.
