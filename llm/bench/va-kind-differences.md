# VMArray kind differences: where the twelve arms are not one piece of code

Campaign `2026-11-16-zig-vmarray-repr`, Task 3. Read from
`src/6model/reprs/VMArray.c` at MoarVM `a92476665` (the file last changed in
`c7ca550e8`); every line number below is that file's unless another file is
named. Nothing here is fixed. Task 6 turns each row into an explicit,
documented comptime branch (or a field of the kind table); a row marked
**uniform** needs none.

## 0. How to read this

The header (`VMArray.h:45-62`) has eighteen kind constants. Twelve have
storage and are handled by the per-kind `switch` arms:

| group | kinds | element | register the C reads/writes |
|---|---|---|---|
| OBJ | `MVM_ARRAY_OBJ` (0) | `MVMObject *` | `.o` |
| STR | `MVM_ARRAY_STR` (1) | `MVMString *` | `.s` |
| I | `I64` (2), `I32` (3), `I16` (4), `I8` (5) | signed integer | `.i64` |
| N | `N64` (6), `N32` (7) | `double`, `float` | `.n64` |
| U | `U64` (8), `U32` (9), `U16` (10), `U8` (11) | unsigned integer | `.u64` or `.i64` (see the rows) |

Six have no storage: `U4` (12), `U2` (13), `U1` (14), `I4` (15), `I2` (16),
`I1` (17). They get `elem_size = 0` and fall into every `default:` arm;
section 3 lists what each operation does with them.

