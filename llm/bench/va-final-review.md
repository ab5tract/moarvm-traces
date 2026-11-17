# va final review: the whole-branch review, the comprehension check and the fix-wave re-review

Three reports by Opus reviewers at Task 9 of the plan `llm/plans/2026-11-16-zig-vmarray-repr.md`, verbatim. The whole-branch review read 0a13b95be..5f8cfedd4 (traces 2ea787e..422e7ba); the comprehension check read only `src/zig/6model/repr.zig` and `src/zig/6model/reprs/**` at 5f8cfedd4; the re-review read the fix wave 5f8cfedd4..2b27377eb (traces 422e7ba..85f1d74). The controller's rulings on them are in `va-ledger.md`.

---

# 1. Whole-branch review

## Final whole-branch review: zig-vmarray 0a13b95be..5f8cfedd4 (traces 2ea787e..422e7ba)

I read all of the library code: `repr.zig`, `VMArray.zig`, and `kinds`, `storage`, `elements`, `mark`, `serial` and `spesh` under `vmarray/`. I compared each against VMArray.c and VMArray.h function by function. I also read the moar.zig additions, the build and Configure.pl changes, the four test files (the elements and storage tests in part), diff.sh, the docs section, and every va-* record named in the Outcome.

Checks I re-ran myself, all read-only:
- **Spectest:** recomputed every median, ratio and spread from va-spectest-raw/*.time.
- **crc-getter:** recomputed all three summary.md tables (plain, bad, rerun).
- **Exports:** `nm -D` on all six prefixes. The lists are equal in each pair: 2,850 for base, 2,852 for oracle and stress.
- **Build commit:** all six libmoar.so carry `2026.09-327-g472cf7e92`.
- **Core-dump offsets:** `nm` on both stress libraries gives `MVM_interp_run` +0x16aa0 / +0x102 on both builds.
- **Library commits:** nothing after 472cf7e92 touches the library.
- **Commit trailers:** all 21 commits have one.

Nothing was built or run.

### Strengths
- **`repr.Ops` is sound and honest.** It walks `@typeInfo(c.MVMREPROps)`, so the only hand-written list is `default_functions`. That list is checked at compile time against each field's type (repr.zig:107-109).
  - `fits` checks the calling convention exactly.
  - `declError` gives errors with the full path (`pos_funcs.pussh`).
  - The vtable dump test, the P6int default-macro test and the paper check together pin the table shape against real C tables.
- **`kinds.dispatch` is the only switch on the slot type.**
  - Its `otherwise` argument makes each C `default:` arm (throw, abort, nothing, or a custom message) visible at the call site.
  - The kind table is checked against the header's union member types, the register members and the serializer names (kinds.zig:172-189).
- **Fault ordering is consistent across files.** The rule is that a NULL fault happens no earlier than the C's first read through that pointer, in the same function. I checked it in `atPos`, `push`, `pop`, `unshift`, `copyElements` (936-958 order, target before source in `slotTypeToKind`), `readBuf`, `writeBuf`, `gcMark`, `describeRefs`, `deserialize` and `findFastImplForJit`. Every one matches the C.
- **Integer semantics are right.** asplice's mixed signed/unsigned arithmetic is wrapped at each C conversion. Widening and narrowing go by type class. The 72 register-kind texts are generated and also pinned literally in a test. The C behaviours that look like accidents are kept: a rejected pop has already decremented elems, a rejected unshift has already decremented start, `write_buf` accepts the num kinds.
- **GC discipline is right.**
  - Every barrier comes before its store (`assignRef`) on bind, push, unshift, deserialize and compose.
  - `typeObjectFor` roots the STable.
  - The mark presizes, then adds in index order over `[start, start+elems)` only. The oracle's raw logs are byte-identical.
- **The JIT and spesh contracts hold.** The two fast functions match graph.c's 5-argument call shapes (graph.c:809-814, 875-880). The (op, register kind, slot kind) table and both spesh rewrites match the C exactly.
- **Allocator rule:** there is no `MVM_*alloc` or `MVM_free` call under `reprs/`, and a zero length is never requested.
- **The `-Dzig-reprs=false` switch really does restore the C array.** It works through sources.list, the root.zig gate, checkRootImports, and equal export lists.
- **The evidence records are honest about the awkward results.** The RSS reading below the range is stated as such, as is the cleanup miss on both sides. The bad-packages RSS offset is reported rather than hidden.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
1. **Spec §7 item 3's whole-system check was dropped without a record.** The spec says: "As a whole-system check, the builder tries comparing the `.moarvm` files of an nqp build made with each moar… if it does not [repeat], that is recorded."
   - Plan Task 7 Step 5 left it out.
   - No record attempts it. I grepped va-*.md and every task report.
   - Neither the spec's §13 Errata nor the plan's Outcome mentions it.
   - Effect: the per-case serialization evidence (65 cases, byte-identical, cross-read both ways) is strong. But a step the binding spec asks for is missing, and nothing says so.
   - Fix, either of:
     - run it: an nqp build under each libmoar, check that the control repeats itself, then `cmp` the `.moarvm` files;
     - or add an Errata item 16 and an Outcome line saying it was not attempted and why.

#### Minor (Nice to Have)
1. **storage.zig:73, 175, 178, 222, 226 use a plain `*` where the C's `size_t` product wraps.** storage.zig:56 was changed to `*%` at Task 7 for exactly this reason, and elements.zig:42-43 claims the wrapping operators are used throughout. These sites can only overflow in states that already crash (a deserialized garbage count). Still, at ReleaseFast this is undefined behaviour, where the C has a defined wrap. Fix: `*%` (deferred minor 5d).
2. **va-cleanup.md:45 says "nothing in it involves the array", which was not shown.** The crashing frame is interpreted code running during global destruction, on both builds. What the evidence shows is "not caused by the Zig array (the C-array control fails alike)". The same record's earlier BLOCKED verdict paragraph also still stands unmarked above the ruling (deferred minor 8.8).
3. **va-mechanism-check.md:58-69 and :118.** The printed P6int struct refers to itself (`pub const serialize = serialize;`, `compose = compose`, `spesh = spesh`) and would not compile. Yet the record says the test declares it "exactly so"; the test actually uses `t`-prefixed stubs (deferred minor 8.3).
4. **docs/zig-build.md, REPRs section:**
   - The `declError` paragraph omits `name` and `ID` from the required list (repr.zig:46).
   - "To add a stored kind", step 3: a new *reference* kind needs more than widening `holds_refs`. These places treat a pointer kind as OBJ or STR: elements.zig:219/227 (`.obj` VMNull), :267 (`.pointer` gives the "string" text), :370-373 (`.pointer` gives the STR spec), and serial.zig:174.
   - "Pin the sizes and offsets … as kinds.zig does" overstates. kinds.zig pins member *types*; sizes and offsets are runtime probe tests (vmarray_storage_test.zig:149).
   - Line 912 is past the wrap width (deferred minor 8.10).
5. **kinds.zig:233-234 and 277.** An `Otherwise.throw` message is passed as a printf format, and "must not contain `%`" is only a comment. A one-line comptime check would enforce it.
6. **Test gap: the growth policy (`ssize`, `start`) is checked only against the test's own transcription** (vmarray_storage_test.zig:126-135). The differential does not print `ssize`, so a mistake shared by the transcription and the implementation would pass. (By reading, the current code does match the C.)
   - Fix in the wave: add the literal sequence (deferred minor 5f).
   - Better: under `-Dzig-reprs=false`, drive the library's C operations and `E` on twin arrays and compare `elems`, `start` and `ssize`, as the serialize test already does Zig against C (vmarray_serial_test.zig:316-320).
7. **The Zig array has never run with runtime safety on a booted VM.** The pre-existing ReleaseSafe boot-path abort (Outcome item 4) blocks it. Fixing that cast and running diff.sh against a ReleaseSafe head is the cheapest strong check left; I'd list it as the first follow-up for the user.
8. **The Outcome does not say the Perl build path was never exercised.** The Configure.pl change was accepted without a Perl build (Task 1 ruling). The change mirrors `zig-gc` and the risk is low, but the user should see one line about it under "For the user".
9. **The Outcome's crc bad-packages row reads only "pass after re-run".** In both runs the Zig side's RSS was 1.1-1.6 % above the control's, with head round medians above the control median in 6 of 7 and 5 of 7 rounds. va-crc-ab.md says this; the Outcome row should carry that one sentence too.
10. **`declError` has two cheap gaps.** It gives a raw compiler error when `R` is not a struct; one `@typeInfo` check would fix it (deferred minor 4d; leave the `pub var` case). The untested `declError` branches (mistyped nested slot, non-struct nested table) are cheap comptime tests to add (4b).
11. **Small source tidy-ups.** repr.zig:46, 133, 241, 244, 278, 281, 340, 349 and 352 have lines over 100 columns (8.7). kinds.zig:175 could name the dense-prefix rule (8.9).
12. **Readability:** `entry(...)` takes seven positional arguments (kinds.zig:130-141), and "u64","u64" and `&reg_uint,&reg_int` are hard to tell apart without the signature. A named-field literal would explain itself. The separate comprehension check will show whether it matters.

### Deferred minors triage (every ledger minor: fix now / fix in wave / leave, one line each)
- **T1** `zigReprs` missing (true,false,false) and (false,false,false) cases: **leave**. All three branches are already exercised.
- **T1** build.sh `exit 1` inside a piped subshell: **leave** for this campaign. The prefixes are verified by version string and export list, which I re-checked. Fix it before the script is reused as a template.
- **T1** no hash-bench-exe: **leave**.
- **T2** devirt cannot show which path ran: **resolved** (va-suites.md §5, gdb on va-n-syms).
- **T2** ~50 Raku Blob cases die in Rakudo first: **leave**. The nqp program reaches those paths.
- **T2** hard-coded rakudo path, unquoted `command_of`: **leave** (machine-local tool; `--rakudo` exists).
- **T2** README "five minutes": **resolved**.
- **T2** serial blobs depend on `write_buf`: **leave**. Both sides' bytes are compared, so a `write_buf` difference would show.
- **T2** missing final newline exits 1 silently: **resolved** (c139c3aff).
- **T2** exit 3 accepts any value: **resolved** (memmove model check).
- **T2** README memmove scope: **resolved** (README.md:18).
- **T3** "ssize >= 4": **resolved** (va-adoption-audit.md:83-87).
- **T3** row 22c six-kind target: **resolved** (va-kind-differences.md:79, 151).
- **T3** "(after a recompose)": **resolved**.
- **T3** va-differential.md:145: **resolved**.
- **T4** same-typed default swap untested: **resolved** (repr_ops_test.zig:252).
- **T4** untested `declError` branches: **fix in wave** (Minor 10).
- **T4** `pub const x = null` rejected: **superseded** by 472cf7e92.
- **T4** raw compiler error for non-struct `R` / `pub var`: **fix in wave** for the non-struct check; leave `pub var`.
- **T4** build.zig comment with two "and"s: **leave**.
- **T5** reallocate fallback copies by the stated length: **leave**. Documented at storage.zig:189-193, and mvm_allocator never fails a remap.
- **T5** doc for a received zero-capacity buffer: **leave** (storage.zig:20-35 covers it).
- **T5** NULL vs malloc(0) reaching nativecall: **resolved** (va-kind-differences §3).
- **T5** products not wrapping: **fix in wave** (Minor 1).
- **T5** `narrow()` test checks its own helper: **leave**.
- **T5** literal growth sequence missing: **fix in wave** (Minor 6).
- **T5** shift-back test comment: **leave**.
- **T5** `dispatch` untested with 255: **leave** (12..17 exercise the same `else` arm).
- **T5** `destroyReprData` non-null: **resolved** (serial.zig:294-298).
- **T5** RED compile at load 2.49: **leave** (process note).
- **T6** task-6-green.out empty: **leave**.
- **T6** skip counts unexplained: **resolved** (va-suites §1).
- **T6** elements.zig size: **leave**.
- **T6** fork-test core dumps: **resolved** (round 2).
- **T6** `markArm` NULL-slots path untested: **leave**. I re-checked mark.zig:61-62 against worklist.h:83-96 by reading; reaching it needs a double recompose.
- **T7** items 1-3: **resolved** (bfebdc43d).
- **T7** item 4, load figure: **resolved** (va-switch-on.md:73-76).
- **T7** item 5, heap probe and size difference: **resolved** (va-suites §4).
- **T7** item 6, `no_tc = undefined`: **leave** (non-throwing rows only).
- **T7** item 7, serialize test comment: **resolved** (vmarray_serial_test.zig:311-315).
- **T8** item 3, mechanism-check self-reference: **fix in wave** (Minor 3).
- **T8** item 4, driver environment wording in the report: **leave** (the records do not overclaim).
- **T8** item 5, memmove-model exit code and wording: **leave**.
- **T8** item 6, null-slot test drives the loop by one dump: **leave** (both dumps come from the same field walk).
- **T8** item 7, overlong doc lines: **fix in wave** (trivial).
- **T8** item 8, superseded cleanup paragraph: **fix in wave**, together with Minor 2.
- **T8** item 9, `compileError` hint: **fix in wave** (trivial).
- **T8** item 10, docs line width: **fix in wave** (trivial).

No deferred minor must be fixed before hand-back.

### Rulings I disagree with
None in substance. Two qualifications:
- **Task 8, cleanup ruling.** I agree with "not caused by the Zig array": the same-commit C control fails alike, at the same offsets, which I confirmed with `nm`. But the record goes further than the evidence (Minor 2).
- **Task 1, Configure.pl.** I agree the change stands. Its unexercised status belongs in the user-facing Outcome, not only in the ledger (Minor 8).

### C behaviour reproduced (new items only)
1. **The mark's worklist presize truncates to 32 bits** (VMArray.c:83 and :97 with worklist.c:24-27). `VMArray_gc_mark` passes `elems` (MVMuint64) as the `MVMint32` presize count, then adds `elems` items with the no-check adds. For an OBJ or STR array with 2^31 or more elements (16 GiB of slots), the worklist ends up undersized and the adds write past `worklist->list`, which is a heap overflow; `items` (MVMuint32) also wraps at 2^32. Zig reproduces it at mark.zig:60. Found by reading; not reachable on this machine.
2. **`write_buf` and `read_buf` bounds arithmetic wraps** (VMArray.c:1006/1011 and 1026/1034). For 4-byte and 8-byte element kinds, an offset of at least 2^62 (4-byte) or 2^61 (8-byte) makes `offset * elem_size` wrap. The bounds check then passes, and the copy reads or writes inside the storage at the aliased position, instead of growing or throwing. It is reachable through `nqp::writeint` and `nqp::readint` on such an array. Zig reproduces it at elements.zig:766/773 and 791/797. Found by reading, not run.

### Declined to judge
- **Accepting memmove versus replicating the C's memcpy on self-splices:** that is the user's decision, by ruling.
- **Root cause of the `blocked.nqp` crash in global destruction:** outside the array, ruled not to be diagnosed in this campaign.
- **The ReleaseSafe "cast causes pointer to be null" abort:** pre-existing, shown at Task 5 before the Zig array was linked.
- **`serialization.c` `read_array_var` not rooting `result` across `MVM_serialization_read_ref`** (serialization.c:1806-1817): outside the array, and I have not verified that a GC can happen there.
- **The Perl build path's runtime behaviour:** not run, and the review is read-only. Listed in Minor 8.
- **The memmove model's correctness, line by line:** verified independently at Tasks 7 and 8; I did not re-derive it.
- **The bodies of vmarray-diff.nqp, vmarray-diff.raku and vmarray-serial.nqp, case by case:** I read their headers and diff.sh's comparison and exit logic only. The coverage record (va-differential.md §3) was reviewed at Task 2.
- **Raw data beyond the spot checks listed at the top** (oracle logs, make-test lists, stress runs): taken from the records and earlier reviews.
- **Comprehension of the comptime constructs by a new reader:** a separate check is running. I flagged only what I saw (Minor 12).
- **Performance beyond the gates (micro-benchmarks, call shape):** not required, since the gates passed.
- **Windows and non-x86_64:** non-goals.
- **roast's `Needed.rakumod` being left modified:** outside the code, and already put to the user.

### Assessment
**Ready to hand back? With fixes.** The code is a faithful, well-documented port: across every operation, kind and error path I found no fidelity, GC, width or ABI defect, and the evidence holds up when recomputed. Before hand-back, the spec §7.3 whole-system check needs either a run or an Errata and Outcome line. The minors are optional, with Minors 1-3 and 8-9 the most worth the small fix wave.


---

# 2. Comprehension check

## Comptime constructs

Paths are relative to `src/zig/6model/`. Each answer is tagged with its source: **comment**, **code** or **guess**.

### repr.zig

1. **repr.zig:46 `required`**, a comptime array of 6 names: name, ID, type_object_for, allocate, get_storage_spec, compose. Only `declError` reads it, and its order decides which missing name is reported first. **comment+code**

2. **repr.zig:55-98 `default_functions`**, a comptime tuple of 38 pairs `{path, &c.MVM_REPR_DEFAULT_*}`:
   - 5 `attr_funcs`
   - 9 `box_funcs`
   - 18 `pos_funcs`
   - 5 `ass_funcs`
   - `elems`

   A slot whose path is not in this tuple defaults to null. The order of rows does not matter, because lookup is by path. **code**

3. **repr.zig:102 `eval_quota`** = 100_000. It is passed to `@setEvalBranchQuota` at lines 122, 171, 213 and 237. Without it, a walk exceeds the default limit of 1000 backward branches. The comment gives "60 leaf fields"; I cannot check that number from these files. **comment**

4. **repr.zig:107-109, comptime check block.** It produces no code.
   - A path with a typo makes `LeafType` fail on `@FieldType` with the compiler's own "no field" error. There is no custom message.
   - A pointer of the wrong type makes `@as` fail with a coercion error.

   **comment+code** (that the messages are the compiler's builtin ones is a **guess**)

5. **repr.zig:113 `LeafType(comptime path) type`** returns the field type of `c.MVMREPROps` at a path with one dot or none. `"elems"` gives the `elems` field's optional function-pointer type. `"pos_funcs.at_pos"` gives `MVMREPROps_Positional.at_pos`'s type. A path with two dots looks up a nested field literally named `"a.b"`, which fails. **code**

6. **repr.zig:121 `defaultFor(comptime path, comptime F) F`.** The `inline for` keeps at most the one matching entry. It returns that entry's pointer coerced to `F`, or null. It is called only at comptime, from `fill` and from `dumpTable`. **comment+code**

7. **repr.zig:168 `Ops(comptime R) c.MVMREPROps`.** It runs `declError(R)` and calls `@compileError(message)` if there is a problem; otherwise it returns `comptime fill(c.MVMREPROps, R, "")`. There is one instantiation in these files, `Ops(VMArray)` at VMArray.zig:111. That produces a static `MVMREPROps` with these values:

   | Slot | Value |
   |---|---|
   | `type_object_for` | pointer to the function `Ser.typeObjectFor(&table)` generates |
   | `allocate` | `&c.MVM_gc_allocate_object` |
   | `initialize` | null |
   | `copy_to` | `&E.copyTo` |
   | `attr_funcs` | 5 defaults |
   | `box_funcs` | 9 defaults |
   | `pos_funcs` | all 18 VMArray's own (`E.atPos` … `E.readBuf`; `slice` is `E.aslice`, `splice` is `E.asplice`) |
   | `ass_funcs` | 5 defaults |
   | `elems` | `&E.elems` (overrides the default) |
   | `get_storage_spec` | `E.getStorageSpec` |
   | `change_type` | null |
   | `serialize` … `deserialize_stable_size` | the five `Ser.*` functions |
   | `gc_mark` | `mark.gcMark` |
   | `gc_free` | `E.gcFree` |
   | `gc_cleanup` | null |
   | `gc_mark_repr_data` | `mark.gcMarkReprData` |
   | `gc_free_repr_data` | `Ser.gcFreeReprData` |
   | `compose` | `Ser.compose` |
   | `spesh` | `spesh_hooks.spesh` |
   | `name` | `"VMArray".ptr` |
   | `ID` | `c.MVM_REPR_ID_VMArray` |
   | `unmanaged_size` | `E.unmanagedSize` |
   | `describe_refs` | `mark.describeRefs` |

   I took the field order from the C expansion in the comment at 155-162. **comment+code**

8. **repr.zig:181 `fill(comptime T, comptime D, comptime prefix) T`.** It is recursive and loops over `@typeInfo(T).@"struct".field_names` at comptime. For each field:
   - a struct field recurses with `@field(D, field)`, or with `struct {}` if D does not declare it;
   - a declared leaf gets `slotValue`;
   - an undeclared leaf gets `defaultFor`.

   For VMArray it runs once for the top table and once for each of the four nested tables. It assumes `declError` has already passed, so a mistake here is reported by `declError`, not by `fill`. **code**

9. **repr.zig:201 `slotValue(comptime F, comptime D, comptime decl) F`.**
   - A function declaration becomes `&@field(D, decl)`.
   - For `F == [*c]const u8` (the `name` field) the value becomes `@as([:0]const u8, v).ptr`.
   - Anything else (a function pointer, null, an integer) is returned and coerced.

   **comment+code**

10. **repr.zig:212 `declares(comptime D, comptime name) bool`** compares `name` with `@typeInfo(D).@"struct".decl_names` byte by byte. Those names are public declarations only, so private helpers are ignored. If D is not a struct, the `.@"struct"` access fails with a compiler error; no comment covers that case. **comment (public-only) / guess (non-struct)**

11. **repr.zig:234 `declError(comptime R) ?[]const u8`** builds one of four messages at comptime, checking in this order:
    1. `"<R>: unknown REPR function '<path>'"`
    2. `"<R>: '<path>' has the wrong type; the field is <type>"`
    3. `"<R>: missing required '<name>'"`
    4. `"<R>: required '<name>' cannot be null"`

    Two examples:
    - `pub const pos_funcs = struct { pub const pushh = f; };` gives "unknown REPR function 'pos_funcs.pushh'".
    - A hook without `callconv(.c)` gives "'<path>' has the wrong type; the field is ?*const fn (...) callconv(.c) ...".

    **Comment and code disagree.** The doc at 232-233 says "`required '<name>' cannot be null`: the first name of `required` that `R` declares as `null`". In the code, `mistypedDecl` runs before that check. For `name = null` or `ID = null`, `fits` returns false (in the pointer branch the null type is not a pointer; in the int branch it is not an int). So those two report "has the wrong type", and "cannot be null" is reachable only for the four required function slots. **code**

12. **repr.zig:252 `unknownDecl`** is recursive. For each public declaration of D it checks `@hasField(T, decl)`. It descends into a declared nested table only when the declaration is a struct type; anything else there is left to `mistypedDecl`. **comment+code**

13. **repr.zig:265 `Mistyped`** is a comptime-only result struct holding a path and the expected type's text. **code**

14. **repr.zig:271 `mistypedDecl`** walks fields in field order.
    - A nested table that is declared but is not a struct type reports "a struct of <T>'s functions".
    - A leaf failing `fits` reports `@typeName(F)`, or `"[:0]const u8"` for `name`.

    **code**

15. **repr.zig:289 `isStructType(comptime v)`** is true when `v` is a `type` whose info is a struct. **code**

16. **repr.zig:298 `fits(comptime F, comptime v) bool`** is a comptime switch on `@typeInfo(F)`:
    - **optional:** accepts `null`, a function whose `*const V` equals the child type exactly (calling convention included), or a pointer of that type.
    - **pointer:** accepts `[:0]const u8`, or a single-item pointer to a `u8` array with sentinel 0 (a string literal).
    - **int:** accepts an integer for which `std.math.cast(F, v) != null`, so an ID that overflows the field fails.
    - **anything else:** compile error "repr.zig: no rule for a field of type …". This fires if the C header gains a leaf of a new type class.

    **comment+code**

17. **repr.zig:333/340 `dumpOps` → `dumpTable(comptime T, …, comptime prefix, …)`.**
    - `inline for` over the fields of T. It emits one `writer.print` per leaf, or recurses for a nested table. There are 5 instantiations: the top table and the 4 nested types.
    - For function slots, the default is a comptime constant (`comptime defaultFor`), and only the comparison happens at run time. The printed class is `null`, `default` or `own`.
    - `name` prints its string and `ID` its number.
    - Any other field type is a compile error: "no rule to dump a field of type …".

    Nothing in these files calls it. **comment+code**

### reprs/VMArray.zig

18. **:47 `allocator`** is a container-level const, `moar.mvm_allocator`. **code**

19. **:50 `S = storage.Storage(struct { pub fn get() … { return allocator; } })`** is the one storage namespace, bound to `mvm_allocator` with no runtime indirection. **comment+code**

20. **:56 `E = elements.Elements(S)`; :58 `Ser = serial.Serial(S)`** are one instantiation each. **code**

21. **:66 `VMArray`**, the declaration struct that `Ops` reads (see item 7). **code**

22. **:69 `Ser.typeObjectFor(&table)`** generates one `type_object_for` function, closed over the table's address. This is a self-reference: `table` is built from `VMArray`, and `VMArray` uses `&table`. **code**

23. **:111 `table = repr.Ops(VMArray)`** is a static vtable. **code**

24. **:124 `exports`**, a comptime tuple of 10 pairs `{C name, function pointer}`. It contains five instantiations of `E.atPosKind(k).withRoot` for `.str`, `.i64`, `.u64`, `.n64` and `.obj`, plus `spesh_hooks.findFastImplForJit(E)`. **code**

25. **:139 `visibility`** is chosen at comptime from `zig_options.lto`: `.protected` when LTO is on, otherwise `.default`. **code**

26. **:145-151, comptime export block.** It emits 10 `@export`s.
    - If a function's type differs from the type of `c.<name>`, the error is "VMArray.zig: <name> does not have the header's signature".
    - If the header has no such name, `@field(c, …)` fails with the compiler's own error. **guess**

    **comment+code**

### reprs/vmarray/kinds.zig

27. **:36 `Kind`** is an `enum(u8)` of 12 stored kinds with values 0-11: obj, str, i64, i32, i16, i8, n64, n32, u64, u32, u16, u8. **code**

28. **:52 `KindInfo`** is a comptime-only struct, because its field `Elem: type` holds a type. Its fields are kind, Elem, member, reg, reg_kind, reg_kinds, stack_reg_kinds, holds_refs, elem_size, reader and writer. **comment+code**

29. **:103 `entry(kind, comptime E, member, reg, reg_kinds, stack_reg_kinds, wire)`** builds one row.
    - `reader` and `writer` are `"MVM_serialization_read_/write_" ++ wire`.
    - `reg_kind` is `reg_kinds[0]`.
    - `holds_refs` is `kind == .obj or kind == .str`. This is hard-coded, not derived from `Elem`.
    - `elem_size` is `@sizeOf(E)`.

    Only `E` is marked `comptime`. The `++` on `wire` works only because the function is called in a comptime initializer; no comment says so. **code**

30. **:120-124, register-kind sets:**

    | Set | Contents |
    |---|---|
    | `reg_obj` | `{obj}` |
    | `reg_str` | `{str}` |
    | `reg_int` | `{int64}` |
    | `reg_uint` | `{uint64, int64}` |
    | `reg_num` | `{num64}` |

    **code**

31. **:129 `kinds`** is a comptime table of 12 `KindInfo` rows. Two worked rows:
    - **`.i32`:** Elem `MVMint32`, member `"i32"`, reg `"i64"`, reg_kind `int64`, reg_kinds `{int64}`, stack_reg_kinds `{int64}`, holds_refs false, elem_size 4, reader `MVM_serialization_read_int`, writer `MVM_serialization_write_int`.
    - **`.u64`:** Elem `MVMuint64`, member `"u64"`, reg `"u64"`, reg_kind `uint64`, reg_kinds `{uint64, int64}`, stack_reg_kinds `{int64}`, elem_size 8, wire `"int"`.

    The other rows: obj uses `"ref"`, str uses `"str"`, the nums use `"num"` with reg `"n64"`. **code**

32. **:149 `Unstored`; :157 `unstored`** list the 6 kinds without storage: U4, U2, U1 (unsigned) and I4, I2, I1 (signed), with bits 4, 2, 1. **code**

33. **:167 `SlotsUnion = @FieldType(c.MVMArrayBody, "slots")`.** **code**

34. **:172-189, table check block.** Its errors:
    - Wrong row count: "kinds: one entry per Kind".
    - Row index differs from its enum value: "kinds: entries out of value order at <tag>".
    - Union member does not point at `Elem`: "kinds: slots.<m> does not point at <T>". A missing member is a builtin `@FieldType` error instead. **guess**
    - Missing register member: "kinds: MVMRegister has no member <r>".
    - Missing reader or writer: "kinds: no <reader> or <writer>".
    - An unstored constant below 12: "kinds: an unstored kind overlaps a stored one".
    - A duplicate unstored constant: "kinds: an unstored kind twice".

    **code**

35. **:192 `info(comptime k)`** returns `kinds[@backingInt(k)]`. **:197 `Elem(comptime k) type`** returns that row's `Elem`; for example `Elem(.u16)` is `c.MVMuint16`. **comment+code**

36. **:205 `slot_alignment` = 16; :207-211 check block.** If any `Elem` needs more alignment, the error is "slot_alignment below <T>". **code**

37. **:220 `slots(comptime k, body) [*]Elem(k)`** returns `@field(body.slots, member)` and calls `nullDeref` if it is null. There is one instantiation per kind used. **code**

38. **:230 `Otherwise`**, a union with three choices: `throw: [:0]const u8`, `abort`, `nothing`. **code**

39. **:243 `ReturnOf(comptime f) type`** returns `f`'s return type. If the return type depends on the kind (it is null in the function's type info), the error is "dispatch: the return type of f must not depend on the kind". **comment+code**

40. **:271 `dispatch(slot_type, comptime f, args, comptime otherwise)`.** It is an `inline fn`, so its switch is inlined into each caller.
    - The prong `inline 0...kinds.len-1` makes 12 arms, each calling `f(@as(Kind, v), args...)`.
    - In the `else` arm, if `otherwise` is a function it is called as `otherwise(slot_type, args...)`. Otherwise it is coerced to `Otherwise` at comptime:
      - `.throw` calls `MVM_exception_throw_adhoc(args[0], msg)`;
      - `.abort` calls `abort()`;
      - `.nothing` returns, and is a compile error "dispatch: .nothing needs f to return void" if `f` does not return void.
    - The obvious mistakes give builtin compile errors with no custom message. **guess**
      - `f` whose first parameter is not a comptime `Kind`;
      - `args` without the thread context first when using `.throw`;
      - an `otherwise` that is neither a function nor coercible to `Otherwise`.
    - A `%` in a throw message is forbidden but not checked.

    **comment+code**

### reprs/vmarray/storage.zig

41. **:47 `Storage(comptime Source) type`** is a stateless namespace: alloc, free, setSize, grow, reallocate, copyTo, createReprData, destroyReprData. Every allocation goes through `Source.get().rawAlloc/rawFree/rawRemap/create/destroy`.
    - There is one instantiation in these files (VMArray.zig:50). The comment also mentions a test instantiation with `std.testing.allocator`, which these files do not show.
    - A `Source` without `get` fails only where a function that uses it is analysed, with a builtin error. **guess**

    **comment+code**

42. **:173, comptime format string.** It is built with `"…%" ++ c.PRIu64 ++ " elements"`. **code**

43. **:271 `zeroSlots`** calls `dispatch` with `zeroArm` and `Otherwise{ .throw = "MVMArray: Unhandled slot type" }`. **:275 `zeroArm(comptime k)`** has 12 copies. Each memsets `count * elem_size(k)` bytes starting at `slots(k) + from`; the copies differ only in stride and size. **code**

### reprs/vmarray/elements.zig

44. **:103 `reprFn(f: anytype)`** has the return type `@typeInfo(@TypeOf(f)).optional.child`, computed at comptime. There are two instantiations: the type of `pos_funcs.at_pos` (:608) and the type of `elems` (:623 and :643). A non-optional argument fails on `.optional` with a builtin error. **code / guess for the error**

45. **:131/:142 `enterSingleUser` / `exitSingleUser`** use `if (comptime c.MVM_ARRAY_CONC_DEBUG != 0)`. At the flag's value of 0 they emit nothing. The comment says the non-zero branch has never been analysed. **comment+code**

46. **:162 `bindIndex(comptime S, …)`** has one instantiation with E's `S`. **code**

47. **:171 `RegMember(comptime k) type`** returns `@FieldType(MVMRegister, info(k).reg)`; for example `.i32` gives the type of `.i64`. **code**

48. **:180 `toReg(comptime k)`** stores `@as(RegMember(k), e)`, a widening coercion. If a table row named a register member that cannot hold `Elem` (for example reg `"i64"` for `.u64`), this fails with a builtin coercion error. **code / guess for the error**

49. **:190 `fromReg(comptime k)`** is a comptime switch on `Elem`'s type class:
    - int: `@truncate`;
    - float: `@floatCast`;
    - pointer: unchanged;
    - anything else: `comptime unreachable`, a compile error for a new type class.

    **code**

50. **:203 `storeElem`** uses a comptime branch on `holds_refs`: `assignRef` (the write barrier) or a plain store. **:217 `readElem`** uses comptime branches on `k == .obj` (VMNull substitution). **code**

51. **:238 `Op`**, an enum: atpos, bindpos, push, pop, unshift, shift. **code**

52. **:241 `upper(comptime str)`**, a comptime block that returns an upper-case copy. **code**

53. **:264 `kindMessage(comptime op, comptime k)`** is a comptime string with 6×12 possible values; only those reached are built. Examples:
    - `(.atpos, .i32)` gives "MVMArray: atpos I32 expected int register".
    - `(.atpos, .u64)` gives "… atpos U64 expected int register, got %d instead".
    - `(.push, .u8)` gives "MVMArray: push expected int register".
    - `(.atpos, .obj)` gives "MVMArray: atpos expected object register".

    Any pointer kind other than obj is worded "string". A non-pointer, non-int, non-float `Elem` hits `unreachable`, a compile error. **comment+code**

54. **:282 `checkKind(comptime op, comptime k, …)`** uses `inline for` to emit one comparison per accepted register kind: 1, or 2 for unsigned kinds on atpos and bindpos. A comptime branch passes the register kind as `%d` only for (atpos, u64). **comment+code**

55. **:302 `Arm(comptime op) type`** is a struct with three generic functions, `read`, `store` and `load`. The combinations used are `Arm(.atpos).read`, `Arm(.bindpos|.push|.unshift).store` and `Arm(.pop|.shift).load`. That is 6 combinations × 12 kinds = 72 arm functions, generated by `dispatch`. Combinations that are never referenced are not generated. **code** (that unreferenced ones are not generated is a **guess** from Zig's lazy analysis)

56. **:325 `unhandled`**, a comptime `Otherwise` value. **:329 `unhandledAtPos`** is the function form of `otherwise`. **code**

57. **:339 `slotTypeToKind`** calls `dispatch(…, ownRegKind, .{}, .abort)`. **:343 `ownRegKind(comptime k)`** has 12 copies, each returning the constant `reg_kind`. **code**

58. **:359 `elemSpec(comptime k)`** has 12 copies. OBJ returns `reference_elem_spec`. The others are chosen by a comptime switch on type class (STR, signed, unsigned, float), with `comptime unreachable` for anything else. **code**

59. **:417-420, comptime assert that `@sizeOf(AO_t)` is 4 or 8.** On failure, `std.debug.assert` at comptime gives a generic "reached unreachable" error. **guess for the message**

60. **:426 `atomicArm(comptime k)`** has 12 copies. Where `Elem` is an integer whose size equals AO_t's (I64 and U64 on x86-64), the copy returns a slot pointer. Every other copy calls `notAtomic`, which throws. **comment+code**

61. **:445 `slotFits(comptime T, comptime field, comptime f)`.** A mismatch gives "elements.zig: <field> does not have the C signature <F>". **code**

62. **:455 `Elements(comptime S) type`** is a namespace of 23 C-callconv slot functions, plus `atPosKind` and `bindPosKind`. Its comptime block at :900-926 checks all 23 with `slotFits`, once per instantiation. **code**

63. **:795 `readBuf`** uses `comptime builtin.cpu.arch.endian() == .big` to choose the byte offset. **:792** builds its format string at comptime with `PRIi64`/`PRIu64`. **code**

64. **:856 `atPosKind(comptime k) type`** returns a struct with `withRoot` (the at_pos signature), `jit` (no root) and an inline `read`. A comptime branch checks the slot type, with the C's error texts, only for `.str` and `.obj`. Instantiations: `.str`, `.i64`, `.u64`, `.n64` and `.obj` for the exports, and `.i64`'s `jit` for spesh. **comment+code**

65. **:886 `bindPosKind(comptime k) type`.** For a kind that holds references it is a compile error: "bindPosKind: <k> needs the root for its write barrier". Otherwise it is a struct with `jit`, which does `bindIndex` and then a narrowed plain store. The only instantiation is `.i64`. **code**

### reprs/vmarray/mark.zig

66. **:53 `markArm(comptime k)`** and **:85 `describeArm(comptime k)`** have 12 copies each. Ten copies are empty because of `if (comptime !holds_refs) return`; obj and str do the work. They are reached through `dispatch` with `Otherwise.nothing`. **comment+code**

67. **:102-107, comptime signature check** for `gc_mark`, `describe_refs` and `gc_mark_repr_data`. A mismatch gives "mark.zig: <name> does not have the C signature". **code**

### reprs/vmarray/serial.zig

68. **:55 `Wire(comptime k) type`** is the return type of `@field(c, info(k).reader)`. Per the comment that is `MVMint64` (int), `MVMnum64` (num), `MVMString*` (str) or `MVMObject*` (ref). A generic reader is a compile error: "serial.zig: a generic reader". **comment (concrete types) / code**

69. **:59-64, comptime check.** For each row, the writer's parameter 2 must equal `Wire`. Errors: "serial.zig: <r> and <w> disagree on the value type", or "a generic writer". **code**

70. **:71 `toWire` / :83 `fromWire` (comptime k)** are comptime switches on type class. `fromWire` builds `@Int(.unsigned, bits)` at comptime; for example, `.i8` does `@bitCast(@as(u8, @truncate(@as(u64, @bitCast(v)))))`. Any other class is `comptime unreachable`. **code**

71. **:95 `writeArm` / :103 `readArm` (comptime k)** have 12 copies each. They call the C function chosen by name with `@field(c, info(k).writer|reader)`. `readArm` uses a comptime branch on `holds_refs`. **code**

72. **:119 `setKind(…, comptime k)`** writes `slot_type` and `elem_size` as constants. **code**

73. **:130 `setInt(…, bits, comptime signedness, comptime unsupported)`** has 2 instantiations.
    - The unsigned copy compares `bits` with 64, 32, 16 and 8 (u64, u32, u16, u8 in table order), then 4, 2 and 1 (U4, U2, U1), then throws "MVMArray: Unsupported uint size".
    - The signed copy does the same with i64…i8 and I4…I1, then throws "…Unsupported int size".

    **comment+code**

74. **:151 `setNum`** uses `inline for` to make 2 comparisons, 64 (n64) and 32 (n32), then throws. **code**

75. **:207 `Serial(comptime S) type`**, a namespace with one instantiation. **code**

76. **:310 `typeObjectFor(comptime this_repr)`** returns a function. Each table it is given yields one distinct function; here there is one, for `&table`. **comment+code**

### reprs/vmarray/spesh.zig

77. **:38-39 `array_size_lit`, `elems_offset_lit`** are comptime constants typed `MVMint16`. If a value does not fit, the compile error comes from the integer coercion. **comment+code**

78. **:88-89 `JitAtPos` / `JitBindPos`** are function types. **:94 `FastImpl`** is a struct. **code**

79. **:100 `fastImpls(comptime E) [4]FastImpl`** gives 4 rows: atpos_i/i64, atpos_u/u64, bindpos_i/i64 and bindpos_u/u64. Both the "i" and "u" rows use the `.i64` functions. The typed `at` and `bind` constants act as a signature check, failing with a builtin coercion error. **comment+code**

80. **:117 `findFastImplForJit(comptime E)`** returns one function, whose `inline for` produces 4 `if (op == …)` blocks. Each block returns null unless `kind` equals that row's `reg_kind` (int64, or uint64 for the "u" ops) and the slot type equals the row's kind. **comment+code**

## A. Defining a new REPR

R must declare these as `pub`: `name` (a string), `ID` (an integer that fits), `type_object_for`, `allocate`, `get_storage_spec` and `compose`. Each function must have the field's exact `callconv(.c)` type. **comment+code**

A slot R does not declare gets:
- the `MVM_REPR_DEFAULT_*` function for every attr, box, pos and ass slot, and for `elems`;
- null for every other slot (initialize, copy_to, change_type, the serialization hooks, the GC hooks, spesh, unmanaged_size, describe_refs).

A nested table can be partly declared; its other slots still get defaults. `pub const x = null;` forces null over a default. Private declarations are ignored. **comment+code**

## B. Adding an element kind

These steps are reconstructed from the code; no comment lists them (**code / guess**):
1. Add the union member to the C header's `slots` and give the kind an `MVM_ARRAY_*` value.
2. Add a `Kind` tag at that value.
3. Add the `entry(...)` row at the matching index, with a reader and writer that exist.
4. If it is a reference kind, edit `holds_refs` in `entry`, which is hard-coded to obj and str. Also check `kindMessage`, which words every non-obj pointer kind as "string".
5. `dispatch`, `setInt`, `setNum`, `elemSpec`, `atomicArm` and the marking pick the new kind up automatically, as long as its type class is int, float or pointer. Any other class hits `comptime unreachable` in `fromReg`, `elemSpec`, `toWire` and `fromWire`.

Adding it "at the end":
- A table row out of enum order gives "entries out of value order".
- A tag without a row gives "one entry per Kind".
- Value 12 is U4's (the comment says the unstored kinds are 12-17), so `kinds.len` becomes 13 and "kinds: an unstored kind overlaps a stored one" fires. The unstored constants would have to move.
- `write_buf`/`read_buf` gate on `slot_type < MVM_ARRAY_I64`, which assumes this ordering. **code + guess**

## C. Where slot memory comes from

Memory comes from `Storage(Source).alloc/grow/reallocate/free`, which call `Source.get()`'s raw functions. Source is the anonymous struct in VMArray.zig:50, which returns `allocator = moar.mvm_allocator` (VMArray.zig:47). REPR data also comes from this allocator, through `create`/`destroy`. To change the allocator, change VMArray.zig:47; the comment says so explicitly. **comment+code**

The stated constraint is that the allocator must ignore the length it is given back on `free`, and must not copy by that length on `remap`:
- Outside C code hands the array buffers whose `ssize` is wrong: smaller, about four times larger, or 0 with a non-NULL buffer.
- `gcFree` passes `elem_size` 0, so the length given to free is 0.
- That is also why the code calls `rawFree` rather than `Allocator.free`.
- A length-sensitive allocator needs the adoption sites changed first.
- Buffers must be 16-byte aligned, which matches C malloc.

**comment**

## D. Reading element i when the kind is known only at run time

1. The VM calls `table.pos_funcs.at_pos`, which is `E.atPos` (elements.zig:458).
2. `reprDataOf(st)`, `bodyOf(data)`, then `fromEnd`.
3. `kinds.dispatch(need(repr_data).slot_type, Arm(.atpos).read, .{tc, body, i, value, kind}, unhandledAtPos)`.
4. **The per-kind code is selected here**, at the inlined `switch (slot_type)` with the `inline 0...11` prong (kinds.zig:272-273). Because `dispatch` is an `inline fn`, this switch is compiled into `atPos`.
5. The chosen arm runs `Arm(.atpos).read(k, …)`, then `checkKind(.atpos, k)` (one or two comparisons, throwing `kindMessage` on failure), then `readElem(k)`, then `kinds.slots(k, body)[start + i]`, then `toReg(k)` (the widening).
6. Any other slot type goes to `unhandledAtPos`, which throws with the name from `MVM_reg_get_debug_name`.

The exported `MVM_VMArray_at_pos_{s,i,u,n,o}` and the JIT's `atPosKind(.i64).jit` bypass `dispatch`: the kind is fixed at comptime, and only str and obj check the slot type. **comment+code**

## E. Opaque spots

1. **repr.zig:232-233 vs :240-244.** The "cannot be null" message cannot be produced for `name` or `ID`; they report the wrong-type message instead. The doc should say the message applies only to the four required function slots.
2. **repr.zig:101.** "60 leaf fields" cannot be checked from these files. The comment would need to say where the number comes from, or be dropped.
3. **VMArray.zig:69 ↔ :111.** `table` depends on `VMArray.type_object_for`, which takes `&table`. No comment says why this cycle compiles (taking an address does not need the value). serial.zig:302 only says why the table is a parameter.
4. **kinds.zig:103 `entry`.** Its parameters are not `comptime`, but it uses `++` on them and returns a comptime-only type. A comment should say it is callable only at comptime.
5. **kinds.zig:271 `dispatch`.** The doc does not say what the compiler reports for an arm whose first parameter is wrong, for `.throw` with an empty `args` or with `args[0]` not the thread context, or for an `otherwise` of the wrong type. The "no `%` in the message" rule is not enforced.
6. **kinds.zig:114.** `holds_refs` is hard-coded to obj and str, and `kindMessage` (elements.zig:267) words any non-obj pointer kind as "string". Neither is flagged as something to update when adding a kind. No comment gives the steps for adding a kind (question B).
7. **elements.zig:846-848 vs code.** The comment reads: "Task 7 exports `.str`, `.i64`, `.u64`, `.n64`, `.obj` of them … and `.i64`'s `jit` as `vmarray_at_pos_int64`". No symbol of that name is exported in these files; the function is only returned by `findFastImplForJit` (spesh.zig). The same applies to `vmarray_bind_pos_int64` at :882. "Task 7" and "Task 2 §4/§6" are references I could not follow.
8. **elements.zig:103 `reprFn`, :419 the AO_t assert, storage.zig:47 `Source` without `get`.** None says what compile error results from misuse.
9. **storage.zig:8-10.** The test instantiation with `std.testing.allocator` cannot be seen in these files.
10. **serial.zig:55 `Wire`.** The concrete types depend on the C header and are stated only in a comment.
11. **elements.zig:302 `Arm`.** "Instantiated twelve times" is per op actually used. The doc does not say which of the 18 op/function combinations exist (6 are used), so the total of 72 arms is my inference.

---

# 3. Fix-wave re-review

### Finding Verdicts

**A1 — ADDRESSED.** All five sites the reviewer named now use `*%`, and no plain ` * ` product is left in storage.zig, elements.zig, serial.zig or mark.zig (grep).
- `copyTo`, storage.zig:184 and :188, matches VMArray.c:55-56. There `dest_body->ssize * repr_data->elem_size` and `src_body->start * repr_data->elem_size` are MVMuint64 × size_t, so unsigned and wrapping.
- `grow`'s `len`, storage.zig:173, matches VMArray.c:466-467 (`ssize * repr_data->elem_size`, unsigned). After the budget check (VMArray.c:450-458) this product cannot wrap: the largest value is 2^60×8 = 2^63. So `*%` is faithful and changes nothing reachable.
- `free` (storage.zig:130) and `grow`'s old length (storage.zig:177) are lengths the C never computes. `*%` only stops a Zig-only trap. The old length feeds `reallocate`'s `keep` only if `rawRemap` fails, and `mvm_allocator`'s remap is MVM_realloc, so it does not fail.
- No site was changed where the C is signed.

**A2 — ADDRESSED.** kinds.zig:445-453 adds a comptime `findScalar(... '%')` check with a legible `@compileError`, plus a comment; the `Otherwise.throw` doc was updated (:396-397).
- The check cannot reject current code: all three unit-test builds pass.
- The manual probe is recorded in va-fix-wave-raw/c1/a2-percent-probe.txt and shows the message.
- It would also reject a legitimate `%%`, which is acceptable.

**A3 — ADDRESSED.** repr.zig:253-255 checks `@typeInfo(R) != .@"struct"` before anything else. Before this, `unknownDecl` would have hit `@typeInfo(D).@"struct"` raw. Only struct `R`s are used, and the tests pass. The new repr_ops_test.zig test covers a mistyped nested slot, a non-struct `pos_funcs`, an enum and `u8`. (See Minor 1 on the doc's order.)

**A4 — ADDRESSED.** The doc at repr.zig:243-248 now says only the four function slots can give "cannot be null". A new test pins the null `name`, null `ID` and null `allocate` messages. zig-build.md agrees.

**A5 — ADDRESSED.** `grep "Task [0-9]\|§"` over src/zig/6model/ finds nothing. The new pointers exist:
- va-differential.md sections 4 and 6 hold the cited facts: the U16 9-element growth at :269-270, and the NULL `s_repr_data` and read_buf rows in section 6.
- serial.zig:24 and storage.zig:54 name va-kind-differences.md.

The implementer is right that "row 25" was already followable, through elements.zig:19.

**A6 — ADDRESSED.** elements.zig:858-865 and :895-900 now say what is exported. Checked against source:
- VMArray.zig:134-138 exports only the five `withRoot`s.
- spesh.zig:100-108 `fastImpls`/`findFastImplForJit` hands out the `.i64` `jit`s for `atpos_i`/`atpos_u` and `bindpos_i`/`bindpos_u`.
- VMArray.c:1559 and :1584 are static.

**A7 — ADDRESSED; the implementer's two corrections are right.**
- serial.zig:176 (:174 at base) maps `BP_STR` to `.str` by name. It does not treat every pointer kind as STR. It is still a site a new non-number kind needs, and it is listed that way.
- `copyElements` (elements.zig:597-598) refuses the block copy by the constants `MVM_ARRAY_OBJ`/`MVM_ARRAY_STR`, so a new reference kind would be memmoved past the barrier. The reviewer's list missed it.
- The other sites (`readElem` :217-228, `kindMessage` :267, `elemSpec` :376) are correct.
- The mark, describe, deserialize and bindPosKind paths do follow `holds_refs` (mark.zig:54, :86; serial.zig:110).
- The dense-prefix wording is in the error at kinds.zig:995-998.

**A8 — ADDRESSED.** I compared every row old against new. All twelve are identical in kind, Elem, member, reg, reg_kinds, stack_reg_kinds and wire. That includes u64/u32/u16/u8 = `&reg_uint`/`&reg_int`, and the n32 and i32/i16/i8 `reg` values of "n64" and "i64". `entry` derives the same fields. The comptime-only doc is present.

**A9 — ADDRESSED.** VMArray.zig:480-485 and :507.

**A10 — ADDRESSED.** The six pairs listed at elements.zig:533-538 match the only `Arm(...)` references in code, at elements.zig:469, 479, 499, 517, 543 and 557.

**A11 — ADDRESSED.** repr.zig:101-103.

**A12 — ADDRESSED; the implementer is right about :333.** At 5f8cfedd4 that line is 65 columns; the other nine were 101-123 and are wrapped. No added line in the diff is over 100 columns.

**A13 — ADDRESSED.** I re-derived the hand table from VMArray.c:441-448: 8, 8, 16, 32, 8191, 16382, 16382, 20480. It matches, and it is checked against both the transcription and the storage. The twin test was added.
- Its samples are gen2 objects/strings with index < 32, and no step allocates on the GC heap, so the by-value `A` and cached `body` stay valid.
- It passes on both switch settings.

**A14 — ADDRESSED (the reviewer's line number was wrong).** The file had 393 lines at base; the test is at :211-225. The fix is in the test: `expect(lb.next() == null)`.

**A15 — ADDRESSED.**
- The declError paragraph lists `name` and `ID` and the non-struct case.
- Step 3 lists the same five sites as A7.
- The closing paragraph's references exist: the test at vmarray_storage_test.zig:149 and the probes in `src/zig/test/layout_probe.c`.
- Only the two dispatch code-excerpt lines (:877, :879) are over 100 columns, and they mirror the source.

**A16 — ADDRESSED; the implementer is right about the lines.** va-cleanup.md has 80 lines at 422e7ba, and the paragraph is at :42-53. The sentence was reworded as asked, and a superseded note precedes the paragraph.

**A17 — ADDRESSED.** va-mechanism-check.md's stubs, P6int and MVMCode now match repr_ops_test.zig:377-441 exactly.

**A18 — ADDRESSED. The implementer's corrections to the brief are right, and both new C-bug texts are accurate.**
- **(a) The worklist bug: the implementer's threshold is the right one.** worklist.c:25 adds `MVMuint32 items` and `MVMint32 items`. Both have int rank, so the signed operand converts to unsigned and the sum is mod 2^32. Between 2^31 and 2^32 − items the truncated-then-negative count therefore gives the correct sum, alloc and realloc (`alloc * sizeof`, promoted to size_t). The presize goes short only once items + elems ≥ 2^32. Then `_nocheck` (worklist.h:83-94) writes past the list and `items` wraps. The "2^31 or more" wording was wrong. The line references are correct: VMArray.c:83 and :97, worklist.c:24-27, mark.zig:60.
- **(b) The write_buf/read_buf bug.** At VMArray.c:1006, :1011, :1026 and :1034, `offset * elem_size` is int64 converted to size_t. It wraps from 2^62 (4-byte kinds) and 2^61 (8-byte kinds), and never for 1- and 2-byte kinds. Placement is as written:
  - write_buf: start·es + w with w + count ≤ elems·es, so inside the window.
  - read_buf: within (start+elems)·es of the window start.
- **(c) read_array_var.** It is correctly labelled unverified. serialization.c:1805-1817 indeed leaves `result` unrooted across `read_ref`.
- **(iv) The crc bad-packages sentence.** I checked it against va-crc-ab-raw/bad/summary.md and rerun/bad/summary.md:
  - Head round medians above the control's median of round medians: 6 of 7 in both readings.
  - Round by round: 7 of 7 and 5 of 7.
  - Ratios: 1.016 and 1.011.

  The brief's "6 of 7 and 5 of 7" mixed the two readings; the sentence as written is correct.
- **(i)/(ii).** Items 9 and 10 were added; 6b45869d9 does touch Configure.pl.

**B — ADDRESSED.** build-nqp.sh does `rm -rf` and a fresh `cp -a` of both the prefix and nqp for each build, then Configure and `make clean`.
- make.log shows every stage 1 and stage 2 file compiled, so nothing stale was reused.
- The probe (`/proc/self/maps` via `./nqp-m`) is the same path for all three builds. The side is told apart by the copied libmoar's SHA-256, taken in the same run: f48899c1… for c1 and c2, 97fbb7af… for n1.
- `moar --version` gives 584d21d02 on both sides, so both libraries are the same commit.
- The three sha256.txt files are identical (diff silent), with 45 files each.
- The verdict is worded no stronger than one control repeat and one build per side.
- The Outcome row and spec Errata 16 were added.

**C1 — ADDRESSED.** The c1 logs show 93/93 steps; 230/242 passed (default and `-Dzig-reprs=false`) and 235/242 (`-Dgc-debug=1`); repr-test 54/54 in all three.

**C2 — ADDRESSED.** All four export lists and exports-base.txt have 2,850 names: c = n, and each equals its 472cf7e92 list (cmp silent). builds.tsv shows 584d21d02 on both.

**C3 — ADDRESSED.** diff.log reports "exit 3, 311 s" with 390 lines, 390 equal to the model and 0 unchecked. The 52 entries of outputs.sha256 are identical to va-differential-final-raw/outputs.sha256. The undefined-*, model-* and libmoar.log files are byte-identical.

**C4 — ADDRESSED.** va-fix-wave.md states plainly that the oracle, stress, spectest, crc-getter, suites and heap snapshot were not re-taken. va-prefixes.md has a new fix-wave section. The plan Outcome header has the matching sentence; it omits "heap snapshot" by name, but that evidence sits in the suites row it does name.

### New Breakage in the Fix Diff
- **Minor 1:** repr.zig:227-235. The declError doc says problems are reported "in this order" but lists the non-struct-R message second, after "unknown REPR function". The code checks it first (repr.zig:253).
- **Minor 2:** The comment reflow in elements.zig left ragged fragments. Examples: "Both / REPR data / pointers are loaded first" in the copyElements doc (~:577-579), "`@memmove`, defined where the C's / memcpy is" in the writeBuf doc (~:785-786), and a 96-column line in the bindPosKind doc next to short ones. Cosmetic only.

### Out-of-Scope Observations
- About 90 pre-existing lines over 100 columns remain in vmarray/*.zig. The implementer stated this; it is outside the brief's list.

### Verdict
**Fix wave:** All findings addressed, no new Critical/Important breakage.
