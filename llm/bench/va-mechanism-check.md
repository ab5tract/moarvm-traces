# va mechanism check: P6int and MVMCode through `repr.Ops` (spec 5.5)

```
Task:      VMArray campaign, Task 8 Step 8 (spec 5.5, "Not array-only by accident")
MoarVM:    zig-vmarray; repr.zig as of 472cf7e92 (the one change below), the test at bea13d101
REPRs:     P6int (src/6model/reprs/P6int.c, table at 317-355): a leaf with its own box functions, no storage
           MVMCode (src/6model/reprs/MVMCode.c, table at 86-114): reference fields in its body
           (sf, outer, code_object, name, and state_vars hanging off it)
Also:      a scan of all 47 C REPR tables (src/6model/reprs/*.c) for what the builder cannot express
Check:     src/zig/6model/test/repr_ops_test.zig, test "P6int and MVMCode, declared for repr.Ops, get their
           C tables' shape" (repr-test, 51/51 at bea13d101 on both switch settings; va-suites.md)
```

MVMCode was chosen over MVMHash because its references are plain fields of the
body (`MVMHash`'s live in a hash table the body embeds), which is the case the
spec names.

## 1. What each REPR would declare

The declarations, as `repr.Ops` reads them, and as the test compiles them:
the code below is copied from `src/zig/6model/test/repr_ops_test.zig`
(corrected at the final review's fix wave, 2026-11-17: this section first
printed declarations with self-named functions, `pub const serialize =
serialize;`, which refer to themselves and would not compile, and said the
test declares them "exactly so"; the test has always used the `t`-prefixed
stubs below). Each slot names a function of exactly the field's type; the
signatures are the translate-c types of `MVMREPROps` (src/6model/6model.h).
The bodies are the REPRs' code and are not part of the question; the stubs
are empty. One stub serves every slot of its type
(`deserialize_repr_data` and `deserialize_stable_size` share `tStReader`).
In a real port `type_object_for` would refer to the REPR's own table, as
VMArray's does (`Ser.typeObjectFor(&table)`); the stub needs no table.

### P6int

```zig
// src/zig/6model/test/repr_ops_test.zig: the stubs both REPRs share, then P6int
const Tc = [*c]c.MVMThreadContext;
const St = [*c]c.MVMSTable;
const Obj = [*c]c.MVMObject;

fn tObjectFor(_: Tc, _: Obj) callconv(.c) Obj {
    return null;
}
fn tCopyTo(_: Tc, _: St, _: ?*anyopaque, _: Obj, _: ?*anyopaque) callconv(.c) void {}
fn tSetInt(_: Tc, _: St, _: Obj, _: ?*anyopaque, _: c.MVMint64) callconv(.c) void {}
fn tGetInt(_: Tc, _: St, _: Obj, _: ?*anyopaque) callconv(.c) c.MVMint64 {
    return 0;
}
fn tSetUint(_: Tc, _: St, _: Obj, _: ?*anyopaque, _: c.MVMuint64) callconv(.c) void {}
fn tGetUint(_: Tc, _: St, _: Obj, _: ?*anyopaque) callconv(.c) c.MVMuint64 {
    return 0;
}
fn tStorageSpec(_: Tc, _: St) callconv(.c) [*c]const c.MVMStorageSpec {
    return null;
}
fn tSerialize(_: Tc, _: St, _: ?*anyopaque, _: [*c]c.MVMSerializationWriter) callconv(.c) void {}
fn tDeserialize(_: Tc, _: St, _: Obj, _: ?*anyopaque, _: [*c]c.MVMSerializationReader) callconv(.c) void {}
fn tSerializeReprData(_: Tc, _: St, _: [*c]c.MVMSerializationWriter) callconv(.c) void {}
fn tStReader(_: Tc, _: St, _: [*c]c.MVMSerializationReader) callconv(.c) void {}
fn tFreeReprData(_: Tc, _: St) callconv(.c) void {}
fn tCompose(_: Tc, _: St, _: Obj) callconv(.c) void {}
fn tSpesh(_: Tc, _: St, _: [*c]c.MVMSpeshGraph, _: [*c]c.MVMSpeshBB, _: [*c]c.MVMSpeshIns) callconv(.c) void {}
fn tGcMark(_: Tc, _: St, _: ?*anyopaque, _: [*c]c.MVMGCWorklist) callconv(.c) void {}
fn tGcFree(_: Tc, _: Obj) callconv(.c) void {}

/// P6int as `repr.Ops` would read it (P6int.c:317-355).
const P6int = struct {
    pub const name = "P6int";
    pub const ID = c.MVM_REPR_ID_P6int;
    pub const type_object_for = tObjectFor;
    pub const allocate = &c.MVM_gc_allocate_object;
    pub const copy_to = tCopyTo;
    pub const box_funcs = struct {
        pub const set_int = tSetInt;
        pub const get_int = tGetInt;
        pub const set_uint = tSetUint;
        pub const get_uint = tGetUint;
    };
    pub const get_storage_spec = tStorageSpec;
    pub const serialize = tSerialize;
    pub const deserialize = tDeserialize;
    pub const serialize_repr_data = tSerializeReprData;
    pub const deserialize_repr_data = tStReader;
    pub const deserialize_stable_size = tStReader;
    pub const gc_free_repr_data = tFreeReprData;
    pub const compose = tCompose;
    pub const spesh = tSpesh;
};
```

Against P6int.c's table, field by field: `initialize`, `change_type`,
`gc_mark`, `gc_free`, `gc_cleanup`, `gc_mark_repr_data`, `unmanaged_size`,
`describe_refs` are NULL there and not declared here (the builder gives null);
`attr_funcs`, `pos_funcs`, `ass_funcs` are the three `MVM_REPR_DEFAULT_*_FUNCS`
macros there and not declared here (the builder gives the same defaults);
`elems` is `MVM_REPR_DEFAULT_ELEMS` there and not declared here; the five box
slots P6int fills with `MVM_REPR_DEFAULT_SET_NUM`, `_GET_NUM`, `_SET_STR`,
`_GET_STR`, `_GET_BOXED_REF` are not declared in the nested `box_funcs` and
get exactly those. Every other field is declared.

The three exported C symbols (`MVMP6int_set_int`, `MVMP6int_get_int`,
`MVMP6int_is_unsigned`, plus `MVMP6int_initialize`) are the REPR file's
business, exported as VMArray.zig exports its ten (an `exports` list checked
against the header's signatures); nothing in `repr.zig` is involved.

### MVMCode

```zig
// src/zig/6model/test/repr_ops_test.zig, with the stubs above
/// MVMCode as `repr.Ops` would read it (MVMCode.c:86-114).
const MVMCode = struct {
    pub const name = "MVMCode";
    pub const ID = c.MVM_REPR_ID_MVMCode;
    pub const type_object_for = tObjectFor;
    pub const allocate = &c.MVM_gc_allocate_object;
    pub const copy_to = tCopyTo;
    pub const get_storage_spec = tStorageSpec;
    pub const gc_mark = tGcMark;
    pub const gc_free = tGcFree;
    pub const compose = tCompose;
};
```

Against MVMCode.c's table: the four default groups and `elems` are the
macros there; `initialize`, `change_type`, the five (de)serialization slots,
`gc_cleanup`, `gc_mark_repr_data`, `gc_free_repr_data`, `spesh`,
`unmanaged_size`, `describe_refs` are NULL there. Neither needs a
declaration.

## 2. The check, run

The test declares both structs as printed in section 1, builds
`repr.Ops` of each and compares `repr.dumpOps` of the result with the dump of
the library's own C table (`MVMP6int_initialize`, `MVMCode_initialize`): the
two dumps are equal line for line for both REPRs (each of the 60 leaves the
same class `own`/`default`/`null`, and the same name and ID), and P6int's
`allocate` is the very `MVM_gc_allocate_object` of the C table. It passed on
first compile; no declaration had to be adjusted, and no signature above is
a guess (each was checked by `fits` against the field type).

## 3. What `repr.zig` lacked, from all 47 tables

The two REPRs need nothing the builder does not have. Reading all 47 C
tables (a scan of their positional initializers against the field order of
`MVMREPROps`) found one thing a REPR could not express:

- **An explicit NULL where the builder fills a default.** MVMContinuation.c
  writes `NULL` for `elems` (where `MVM_REPR_DEFAULT_ELEMS` would go), and
  P6opaque.c writes `NULL` for `ass_funcs.get_value_storage_spec` in its own
  associative table. Before this task `repr.Ops` gave every undeclared slot
  its default and rejected `pub const elems = null` as mistyped, so neither
  table could be built. **Changed now (small, with its test)**, in
  472cf7e92, before the prefixes were built: a function slot may be declared
  `null`; a required slot (`type_object_for`, `allocate`,
  `get_storage_spec`, `compose`) still may not ("required 'compose' cannot be
  null"). Test: "a slot declared null is null although it has a default".
  The array declares no null slot; its dump still equals
  `vmarray_vtable_c.tsv`.

Seen and not a gap:

- Four C REPRs (MVMNull, MultiDimArray, P6opaque, Uninstantiable) put their
  own function in `allocate` instead of `MVM_gc_allocate_object`: a Zig
  function of the field's type fills it like any other slot.
- Every table's `type_object_for` refers to the table itself
  (`MVM_gc_allocate_stable(tc, &X_this_repr, HOW)`). VMArray.zig already does
  this (`Ser.typeObjectFor(&table)`), so the self-reference is known to work.
- Exported helpers beside the table (`MVMP6int_set_int`, `MVMHash_at_key`, ...)
  are the REPR file's exports, as VMArray's are.

Not the builder's question, but for the next REPR: MVMCode's `gc_free` frees
`body.state_vars`, which `src/core/frame.c` allocates; that is the array's
adoption pattern again (memory hanging off the object, allocated outside the
REPR file), so its allocator has the same constraint as the array's
(`va-adoption-audit.md` section 5). And its `gc_mark` is a fixed list of
body fields plus a loop: the "derive the mark from the body's fields" shape
the spec postponed (2, non-goals) would fit it, and that is a new comptime
construct, not a change to `repr.Ops`.

## Verdict

For P6int and MVMCode nothing in `repr.zig` must change: both tables come
out of `repr.Ops` with the C tables' shape, checked by a test against the
linked library. The one gap found across the 47 tables (an explicit NULL in
a slot that has a default; MVMContinuation, P6opaque) was small and is
closed, with its test, in 472cf7e92. Nothing is left for the next campaign's
first item from this check.
