# cfix area P: splice sources VMArray cannot copy from (P1, P2, P3) (Task 3)

(Revised at Task 3's fix round 1, section 8. The call-site section is redone: ordinary Raku code reaches
P1 through shaped native arrays. The P3 message no longer names widths. The P2 "before" is qualified.
A type-object source is recorded as seen on the way. All three commits were recreated.)

```
Branch:    vmarray-splice-guards, from origin/main f112c3998, in P (local only, not pushed)
Commits:   0073826640e0c352fd0c0146423e30c8a0f29ec1 "Refuse a VMArray splice from a non-empty source that is not a VMArray" (P1)
           f2f306ae8df72d3e618977b5cfdbb1902507df99 "Refuse a VMArray splice into or out of a kind without storage" (P2)
           c7513438eea2763904d8807d58578a017038b617 "Refuse a VMArray splice between element kinds that would be reinterpreted" (P3)
           (before fix round 1: c1ff96d40, 0b32272b5, e9c533194; section 8)
Diff:      src/6model/reprs/VMArray.c, +36 lines, two hunks: the block in asplice (between the offset
           check and enter_single_user), and P3's message helper kind_to_elements_name after
           slot_type_to_kind; each commit only adds lines
Prefixes:  /tmp/claude-1000/cfix-P (defaults), /tmp/claude-1000/cfix-P-asan (--asan --no-mimalloc), rebuilt
           at fix round 1 from `git archive vmarray-splice-guards` (c7513438e) copies
           /tmp/claude-1000/cfix-src-P{,-asan} (cfix-P-raw/build/export-build.sh, unchanged from Task 2's);
           the built VMArray.c is byte-identical to the branch's. Commits were made without checking the
           branch out (cfix-P-raw/build/mkcommit.sh, and git commit-tree for the message-only rewrites)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b), only the libmoar swapped
Raw:       cfix-P-raw/repro/ (run-all on the fix-round-1 builds), cfix-P-raw/cmp.txt,
           cfix-P-raw/pr-repro/ (the PR text's nqp programs on cfix-base, cfix-asan, cfix-P,
           cfix-P-asan), cfix-P-raw/round1/ (shaped-array and site probes, type-object source, P2
           growth check, N2 reruns), cfix-P-raw/hand/, cfix-P-raw/suites/ (first build) and
           cfix-P-raw/suites-r1/ (fix-round-1 build), section 4, cfix-P-raw/build/
```

## 1. The fix

The block in asplice, after the "Illegal splice offset" check and before `enter_single_user`:

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
                "MVMArray: Cannot splice from an array of %s into an array of %s",
                kind_to_elements_name(s_kind), kind_to_elements_name(d_kind));
    }
