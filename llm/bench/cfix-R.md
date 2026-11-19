# cfix area R: recomposing a VMArray type to another element kind (R1, X1) (Task 4)

```
Branch:    vmarray-recompose, from origin/main f112c3998, in P (local only, not pushed)
Commit:    40b44838192469b2e2842160ee783813d4f958d3 "Refuse recomposing a VMArray type to another element kind"
           (R1 and X1: one defect, compose rewriting the kind of a type that may have arrays)
Diff:      src/6model/reprs/VMArray.c, +16 -1, one hunk in compose
Prefixes:  /tmp/claude-1000/cfix-R (defaults), /tmp/claude-1000/cfix-R-asan (--asan --no-mimalloc), built from
           `git archive` copies /tmp/claude-1000/cfix-src-R{,-asan} (cfix-T-raw/build/export-build.sh); the
           built VMArray.c is byte-identical to the branch's; make exit 0, 10 s / 21 s, no warning in
           VMArray.c. (The prefixes were built from cff266f29, which has the same tree as 40b448381: only the
           commit message was reworded after the build.)
nqp/rakudo: Task 1's builds, only the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-R-raw/repro/ (run-all on both prefixes; R-recompose-matrix.nqp also on cfix-base and
           cfix-asan), cfix-R-raw/cmp.txt (cfix-B-raw/cmp-repro.sh), cfix-R-raw/pr-repro/,
           cfix-R-raw/matrix-check.py, cfix-R-raw/hand/p6num-bits16.nqp, cfix-R-raw/suites/, cfix-R-raw/build/
```

## 1. The choice and the fix

