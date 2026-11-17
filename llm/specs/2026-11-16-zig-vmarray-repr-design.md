# The first REPR in Zig: VMArray by a comptime mechanism, with allocator-backed slots: design

Campaign 8 of the MoarVM C-to-Zig migration. Follows the collector's three campaigns (`2026-11-04-zig-gc-port-design.md`, `2026-11-09-zig-native-gc-design.md`, `2026-11-11-gc-call-boundary-design.md`; all of `src/gc` is Zig on `zig-hash-engine` at 4e7e981dd). Author: the controller session, from a brainstorm with the user on 2026-11-16. Status: approved by the user 2026-11-16 ("looks great") after the builder check (its four points settled in 5.2, 5.4 and 7.1).

## 1. Intent

The collector is ported. The next thing the port roadmap names (step-zero spec, Appendix A items 5 and 6; native-GC spec section 2) is the REPRs. The user wants the first REPR in Zig to show what C could not give:

- **no more macros**: what C does with `MVM_REPR_DEFAULT_*` fillers and hand-copied per-kind switches is done by comptime;
- **Zig allocators for the memory hanging off objects**: the storage a REPR owns outside the GC heap comes from a `std.mem.Allocator` the REPR names, not from bare `MVM_malloc`/`MVM_free` calls.

Success, in the user's words, is "the mechanism in place and proven on one REPR". That REPR is VMArray (`src/6model/reprs/VMArray.c`, 1,694 lines). It was chosen over the bigint and the string because it is the only one of the three whose REPR file owns its storage (copy, resize, deserialize, free), no library sits between it and its memory, and it has the most per-kind code for comptime to collapse: 135 `case MVM_ARRAY_*` labels over twelve slot kinds.

A measured win is not required. The numbers must not get worse.

## 2. Goals, non-goals, anti-goals

Goals

1. VMArray implemented in Zig behind the same C symbols and the same struct layouts, selectable at build time against the C file.
2. A comptime mechanism, shaped by what the array needs, with two parts:
   - a function that builds an `MVMREPROps` table from a REPR's declarations and fills every slot the REPR does not declare with the default the C macros give it;
   - one generic body per array operation, parameterised at comptime over the slot kind, in place of the per-kind switch arms.
3. The array's `gc_mark` (and `describe_refs`) derived from the slot kind by the same per-kind machinery: only object and string slots hold references.
4. Every allocation and release of memory the array owns (the slots, the `MVMArrayREPRData`) goes through one `std.mem.Allocator` declared in the REPR's file, backed by `moar.mvm_allocator` (that is, the same `MVM_malloc`/`MVM_realloc`/`MVM_free` as today).
5. Behaviour identical to the C array, shown by the evidence of section 7; wall time and memory not worse, by the gate of section 8.
6. Comptime code that is documented well enough to be predicted (section 6).

Non-goals

- Any other REPR, including `MultiDimArray`, which has its own body and file.
- Encapsulating the body from its C readers. The interpreter, spesh, the JIT (`src/jit/x64/emit.dasc` declares `.type VMARRAY, MVMArray`), the I/O code, the decoder, normalization and the string ops read and write `MVMArrayBody` directly and keep doing so. The user put encapsulation on the back burner until those readers are ported.
- An allocator over GC objects themselves (ruled out 2026-11-02; see the `gc-heap-allocator-and-escape-analysis` note).
- An allocator whose lifetime follows the nursery, or any allocator other than the `MVM_malloc`-backed one. That is a later throwaway spike, after this campaign. This campaign only makes the choice of allocator one declaration.
- Deriving `gc_mark` from the fields of a body struct. That waits for a REPR where it is the natural shape.
- A general framework for all 47 REPRs. The mechanism is built for the array and then checked on paper against two other REPRs (section 5.5), nothing more.
- Any change to the array's growth policy, to error messages, to the serialization format, to which C functions exist or to their signatures.
- The full-Zig build stack; Windows or non-x86_64 targets; a Perl-side switch.

Anti-goals (a failure even if everything passes)