```

and, for P3's message, after slot_type_to_kind:

```c
/* What a register kind from slot_type_to_kind holds, for messages. */
static const char * kind_to_elements_name(MVMuint16 kind) {
    switch (kind) {
        case MVM_reg_obj:    return "objects";
        case MVM_reg_str:    return "strings";
        case MVM_reg_int64:  return "integers";
        case MVM_reg_uint64: return "unsigned integers";
        default:             return "numbers";
    }
}
```

(The `/* P1 */` .. markers are for this record only; they are not in the code.) slot_type_to_kind
returns only obj, str, int64, uint64 and num64 (or aborts), so `default` is exactly num64.

**Checked against the C, every caller-visible path.**
- **Callers.** The only callers of the splice REPR function are:
  - the `splice` op (interp.c:2321), and the JIT's call to the same function or to MVM_repr_pos_splice;
  - P6opaque's positional delegation (P6opaque.c:1519), which passes the source on unchanged.

  Nothing inside MoarVM calls asplice with a mixed or foreign source. aslice also uses copy_elements,
  but its destination is made by `MVM_repr_alloc_init` of the source's own type (interp.c:5196), so
  the kinds match. aslice is not touched.
- **Ordering.** `elems1` is computed through the source's REPR before anything else (unchanged). Every
  check is inside `elems1 > 0` and runs before `enter_single_user`, the offset-0 start adjustment, the
  tail memmoves, set_size_internal and copy_elements. A throw therefore leaves the target exactly as
  it was.
- **Empty source.** With `elems1 == 0` nothing new runs. copy_elements copies only when `elems > 0`,
  so an empty source of any REPR or kind copied nothing before and copies nothing now.
- **P1.** For a non-VMArray source with elements, copy_elements set `s_repr_data = NULL`, skipped the
  fast path (`s_repr_data &&`) and dereferenced it in `slot_type_to_kind(s_repr_data->slot_type)`.
  Every such splice crashed, so nothing that worked before changes. This includes:
  - shaped native arrays (MultiDimArray), which ordinary Raku code passes (section 5);
  - P6opaque objects with a positional delegate.

  The message names the REPR (`REPR(from)->name`, for example "VMHash" or "MultiDimArray").
- **P2.** Kinds U4, U2, U1, I4, I2, I1 have `elem_size == 0` (compose, VMArray.c:1247-1290), and no
  other kind does. `slot_type_to_kind` aborts on them, so the P2 test must come before the P3 test,
  which calls it. Paths before the change, with elements to copy:
  - **Different kinds, one of them without storage.** Two sub-cases:
    - If the splice reached copy_elements, slot_type_to_kind called abort(). It got there with a
      storage-less source (line 958), and with a storage-less target that did not have to grow
      (line 957).
    - A storage-less target that had to grow never got there. set_size_internal reallocated the slots
      to 0 bytes, then zero_slots threw "MVMArray: Unhandled slot type". For example, a fresh uint4
      array (ssize 0) as the target dies that way on cfix-base and on cfix-asan
      (`cfix-P-raw/round1/p2-grow/`). Only that message survives the fix; the realloc no longer
      happens.
  - **The same storage-less kind on both sides.** copy_elements' fast path (same slot_type and
    elem_size) memcpy'd 0 bytes.
    - If the target did not grow, asplice returned with elems changed and nothing copied (`same-fit`:
      elems 4, read back as `1 4 7 0`).
    - If it grew, set_size_internal reallocated the slots to 0 bytes and stored the pointer. zero_slots
      then threw before ssize was updated (`same-grow`: read back as `0 0 0` on the plain build, a SEGV
      in MVM_VMArray_at_pos under ASAN).

  All of these now throw "MVMArray: Unhandled slot type" before anything changes.
  - **Deviation from cfix-baseline.md section 4**, which kept the same-kind case. I followed the
    controller's ruling for this task ("a splice into or out of a kind without storage throws"). The
    old same-kind result was a wrong elems or a freed buffer, which code cannot rely on.
  - **Empty sources still work.**
    - An empty source into a storage-less target returns early when count is 0 (`empty-into`).
    - When count > 0, upstream already throws from zero_slots (the array is downsizing), and that is
      unchanged. `cfix-P-raw/hand/p2-empty-count.nqp` gives "DIED MVMArray: Unhandled slot type,
      elems 3" on cfix-base and on cfix-P.
    - An empty array of a storage-less kind as the source of a deletion also works (`empty-src`).
- **P3.** copy_elements' element path passes the register through unchanged:
  `at_pos(..., source_kind)` then `bind_pos(..., target_kind)`, where each kind is slot_type_to_kind's
  register kind (obj, str, int64 for I*, uint64 for U*, num64 for N*). The directions, with a
  non-empty source:

  | pair (register kinds) | before | rule |
  |---|---|---|
  | same kind (incl. any int width ↔ int width, num32 ↔ num64, uint ↔ uint) | works (bind_pos narrows or widens) | kept |
  | str → obj | an MVMString is an MVMObject (MVMString.h:72-75): the array gets a string object | kept |
  | int64 ↔ uint64 (any widths) | the same 64-bit register, bind_pos narrows (`300` → uint8 `44`) | kept |
  | obj → str | an object stored as a string pointer | throws |
  | obj or str ↔ int / uint / num | integer bits used as a pointer (the collector follows it), or a pointer read as a number | throws |
  | int / uint ↔ num | the bits reinterpreted (`4607182418800017408` → `1`) | throws |

  The condition tests exactly these register-kind pairs. A storage-less kind never reaches
  `slot_type_to_kind`, because P2 runs first.
- **Offset errors.** The checks come after the offset check, so an illegal offset with a bad source
  still gives "Illegal splice offset" first, as before.
- **Self-splice** (`from == root`). The source has the target's kind, so neither P2 nor P3 throws.
  The exception is a storage-less kind with elements: it now throws, where before it took P2's
  same-kind path.

**Message choices** (new behaviour, flagged for the maintainers):
- **P1:** "MVMArray: Can only splice from a VMArray, got a %s". It follows the style of the
  neighbouring "MVMArray: write_buf requires an integer type". There are two alternatives (section 5
  shows that ordinary Raku code reaches this):
  - The VM could copy from any positional source through its at_pos. copy_elements already calls
    `REPR(src)->pos_funcs.at_pos` on its element path, but it would need a register kind to read a
    non-VMArray with. Whether that makes MultiDimArray sources work was not tried.
  - The Rakudo callers could handle shaped arrays themselves.
- **P2:** the existing "MVMArray: Unhandled slot type", which every other op on these kinds gives.
- **P3:** "MVMArray: Cannot splice from an array of %s into an array of %s". The words are "objects",
  "strings", "integers", "unsigned integers" and "numbers", with no widths. An int8 source reads
  "integers", not "int64" as in the first version. For the numeric pairs, the alternative is to
  convert the value; the code's own comment says "actually should coerce between source_kind and
  target_kind here". This change only stops the reinterpretation.

**Three commits.** There are three defects: a NULL dereference, an abort on an unhandled kind, and a
reinterpretation. Each commit only adds lines; P2 and P3 add to the block that P1 opens.

**Hunk placement.**
- The asplice hunk is inserted after line 1056 (upstream numbering). Its trailing context is
  `enter_single_user(tc, body);` and the comment after it.
- The helper is inserted after slot_type_to_kind (line 931). Its trailing context is copy_elements'
  first line.
- Area S's hunks sit at copy_elements' memcpy (951), its element loop (956-965) and
  `if (offset == 0)` (1065).
- `git merge-tree --write-tree` of the new tip with vmarray-self-splice-memmove, with
  vmarray-size-overflow and with vmarray-stale-slots is clean in each case.

## 2. Reproducers, before and after

Outputs on the fix-round-1 builds (cfix-P-raw/repro/):

| program | cfix-base / cfix-asan (before) | cfix-P / cfix-P-asan (after, identical) |
|---|---|---|
| `P1-splice-from-non-vmarray.nqp` | SIGSEGV / ASAN SEGV at 0x8 in copy_elements | `splice from a hash: DIED MVMArray: Can only splice from a VMArray, got a VMHash`, `after: 3 elements` |
| `P1-splice-shaped-raku.raku buf`, `strapp`, `intapp` (new, round 1) | SIGSEGV (exit 139) / ASAN SEGV at 0x8 in copy_elements, each | `<case>: DIED MVMArray: Can only splice from a VMArray, got a MultiDimArray`, `survived` |
| `P1-splice-empty-non-vmarray.nqp` (new) | `delete one through an empty hash: elems 2: 1 3`, `nothing through an empty hash: elems 2: 1 3` | identical |
| `P2-splice-no-storage-kind.nqp target`, `source` | SIGABRT (exit 134) | `target: DIED MVMArray: Unhandled slot type` / `source: DIED ...`, `survived` |
| `P2-splice-no-storage-same-kind.nqp same-fit` (new) | `returned, elems 4`, `back to int8: elems 4: 1 4 7 0` | `DIED MVMArray: Unhandled slot type`, `back to int8: elems 3: 1 4 7` |
| `... same-grow` (new) | plain: `DIED MVMArray: Unhandled slot type`, `back to int8: elems 3: 0 0 0`; ASAN: the same line, then SEGV at address 0 in MVM_VMArray_at_pos (the slots realloc'ed to 0) | `DIED ...`, `back to int8: elems 3: 1 4 7`, no ASAN report |
| `... empty-src`, `empty-into` (new) | `returned, elems 2: 5 7`; `returned, elems 3` | identical |
| `P3-splice-cross-kind.nqp int-into-obj` | returns, SIGSEGV in the collection (ASAN in VMArray_gc_mark) | `DIED MVMArray: Cannot splice from an array of integers into an array of objects`, `gc: survived` |
| `... obj-into-int` | element 1 is an address | `DIED MVMArray: Cannot splice from an array of objects into an array of integers` |
| `... num-from-int` | `element 0 = 1` | `DIED MVMArray: Cannot splice from an array of integers into an array of numbers` |
| `... str-into-obj`, `empty-other` (controls) | `element 1: MVMString`; `str: a c`, `u8: 1 3 (elems 2)` | identical |
| `P3-splice-kind-matrix.nqp` (new) | part 1: all 64 pairs `returned`; part 2: all 64 `elems 1` | part 1: the 41 pairs of the rule `DIED` (elems 0), the 23 kept pairs print the same values as before; part 2: all 64 `elems 1` |

**The matrix.** Kinds obj, str, int, int8, uint8, uint64, num and num32, checked by diff against the
base output:
- Exactly 41 lines differ, and each one is a "DIED MVMArray: Cannot splice from an array of ..." line
  after the fix. There are 17 distinct messages; for example, int8 → num reads "from an array of
  integers into an array of numbers".
- The 23 kept pairs are obj→obj, str→obj, str→str, the 16 int/uint pairs and the 4 num pairs.
- Plain and ASAN outputs are identical before the fix, and identical after it.
- The matrix header comment was updated to the new message after these runs. It is a comment only.

**`P1-splice-shaped-raku.raku`** (new at round 1, adopted from the reviewer's three lines). It has
one case per run, because each case crashes upstream:
- `Buf.new(my int @a[2] = 1, 2)`;
- `@t.append(@s)` for `my str @t = <x>; my str @s[2] = <a b>`;
- `@i.append(@a)` for `my int @i = 1`.

Every run first prints "a shaped native array: array[int], REPR MultiDimArray". After the fix, plain
and ASAN print identical output.

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-P -o cfix-P-raw/repro` and `-p cfix-P-asan` were run on the fix-round-1 builds:
47 program/case pairs each, 94 outputs. `cfix-P-raw/cmp-repro.sh` (described in cfix-T.md section 3)
compared them, and `cfix-P-raw/cmp.txt` has 67 same and 27 differing:
- **24 are the expected flips above:**
  - P1 (2 files);
  - the shaped-array Raku cases (6);
  - P2 target/source (4);
  - P3 int-into-obj, obj-into-int and num-from-int (6);
  - same-fit and same-grow (4);
  - the matrix (2).