"Same code with the type swapped" means the arm differs from its siblings
only in the union member, the C element type and the kind name in the text.
Within a group that is true unless a row says otherwise. Every row's ruling
is **kept** (the Zig array reproduces it, per the global constraint "a
per-kind difference in the C is kept"); a row that also looks like a bug says
**report to the user**.

Where a row touches what Task 2 already recorded
(`traces/llm/bench/va-differential.md`, section 4 "Per-kind differences",
section 5 "Splices from the array itself", section 6 "Left out"), it says
"Task 2 §n" instead of restating; section 4 below says where this record
agrees, adds to, or disagrees with those sections.

## 1. Operation by operation

| # | operation (lines) | kinds | what differs | ruling |
|---|---|---|---|---|
| 1 | `enter_single_user`/`exit_single_user` (7-19) | all | uniform (no-ops unless `MVM_ARRAY_CONC_DEBUG`) | uniform |
| 2 | `type_object_for` (26-43) | - | uniform: every new type starts as OBJ, `elem_size = sizeof(MVMObject *)` until `compose` | uniform |
| 3 | `copy_to` (48-65) | all | uniform: one `memcpy` of `elems * elem_size` bytes from `start`, for OBJ and STR too (raw pointer copy, no `MVM_ASSIGN_REF`; the destination is a fresh object). `ssize = elems`, `slots = NULL` when empty. For one of the six with `elems > 0` (only after a recompose) the clone gets `MVM_malloc(elems * 0)` (59) with `ssize = elems > 0`, so `ssize` misstates the allocation inside `VMArray.c` itself (53-60) | uniform |
| 4 | `VMArray_gc_mark` (68-109) | OBJ, STR | only OBJ and STR have an arm; they are the same code with the pointer type swapped (presize the worklist for `elems`, add `&slots[start + i]` for `i < elems`, `include_gen2` or not). Every other kind, the six included, marks nothing. Only the live window `[start, start + elems)` is marked: slots outside it are not kept alive (rows 18c, 19b, 20) | kept |
| 5 | `gc_free`, `gc_mark_repr_data`, `gc_free_repr_data` (112-128) | all | uniform | uniform |
| 6 | `get_storage_spec` (131-144) | all | uniform (the array itself is a reference) | uniform |
| 7 | `MVM_VMArray_at_pos_s` (146-164) | STR only | checks `slot_type == STR`, else "MVMArray: atpos expected a string register, but %u is not MVM_ARRAY_STR" (the slot type's number). Order: negative-index fix-up and "MVMArray: Index out of bounds" first, then the kind check, then out of range gives `NULL` | kept |
| 8 | `MVM_VMArray_at_pos_i` (166-181) | I64 (by contract) | no kind check: reads `slots.i64` whatever the kind. Its only caller, `MVM_repr_at_pos_i` (`reprconv.c:95-110`), calls it only for I64 | kept |
| 9 | `MVM_VMArray_at_pos_u` (183-198) | U64 (by contract) | as row 8, `slots.u64`; caller `reprconv.c:112-127` guards U64 | kept |
| 10 | `MVM_VMArray_at_pos_n` (200-215) | N64 (by contract) | as row 8, `slots.n64`; caller `reprconv.c:129-144` guards N64. Out of range gives integer `0` assigned to a double (same as `0.0`) | kept |
| 11 | `MVM_VMArray_at_pos_o` (217-238) | OBJ only | checks `slot_type == OBJ`, else "MVMArray: atpos with an object register, but array type %u is not MVM_ARRAY_OBJ"; out of range and a NULL slot both give `VMNull` | kept |
| 12a | `MVM_VMArray_at_pos` (240-358): accepted register kind | U vs I | OBJ wants `MVM_reg_obj`, STR `MVM_reg_str`, N `MVM_reg_num64`, I only `MVM_reg_int64`, **U either `MVM_reg_uint64` or `MVM_reg_int64`** (324, 332, 340, 348). The check comes after the negative-index fix-up and before the range check (Task 2 §4) | kept |
| 12b | at_pos: error text | per arm | OBJ "MVMArray: atpos expected object register"; STR "MVMArray: atpos expected string register"; I "MVMArray: atpos I64 expected int register" with `I64`/`I32`/`I16`/`I8`; N64 and N32 the same "MVMArray: atpos expected num register" (no kind name); U64 "MVMArray: atpos U64 expected int register, got %d instead" with the register kind; U32/U16/U8 "MVMArray: atpos U32 expected int register" etc., **without** the ", got %d instead" (Task 2 §4). The Zig needs a per-kind message table, not a format over the kind name | kept |
| 12c | at_pos: value for a hole and for out of range | OBJ, STR, numeric | OBJ: out of range **and a NULL slot** give `VMNull` (259-265); STR: out of range gives `NULL`, a NULL slot gives `NULL`; I and U: `0`; N: `0.0` | kept |
| 12d | at_pos: widening into the register | I, U, N32 | I: sign-extended into `.i64` (`(MVMint64)` cast). U: zero-extended, cast to `MVMint64`, stored in `.u64` (329-353): the cast changes no bits, so U32 `0xFFFFFFFF` reads as 4294967295. N32: promoted to double (exact) | kept |
| 12e | at_pos: `default` arm (355-356) | the six | "MVMArray: Unhandled slot type, got '%s'" naming the **slot** type through `MVM_reg_get_debug_name`, the **register**-kind name table (Task 2 §4: `'unknown'`, `'uint8'`) | kept; report to the user (wrong name table) |
| 13 | `zero_slots` (360-403) | all twelve | the same `memset` of `(ssize - elems) * sizeof(T)` bytes at `&slots.T[elems]` per arm: uniform as a function of the element size (OBJ/STR get `NULL`, N gets `+0.0`). The six reach `default:` "MVMArray: Unhandled slot type" (400), which is how every growth of a no-storage array dies (section 3) | uniform (twelve); kept (six) |
| 14 | `set_size_internal` (405-476) | all, by `elem_size` | no per-kind arm; kind-dependent only through `elem_size`: the address-budget table at 454-457 maps 8 -> 4, 4 -> 3, 2 -> 2 and **everything else (1 and 0) -> 1**, so the largest `ssize` is 2**60, 2**61, 2**62 and 2**63 elements for 8-, 4-, 2- and 1-byte kinds, and 2**63 for the six. `ssize > limit` throws "Unable to allocate an array of %"PRIu64" elements". The rounding wrap near 2**64 and the panic at the limit are Task 2 §6 | kept (the table, including 0 -> 1) |
| 15a | `MVM_VMArray_bind_pos` (478-561): accepted register kind | U vs I | as at_pos (row 12a): U accepts `MVM_reg_uint64` or `MVM_reg_int64`, I only `MVM_reg_int64`. The growth (`set_size_internal`, 490-491) happens **before** the kind check, for every kind (Task 2 §4) | kept |
| 15b | bind_pos: error text | per arm | OBJ "MVMArray: bindpos expected object register"; STR "MVMArray: bindpos expected string register"; I "MVMArray: bindpos I64 expected int register" etc.; N64/N32 "MVMArray: bindpos expected num register"; U "MVMArray: bindpos U64 expected int register" etc. (no "got %d" in any bind arm, unlike at_pos U64); `default` "MVMArray: Unhandled slot type" | kept |
| 15c | bind_pos: how the value is stored | OBJ/STR vs numeric | OBJ and STR store through `MVM_ASSIGN_REF(tc, &root->header, slot, value)` (the generational write barrier); every numeric kind is a plain store | kept |
| 15d | bind_pos: narrowing | I32/I16/I8, U32/U16/U8, U64, N32 | I32/I16/I8 and U32/U16/U8 truncate `value.i64` with a C cast (keep the low bits; the Zig must use `@truncate`, not `@intCast`, which traps in safe builds). U64 stores `value.i64` with no cast (540) and push/unshift store `(MVMuint64)value.i64`: same bits. The U arms read `.i64` even when the register kind is `uint64`: same union bits. N32 stores `(MVMnum32)value.n64`: round to nearest; a double outside float range becomes +-inf on x86-64 (C leaves it undefined; the Zig cast must give the same result) | kept |
| 16 | `elems`, `set_elems` (563-574) | all | uniform | uniform |
| 17a | `MVM_VMArray_push` (576-646): accepted register kind | U vs I | **every integer arm, U included, accepts only `MVM_reg_int64`** (U64 at 623, U32 628, U16 633, U8 638), unlike bind_pos. Not reachable with `uint64` from bytecode: the op list has `push_i`/`push_n`/`push_s`/`push_o` only (`src/core/oplist:353-356`). Growth happens before the check (Task 2 §4) | kept |
| 17b | push: error text | per group | "MVMArray: push expected object register", "... string register", "... num register", and one "MVMArray: push expected int register" for all eight integer kinds (no kind name); `default` "MVMArray: Unhandled slot type" | kept |
| 17c | push: stores | as 15c, 15d | OBJ/STR through `MVM_ASSIGN_REF`, narrowing as row 15d | kept |
| 18a | `pop` (648-725): accepted register kind, text | U vs I | as push: every integer arm accepts only `MVM_reg_int64`; "MVMArray: pop expected int register" for all eight, "... object/string/num register" for the rest; `default` "MVMArray: Unhandled slot type". "MVMArray: Can't pop from an empty array" comes first, for every kind | kept |
| 18b | pop: what is returned | OBJ vs at_pos | OBJ returns the **raw slot**: a hole (NULL, e.g. after `setelems` grew the array) comes back as `NULL`, not `VMNull` as from at_pos (row 12c); `pop_o` (`interp.c:2249-2255`) puts it in the register as is. STR returns NULL likewise. I sign-extends, U zero-extends into `.i64` (U64 reinterpreted), N32 widens | kept |
| 18c | pop: order | all | `elems--` before the kind check (658), so a rejected pop has dropped the element without clearing its slot; `zero_slots(slot, slot + 1)` clears it only on success (723). For OBJ/STR the uncleared slot holds a pointer the collector no longer marks (Task 2 §4, §6) | kept; report to the user (OBJ/STR) |
| 19a | `unshift` (727-824): accepted register kind, text | U vs I | as push: integer arms only `MVM_reg_int64`; "MVMArray: unshift expected int register" for all eight; `default` "MVMArray: Unhandled slot type" | kept |
| 19b | unshift: order | all | when `start == 0` it first makes `n = min(max(elems, 8), 8192)` slots of front room (737-754, uniform: `set_size_internal`, `memmove` by `elem_size`, `zero_slots(0, n)`). Then `start--` **before** the kind check (757): a rejected unshift leaves the window one slot to the left with `elems` unchanged. If room had just been made, element 0 is a zero; **if `start > 0` already (after a `shift`), element 0 is the old shifted-off value, which for OBJ/STR is an untracked pointer** (row 20). Stores as rows 15c/15d | kept; report to the user (OBJ/STR) |
| 20 | `shift` (826-902) | U vs I; all | integer arms only `MVM_reg_int64`, "MVMArray: shift expected int register" for all eight, `default` "MVMArray: Unhandled slot type"; "MVMArray: Can't shift from an empty array" first. The kind check is before any change (a rejected shift changes nothing). OBJ returns the raw slot (NULL for a hole), as pop. The shifted-off slot is **not** cleared (`start++` only, 899): uniform, but for OBJ/STR it leaves an unmarked pointer below `start` that rows 19b and 26 can bring back into the window | kept |
| 21 | `slot_type_to_kind` (904-931) | groups | OBJ -> `MVM_reg_obj`, STR -> `MVM_reg_str`, I -> `MVM_reg_int64`, N -> `MVM_reg_num64`, U -> `MVM_reg_uint64`; the six -> `abort()` (929) | kept |
| 22a | `copy_elements` (933-967): fast path | STR, OBJ | `memcpy` of `elems * elem_size` bytes when the source is a VMArray with the same slot type and element size (the size test is redundant: kind fixes it), **except** STR always, and OBJ when the target is in gen2 (`MVM_CF_SECOND_GEN`, 942-947); those go element by element through the source's `at_pos` and `MVM_VMArray_bind_pos` (so through the write barrier). The other ten kinds always `memcpy` (Task 2 §4) | kept |
| 22b | copy_elements: holes on the slow path | OBJ | on the element path `at_pos` turns a NULL hole into `VMNull` (row 12c) and `bind_pos` stores that. So copying an OBJ array with holes keeps `NULL` holes into a nursery target (memcpy) but writes `VMNull` into a gen2 target. The test is the **destination's** `MVM_CF_SECOND_GEN` flag (942, 946), never the source's, and it applies to `aslice` as well as `asplice`, since both copy through `copy_elements` (985, 1120). Observable: `pop`/`shift` then return `NULL` versus `VMNull` (rows 18b, 20), and `serialize` writes `REFVAR_NULL` versus `REFVAR_VM_NULL` (`serialization.c:709-714`) | kept (the Zig must take the same path on the same gen2 test) |
| 22c | copy_elements: across kinds | all pairs | the register is read with the source's kind and written with the target's (957-963), so the kind checks always pass and nothing converts: num bits reinterpreted as an integer and back, a pointer as an integer, an integer narrowed by row 15d (Task 2 §4, §6). A non-VMArray source with elements crashes on `s_repr_data` NULL (958; Task 2 §6). The six (reachable only after a recompose, with elements and room): source and target of the **same** six kind pass the fast-path test (943-947: same slot type, same `elem_size` 0, neither STR nor OBJ), so `memcpy` copies `0 * elems` bytes and returns with no effect and no error; a six kind on **either** side with differing kinds takes the slow path and reaches `abort()` in `slot_type_to_kind`, at 957 for a six-kind target, at 958 for a six-kind source | kept; report to the user (the crash and the aborts; Task 2 §6 names only the target case, see section 4) |
| 22d | copy_elements: overlap | the eleven memcpy kinds vs STR/promoted OBJ | a self-splice copies overlapping ranges: `memcpy` (undefined) for eleven kinds, a forward element loop for STR and promoted OBJ. Ruled in Task 2 §5: memmove semantics for the eleven, the forward loop kept for STR and promoted OBJ. I agree | kept as ruled |
| 23 | `aslice` (969-986) | all | uniform: bounds check "MVMArray: Slice index out of bounds", `set_size_internal` on the target, then `copy_elements` (row 22) | uniform |
| 24 | `write_buf` (988-1012) | OBJ/STR vs the rest | the kind gate is `slot_type < MVM_ARRAY_I64` (995): OBJ and STR are refused with "MVMArray: write_buf requires an integer type"; **N64 and N32 are accepted** although the text says integer, and so are the six (section 3). Otherwise kind-generic through `elem_size`; the over-growth to `offset + count` elements is Task 2 §4 | kept; report to the user (nums accepted, message says integer) |
| 25 | `read_buf` (1014-1036) | as row 24 | same gate and text "MVMArray: read_buf requires an integer type"; N accepted. Kind-generic otherwise; the bounds check that adds `start` is Task 2 §4, §6 | kept (the gate); the bounds check is reported in Task 2 |
| 26 | `asplice` (1040-1121) | all | uniform: index arithmetic, `memmove` of the tail by `elem_size`, `set_size_internal`, then `copy_elements` (row 22). The offset-0 `start` adjustment (1065-1082) is uniform but brings shifted-off slots back for OBJ/STR on a self-splice (Task 2 §4, §6) | uniform |
| 27 | `at_pos_multidim`, `bind_pos_multidim`, `dimensions`, `set_dimensions` (1123-1145) | all | uniform (one dimension, delegate) | uniform |
| 28 | `get_elem_storage_spec` (1147-1192) | groups | STR: `INLINED`, `BP_STR`, `CAN_BOX_STR`; I: `INLINED`, `BP_INT`, `CAN_BOX_INT`; N: `INLINED`, `BP_NUM`, `CAN_BOX_NUM`; U: `INLINED`, `BP_UINT64`, `CAN_BOX_INT`, `is_unsigned = 1`; OBJ **and the six**: `REFERENCE`, `BP_NONE`, `can_box = 0` (`default`). `bits` and `align` are 0 for every kind: the spec never states the element width | kept; report to the user (the six reported as reference arrays; Task 2 §4) |
| 29 | `pos_as_atomic` (1194-1213) | I64/U64 or I32/U32 | index check "Index out of bounds in atomic operation on array" first; then a pointer into the slots only for I64 and U64 when `sizeof(AO_t) == 8`, or I32 and U32 when it is 4 (on x86-64: I64 and U64 only). Every other kind: "Can only do integer atomic operation on native integer array element of atomic size" | kept |
| 30 | `pos_as_atomic_multidim` (1215-1221) | all | uniform | uniform |
| 31a | `spec_to_repr_data` (1224-1319): integers | signedness | `BP_UINT64` and `BP_INT` share one branch and the **`is_unsigned` flag**, not the box kind, picks U or I: a `BP_UINT64` spec with `is_unsigned == 0` makes a signed array. Bits 64/32/16/8 give the storage kinds with `sizeof(T)`; 4/2/1 give the six with `elem_size = 0`; anything else "MVMArray: Unsupported uint size" or "MVMArray: Unsupported int size" | kept |
| 31b | spec_to_repr_data: num, str, the rest | N, STR, others | `BP_NUM` 64/32 -> N64/N32, else "MVMArray: Unsupported num size"; `BP_STR` -> STR. **Any other box kind (`BP_NONE`: an object type) changes nothing**: the slot type and size stay what they were, so recomposing a native array with an object element type leaves it native while `elem_type` changes | kept; report to the user |
| 32 | `compose` (1320-1333) | all | uniform: assigns `elem_type` (1329) and then calls row 31, so an "Unsupported ... size" error leaves the new `elem_type` with the old slot type. Recomposing a type with live arrays changes their kind in place (Task 2 §4) | uniform (the order is kept) |
| 33 | `deserialize_stable_size`, `serialize_repr_data`, `deserialize_repr_data` (1336-1362) | all | uniform: default OBJ, then row 31 when there is an element type | uniform |
| 34a | `deserialize` (1364-1426): per-kind reads | groups | OBJ `MVM_serialization_read_ref`, STR `read_str`, both stored through `MVM_ASSIGN_REF`; I and U `read_int`, narrowed by a cast; N `read_num`, N32 narrowed to float. The U arms store through the **signed** members with unsigned casts (U64 `slots.i64[i] = read_int(...)`, U32 `slots.i32[i] = (MVMuint32)...`, U16, U8 likewise, 1399-1413): the same bits as storing through the unsigned members, so no behaviour difference; the Zig can use the unsigned members. The arms appear in the order I, U, N (code order only) | kept (bits); code shape need not be copied |
| 34b | deserialize: allocation and the six | all; the six | `elems` is read and `ssize = elems`, `MVM_malloc(ssize * elem_size)` when non-zero, **before** the kind switch, with no limit check (1369-1372); for one of the six with `elems > 0` that is `MVM_malloc(0)` with `ssize = elems > 0`, a misstated `ssize` inside `VMArray.c` (the throw that follows leaves the object holding it); `start` is not written (the fresh body is zeroed). The six reach `default:` "MVMArray: Unhandled slot type" even with `elems == 0` (Task 2 §4) | kept; report to the user (the six cannot be deserialized; Task 2) |
| 35 | `serialize` (1428-1476) | groups; the six | per element: OBJ `write_ref`, STR `write_str`, I and U `write_int` of the value as `MVMint64` (U64 above 2**63 written as a negative number; reads back to the same bits), N `write_num` (N32 widened). The `switch` is **inside** the element loop, after `elems` is written: an empty array of one of the six serializes as just `0`; a non-empty one throws "MVMArray: Unhandled slot type" after writing its count (Task 2 §4) | kept |
| 36 | `spesh` (1479-1512) | all | uniform (`create` -> `sp_fastcreate`, `elems` -> `sp_get_i64` at `offsetof(MVMArray, body.elems)`) | uniform |
| 37 | `unmanaged_size` (1515-1519) | all | uniform: `ssize * elem_size` (0 for the six; see the adoption audit for sites where `ssize` is wrong) | uniform |
| 38 | `describe_refs` (1521-1550) | OBJ, STR | as row 4: OBJ and STR arms, the same code with the pointer type swapped; other kinds nothing. No `elems == 0` early return (the loop does nothing) | kept |
| 39 | `MVMArray_initialize` (1553-1555) | - | uniform | uniform |
| 40 | `vmarray_bind_pos_int64`, `vmarray_at_pos_int64` (1559-1601) | I64, U64 | 8-byte only, no kind check; serve both I64 and U64 (row 41). `at_pos` gives 0 out of range; `bind_pos` grows like row 15 | kept |
| 41 | `MVM_VMArray_find_fast_impl_for_jit` (1605-1645) | I64, U64 | `atpos_i`/`bindpos_i` with register `int64` on an I64 array, and `atpos_u`/`bindpos_u` with register `uint64` on a U64 array, get row 40's functions; every other op, register kind or slot kind gets `NULL` (the generic path). So a U64 array read with `atpos_i` is not devirtualized, although at_pos accepts it | kept |
| 42 | `VMArray_this_repr` (1647-1694) | - | uniform | uniform |

## 2. What Task 6's kind table must carry

From the rows above, the per-kind facts that are not "the type swapped",
i.e. what each entry of the kind table needs as a field or what a comptime
branch must test:

- element type and size, the union member, and the register member read and
  written (`.o`, `.s`, `.i64`, `.n64`; U reads into `.u64` in at_pos and into
  `.i64` in pop/shift: same bits);
- the register kinds accepted by at_pos/bind_pos (U: two) and by
  push/pop/shift/unshift (one for every kind);
- the error texts: four families (at_pos, bind_pos, the push/pop/shift/
  unshift family, the exported `_s`/`_o`), with the per-arm variations of
  rows 12b, 15b, 17b; byte-identical;
- whether stores go through the write barrier (OBJ, STR) and whether a NULL
  slot reads as `VMNull` (OBJ in at_pos and `MVM_VMArray_at_pos_o` only, not
  in pop/shift);
- the narrowing on store (row 15d) and the widening on read (row 12d);
- whether the GC marks and the heap snapshot describes the slots (OBJ, STR);
- whether `copy_elements` may block-copy (rows 22a, 22b, 22d);
- the serialization reader/writer (row 34a, 35);
- the storage-spec group (row 28) and the atomic and JIT eligibility (rows
  29, 41);
- for the six: a kind with `elem_size = 0` and no arm anywhere (section 3).

## 3. The six kinds without storage (U4, U2, U1, I4, I2, I1)

Where they are accepted: only `spec_to_repr_data` creates them (rows 31a,
33), from `compose` or `deserialize_repr_data`, for an int or uint element
type of 4, 2 or 1 bits. None of the outside sites of the adoption audit
accepts them (they check for U8/I8, I32/U32 or the eight integer kinds);
kind-generic outside code such as `MVM_nativecall_unmarshal_vmarray` passes
them through (`slots + start * 0`). Every arm table in `VMArray.c` sends them
to `default:`.

A fresh array of one of them has `elems = start = ssize = 0`,
`slots = NULL`. What each operation then does:

| operation | what the C does |
|---|---|
| `at_pos` (and `at_pos_multidim`) | negative index: "MVMArray: Index out of bounds"; otherwise "MVMArray: Unhandled slot type, got '%s'" (row 12e) |
| `MVM_VMArray_at_pos_s` / `_o` | the kind-mismatch error (rows 7, 11); `_i`/`_u`/`_n` are never called for them (callers guard) |
| `bind_pos` with a negative index | "MVMArray: Index out of bounds" before any growth (485-488), as at_pos |
| `bind_pos` (index >= 0), `push`, `unshift`, `set_elems(n > 0)`, `aslice` into one, `asplice` with elements to copy, `write_buf` with `count > 0` | grow: `set_size_internal` sets `ssize` to at least 8, passes the limit (2**63, row 14), calls `MVM_malloc(8 * 0)` (or `MVM_realloc(slots, 0)` if `slots` is already non-NULL), **stores the result in `slots` but not `ssize`**, then `zero_slots` throws "MVMArray: Unhandled slot type" (400). `malloc(0)` returns a non-NULL pointer under glibc and mimalloc. For `realloc(p, 0)`, mimalloc (the default build, `-Dmimalloc=true`) returns a new zero-sized block (`3rdparty/mimalloc/src/alloc.c:380-382`), so `slots` stays non-NULL; glibc frees `p` and returns NULL, which `MVM_realloc` accepts for size 0 (`alloc.h:34`), so `slots` alternates between a zero-byte buffer and NULL. `ssize` stays 0 either way (Task 2 §4) |
| `set_elems(0)`, `asplice` with nothing to copy or delete | nothing (early returns at 411-412 and 1086-1089) |
| `pop`, `shift` | "MVMArray: Can't pop/shift from an empty array" |
| `aslice` from one | "MVMArray: Slice index out of bounds" (0 elements) |
| `copy_elements` (from `aslice` or `asplice`) with one of the six on either side (only reachable after a recompose, when the source has elements and the target has room) | same six kind on both sides: the fast path `memcpy`s 0 bytes, no effect (943-954); a six kind against any different kind: `abort()` in `slot_type_to_kind`, at 957 (target) or 958 (source) |
| the debugger protocol (`src/debug/debugserver.c`) | `write_vmarray_slot_type` names them `"u4"`, `"u2"`, `"u1"`, `"i4"`, `"i2"`, `"i1"` (2526-2531); `write_vmarray_slot_kind` reports them as `"int"` with `MVM_reg_int64` (2551-2556), with which the element dump then calls `at_pos`, so a non-empty (recomposed) one throws there (row 12e) |
| `read_buf` | the kind gate passes (row 25); `count > 0` fails the bounds check "MVMArray: read_buf out of bounds offset ..."; `count == 0` returns 0 |
| `write_buf` with `count == 0` | `memcpy` of 0 bytes to `slots + 0` (NULL): nothing |
| `pos_as_atomic` | "Index out of bounds in atomic operation on array" |
| `get_elem_storage_spec` | reference, `BP_NONE`, `can_box = 0` (row 28) |
| `serialize` | an empty array writes `0` and succeeds (row 35) |
| `deserialize` | "MVMArray: Unhandled slot type", even for 0 elements (row 34b) |
| `copy_to` (clone) | `elems == 0`: `slots = NULL`, nothing copied |
| `gc_mark`, `describe_refs`, `unmanaged_size`, JIT lookup | nothing, nothing, 0, NULL |

An array that had storage and whose type was then recomposed to one of the
six (Task 2 §4, §6) keeps its `slots`, `ssize`, `elems` and `start` with
`elem_size = 0`: every per-kind arm throws "MVMArray: Unhandled slot type"
(`at_pos` with the `got '%s'` form), but `pop` has already decremented
`elems` and `unshift` already moved `start` when they throw, `write_buf`
copies to the start of the old storage, and a splice or slice into it from a different kind aborts (from the same six kind it copies nothing). The Zig
array reproduces these by keeping the same order of effects, not by special
cases.

**The one deliberate difference of the Zig array (2026-11-17, Task 6).**
Where the C hands the allocator a zero length for one of the six kinds (the
growth before `zero_slots` throws: `MVM_malloc(8 * 0)` or
`MVM_realloc(slots, 0)`; `copy_to` and `deserialize` of a recomposed array
with `elems > 0`: `MVM_malloc(elems * 0)`), the Zig array does not call the
allocator: `slots` keeps its value (NULL for a fresh array) or stays NULL,
where the C holds a zero-byte block (or, under glibc's `realloc(p, 0)`,
NULL). Every other field (`ssize`, `elems`, `start`) and every message and
throw is the C's. The allocator rule (spec 5.4: a zero length is never
passed to the allocator; an array without storage has `slots.any == NULL`)
takes precedence over reproducing the pointer value. The value reaches
outside code: `MVM_nativecall_unmarshal_vmarray` passes `slots + start * 0`
through, so native code given such an array receives NULL where the C gave
a non-NULL zero-byte pointer. One consequence inside the array: an
operation that goes on to read or write the slots of such an array (only
after a further recompose, or a `write_buf` with `count > 0` into a
recomposed clone whose `offset + count == elems`, which neither grows nor
throws) accesses a zero-byte block in the C, a heap overrun with undefined
result. The Zig array checks the slots pointer there (`kinds.slots` and the
byte copies of `elements.zig`) and faults deterministically through
`moar.nullDeref`: a volatile read in the null page, SIGSEGV (SIGABRT only
if page 0 were mapped). No differential case drives this (Task 2 §6
"`writeint` on a recomposed array without storage").

The same helper is used wherever the C itself reads through NULL on a path
it reaches, so the Zig faults with the C's signal instead of unwrapping a
NULL pointer (illegal behaviour in Zig): a splice or slice copying from a
non-VMArray with elements (`s_repr_data->slot_type`, `VMArray.c:958`, Task 2
§6), a splice whose `from` is a NULL object (`REPR(from)`), another REPR's
`elems` or `at_pos` slot left NULL (MVMContinuation's `elems`: the C jumps
to address 0), and NULL REPR data. Task 2's programs drive none of these
(they crash the process); `vmarray_elements_test.zig` checks the first two
in forked children (both SIGSEGV).

## 4. Against Task 2's sections 4-6

- Section 4: every bullet agrees with the source. Precision added here: the
  rejected-`unshift` bullet ("element 0 is a zero") holds when the unshift
  had to make front room (`start == 0`). When `start > 0` after a `shift`,
  element 0 becomes the value that was shifted off (row 19b), because `shift`
  never clears its slot (row 20).
- Section 5: agree with the ruling (memmove semantics for the eleven memcpy
  kinds, the forward element copy kept for STR and promoted OBJ).
- Section 6: agree with every row but one. The row "a splice that copies
  elements into an array of a kind without storage -> `abort()`" (and the
  matching coverage row at line 145) is incomplete (correction, 2026-11-16,
  Task 3 fix round 1): the abort happens when a six kind is on **either**
  side and the kinds differ (`VMArray.c:957` target, `958` source); with the
  same six kind on both sides the fast path copies 0 bytes and nothing
  happens (row 22c). A dated note to that effect is appended to Task 2's
  row. One addition to the "untracked pointers
  resurrected in OBJ/STR arrays" row: a third path, besides the rejected
  `pop` and the offset-0 self-splice with `start > 0`, is a **rejected
  `unshift` with `start > 0`** after a `shift` (row 19b). Not driven by any
  differential case. **Report to the user.** Also new here, though not a
  crash: the NULL-versus-`VMNull` holes of row 22b, and `spec_to_repr_data`
  ignoring an object element type on recompose (row 31b).