- Opaque comptime. Cleverness is allowed; a reader who cannot tell from the file what a comptime construct emits is a defect.
- A line-by-line translation. A Zig file that carries the 135 switch arms over proves nothing about the mechanism.
- A second definition of the layouts. `MVMArrayBody`, `MVMArray`, `MVMArrayREPRData` and `MVMREPROps` stay defined once, in the C headers.

## 3. Constraints

- Toolchain and build as in Campaign 6: Zig 0.17.1, `zig build install --prefix <P>` (LTO, `-Doptimize=fast`, x86-64-v3), the `translate_c` package, no API the 0.17 release notes deprecate.
- No git worktrees. Work in the main checkout on a new branch `zig-vmarray` off `zig-hash-engine`. Records go in the `traces/` submodule (`traces/llm/bench/`, prefix `va-`), committed there before the MoarVM pointer commit. Nothing is pushed and nothing is merged until the user says.
- Machine: 32 GB, no swap, no OOM daemon. Anything that can grow runs under `systemd-run --user --scope -q -p MemoryMax=…`; kill by PID only; check the load and for another session's benchmark before a long run (see the `machine-memory-and-concurrent-benches` note).
- The build prefixes under `/tmp/claude-1000/` no longer exist (a reboot removed them). The first task rebuilds what it needs by the recipe in that note. Prefix names within one comparison have equal length (the install path is baked into libmoar's config strings).
- Measurement conventions as in Campaigns 4 to 7: interleaved rounds with rotated side order, medians of at least five runs per round, spread as the min and max of round medians, 1-minute load under 2.0 before every run, nothing judged from one run. The spectest recipe is unchanged (`TEST_JOBS=24`, `make -o spectest_update spectest`, roast pinned at fb1d87214, `.precomp` removed before each run).

## 4. The starting point (for the builder)

What exists and is reused:

- `src/zig/moar.zig`: the translated C API as `c`, `mvm_allocator` (a `std.mem.Allocator` over `MVM_malloc`/`MVM_realloc`/`MVM_free`; `remap` is `MVM_realloc`, `resize` is unsupported, `free` ignores the length, alignment at most 16), the rooting helpers `root`/`TempRoot`.
- `build/sources.list` sections `[zig]` and `[zig-gc]`, with lines `<zig file>: <c file>`; `build.zig` options `-Dzig-impl` and `-Dzig-gc`; the root-reference check in `build/zig/zigimpl.zig`; unit-test roots registered in `build.zig` (`shim-test`, `hash-str-test`, `gc-test`), linked against libmoar and able to boot a VM.
- `src/zig/gc/`: `view.zig`, `worklist.zig` and the rest of the collector, including the worklist add functions the array's mark calls.
- `tools/bench/gc/`: `oracle.sh`, `ab.sh` (three-sided), `profile.sh`, `cleanup.sh`, `crc-getter.raku`, `crc-sequential.raku`; `tools/bench/timev.py`.

What VMArray is today:

- Layouts in `src/6model/reprs/VMArray.h`: `MVMArrayBody` (`elems`, `start`, `ssize`, a union of twelve typed slot pointers plus `any`, and an `in_use` word only when `MVM_ARRAY_CONC_DEBUG` is non-zero, which it is not), `MVMArrayREPRData` (`elem_size`, `slot_type`, `elem_type`), eighteen `MVM_ARRAY_*` kind constants of which twelve have storage.
- Exported functions declared in the header: `MVMArray_initialize`, `MVM_VMArray_at_pos`, `MVM_VMArray_at_pos_s/_i/_u/_n/_o`, `MVM_VMArray_bind_pos`, `MVM_VMArray_push`, `MVM_VMArray_find_fast_impl_for_jit`. The last returns pointers to two file-local functions the JIT calls directly.
- The vtable `VMArray_this_repr`: 35 array-specific functions (18 positional, 17 others), `MVM_gc_allocate_object` as the allocate slot (`serialization.c` relies on that and on the `NULL` initialize after it), and three macro groups of defaults (`MVM_REPR_DEFAULT_ATTR_FUNCS`, `_BOX_FUNCS`, `_ASS_FUNCS`).
- A `spesh` hook in the same file that rewrites `elems` on a known array into a direct field read (`offsetof(MVMArray, body.elems)`).
- Storage: slots are allocated in `copy_to`, `set_size_internal` (`MVM_realloc` or `MVM_malloc`) and `deserialize`, and freed in `gc_free`; the REPR data is allocated in `type_object_for` and `deserialize_repr_data` and freed in `gc_free_repr_data`.
- Outside code that hands the array a buffer it allocated itself, or frees or replaces the slots, by writing `slots`, `start` or `ssize` directly: about two dozen sites in `src/io/` (asyncsocket, asyncsocketudp, io, procops), `src/strings/` (normalize, ops) and `src/6model/reprs/Decoder.c`. (A first grep counted 24 in 8 files; two of those are in `MultiDimArray.c` and may be that REPR's own body. The audit of section 5.4 settles the list.)

## 5. The design

### 5.1 Files and the build switch (my call on names and shape)

- `src/zig/6model/repr.zig`: the mechanism of section 5.2, and nothing array-specific.
- `src/zig/6model/reprs/VMArray.zig`: the array.
- `src/zig/6model/test/`: unit tests; a new test root `repr-test` in `build.zig`.
- `build/sources.list` gains a section `[zig-reprs]` with the line `src/zig/6model/reprs/VMArray.zig: src/6model/reprs/VMArray.c`. `zig build -Dzig-reprs=false` (default true) leaves the section out, so `VMArray.c` compiles and the Zig file is not imported. `-Dzig-reprs=true` with `-Dzig-gc=false` or `-Dzig-impl=false` is a build error, as `-Dzig-gc` with `-Dzig-impl=false` already is: the Zig array calls the Zig collector's worklist directly. The Perl build treats the section as part of the Zig groups.
- The exported symbol set of a `-Dzig-reprs=true` build equals that of a `-Dzig-reprs=false` build of the same commit (2,850 at the base). A `-Dzig-reprs=false` build is the control for every comparison in this campaign: same commit, same collector, C array.

### 5.2 The vtable builder

`repr.zig` exposes one comptime function (name the builder's; `Ops(comptime R: type)` in this document) that returns a `c.MVMREPROps` value for a REPR declared as a Zig struct type `R`.

- `R` declares its name, its REPR ID and the functions it implements, under the names of the `MVMREPROps` fields (and of the fields of the nested `attr_funcs`, `box_funcs`, `pos_funcs`, `ass_funcs` tables).
- For every field `R` does not declare, the builder fills in exactly what the C gives a REPR that uses the corresponding `MVM_REPR_DEFAULT_*` macro: the same default function (the C default functions stay in C and are referenced, not reimplemented) or `NULL` where C REPRs write `NULL`.
- A declaration in `R` whose name matches no field is a compile error. So is a function whose signature does not match the field's type. A misspelt hook must not silently become a default.
- A slot may be given as an existing C function instead of a Zig one. The array needs this for the allocate slot (`MVM_gc_allocate_object`), which `serialization.c` compares against.
- The result is a constant with static storage, and `MVMArray_initialize` returns its address, as the C returns `&VMArray_this_repr`.

The check that this is right is mechanical: for the array, every field of the table the builder produces holds the same default as `VMArray_this_repr` wherever the C table holds a default or `NULL`, and a non-null array function wherever the C table holds one. A unit test compares the two tables field by field against a `-Dzig-reprs=false` build's table (how the C table's contents are obtained for the comparison is the builder's call. `VMArray_this_repr` is `static`, and in a `-Dzig-reprs=true` library `MVMArray_initialize` returns the Zig table, so both tables are never in one binary: the comparison is against a dump recorded from the control build, which means the dump's format is settled in the task that builds the mechanism and `repr-test` must run against either library.)

### 5.3 One body per operation, over the slot kind

- A comptime description of the slot kinds: for each of the twelve stored kinds, its `MVM_ARRAY_*` constant, its element type, which union member it uses, which register member carries its value (`o`, `s`, `i64`, `u64`, `n64`), which `kind` values the caller may pass for it, and whether it holds references. This table is the single place a kind's properties are stated. The six kinds without storage (`U4`, `U2`, `U1`, `I4`, `I2`, `I1`) are handled exactly as the C handles them.
- Each array operation (`at_pos`, `bind_pos`, `push`, `pop`, `shift`, `unshift`, `aslice`, `asplice`, `copy_elements`, `zero_slots`, `set_size_internal`, `write_buf`, `read_buf`, `pos_as_atomic`, `serialize`, `deserialize`, `spec_to_repr_data`, `get_elem_storage_spec`, and the rest) is written once as a function generic over the kind, and the runtime dispatch on `repr_data.slot_type` is one generated `switch` that calls the instantiation for each kind.
- `gc_mark` and `describe_refs` come out of the same table: the generated switch has work only in the arms whose kind holds references. The mark visits the slots in index order from `start` and pre-sizes the worklist as the C does, so the collector's per-collection log is unchanged.
- The specialised entry points keep their C names and signatures: `MVM_VMArray_at_pos_s/_i/_u/_n/_o` and the two functions `MVM_VMArray_find_fast_impl_for_jit` returns. Where the C has an entry point specialised for one kind, the Zig exports the instantiation for that kind.
- Semantics the C has per kind are kept per kind, including the ones that look like accidents: sign and zero extension on read, truncation on write, which `kind` mismatches throw and with what text, write barriers on object and string binds, what a read past `elems` returns. Exception messages are byte-identical; roast matches on some of them.
- The growth policy in `set_size_internal` (when it reallocates, to what `ssize`, when it shifts `start` back to zero, the size limits and their errors) is reproduced exactly. Peak memory is part of the gate.
- `enter_single_user`/`exit_single_user` follow the header's `MVM_ARRAY_CONC_DEBUG` at comptime; at its value of 0 they emit nothing.
- The `spesh` hook moves with the file and emits the same instructions with the same operands.

### 5.4 The allocator

- `VMArray.zig` declares one allocator, in one place: `const allocator: std.mem.Allocator = moar.mvm_allocator;` (spelling the builder's). Slots and REPR data are allocated, resized and freed only through it. There is no direct `MVM_malloc`, `MVM_realloc` or `MVM_free` call in the file. Changing the array's allocator is a change to that one line; nothing else in this campaign depends on which allocator it is, except the adoption sites below.
- Unit tests instantiate the storage paths with `std.testing.allocator`, so a leak or a free with the wrong length fails the test. Leak assertions apply to the non-throwing paths only (see 7.1). How the allocator is made substitutable for tests (a comptime parameter of the storage code, with the REPR's own instantiation fixed to the declared allocator) is the builder's call; it must not add a runtime field or an indirection on the hot paths beyond what calling through `std.mem.Allocator` already costs.
- Lengths and alignment (my call): the Zig allocator interface wants the length and alignment back on `free`. The array records neither separately, so slots are always allocated and freed as bytes of length `ssize * elem_size` at one fixed alignment for every kind (the builder picks it; it must be at least the alignment of the widest element and at most 16). `mvm_allocator` ignores both on free, which is what makes the next point safe.
- The adoption sites stay as they are. Outside C code keeps allocating a buffer with `MVM_malloc`, storing it in `slots` and setting `ssize`, and the array later frees it; and some outside code frees or replaces the slots itself. This is valid only because the declared allocator is `MVM_malloc`-backed. The campaign audits every such site and records it (`va-adoption-audit.md`): file and line, what it allocates, whether `ssize` matches the allocated size in elements, and how the buffer was obtained (anything from `MVM_malloc` is 16-aligned and so satisfies the fixed alignment; the column is there for the later spike, not as a check that can fail here). The record is what a later allocator spike will need; a site where `ssize` understates or overstates the allocation is reported in the record, not fixed here.
- Zero length (settled after the builder check): the C array never allocates zero bytes. `copy_to` leaves `slots.any` NULL when there are no elements, `set_size_internal` never grows to fewer than 8 slots, and `deserialize` allocates only when `ssize` is non-zero. The Zig array keeps exactly that: it never passes a zero length to the allocator, and an array without storage has `slots.any == NULL`, never the non-null sentinel that `std.mem.Allocator.alloc` returns for an empty slice. Outside C code tests and frees that pointer.
- Out-of-memory behaviour is the C's: `MVM_malloc` and friends panic and do not return failure. The array does not introduce an error path for allocation failure. The builder checks how `mvm_allocator` surfaces failure today and keeps the panic.

### 5.5 Not array-only by accident

Before acceptance the builder writes `va-mechanism-check.md`: on paper, no code, what `P6int` (a leaf with box functions and no storage) and one REPR with reference fields in its body (builder's choice; `MVMHash` or `MVMCode` are candidates) would declare to get their vtables from the builder of 5.2, and whether anything in 5.2 would have to change. A change that is needed is made now only if it is small; otherwise it is recorded as the next campaign's first item.

## 6. The documentation rule for comptime

The user's rule: comptime "can be clever as long as it is not opaque", and it must be well documented.

- Every comptime construct (a function returning a type or a table, an `inline for`/`inline switch` that generates arms, a comptime-built constant) carries a doc comment that says what it generates, in terms of the result: which fields, which switch arms, which exported symbols, for which inputs. Where it helps, the comment shows the expansion for one concrete input.
- The slot-kind table and the vtable builder each have a short prose section at the top of their file explaining the idea before the code.
- `docs/zig-build.md` gains a section for the REPR mechanism: how a REPR declares itself, what the builder fills in, how to add a kind, how to change the allocator.
- Comprehension check (my call): the final review includes a reader who is given `repr.zig` and `VMArray.zig` and nothing else (no spec, no plan, no C file) and must write down, for each comptime construct, what it produces. Any construct whose output the reader gets wrong or cannot state is a finding against the documentation, fixed before acceptance.

## 7. Evidence of identical behaviour

There is no line-by-line correspondence to review, by decision. Identity rests on these, each comparing the head (`-Dzig-reprs=true`) with the control (`-Dzig-reprs=false`, same commit):

1. **Unit tests** (`repr-test`): the vtable comparison of 5.2; every operation on every kind on a booted VM, including the non-throwing boundaries (empty array, growth from every direction, `start` non-zero, negative indices that resolve, reads past `elems`); the storage paths under `std.testing.allocator`. Paths that throw are not unit-tested (settled after the builder check): `MVM_exception_throw_adhoc` leaves by `longjmp`, the test roots have no handler frame, and a `longjmp` skips Zig's `defer`, so neither the message nor a leak assertion can be checked there. Every throwing path (kind mismatches, out-of-range binds, the size limit) and its message is covered by the differential program below, which is why that program must reach each of them.
2. **A differential program**: one nqp program (and a Raku one where nqp cannot reach an operation) that drives every array operation over every kind with fixed inputs and prints results and caught error messages; its output is byte-identical between head and control. The control's own output must repeat run to run before it counts as an oracle.
3. **Serialization**: arrays of every kind serialized by each build give identical bytes, and each build deserializes the other's output. As a whole-system check, the builder tries comparing the `.moarvm` files of an nqp build made with each moar; this counts only if the control repeats itself byte for byte, and if it does not, that is recorded and the per-kind comparison stands alone.
4. **The collector's oracle**: `tools/bench/gc/oracle.sh` group a (8 cells, tiers 1 and 2) byte-identical between head and control. The array's mark feeds the collector, so a changed visiting order or count would show here.
5. **Suites**: MoarVM's unit tests, nqp `make test`, rakudo `make test` and the spectest: the same list of test names and verdicts on both builds, zero new failures (a known intermittent is re-run and classified, as before).
6. **Cleanup and stress**: `tools/bench/gc/cleanup.sh` on both, plain and `--stress` (512 KiB nursery, `-Dgc-debug=1`), all runs clean.

## 8. Performance and memory gate

- Bar: not slower, not more memory. A gain is welcome and is not required.
- Spectest A/B, control against head, is the primary gate: wall and peak RSS within the control's spread or 1 percent, zero new failures.
- `crc-getter` at volume 100 000, `--runs=5`, plain and `--bad-packages`, through `ab.sh --rounds=7`: head/control wall and RSS within the control's spread. A reading outside it stops the campaign for a report; the builder may take one re-run of the affected setting first and reports both.
- The array's hot paths (`at_pos`, `bind_pos`, `push`, the JIT's two fast functions) are reached through function pointers and from JIT code, so LTO cannot hide a worse shape. If the gate misses, the builder profiles with `profile.sh` and compares the size and call shape of those functions between the builds before changing any code, as Campaign 7 did; that campaign's rule (where the C build calls out of line, the Zig build calls out of line) applies to the array's slow paths, growth above all.
- A micro-benchmark of array operations per kind may be added if the two programs above cannot resolve a question; it is not a gate.

## 9. Task ladder (the plan may regroup; the order of dependencies is what matters)

1. Setup: branch, rebuild the prefixes, the `[zig-reprs]` section and `-Dzig-reprs` switch with no Zig array yet (the switch on and off both build the C file at this point and give identical libraries), the control's records (differential program written and shown repeatable on the C array, serialization bytes, oracle, suites, A/B baseline of control against itself for the spread).
2. The adoption-site audit (`va-adoption-audit.md`). It comes early because it can change the allocator decisions of 5.4.
3. The vtable builder with its tests, on a stub REPR, and the table comparison against the C array's table.
4. The slot-kind table and the array's storage (allocation, growth, free, copy) with the allocator tests.
5. The element operations, mark and `describe_refs`, serialization, the spesh hook and the JIT entry points; the switch turns the Zig array on. The plan may split this into more than one task, but the array is all-C or all-Zig in any build: no build mixes operations from both files.
6. Evidence and gate (sections 7 and 8), the paper check (5.5), docs.
7. Final whole-branch review including the comprehension check; fix wave; hand back to the user for the merge decision.

Process as in the earlier campaigns: subagent-driven development, one implementer and one reviewer per task, a ledger, a final whole-branch review. Models (the user's instruction, 2026-11-16): Fable implementers, Opus reviewers (task reviews, re-reviews, the final whole-branch review and its comprehension check).

## 10. Risks the builder should plan around

- **Per-kind accidents.** The C's twelve copies are not guaranteed to be the same code with a type swapped; some arms differ on purpose (object and string barriers) and some may differ by history. A generic body that makes them uniform changes behaviour. The differential program must be written and recorded on the C array before the generic bodies exist, and a per-kind difference found while reading the C is listed in a record (`va-kind-differences.md`) with the decision "kept", never smoothed over. A difference that looks like a C bug is reported to the user and kept.
- **The allocator interface on the hot path.** Growth goes through `std.mem.Allocator`'s vtable where the C calls `MVM_realloc` directly. If that shows in the profile, the answer is in the shape of the call (out of line, as the C's slow path is), not in bypassing the allocator.
- **Free with unknown provenance.** A buffer adopted from outside may have been allocated with a size other than `ssize * elem_size`. `mvm_allocator` does not care; `std.testing.allocator` does, so unit tests that model adoption must allocate the way the sites do. The audit says which sites those are.
- **`translate_c` and the REPR headers.** `MVMREPROps` has nested tables of function pointers and the default macros expand to lists of identifiers; the builder may find that the translated header does not expose something the mechanism needs (a default function that is `static`, a macro that does not translate). The fallback is a small C shim that exposes it, not a second definition in Zig.
- **Comptime that works but cannot be read.** `@typeInfo` walks and `@field` by computed name are the natural tools for 5.2 and are also the fastest route to opacity. Section 6 is a gate, not a courtesy.
- **Spesh and the JIT keep reading the body.** Nothing here may change a field's offset or meaning; comptime asserts pin the sizes and offsets of the three structs against the C header's.

## 11. Left to the builder

Names of functions and types; the internal split of `VMArray.zig`; how the kind table is represented; how the test allocator is injected; the fixed alignment's value; which second REPR the paper check uses; how the C vtable is captured for comparison; the grouping of tasks; whether a micro-benchmark is worth having; whether the Raku half of the differential program is needed.

## 12. Decisions recorded

The user's (2026-11-16):

- What the first REPR in Zig must show: "no more macros, genuine encapsulation, opportunities for introducing zig-specific allocators".
- Encapsulation: "let it happen. eventually we will port the readers but for now it should work as it already does (encapsulation onto the back burner)".
- Allocators are for "the memory hanging off of them", not for the objects.
- Success is "the mechanism in place and proven on one REPR"; a measured win is not required.
- "VMArray first with the malloc-backed allocator"; the nursery-lifetime allocator is a later spike.
- "straight to comptime shapes": no line-by-line translation first.
- Comptime: "well documented comptime activity. it can be clever as long as it is not opaque".
- Models: "Let's go with Fable implementors and Opus reviewers for this campaign".

Mine (the user saw these in summary and said nothing was missing; each can be overruled):

- The mechanism is shaped by the array and checked on paper against two other REPRs, not designed for all 47.
- The array's `gc_mark` is derived from the slot kind; derivation from body fields waits.
- The build switch `-Dzig-reprs` and section `[zig-reprs]`, and that it requires the Zig collector.
- The spesh hook and the JIT entry points move with the file.
- The evidence list of section 7 and the gate of section 8, including "break-even is enough".
- Bytes at one fixed alignment for all kinds; the adoption sites left as they are and audited.
- The comprehension check in the final review.
- File locations, the branch name `zig-vmarray`, the record prefix `va-`, and handing the branch back for the merge decision instead of merging it.

## 13. Errata (what was built differently, recorded at Task 8, 2026-11-17)

Each item: what this document says, what was built, and why. None changes
the goals of section 2; the behavioural ones are put to the user in the
plan's Outcome.

1. **Files (5.1).** `VMArray.zig` is a thin file (declaration, allocator,
   table, exports); the array's code is in `src/zig/6model/reprs/vmarray/`
   (`kinds`, `storage`, `elements`, `mark`, `serial`, `spesh`), export-free
   so that `repr-test` can link it beside libmoar without interposing its
   symbols (the plan's architecture).
2. **Kind constants (4, 5.3).** The header has eighteen `MVM_ARRAY_*`
   constants: twelve with storage (the `Kind` table) and six without
   (`U4`, `U2`, `U1`, `I4`, `I2`, `I1`, element size 0), listed once in
   `kinds.unstored` and handled per call site, not as table entries.
3. **The kind table (5.3)** has two more columns than listed: the
   serialization reader and writer of each kind (`reader`, `writer`), and
   two register-kind sets (`reg_kinds` for `at_pos`/`bind_pos`,
   `stack_reg_kinds` for push/pop/shift/unshift), because the C accepts
   different register kinds there.
4. **`dispatch` has a fourth argument, `otherwise`** (`.throw = "..."`,
   `.abort`, `.nothing`, or a function), stating at each call site what the
   C's `default:` arm does for the six kinds without storage; and
   **`zeroSlots` takes `tc`**, because the C's `zero_slots` throws for those
   kinds (Task 5 ruling).
5. **The allocator's raw functions (5.4).** The storage calls
   `rawAlloc`/`rawRemap`/`rawFree` of the declared allocator, not
   `Allocator.alloc/realloc/free`: the lengths given back cannot be trusted
   (adoption sites misstate `ssize`, and a non-NULL buffer with `ssize == 0`
   exists), and `Allocator.free` skips a zero-length slice, which would
   leak such a buffer. `gc_free` passes length 0. So the declared allocator
   must ignore lengths on free and remap, as `mvm_allocator` does; the
   adoption-shape unit tests use a length-agnostic tracking allocator
   instead of `std.testing.allocator` (Task 5 ruling). "Bytes of length
   `ssize * elem_size`" (5.4) is what is requested, not what is trusted.
6. **NULL faults (no behaviour change).** Where the C dereferences a NULL
   REPR data or NULL slots deterministically, the Zig calls
   `moar.nullDeref` (a read in the null page: SIGSEGV as in the C) rather
   than unwrapping an optional, and never earlier than the C's first
   dereference of that pointer in the same function (Task 6 rulings).
   `kinds.slots` and `reprDataOf` keep one defensive NULL test on every
   element access; the gates of section 8 measured it (plan Outcome).
7. **The no-check worklist adds** (`MVM_gc_worklist_add_include_gen2_nocheck`
   and friends, macros) live in `src/zig/moar.zig` beside `worklistAdd`,
   not in the array's files: the test root cannot import files outside
   `src/zig/6model`.
8. **Spesh (4, 5.3)** ports both rewrites of the C hook: `elems` on a known
   array into a direct field read, and `create` of a type without
   `MVM_FINALIZE_TYPE` into `sp_fastcreate` (section 4 named only `elems`).
9. **Self-splice copies (5.3, "no behaviour change").** Where the C copies
   overlapping ranges with `memcpy` (a splice of an array from itself, the
   eleven memcpy kinds), the result is undefined; the Zig uses memmove
   semantics there (Task 2 ruling). The C's defined element-by-element
   copy (STR, OBJ into a second-generation target) is kept. This is the one
   place the outputs differ.
10. **No storage is NULL (5.4).** For the six kinds without storage the C
    keeps `MVM_malloc(0)` in some paths (growth before the throw, `copy_to`);
    the Zig keeps NULL (zero length never requested). Only the pointer
    value differs (Task 5 ruling; `va-kind-differences.md` section 3).
11. **The differential (7.2)** has four programs, not two: `vmarray-diff.nqp`,
    `vmarray-diff.raku`, `vmarray-serial.nqp` and `vmarray-devirt.nqp` (only
    its shape reaches the JIT's two direct functions). `diff.sh` has an exit
    3, "differs only in the listed undefined self-splice lines, and equals
    memmove there" (`undefined-lines.txt`, 195 entries, every one checked
    against `memmove-model.py`), which is neither a pass nor a failure and
    goes to the user.
12. **The vtable builder (5.2)** also accepts a slot declared `null` (two C
    tables need it, MVMContinuation and P6opaque; found by the paper check,
    `va-mechanism-check.md`), and reports a required slot declared null.
    The comparison of 5.2 is against a recorded dump
    (`src/zig/6model/test/vmarray_vtable_c.tsv`), as anticipated.
13. **Test-only C.** `src/zig/test/layout_probe.c` (a test-only C file)
    gained probes: the C compiler's sizes and offsets of `MVMArrayBody`,
    `MVMArray` and `MVMArrayREPRData` (Task 5), checked against
    translate-c's, and two `MVMOpInfo` probes, a struct translate-c leaves
    opaque (bit-fields) (Task 7 ruling). No C file of the library changed.
14. **Models (9).** Tasks 1-2 had Fable implementers; from Task 3 on,
    implementers were Opus (the user's change of 2026-11-16); reviewers
    Opus throughout.
15. **Cleanup and stress (7, item 6).** "All runs clean" was met on the base prefixes (120 of 120) but not with
    `cleanup.sh --stress` on the stress prefixes: `blocked.nqp` segfaults in global destruction in about 2 % of
    runs, equally on the C control (2/120) and the Zig array (3/120), at the same site. Ruled not the array's and
    put to the user as a finding outside it (`va-cleanup.md`, plan Outcome).
16. **The whole-system check (7, item 3)** was run at the final review's fix wave, not at Task 7 where the
    ladder placed it (it was not attempted at Task 7 or Task 8). nqp was built three times from copies, twice
    with the C-array moar and once with the Zig-array moar (both libmoar at 584d21d02); the control repeated
    byte for byte and the Zig array's build gave the same 45 `.moarvm` files (`va-whole-system.md`).