**Choice: option (b).** Once a VMArray type has been composed with an element type, a further compose
that would change the element kind (slot type or element size) throws, before anything is changed. A
recompose to the same kind stays allowed, also with another object type. A type that was never composed
with an element type (BOOTArray, `nqp::newtype` without a compose) may be composed once with any type, as
today. This is new behaviour, chosen after P6opaque, which refuses any second compose ("Type %s is already
composed", P6opaque.c:735-737), limited to the case that breaks arrays that exist.

The alternative, **option (a)**: a default arm in spec_to_repr_data that gives an object element type
object slots, and every recompose stays allowed. That fixes R1 (the object type is ignored) but leaves
every array alive at the recompose laid out for the old kind and read through the new one: X1 is the
evidence (an int8 array's 8-byte buffer read and written as eight int64 slots, a heap-buffer-overflow).

```c
         if (!MVM_is_null(tc, type)) {
             const MVMStorageSpec *spec = REPR(type)->get_storage_spec(tc, STABLE(type));
+            /* Work out the element kind; an object type (no boxed
+             * primitive) gives object slots. */
+            MVMArrayREPRData kind;
+            kind.slot_type = MVM_ARRAY_OBJ;
+            kind.elem_size = sizeof(MVMObject *);
+            spec_to_repr_data(tc, &kind, spec);
+            /* Arrays of this type may already exist; they were laid out for
+             * the current kind, so once an element type has been composed,
+             * the kind may not change. */
+            if (repr_data->elem_type && (kind.slot_type != repr_data->slot_type
+                    || kind.elem_size != repr_data->elem_size))
+                MVM_exception_throw_adhoc(tc,
+                    "MVMArray: Type %s is already composed with another element kind",
+                    MVM_6model_get_stable_debug_name(tc, st));
             MVM_ASSIGN_REF(tc, &(st->header), repr_data->elem_type, type);
-            spec_to_repr_data(tc, repr_data, spec);
+            repr_data->slot_type = kind.slot_type;
+            repr_data->elem_size = kind.elem_size;
         }
```

**Checked against the C.**
- "Already composed with an element type" is `elem_type != NULL`: type_object_for sets it to NULL with kind
  OBJ (VMArray.c:33-35); compose sets it only when the `array` info has a non-null `type`, for object and
  native element types alike; deserialize_repr_data restores it from the stream with kind OBJ when it is
  NULL (1350-1353). So elem_type NULL always goes with kind OBJ, and copying the computed kind (instead of
  calling spec_to_repr_data on repr_data) gives the same result as before in every allowed case: a first
  compose with an object type leaves OBJ (now by assignment, before by not touching it), and an allowed
  recompose has the same kind by the rule. Checked by program: every allowed pair of the matrix below prints
  exactly what upstream prints.
- The throw comes before MVM_ASSIGN_REF, so a refused compose leaves elem_type, slot_type and elem_size as
  they were (the matrix: the live array still reads its elements, a fresh array takes the old kind).
- What else the hunk changes: spec_to_repr_data's own refusals ("Unsupported int size", "... num size") now
  come before elem_type is assigned instead of after. That is not known to be visible: P6int and P6num
  refuse such sizes in their own compose and keep their default storage spec (cfix-R-raw/hand/
  p6num-bits16.nqp: P6num composed with bits 16 dies, a VMArray composed with it then gets num64 elements,
  on cfix-base and cfix-R alike).
- Callers of compose: `nqp::composetype` (interp.c:2463) and `MVM_repr_compose` (reprconv.c:43, used by
  bootstrap.c's boot_typed_array for BOOTIntArray/NumArray/StrArray: one compose each of a fresh type).
- Same-kind cases kept: the same native kind again (also through another P6int type object), obj <-> another
  object type. Different slot type with the same size (int8 <-> uint8, int64 <-> uint64, int64 <-> num64) is
  refused: arrays would be reinterpreted (campaign 8's differential has such recomposed cases; the Zig mirror
  has to follow).

**What this closes.** R1, X1, and with them the only route to a live array of a storage-less kind (int1/2/4,
uint1/2/4 with storage): an array gets such a kind only through a recompose of its type while it is alive.
Two defects that need such an array are fixed independently on their own branches (a splice into or out of
such a kind, area P; a writeint on it, area B); with this branch their reproducers cannot be set up
(section 3).

**Search of nqp and Rakudo for a recompose to another kind** (the STOP condition): none.
- nqp 305ff2f77, `git grep composetype -- src` (MoarVM backend): IO.nqp:9 and testing.nqp:80 compose a fresh
  `nqp::newtype(..., 'VMArray')` once; NQPClassHOW.nqp:374 (array types) runs only under `unless $!composed`
  (NQPClassHOW.nqp:286); NQPNativeHOW.nqp:41 composes P6int/P6num/P6str types.
- Rakudo c6d6fc3c6b: REPRComposeProtocol.nqp:8 `unless $!composed_repr` around the only array-type compose
  (163); var-lowering.rakumod:1386 composes a fresh VMArray type once; Internals.rakumod:530 is MultiDimArray
  (another REPR); NativeHOW/NativeRefHOW compose other REPRs; Metamodel::Primitives.compose_type
  (Primitives.rakumod:46-65) is the user-facing primitive, with no caller in Rakudo's sources.
- The nqp tests that compose VMArray types (t/moar/11-decode.t, t/nqp/019-file-ops.t, 059-nqpop.t,
  082-decode.t, 110-normalization.t, 111-spawnprocasync.t, 116-streaming-decoder.t,
  t/serialization/01-basic.t) each compose a fresh type once; 102-multidim.t is MultiDimArray.
- Ecosystem modules were not searched. User code that calls `Metamodel::Primitives.compose_type` or
  `nqp::composetype` twice on one array type with different kinds now dies.

## 2. Reproducers, before and after

| program | cfix-base / cfix-asan (before) | cfix-R / cfix-R-asan (after) |
|---|---|---|
| `R1-recompose-object-type.nqp` | `recompose to an object type: returned`, `push an object: DIED MVMArray: push expected int register`, `push_i: returned, elems 1`; composed once: `push an object: returned` | `recompose to an object type: DIED MVMArray: Type  is already composed with another element kind`; then the type is still int64: `push an object: DIED ... push expected int register`, `push_i: returned, elems 1`; composed once unchanged; both builds |
| `X1-recompose-wider-kind.nqp` | plain `element 7: 524296`, `bound element 7: 42` on an 8-byte buffer; ASAN heap-buffer-overflow READ in MVM_VMArray_at_pos | dies at the recompose, `MVMArray: Type  is already composed with another element kind` (exit 1: the program does not catch it); both builds, no ASAN report |
| `R-recompose-matrix.nqp` (new) | all 72 pairs `allowed` (plain and ASAN identical: the program avoids every unsafe read, see its header) | 18 allowed, 54 `DIED`; below |

(The name in the message is the type's debug name; these test types have none, hence `Type  is`. The PR
text's program sets one.)

**The matrix** (`cfix-repro/R-recompose-matrix.nqp`): first kind none/obj/obj2/int8/uint8/int64/uint64/num64/str
× second kind (the same minus none): a live array with two elements, the second compose, then the live array
and a fresh array. `cfix-R-raw/matrix-check.py base.txt cfix-R.txt` checks (cfix-R and cfix-R-asan alike:
"pairs 72, allowed 18, refused 54, violations 0"):
- allowed exactly when the first kind is none or both kinds have the same slot type and size (obj and obj2
  count as one kind): 18 pairs; every other pair (54) dies;
- every allowed pair prints exactly what cfix-base prints;
- every refused pair leaves the live array as it was (`elems 2: 5 6`, `VMArray(5) VMArray(6)`,
  `5.5 6.5`, `x y`) and the type with its first kind (the fresh array takes an element of it);
- cfix-R-asan prints the same as cfix-R (diff empty), and cfix-base the same as cfix-asan.

## 3. Every other reproducer

`run-all.sh -p cfix-R` and `-p cfix-R-asan` (98 outputs), `cfix-B-raw/cmp-repro.sh cfix-R-raw/repro R`
(`cfix-R-raw/cmp.txt`): 74 same, 24 differ.
- Expected, the area's own: R1 and X1 (both builds), R-recompose-matrix (both).
- Expected, the closed route (each program recomposes a live array's type to a storage-less kind to set its
  case up, and now dies at that compose with the new message, exit 1, before the case runs): P2 target and
  source, P2-splice-no-storage-same-kind same-fit, same-grow and empty-into (empty-src does not recompose: same),
  B3-writeint-no-storage-kind, B3-write-no-storage-state live (fresh composes once: same); each on both builds.
- Noise, each varying run to run on the baseline: B1's raku program (bytes past a block), O1 int64 (element 99
  is garbage), N2 on ASAN (RSS growth 396 vs 397 MB), and the plain B-buf-grid (its B1 lines print bytes past
  the block; `cfix-B-raw/grid-check.py base cfix-R --unchanged`: 117 such lines differ, 0 others).

## 4. Suites

`cfix-maketest-driver.sh cfix-R-raw/suites cfix-R` (probes map `/tmp/claude-1000/cfix-R/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 1.44) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (129 s, load 1.51) | identical (`diff` empty) |

## 5. Draft PR text

Title: **Refuse recomposing a VMArray type to another element kind**

Body:

> This makes a second compose of a VMArray type throw if it would change the element kind, that is, the
> slot type or the element size. The check runs before anything is changed. This is new behaviour, so
> here is the choice first. It follows P6opaque, which refuses any second compose ("Type %s is already
> composed"), but it is limited to the case that breaks existing arrays. A recompose to the same kind
> stays allowed, also with another object type. A type that was never composed with an element type
> (BOOTArray, or one fresh from `nqp::newtype`) can still be composed once with anything. The new
> message is "MVMArray: Type <name> is already composed with another element kind".
>
> The alternative would be to give object element types object slots in spec_to_repr_data, which sets
> nothing for them today, and keep allowing every recompose. That fixes the second problem below but not
> the first: arrays that exist when the type is recomposed keep storage laid out for the old kind and are
> read through the new one.
>
> The two problems. compose rewrote slot_type and elem_size in the STable's REPR data, which every array
> of the type uses. An int8 array of three elements has 8 bytes of storage. After a recompose to int64,
> its ssize of 8 means 64 bytes, and every element but the first lies past the buffer (AddressSanitizer:
> heap-buffer-overflow in MVM_VMArray_at_pos). And because spec_to_repr_data ignores
> an object element type, a type composed with int64 and recomposed with an object type kept int64 slots
> while elem_type named the object type.
>
> ```
> sub int_type(int $bits) {
>     my $t := nqp::newtype(nqp::null(), 'P6int');
>     nqp::composetype($t, nqp::hash('integer', nqp::hash('bits', $bits)));
>     $t
> }
> sub compose($type, $elem, $what) {
>     my $r := 'returned';
>     try { nqp::composetype($type, nqp::hash('array', nqp::hash('type', $elem)));
>           CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
>     say("$what: $r");
> }
>
> # An int8 array alive when its type is recomposed to int64.
> my $t1 := nqp::newtype(nqp::null(), 'VMArray');
> nqp::setdebugtypename($t1, 'Bytes');
> compose($t1, int_type(8), 'compose with int8');
> my $a := nqp::create($t1);
> nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
> compose($t1, int_type(64), 'recompose with int64');
> nqp::setelems($a, 8);
> say("elems " ~ nqp::elems($a) ~ ", element 2: " ~ nqp::atpos_i($a, 2) ~ ", element 7: " ~ nqp::atpos_i($a, 7));
>
> # A type composed with int64, recomposed with an object type.
> my $t2 := nqp::newtype(nqp::null(), 'VMArray');
> nqp::setdebugtypename($t2, 'Ints');
> compose($t2, int_type(64), 'compose with int64');
> compose($t2, nqp::what(nqp::hash()), 'recompose with an object type');
> my $b := nqp::create($t2);
> my $r := 'returned';
> try { nqp::push($b, nqp::hash()); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
> say("push an object: $r");
>
> # Same kind again, and the first compose of a type without an element type.
> compose($t2, int_type(64), 'recompose with another int64 type');
> my $t3 := nqp::newtype(nqp::null(), 'VMArray');
> compose($t3, int_type(8), 'first compose of a fresh type with int8');
> ```
>
> Before (the two elements read are past the 8-byte buffer; element 7 differs from run to run, and with
> AddressSanitizer the program stops at element 2 with a heap-buffer-overflow):
>
> ```
> compose with int8: returned
> recompose with int64: returned
> elems 8, element 2: 64, element 7: 3912022129048
> compose with int64: returned
> recompose with an object type: returned
> push an object: died: MVMArray: push expected int register
> recompose with another int64 type: returned
> first compose of a fresh type with int8: returned
> ```
>
> After (plain and AddressSanitizer builds alike):
>
> ```
> compose with int8: returned
> recompose with int64: died: MVMArray: Type Bytes is already composed with another element kind
> elems 8, element 2: 7, element 7: 0
> compose with int64: returned
> recompose with an object type: died: MVMArray: Type Ints is already composed with another element kind
> push an object: died: MVMArray: push expected int register
> recompose with another int64 type: returned
> first compose of a fresh type with int8: returned
> ```
>
> After the refused compose the int8 array is still an int8 array, and the int64 type is still an int64
> type. I also ran every pair of nine kinds (never composed, two object types, int8, uint8, int64, uint64,
> num64, str), each with a live array of two elements. With this change, the pairs that keep the kind
> (18) print exactly what they printed before. The other 54 die, and the live array and the type stay as
> they were. Types that only differ in signedness (int8 and uint8, int64 and uint64) or are int64 and num64
> count as different kinds, because existing elements would be reinterpreted.
>
> A side effect: the refusals of spec_to_repr_data itself ("Unsupported int size" and the like) now
> happen before elem_type is assigned instead of after. P6int and P6num refuse such sizes when they are
> composed, so I don't know of a way to see this.
>
> NQP and Rakudo compose each type once (NQPClassHOW and Rakudo's REPRComposeProtocol guard it, and
> the other `composetype` calls on VMArray types are on fresh types). `make test` of nqp and Rakudo gives
> the same per-file results as before. Code that composes one array type twice with different element
> kinds will now die at the second compose.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