- **1 is `B1-read-buf-past-storage.raku` plain.** It prints bytes past a block and varies on
  cfix-base too. Noise.
- **2 are `N2-strtocodes-leak.nqp` ASAN, case and control.** They read `RSS grew by 397 MB` against
  396, and 276 MB against 280. The two ASAN run-alls ran concurrently. Three sequential reruns each
  (`cfix-P-raw/round1/n2-rerun/`) gave 396/396/396 and 280/280/280 on both cfix-asan and cfix-P-asan.
  Noise.

The P1, P2 and P3 controls, the empty-source programs, and S1, T3, G1 and the rest are among the same.

**Task 4's programs.** By the time of the round-1 runs, Task 4 had added its own programs to run-all
(traces 020f6b2): `B-buf-grid.nqp`, `B2-buf-offset-before-storage.nqp`, `B3-write-no-storage-state.nqp
fresh|live` and `R-recompose-matrix.nqp`. So the run-alls on cfix-P and cfix-P-asan ran them too, and
their outputs are in cfix-P-raw/repro/. cmp-repro.sh does not cover them, so I compared them by hand,
with the same normalisation, against Task 4's upstream outputs (cfix-B-raw/repro/ and
cfix-R-raw/repro/, `.base` and `.asan`):
- 9 of the 10 are the same.
- The tenth, `B-buf-grid.nqp` plain, differs only in `R kind=int8 start=3 ...` lines. Those lines print
  bytes read past the storage (the B1 bug), and they vary between upstream runs too (Task 4's
  `cfix-B-raw/base-rerun/` differs from its base run in the same lines). Noise.

