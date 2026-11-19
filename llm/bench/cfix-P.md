# cfix area P: splice sources VMArray cannot copy from (P1, P2, P3) (Task 3)

```
Branch:    vmarray-splice-guards, from origin/main f112c3998, in P (local only, not pushed)
Commits:   c1ff96d40185384bcb30af779d427392ddc2e22f "Refuse a VMArray splice from a non-empty source that is not a VMArray" (P1)
           0b32272b50d788f5347c36769b4c0bb9b693f87b "Refuse a VMArray splice into or out of a kind without storage" (P2)
           e9c53319438a7ab3616a3d5f76035823de72c07f "Refuse a VMArray splice between element kinds that would be reinterpreted" (P3)
Diff:      src/6model/reprs/VMArray.c, +25 lines, one hunk in asplice (between the offset check and
           enter_single_user); each commit only adds lines to the block the first one opens
Prefixes:  /tmp/claude-1000/cfix-P (defaults), /tmp/claude-1000/cfix-P-asan (--asan --no-mimalloc), built
           from `git archive vmarray-splice-guards` copies /tmp/claude-1000/cfix-src-P{,-asan}
           (cfix-P-raw/build/export-build.sh, unchanged from Task 2's); the built VMArray.c is
           byte-identical to the branch's. Commits were made without checking the branch out
           (cfix-P-raw/build/mkcommit.sh: read-tree / hash-object / commit-tree on a temporary index)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b), only the libmoar swapped
Raw:       cfix-P-raw/repro/, cfix-P-raw/cmp.txt, cfix-P-raw/pr-repro/ (the PR text's three programs on
           cfix-base, cfix-asan, cfix-P, cfix-P-asan), cfix-P-raw/suites/, cfix-P-raw/build/
```

## 1. The fix

The whole change, in asplice after the "Illegal splice offset" check and before `enter_single_user`:

```c
    /* Refuse a source copy_elements cannot copy from, before anything is
     * changed. An empty source of any kind copies nothing and is fine. */
    if (elems1 > 0) {
        MVMArrayREPRData *s_repr_data;                                     /* P2 */
        MVMuint16 s_kind, d_kind;                                          /* P3 */
        if (REPR(from)->ID != MVM_REPR_ID_VMArray)                         /* P1 */
            MVM_exception_throw_adhoc(tc,
                "MVMArray: Can only splice from a VMArray, got a %s", REPR(from)->name);
        s_repr_data = (MVMArrayREPRData *)STABLE(from)->REPR_data;         /* P2 */
        if (s_repr_data->elem_size == 0 || repr_data->elem_size == 0)
            MVM_exception_throw_adhoc(tc, "MVMArray: Unhandled slot type");
        /* The elements are copied as registers of these kinds, without    (P3)
         * conversion: only allow the pairs where that is still a value of
         * the target's kind (a string is an object, int and uint convert). */
        s_kind = slot_type_to_kind(s_repr_data->slot_type);
        d_kind = slot_type_to_kind(repr_data->slot_type);
        if (s_kind != d_kind
                && !(s_kind == MVM_reg_str && d_kind == MVM_reg_obj)
                && !((s_kind == MVM_reg_int64 || s_kind == MVM_reg_uint64)
                    && (d_kind == MVM_reg_int64 || d_kind == MVM_reg_uint64)))
            MVM_exception_throw_adhoc(tc,
                "MVMArray: Cannot splice %s elements into an array of %s elements",
                MVM_reg_get_debug_name(tc, s_kind), MVM_reg_get_debug_name(tc, d_kind));
    }
```

(The `/* P1 */` .. markers are for this record only; they are not in the code.)

**Checked against the C, every caller-visible path.**
- The only callers of the splice REPR function are the `splice` op (interp.c:2321, and the JIT's call
  to the same function or to MVM_repr_pos_splice) and P6opaque's positional delegation
  (P6opaque.c:1519, which passes the source on unchanged). Nothing inside MoarVM calls asplice with a
  mixed or foreign source. aslice also uses copy_elements, but with a destination made by
  `MVM_repr_alloc_init` of the source's own type (interp.c:5196), so same kind; not touched.
- `elems1` is computed through the source's REPR before anything else (unchanged). Every check is
  inside `elems1 > 0` and before `enter_single_user`, the offset-0 start adjustment, the tail memmoves,
  set_size_internal and copy_elements: a throw leaves the target exactly as it was.
- With `elems1 == 0` nothing new runs: copy_elements copies only when `elems > 0`, so an empty source of
  any REPR or kind did and does copy nothing.
- **P1.** For a non-VMArray source with elements, copy_elements set `s_repr_data = NULL`, skipped the
  fast path (`s_repr_data &&`) and dereferenced it in `slot_type_to_kind(s_repr_data->slot_type)`, so
  every such splice crashed. Nothing that works today changes. That includes a P6opaque object with a
  positional delegate passed as the *source*: its `elems` delegates, its REPR is P6opaque, and it
  crashed. The message names the REPR (`REPR(from)->name`, e.g. "VMHash").
- **P2.** Kinds U4, U2, U1, I4, I2, I1 have `elem_size == 0` (compose, VMArray.c:1247-1290), and only
  those. `slot_type_to_kind` aborts on them, so the P2 test must come before the P3 test, which calls
  it. Paths before the change, with elements to copy:
  - different kinds, one without storage: abort() from slot_type_to_kind, for the target (957) or the
    source (958);
  - the same storage-less kind on both sides: copy_elements' fast path (same slot_type and
    elem_size) memcpy'd 0 bytes. If the target did not grow, asplice returned with elems changed
    and nothing copied (`same-fit`: elems 4, read back as `1 4 7 0`). If it grew, set_size_internal
    realloc'ed the slots to 0 bytes, stored the pointer, and zero_slots threw "Unhandled slot type"
    before ssize was updated (`same-grow`: read back as `0 0 0` on the plain build, a SEGV in
    MVM_VMArray_at_pos under ASAN).
  All of these now throw "MVMArray: Unhandled slot type" before anything changes.
  - **Deviation from cfix-baseline.md section 4**, which kept the same-kind case. I followed the
    controller's ruling for this task ("a splice into or out of a kind without storage throws"). The
    same-kind case's old result was a wrong elems or a freed buffer, so it is not something code can
    rely on. The new P2 program shows it.
  - Empty sources still work. An empty source with the target of a storage-less kind returns early
    when count is 0 (`empty-into`). When count > 0, upstream already throws from zero_slots
    (downsizing); that is unchanged (`cfix-P-raw/hand/p2-empty-count.nqp`: "DIED MVMArray: Unhandled
    slot type, elems 3" on cfix-base and on cfix-P). An empty array of a storage-less kind as the source of a deletion
    also works (`empty-src`).
- **P3.** copy_elements' element path passes the register through unchanged:
  `at_pos(..., source_kind)` then `bind_pos(..., target_kind)`, where `kind` is the register kind of
  slot_type_to_kind (obj, str, int64 for I*, uint64 for U*, num64 for N*). Directions, with a
  non-empty source:

  | pair (register kinds) | before | rule |
  |---|---|---|
  | same kind (incl. any int width ↔ int width, num32 ↔ num64, uint ↔ uint) | works (bind_pos narrows or widens) | kept |
  | str → obj | an MVMString is an MVMObject (MVMString.h:72-75): the array gets a string object | kept |
  | int64 ↔ uint64 (any widths) | the same 64-bit register, bind_pos narrows (`300` → uint8 `44`) | kept |
  | obj → str | an object stored as a string pointer | throws |
  | obj or str ↔ int / uint / num | integer bits as a pointer (the collector follows it) or a pointer as a number | throws |
  | int / uint ↔ num | the bits reinterpreted (`4607182418800017408` → `1`) | throws |

  The register-kind pairs are exactly what the condition tests. A storage-less kind never reaches
  `slot_type_to_kind` (P2 first).
- The checks come after the offset check, so an illegal offset with a bad source still gives "Illegal
  splice offset" first, as before.
- Self-splice (`from == root`): the source has the target's kind, so no P2 or P3 throw, except a
  storage-less kind with elements, which now throws (it went through the P2 same-kind path before).

**Message choices** (new behaviour, flagged for the maintainers):
- P1: "MVMArray: Can only splice from a VMArray, got a %s". It is in the style of the neighbouring
  "MVMArray: write_buf requires an integer type". The alternative is to support any positional source
  by copying through its at_pos (copy_elements already calls `REPR(src)->pos_funcs.at_pos` on the
  element path, but it needs a source kind, and a non-VMArray has none to read).
- P2: the existing "MVMArray: Unhandled slot type", as every other op on these kinds gives.
- P3: "MVMArray: Cannot splice %s elements into an array of %s elements", with
  MVM_reg_get_debug_name of the two register kinds (`obj`, `str`, `int64`, `uint64`, `num64`), e.g.
  "Cannot splice int64 elements into an array of num64 elements". For the numeric pairs the
  alternative is to convert (the code's own comment: "actually should coerce between source_kind and
  target_kind here"); this change only stops the reinterpretation.

**Three commits.** They are three defects: a NULL dereference, an abort on an unhandled kind, and a
reinterpretation. Each commit adds lines to the block the first one opens, so no commit rewrites
another's lines.

**Hunk placement.** The hunk is inserted after line 1056; its trailing context is
`enter_single_user(tc, body);` and the comment that follows it. Area S's asplice hunk is at
`if (offset == 0)`, line 1065, 6 lines further down. `git merge-tree --write-tree` of this branch with
vmarray-self-splice-memmove, with vmarray-size-overflow and with vmarray-stale-slots is clean each
time, so the PRs do not conflict.

## 2. Reproducers, before and after

| program | cfix-base / cfix-asan (before) | cfix-P / cfix-P-asan (after, identical) |
|---|---|---|
| `P1-splice-from-non-vmarray.nqp` | SIGSEGV / ASAN SEGV at 0x8 in copy_elements | `splice from a hash: DIED MVMArray: Can only splice from a VMArray, got a VMHash`, `after: 3 elements` |
| `P1-splice-empty-non-vmarray.nqp` (new) | `delete one through an empty hash: elems 2: 1 3`, `nothing through an empty hash: elems 2: 1 3` | identical |
| `P2-splice-no-storage-kind.nqp target`, `source` | SIGABRT (exit 134) | `target: DIED MVMArray: Unhandled slot type` / `source: DIED ...`, `survived` |
| `P2-splice-no-storage-same-kind.nqp same-fit` (new) | `returned, elems 4`, `back to int8: elems 4: 1 4 7 0` | `DIED MVMArray: Unhandled slot type`, `back to int8: elems 3: 1 4 7` |
| `... same-grow` (new) | plain: `DIED MVMArray: Unhandled slot type`, `back to int8: elems 3: 0 0 0`; ASAN: the same line, then SEGV at address 0 in MVM_VMArray_at_pos (the slots realloc'ed to 0) | `DIED ...`, `back to int8: elems 3: 1 4 7`, no ASAN report |
| `... empty-src`, `empty-into` (new) | `returned, elems 2: 5 7`; `returned, elems 3` | identical |
| `P3-splice-cross-kind.nqp int-into-obj` | returns, SIGSEGV in the collection (ASAN in VMArray_gc_mark) | `DIED MVMArray: Cannot splice int64 elements into an array of obj elements`, `gc: survived` |
| `... obj-into-int` | element 1 is an address | `DIED ... obj elements into an array of int64 elements` |
| `... num-from-int` | `element 0 = 1` | `DIED ... int64 elements into an array of num64 elements` |
| `... str-into-obj`, `empty-other` (controls) | `element 1: MVMString`; `str: a c`, `u8: 1 3 (elems 2)` | identical |
| `P3-splice-kind-matrix.nqp` (new) | part 1: all 64 pairs `returned`; part 2: all 64 `elems 1` | part 1: the 41 pairs of the rule `DIED` (elems 0), the 23 kept pairs print the same values as before; part 2: all 64 `elems 1` |

The matrix (kinds obj, str, int, int8, uint8, uint64, num, num32), checked by diff against the base
output: exactly 41 lines differ, all `DIED` after the fix. The kept 23 are: obj→obj, str→obj,
str→str, the 16 int/uint pairs, and the 4 num pairs. Plain and ASAN outputs are identical on both sides.

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-P -o cfix-P-raw/repro` and `-p cfix-P-asan`: 44 program/case pairs each, 88
outputs. Compared by `cfix-P-raw/cmp-repro.sh` (described in cfix-T.md section 3), the result in
`cfix-P-raw/cmp.txt` is 69 same and 19 differing:
- 18 are the expected flips above:
  - P1 (2 files);
  - P2 target/source (4);
  - P3 int-into-obj, obj-into-int, num-from-int (6);
  - the new same-fit and same-grow (4);
  - the matrix (2).
- 1 is `B1-read-buf-past-storage.raku` plain (`past1: 1`, `past4: 16844807`). It prints bytes past a
  block and varies on cfix-base too. Noise.

These are among the same: the P1, P2 and P3 controls; the new empty-source programs; S1, T3, G1 and the
rest. O1 `int64` and N2 were also the same this time.

## 4. Suites

`cfix-maketest-driver.sh cfix-P-raw/suites cfix-P` (probes map `/tmp/claude-1000/cfix-P/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 0.63) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (128 s, load 0.92) | identical (`diff` empty) |

## 5. Call sites of nqp::splice in nqp and Rakudo

**What was searched.**
- The tested sources, read-only with `git grep` at nqp 305ff2f77 and rakudo c6d6fc3c6b: nqp `src/`,
  and rakudo `src/` and `lib/`.
- The checkouts' HEADs (nqp 41e7210ba, rakudo 042608fb82) have the identical list of lines.
- 18 nqp sites (3 of them in the JS backend, not MoarVM) and 138 rakudo sites.
- One QAST-generated splice: RakuAST code.rakumod:2319. It splices a Junction's `$!eigenstates` (an
  IterationBuffer) into an nqp list.
- The test files (`t/`) are not listed: they run under the suites.

For each kind combination that now throws, can any site produce it with a non-empty source?

| combination now refused (non-empty source) | sites that could produce it |
|---|---|
| a source that is not a VMArray (P1) | none. All sources are nqp lists/arrays (`nqp::list`, `[...]`, `@x` in nqp code), IterationBuffers and List `$!reified` buffers, native arrays (`nqp::create(self)`, typed `intarray:D` / `strarray:D` / ... parameters), Blobs/Bufs (`Blob:D`, `int @values`), and Uni/NFD (`nqp::strtocodes(..., nqp::create(NFD))`, `.NFD`): all REPR VMArray. A P6opaque source with elements would have crashed before. |
| a storage-less kind (P2) | none. No site creates arrays of 1/2/4-bit element types, and with elements they need a recompose. |
| obj/str ↔ int/uint/num, obj → str (P3) | none. The object-array sites all splice object arrays into object arrays. Examples: the metamodel's `role_typecheck_list` / `roles` / `attributes` / `concretizations`; Actions' and RakuAST's QAST and pod lists; `nqp::split` results (slurpy_array_type, an object array), as in Internals.rakumod:1395 and Str.rakumod:3107/3129; Str.rakumod's `$needles` / `$pins` IterationBuffers. The str-array sites (native_array.rakumod strarray) splice `strarray:D`, `nqp::create(self)` or `$empty_s`. |
| int/uint ↔ num (P3) | none. The numarray sites splice `numarray:D`, `nqp::create(self)` or `$empty_n`. The int sites are all int/uint, which stays allowed. |

The int/uint sites that stay allowed are:
- Buf.rakumod: `int @values` into any Buf (410, 1193, 1411, 1428, and `from` in `!spread`, 88 and
  268); Blob into Blob/Buf,
  including the mixed-width `~` (1466-1467, and core.e Fixups.rakumod:458-459); `nqp::list_i(x)` in
  `!splice-native`;
- JSON.rakumod:90-113: `nqp::list_i` and `.NFD` into an NFD (uint32);
- Str.rakumod:2785/2807: NFD into NFD;
- IO/Path.rakumod:663/693: buf8 into buf8;
- native_array.rakumod: intarray and uintarray STORE, append and splice.

**Empty sources of another kind** stay allowed:
- `$empty := nqp::list` into native or str arrays and IterationBuffers (Str.rakumod:22,
  Iterator.rakumod:16, Internals.rakumod:111);
- `$empty := nqp::list_i` into any Buf (Buf.rakumod:1345-1353);
- `nqp::list()` in NFA.nqp:1048 / 1422 (into the NFA's state lists);
- `$empty-array` in HLL/Backend.nqp.

**Conclusion.** No call site in nqp or Rakudo can produce a combination that now throws with a
non-empty source. Module code outside these two repositories was not searched.

## 6. Seen on the way (reported, not fixed)

- MVM_VMArray_at_pos's default arm (VMArray.c:356) passes `repr_data->slot_type` to
  `MVM_reg_get_debug_name`, which takes a register kind. For the storage-less slot types 12-17 the
  message prints the name of whatever register kind has that number (or "unknown"), not the slot
  type. That is only the message; not on
  the list, not changed.

## 7. Draft PR text

Title: **Refuse VMArray splices from sources it cannot copy from**

Body:

> This makes `nqp::splice` throw, before the target array is changed, in three cases that used to
> crash, abort or silently reinterpret bits. All three only apply when the source has elements: an
> empty source of any kind or REPR still copies nothing, so deleting with an empty list
> (`nqp::splice($buf, nqp::list_i(), $i, $n)`, `nqp::splice($strs, nqp::list(), $i, $n)`) works as
> before. The choices, which you may want to change:
>
> 1. **A source that is not a VMArray** now throws "MVMArray: Can only splice from a VMArray, got a
>    \<REPR name\>". Before, copy_elements read the source's REPR data as a VMArray's, which is NULL
>    for anything else, and crashed. The alternative would be to support any positional source by
>    copying through its at_pos.
> 2. **A source or target of a kind without storage** (the 1, 2 and 4 bit integer element types,
>    elem_size 0) now throws "MVMArray: Unhandled slot type", the message every other operation gives
>    for these kinds. Before:
>    - between such a kind and another one, slot_type_to_kind reached `abort()`;
>    - with the same such kind on both sides, the splice either returned with `elems` changed and
>      nothing copied, or threw from zero_slots after the slots had been reallocated to 0 bytes.
>
>    An array of such a kind only has elements after its type was recomposed while it was alive.
> 3. **Element kinds whose registers do not convert** now throw "MVMArray: Cannot splice \<kind\>
>    elements into an array of \<kind\> elements". When the kinds differ, copy_elements reads each
>    element in the source's register kind and binds it in the target's, passing the same register
>    through ("actually should coerce between source_kind and target_kind here"). The refused pairs
>    are:
>    - obj or str to or from int, uint or num;
>    - obj into str;
>    - int or uint to or from num.
>
>    The pairs that work today are kept:
>    - the same kind;
>    - str into obj (an MVMString is an MVMObject, so the array gets a string object);
>    - int and uint of any width into each other (bind_pos narrows; Rakudo splices `int @values` into
>      bufs);
>    - num32 and num64.
>
>    For the int/num pairs, converting the value instead of throwing would be the alternative.
>
> I searched every `nqp::splice` in nqp and Rakudo. None of them can produce one of the refused
> combinations with a non-empty source. Their sources are VMArrays of the same kind family, or empty
> lists.
>
> To reproduce on a stock nqp, three programs (each crashes before the change, so they are separate).
> A non-VMArray source:
>
> ```
> my $a := nqp::list('a', 'b', 'c');
> my $r;
> try { nqp::splice($a, nqp::hash('k', 1), 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
> say("splice from a hash: $r");
> say("elems " ~ nqp::elems($a) ~ ": " ~ nqp::join(' ', $a));
> nqp::splice($a, nqp::hash(), 1, 1);
> say("delete through an empty hash: " ~ nqp::join(' ', $a));
> ```
>
> Before: SIGSEGV before anything is printed (AddressSanitizer: SEGV on address 0x8 in
> copy_elements). After:
>
> ```
> splice from a hash: DIED MVMArray: Can only splice from a VMArray, got a VMHash
> elems 3: a b c
> delete through an empty hash: a c
> ```
>
> A kind without storage:
>
> ```
> sub inttype(int $bits, int $unsigned) {
>     my $t := nqp::newtype(nqp::null(), 'P6int');
>     my $h := nqp::hash('bits', $bits);
>     if $unsigned { $h<unsigned> := 1 }
>     nqp::composetype($t, nqp::hash('integer', $h));
>     $t
> }
> my $ty := nqp::newtype(nqp::null(), 'VMArray');
> nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(8, 0))));
> my $a := nqp::create($ty);
> nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
> # recompose the live array's type to a 4-bit element type (elem_size 0)
> nqp::composetype($ty, nqp::hash('array', nqp::hash('type', inttype(4, 1))));
> my $r;
> try { nqp::splice($a, nqp::list_i(9), 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
> say("splice into it: $r, elems " ~ nqp::elems($a));
> try { nqp::splice(nqp::list_i(5, 6), $a, 1, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
> say("splice from it: $r");
> ```
>
> Before: SIGABRT with no message, on a plain and an AddressSanitizer build. After:
>
> ```
> splice into it: DIED MVMArray: Unhandled slot type, elems 3
> splice from it: DIED MVMArray: Unhandled slot type
> ```
>
> Element kinds:
>
> ```
> sub try-splice($name, $target, $source) {
>     my $r;
>     try { nqp::splice($target, $source, 0, 0); $r := 'returned'; CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
>     say("$name: $r, elems " ~ nqp::elems($target));
> }
> my $i := nqp::list_i();
> try-splice('obj into int', $i, nqp::list(nqp::hash()));
> say("  element 0: " ~ nqp::atpos_i($i, 0)) if nqp::elems($i);
> my $n := nqp::list_n();
> try-splice('int into num', $n, nqp::list_i(4607182418800017408));
> say("  element 0: " ~ nqp::atpos_n($n, 0)) if nqp::elems($n);
> my $s := nqp::list_s();
> try-splice('obj into str', $s, nqp::list(nqp::hash()));
> nqp::setelems($s, 0);
> # kept as they are
> my $o := nqp::list();
> try-splice('str into obj', $o, nqp::list_s('x'));
> say("  element 0: " ~ nqp::reprname(nqp::atpos($o, 0)));
> my $u8t := nqp::newtype(nqp::null(), 'P6int');
> nqp::composetype($u8t, nqp::hash('integer', nqp::hash('bits', 8, 'unsigned', 1)));
> my $buft := nqp::newtype(nqp::null(), 'VMArray');
> nqp::composetype($buft, nqp::hash('array', nqp::hash('type', $u8t)));
> my $buf := nqp::create($buft);
> try-splice('int into uint8', $buf, nqp::list_i(65, 300));
> say("  elements: " ~ nqp::atpos_i($buf, 0) ~ ' ' ~ nqp::atpos_i($buf, 1));
> my $strs := nqp::list_s('a', 'b', 'c');
> nqp::splice($strs, nqp::list(), 1, 1);
> say("delete from str through an empty obj list: " ~ nqp::join(' ', $strs));
> nqp::splice($buf, nqp::list_n(), 0, 1);
> say("delete from uint8 through an empty num list: elems " ~ nqp::elems($buf));
> # last, because before the change the collector crashes on it
> my $o2 := nqp::list();
> try-splice('int into obj', $o2, nqp::list_i(280267669825));
> nqp::force_gc();
> say("survived a collection");
> ```
>
> Before (the address differs from run to run):
>
> ```
> obj into int: returned, elems 1
>   element 0: 3424972547752
> int into num: returned, elems 1
>   element 0: 1
> obj into str: returned, elems 1
> str into obj: returned, elems 1
>   element 0: MVMString
> int into uint8: returned, elems 2
>   elements: 65 44
> delete from str through an empty obj list: a c
> delete from uint8 through an empty num list: elems 1
> int into obj: returned, elems 1
> (SIGSEGV; AddressSanitizer: SEGV on an unknown address in VMArray_gc_mark)
> ```
>
> After:
>
> ```
> obj into int: DIED MVMArray: Cannot splice obj elements into an array of int64 elements, elems 0
> int into num: DIED MVMArray: Cannot splice int64 elements into an array of num64 elements, elems 0
> obj into str: DIED MVMArray: Cannot splice obj elements into an array of str elements, elems 0
> str into obj: returned, elems 1
>   element 0: MVMString
> int into uint8: returned, elems 2
>   elements: 65 44
> delete from str through an empty obj list: a c
> delete from uint8 through an empty num list: elems 1
> int into obj: DIED MVMArray: Cannot splice int64 elements into an array of obj elements, elems 0
> survived a collection
> ```
>
> The same with AddressSanitizer, without a report. I also checked every pair of eight kinds (obj, str,
> int, int8, uint8, uint64, num, num32) both ways. With one element, exactly the 41 refused pairs now
> throw, and the 23 others give the values they gave before. With an empty source, all 64 pairs delete
> as before. `make test` of nqp and Rakudo gives the same per-file results as before.
>
> The checks sit at the top of asplice, before anything is changed, so a refused splice leaves the
> target as it was.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