## 4. Suites

`cfix-maketest-driver.sh cfix-P-raw/suites cfix-P` ran on the first build, from e9c533194. The probes
map `/tmp/claude-1000/cfix-P/lib/libmoar.so`:

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 0.63) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (128 s, load 0.92) | identical (`diff` empty) |

**Re-run on the fix-round-1 build** (tip c7513438e, cfix-P rebuilt from it; its libmoar holds the new
P3 string), `cfix-maketest-driver.sh cfix-P-raw/suites-r1 cfix-P`, probes map
`/tmp/claude-1000/cfix-P/lib/libmoar.so`:

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 0.23) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (124 s, load 0.58) | identical (`diff` empty) |

The delta between the two builds is the P3 throw's format string and arguments plus the new static
helper `kind_to_elements_name` (`git diff e9c533194 c7513438e`). The table above is the result for the
build offered.

## 5. Call sites of nqp::splice in nqp and Rakudo (redone at fix round 1)

**What the first version got wrong.** It said every source at these sites is a VMArray. That is false.
Rakudo's native array and Buf methods take their source through candidates typed by a role:
- `int @values` (a Positional[int] constraint);
- `intarray:D \values`, `uintarray:D`, `numarray:D` and `strarray:D`.

A **shaped** native array (`my int @a[2]`) is MultiDimArray, not VMArray. It still type-checks as
`array[int]` and does those roles, so it binds to those candidates and is handed to `nqp::splice` as
the source. I classified these sites by the declared parameter type and assumed it implied the REPR,
which it does not. Upstream, every such call with elements crashes (copy_elements' NULL dereference).
With P1 each throws "Can only splice from a VMArray, got a MultiDimArray". **Ordinary Raku code
reaches the P1 case**, which includes plain assignment: `my int @i = @a`.

**Re-check, by running each method** (`cfix-P-raw/round1/sites/`: snippets.txt, snippets2.txt, the
scripts, and per-snippet outputs for cfix-base and cfix-P; rakudo -e, 2G cap, 60 s each):

| call (shaped source unless noted) | site | cfix-base | cfix-P |
|---|---|---|---|
| `Buf.new(@a)`, `Blob.new(@a)` | Buf.rakumod:410 | SIGSEGV | P1 exception |
| `Buf.allocate(4, @a)` | Buf.rakumod:449-450 → `!spread` (88) | SIGSEGV | P1 exception |
| `$buf.STORE(@a)` | Buf.rakumod:1193 | SIGSEGV | P1 exception |
| `$buf.append(@a)` | Buf.rakumod:1411 | SIGSEGV | P1 exception |
| `$buf.prepend(@a)` | Buf.rakumod:1428 | SIGSEGV | P1 exception |
| `$buf.splice(1, 0, @a)` | Buf.rakumod:1369 → `!splice-native` (1389) | "cannot unbox to a native int": `nqp::islist` is false for a MultiDimArray, so it goes to `nqp::list_i(x)`; splice is not reached | the same |
| `$buf.push(@a)` | (no splice) | type check failure | the same |
| `my int @i; @i.STORE(@a)`, `my int @i = @a` | native_array.rakumod:947 | SIGSEGV | P1 exception |
| `@i.append(@a)` (int, uint, num) | 1015, 1687, 2359 | SIGSEGV | P1 exception |
| `@n.STORE(@a)` (num) | 2291 | SIGSEGV | P1 exception |
| `@i.splice(1, 0, @a)` (int) | 1106 (`intarray:D \values`) | SIGSEGV | P1 exception |
| `my str @t; @t.STORE(@s)`, `@t.append(@s)`, `@t.splice(1, 0, @s)` | 317, 385, 476 | SIGSEGV | P1 exception |
| `Buf.new(array[int])` (a type object) | Buf.rakumod:410 | "MoarVM panic: Memory allocation failed; could not allocate 264965122424860 bytes" | the same (section 6) |
| `@i.append(array[int])` (a type object) | — | "Cannot unbox a type object" | the same |
| `Buf.new(CArray[int64].new(1, 2))`, `$buf.append(...)` | — | `Buf:0x<01 02>`, `Buf:0x<05 01 02>` (another candidate, no splice) | the same |
| `@i.append(CArray[int64].new(1, 2))` | — | "This representation (CArray) cannot unbox to a native int" (no splice) | the same |

Every native-array and Buf candidate typed by one of these roles has the same blind spot. That covers
STORE, append, splice and Blob.new/allocate/STORE/append/prepend for every element type, and the rows
above include at least one site of each method. The uint and num STORE/splice candidates (1619, 1778,
2450) have the same parameter types as the int ones that were run; they were not run separately.

**Other REPRs that can arrive where a native array is expected.**
- **CArray** does not reach `nqp::splice` from these methods: the role-typed candidates do not bind
  it, and the methods it does bind convert element by element.
- **A VMArray type object** reaches `nqp::splice` from `Buf.new(array[int])`, through the
  `int @values` candidate. That is not the P1 case: the REPR is VMArray and the elems are garbage.
  See section 6.
- **Shaped arrays** are the only non-VMArray REPR found that reaches a splice with elements.

**The other sites**, rechecked for the same blind spot (a declared type the source may satisfy
without being a VMArray):
- **Internal sources** (all nqp code, and most Rakudo sites) are VMArrays the code itself creates:
  - `nqp::list` and `[...]`;
  - IterationBuffer, and List's `$!reified`, which is always an IterationBuffer;
  - `nqp::create(self)` and `nqp::clone`;
  - `nqp::split` (slurpy_array_type);
  - `nqp::strtocodes` into `nqp::create(NFD)`, and `.NFD`;
  - `nqp::readfh` into `buf8.^pun`;
  - the metamodel's list methods;
  - QAST and pod lists;
  - Junction `$!eigenstates`.
- **`Blob:D` sources** (Buf.rakumod 407, 1189, 1399, 1408, 1420, 1427, 1445, 1466-1467, core.e
  Fixups 458-459): Blob is a role, so a user class doing Blob with another REPR is possible in
  principle. The core Blob/Buf types are VMArray, and no shaped Blob exists. Not tried.
- **Telemetry.rakumod:593** and **List.rakumod:345** take `$!reified` of a List argument, which is
  always an IterationBuffer.

**Kind combinations P3 refuses** (obj/str ↔ int/uint/num, obj → str, int/uint ↔ num) with a
non-empty source: no site produces one. A shaped source never gets that far, because P1 refuses it
first. The rest of the earlier analysis stands:
- the object-array sites splice object arrays;
- the str-array sites splice `strarray:D` (VMArray or, see above, MultiDimArray), `nqp::create(self)`
  or `$empty_s`;
- the num sites splice `numarray:D`, `nqp::create(self)` or `$empty_n`;
- the int sites are all int/uint, which stays allowed:
  - Buf's `int @values`, Blob `~` (mixed widths), `nqp::list_i(x)`;
  - JSON.rakumod:90-113, `nqp::list_i` and `.NFD` into an NFD;
  - Str.rakumod:2785/2807, NFD into NFD;
  - IO/Path.rakumod:663/693, buf8 into buf8;
  - intarray/uintarray STORE, append and splice.

**Storage-less kinds (P2):** no site creates arrays of 1, 2 or 4 bit element types, and with elements
such arrays need a recompose.

**Empty sources of another kind** stay allowed:
- `$empty := nqp::list` into native or str arrays and IterationBuffers (Str.rakumod:22,
  Iterator.rakumod:16, Internals.rakumod:111);
- `$empty := nqp::list_i` into any Buf (Buf.rakumod:1345-1353);
- `nqp::list()` in NFA.nqp:1048 / 1422, into the NFA's state lists;
- `$empty-array` in HLL/Backend.nqp.

**Conclusion.**
- The P1 case is reached from ordinary Raku code, through every native-array and Buf method that
  takes a role-typed source, whenever that source is a shaped native array with elements. Upstream
  this is a SIGSEGV, and with this change it is the P1 exception.
- No site produces a P2 or P3 combination with a non-empty source.
- Module code outside these two repositories was not searched.

## 6. Seen on the way (reported, not fixed)

- **A VMArray type object as the splice source.** asplice does not check that `from` is concrete, and
  `elems` reads the body of a type object, which holds no array.
  - Program: `cfix-P-raw/round1/typeobj/typeobj.nqp`. It runs `nqp::splice(nqp::list(1, 2, 3),
    nqp::what(nqp::list()), 1, 0)` with `MemoryMax=2G` and a 60 s timeout.
  - Plain cfix-base and cfix-P print `source is concrete: 0`, then die by the memory cap's kill (exit
    137).
  - ASAN cfix-asan and cfix-P-asan report `allocation-size-too-big`: "requested allocation size
    0x16800000038" in set_size_internal.
  - From Raku: `Buf.new(array[int])` gives "MoarVM panic: Memory allocation failed; could not allocate
    264965122424860 bytes" on cfix-base and on cfix-P (section 5 table).
  - P's checks do not catch it: the REPR is VMArray, and the type object's REPR data is that of an
    object array (kind OBJ, elem_size 8). Not on the list, not changed.
- **MVM_VMArray_at_pos's default arm (VMArray.c:356)** passes `repr_data->slot_type` to
  `MVM_reg_get_debug_name`, which takes a register kind. For the storage-less slot types 12-17 the
  message prints the name of whichever register kind has that number (or "unknown"), not the slot
  type. Only the message is wrong. Not on the list, not changed.

## 7. Draft PR text

Title: **Refuse VMArray splices from sources it cannot copy from**

Body:

> This makes `nqp::splice` throw, before the target array is changed, in three cases that used to
> crash, abort or silently reinterpret bits. All three apply only when the source has elements. An
> empty source of any kind or REPR still copies nothing, so deleting with an empty list
> (`nqp::splice($buf, nqp::list_i(), $i, $n)`, `nqp::splice($strs, nqp::list(), $i, $n)`) works as
> before. The choices, which you may want to change:
>
> 1. **A source that is not a VMArray** now throws "MVMArray: Can only splice from a VMArray, got a
>    \<REPR name\>". Before, copy_elements read the source's REPR data as a VMArray's, which is NULL
>    for anything else, and crashed.
>
>    Ordinary Raku code reaches this case. Rakudo's native array and Buf methods take their source
>    through role-typed candidates (`int @values`, `intarray:D`, `strarray:D`, ...). Those candidates
>    also accept a shaped native array, whose REPR is MultiDimArray, and pass it to `nqp::splice`. So
>    with this change these calls die with the exception instead of crashing; they do not start
>    working. There are two ways to make them work, and I have done neither here:
>    - the VM could copy from any positional source through its at_pos;
>    - the callers in Rakudo could handle shaped arrays themselves.
> 2. **A source or target of a kind without storage** (the 1, 2 and 4 bit integer element types,
>    elem_size 0) now throws "MVMArray: Unhandled slot type", the message every other operation gives
>    for these kinds. What happened before:
>    - Between such a kind and another one, the splice reached `abort()` in slot_type_to_kind. It did
>      so for such a source, and for such a target that did not have to grow. A target that had to
>      grow (a fresh array of such a type, for one) already threw "Unhandled slot type" from
>      zero_slots, after its slots had been reallocated to 0 bytes.
>    - With the same such kind on both sides, the splice either returned with `elems` changed and
>      nothing copied, or threw from zero_slots in the same way.
>
>    An array of such a kind only has elements after its type was recomposed while it was alive.
> 3. **Element kinds whose registers do not convert** now throw "MVMArray: Cannot splice from an
>    array of \<objects | strings | integers | unsigned integers | numbers\> into an array of
>    \<...\>". When the kinds differ, copy_elements reads each element in the source's register kind
>    and binds it in the target's, passing the same register through ("actually should coerce
>    between source_kind and target_kind here").
>
>    The refused pairs are:
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
> I went through every `nqp::splice` in nqp and Rakudo. None of them can produce a kind pair from 2
> or 3 with a non-empty source. Case 1 is reached by every native-array and Buf method that takes a
> role-typed source, whenever the caller passes a shaped array, as shown below.
>
> Reproducing case 1 from Raku. Each line is a separate run on a stock Rakudo:
>
> ```
> my int @a[2] = 1, 2; say Buf.new(@a)
> my str @t = <x>; my str @s[2] = <a b>; @t.append(@s); say @t
> my int @a[2] = 1, 2; my int @i = 1; @i.append(@a); say @i
> ```
>
> Before: each one dies with SIGSEGV (exit 139). With AddressSanitizer, each is a SEGV on address 0x8
> in copy_elements. The same happens for `my int @i = @a`, `Buf.allocate(4, @a)`, `.STORE`,
> `.prepend` and `.splice` with a shaped source, and for the str, uint and num array methods. After,
> each dies with:
>
> ```
> MVMArray: Can only splice from a VMArray, got a MultiDimArray
>   in block <unit> at -e line 1
> ```
>
> The nqp programs below are self-contained for a stock nqp. They are three separate programs,
> because each one crashes before the change. A non-VMArray source:
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
> Before: SIGABRT with no message, on a plain build and on an AddressSanitizer build. After:
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
> obj into int: DIED MVMArray: Cannot splice from an array of objects into an array of integers, elems 0
> int into num: DIED MVMArray: Cannot splice from an array of integers into an array of numbers, elems 0
> obj into str: DIED MVMArray: Cannot splice from an array of objects into an array of strings, elems 0
> str into obj: returned, elems 1
>   element 0: MVMString
> int into uint8: returned, elems 2
>   elements: 65 44
> delete from str through an empty obj list: a c
> delete from uint8 through an empty num list: elems 1
> int into obj: DIED MVMArray: Cannot splice from an array of integers into an array of objects, elems 0
> survived a collection
> ```
>
> The output is the same with AddressSanitizer, without a report. I also checked every pair of eight
> kinds (obj, str, int, int8, uint8, uint64, num, num32) in both directions:
> - with one element, exactly the 41 refused pairs now throw, and the 23 others give the values they
>   gave before;
> - with an empty source, all 64 pairs delete as before.
>
> `make test` of nqp and Rakudo gives the same per-file results as before.
>
> The checks sit at the top of asplice, before anything is changed, so a refused splice leaves the
> target as it was.
>
> A related observation, not addressed here: asplice does not check that the source is concrete. A
> VMArray type object as the source (`Buf.new(array[int])` in Raku) reads a garbage element count, and
> the target is grown to it: an allocation failure, or a panic.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)

## 8. Fix round 1

The review found the C correct. Its findings, and what was done for each:

1. **The call-site claim was false.**
   - Shaped native arrays (MultiDimArray) reach P1 through role-typed Rakudo candidates.
   - I verified the reviewer's three lines on cfix-base, cfix-asan, cfix-P and cfix-P-asan, and adopted
     them as `cfix-repro/P1-splice-shaped-raku.raku` (cases buf, strapp, intapp), now in run-all.
   - I ran every splice-using method with shaped, CArray and type-object sources
     (`cfix-P-raw/round1/sites/`).
   - Section 5 is rewritten, and the PR text now says plainly that ordinary Raku code reaches the case.
     It shows the three lines with before (SIGSEGV) and after, and names both alternatives (copy
     through at_pos in the VM, or fix the callers in Rakudo).
   - The P1 commit body now says how Raku reaches it.
2. **The P3 message named register widths.**
   - It is now "MVMArray: Cannot splice from an array of \<objects | strings | integers | unsigned
     integers | numbers\> into an array of \<...\>", using a new static helper `kind_to_elements_name`.
   - cfix-P and cfix-P-asan were rebuilt from the new tip (make exit 0, 11 s and 21 s; logs in
     `cfix-P-raw/build/`, the first build's logs in `/tmp/claude-1000/cfix-logs/round1-old/`).
   - All reproducers and the PR programs were re-run on both builds, and every quoted output was
     updated.
   - The suites were re-run on the rebuilt cfix-P (c7513438e): nqp and rakudo PASS, per-file lists
     identical to cfix-base (section 4). `git diff e9c533194 c7513438e` is the helper and the throw's
     format string and arguments.
3. **The P2 "before" was too broad.**
   - Verified: a fresh uint4 array as the target dies with "Unhandled slot type" from zero_slots on
     cfix-base and cfix-asan (`cfix-P-raw/round1/p2-grow/`).
   - The P2 commit body and the PR text now say that abort() was reached for a storage-less source,
     or for such a target that did not have to grow.
   - The program's header comment was corrected after the run (comment only).
4. **The type-object source** is verified and recorded in section 6, with a related-observation
   paragraph in the PR text. Not fixed.

| commit | old | new | change |
|---|---|---|---|
| P1 | c1ff96d40 | 0073826640e0c352fd0c0146423e30c8a0f29ec1 | message only, same tree |
| P2 | 0b32272b5 | f2f306ae8df72d3e618977b5cfdbb1902507df99 | message only, same tree |
| P3 | e9c533194 | c7513438eea2763904d8807d58578a017038b617 | message (text) and the P3 message string + helper |
