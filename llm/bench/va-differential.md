# va differential: what the C array prints, and how much of it the programs reach

```
Programs:   tools/bench/repr/vmarray-diff.nqp, vmarray-diff.raku, vmarray-serial.nqp, vmarray-devirt.nqp
Runner:     tools/bench/repr/diff.sh (README beside it)
Control:    /tmp/claude-1000/va-c-base (-Dzig-reprs=false, MoarVM zig-vmarray at 6b45869d9; va-prefixes.md)
Runners:    /tmp/claude-1000/tune-zig-prefix/bin/nqp-m; rakudo/rakudo-m with RAKUDO_NO_PRECOMPILATION=1
Settings:   spesh (MVM_SPESH_DISABLE unset, MVM_SPESH_BLOCKING=1) and nospesh (MVM_SPESH_DISABLE=1)
Raw:        va-differential-raw/ (the control's outputs, the run log, the coverage measurement)
```

This is the record the later tasks hold the Zig array to: the same command with
`--head=` a Zig-array prefix must exit 0.

## 1. The control repeats

2026-11-16 11:52 CET, 1-minute load 0.20 to 1.07 over the 52 runs (`load.log`),
no other raku or moar process running:

    tools/bench/repr/diff.sh --base=/tmp/claude-1000/va-c-base \
        --head=/tmp/claude-1000/va-c-base --out=<workspace>/diff-self

exit 0 after 189 s: "identical (3 runs a side; lines: diff-nqp/spesh 9987
diff-nqp/nospesh 9987 diff-raku/spesh 2475 diff-raku/nospesh 2475 serial/spesh
196 serial/nospesh 196 devirt/spesh 10 devirt/nospesh 10; cross-read
identical)" (`diff-self.log`). Both sides are the control, so this shows what
it is meant to show: three runs of each program in each setting give the same
bytes, twice over, no run wrote to stderr, and the control reads its own
serialization as it wrote it (66 lines a setting).

The runner's own checks were exercised on a copy of that directory with
`--compare-only`: one run of a side altered gives exit 2 ("not repeatable",
the line named), all three runs of head altered gives exit 1, a cross-read
altered gives exit 1; unknown argument and missing prefix 64. `sh -n
tools/bench/repr/diff.sh` is clean.

After the review of this task the runner gained exit 3 (section 5), a probe of
the libmoar each side maps, the removal of the caller's `MVM_*` and related
variables from the runs, and exit 64 for prefixes of unequal length. The
control was run against itself again with that script, 2026-11-16 12:08 CET, load 0.78 to 1.70: exit 0 after 192 s, both sides mapping `/tmp/claude-1000/va-c-base/lib/libmoar.so` through both runners
(`diff-self-fix1.log`, `libmoar-fix1.log`); the outputs are the bytes recorded
here. Its checks on tampered copies and a fake prefix are in
`diff-fix1-tests.txt`: only listed lines altered in all head runs gives 3; a
listed and an unlisted line, a dropped line or a changed case name gives 1; one
head run altered gives 2; unequal prefix lengths 64; a prefix whose libmoar.so
is a link into another prefix 4.

| program | setting | lines | spesh output = nospesh output |
|---|---|---|---|
| diff-nqp | spesh | 9,987 | no (66 lines) |
| diff-nqp | nospesh | 9,987 | |
| diff-raku | spesh, nospesh | 2,475 | yes |
| serial | spesh, nospesh | 196 (65 cases x 3, and `done`) | yes |
| devirt | spesh, nospesh | 10 | yes |
| serial cross-read | spesh, nospesh | 66 | yes |

`diff-nqp` differs between the settings in 66 lines, all `*.mega.*` cases, by
design (section 3, the `MVM_VMArray_at_pos_s`/`_o` rows of the throw sites). The raw outputs kept
are one per program and setting where they differ, one per program where they
do not (`va-differential-raw/README.md`).

`MVM_SPESH_BLOCKING=1` is an addition to the plan's "MVM_SPESH_DISABLE unset":
it makes the program wait for the specializer, so what runs specialized and
compiled does not depend on thread timing. The outputs of `diff-nqp` and
`diff-raku` were also identical without it (two runs each during development,
compared with a blocking run), because the `*.mega.*` cases print the set of
distinct results, not when they changed; the blocking is there so that this
stays true under load.

The same four programs on a second build of the same commit (`va-c-syms`, the
control's options plus `-Dstrip=false`, built for section 3) print the same
bytes as `va-c-base`, including the cases of section 5.

## 2. What the cases are

Every line is `<case>: <result>` or `<case>: DIED <message>`. In
`vmarray-diff.nqp` the case name starts with the slot kind (`obj str i64 i32
i16 i8 u64 u32 u16 u8 n64 n32`, then `u4 i4 u2 i2 u1 i1` for the kinds without
storage), then the group:

| group | what it drives |
|---|---|
| `empty`, `bind`, `at`, `push`, `pop`, `shift`, `unshift`, `queue`, `stack` | the basic operations with the register kind natural to the slot kind; empty array; negative indices in and out of range; reads past `elems`; a bind that leaves a gap |
| `setelems`, `shiftback`, `shrinkgrow`, `grow`, `limit` | `set_size_internal`: same size, within the storage, below 8, doubling up to 8,192, the 4,096-rounding branch above it, growth with `start > 0` (the elements move back to the front), shrinking then growing (the slots come back zero), growth by `push`, `bindpos`, `unshift` (its 8 / `elems` / 8,192 front room) and `setelems`; the size limit on a fresh, a small, a large (8,192+ slots) and a shifted array, through `setelems`, `bindpos`, `setdimensions` and `splice` |
| `splice` | insert, delete and replace at the front, middle, end and past the end, negative offsets in and out of range, each on an array with `start` 0 and `start` 3; `splice.start.*`: the offset-0 branch that moves `start`; from a 9,000-element array; from an empty hash |
| `selfsplice` | a splice from the array itself (Review Focus 3), section 5 |
| `slice`, `clone` | `aslice` and `copy_to`, with `start > 0`, of 9,000 elements, and that the copy is independent |
| `nd` | `atposnd`/`bindposnd` with one index (works) and with none or two (throws), `atpos2d`/`3d`, `bindpos2d`/`3d`, `dimensions`, `numdimensions`, `setdimensions` |
| `buf` | `writeint`/`writeuint`/`readint`/`readuint` at 1, 2, 4, 8 bytes and `writenum`/`readnum` at 4, 8, each native, little and big endian (`f<flags>`), growing, at the end, on an empty and a shifted array, past the end, negative offset, bad flags |
| `kind` | every typed op (`atpos`, `bindpos`, `push`, `pop`, `shift`, `unshift`, each `_o _i _u _n _s` that nqp has) on every kind: the mismatches and their messages, on an array with `start` 0, `start` 2 and empty, and `.state`, the array after the failed op; plus `existspos`, `join`, the iterator in each register kind, `for`, argument flattening |
| `value` | Review Focus 2: 27 integers (each width's minimum, maximum, one below, one above, -1, 2**63, 2**64-2 as bits) through `bindpos_i`, `bindpos_u`, `push_i`, `unshift_i`, `bindposnd_i`, `writeint`, `splice`, read back through `atpos_i`, `atpos_u`, `atposnd_i`, clone, slice, flattening, iterator, `pop_i`, `shift_i`; 29 nums (NaN, infinities, -0, the largest num32, the tie above it, denormals, values num32 rounds) the same way, with the stored bits |
| `cross.*` | a splice into each numeric kind from each numeric kind (no coercion: an int lands in a num array as bits), same kind through another array type, the `nqp::list*` literals |
| `odd`, `compose.*`, `typeobject.*` | the kinds without storage; what `compose` accepts |
| `gc` | arrays of OBJ and STR across `nqp::force_gc`, binds and a splice into a promoted array, 50,000 elements |
| `hot` | loops of 300,000 rounds per kind; subs called 100,000 times and then out of bounds; a loop that ends out of bounds |
| `mega` | five subs that each see all twelve kinds in turn (3,000 rounds), so that compiled code reaches the `MVM_VMArray_at_pos_*` entry points |
| `recomposed` | arrays whose type is composed again while they are alive: the only way to hold a non-empty array of a kind without storage, and so into the default arms of `bind_pos`, `push`, `pop`, `shift`, `unshift`, `serialize` |

`vmarray-diff.raku` names its cases by the Raku type (`int8` ... `uint64`,
`num32`, `num64`, `str`, `Buf[uint8]` ... `Blob[uint64]`, `buf8.*`, `array.*`):
the same operations through Rakudo's `array[T]`, `Buf` and `Array`, the values
of Review Focus 2 again (where Rakudo throws for a value before the array sees
it, that message is the result), `ref.*`/`mdref.*` (`nqp::atposref_*`,
`nqp::multidimref_*`), `atomic.*` and `atomicint.*` (`pos_as_atomic`,
`pos_as_atomic_multidim`), every `read-*`/`write-*` of `buf8`/`blob8`, and
`array.reified.*` (nqp ops on the `IterationBuffer` inside an `Array`).

`vmarray-serial.nqp`: 65 cases (16 kinds x empty, 3 elements, shifted, 10,000
elements, plus an empty array of a 4-bit element type whose deserialization
throws), each `.blob` (hex), `.strings`, `.roundtrip`. The cross-read of
`diff.sh` has each side deserialize the other side's blobs and compares with
the writer's own `.roundtrip` lines.

## 3. Coverage, measured

No coverage tool is set up for this build, so the plan asked for a check by
hand. A measurement was cheap enough to add: a second control prefix with
symbols (`va-c-syms`: `zig build install --prefix /tmp/claude-1000/va-c-syms
-Dzig-reprs=false -Dstrip=false`, 68 s at load 0.34, 2026-11-16 11:27 CET, same commit plus the traces pointer, 2,850 exported names like the control) and gdb with a breakpoint on every
line of `src/6model/reprs/VMArray.c` that has code, each disabled at its first
hit (`va-differential-raw/coverage/cov.py`, `cov.sh`; per-run maps
`cov-<program>-<setting>.txt`; the tables of this section are
`coverage/sites.tsv`, made by `sites.py`).

| run | lines hit of 541 with code |
|---|---|
| diff-nqp, spesh | 479 |
| diff-nqp, nospesh | 422 |
| diff-raku, spesh | 467 |
| diff-raku, nospesh | 425 |
| serial (write and in-process read), spesh / nospesh | 385 / 345 |
| serial `--read`, spesh / nospesh | 336 / 296 |
| devirt, spesh / nospesh | 258 / 215 |
| all runs together | 517 |

(The build is optimized, so a line is "hit" when the code the compiler
attributes to it runs; 541 is the number of lines gdb can place a breakpoint
on exactly.)

Lines never hit by any run, all 24 of them:

| lines | what | why |
|---|---|---|
| 146, 164, 181, 198, 215, 217, 238 | the opening and closing lines of `MVM_VMArray_at_pos_s/_i/_u/_n/_o` | line-table artefacts: the body lines of all five are hit |
| 929 | `abort()` in `slot_type_to_kind` | reached only by a splice that copies elements into an array of a kind without storage; it would abort the process, so no case goes there |
| 1259, 1294, 1310 | the three "Unsupported uint/int/num size" throws of `spec_to_repr_data` | unreachable from the language: every REPR whose storage spec says boxed int or uint has 1, 2, 4, 8, 16, 32 or 64 bits (P6int refuses anything else with its own "MVMP6int: Unsupported int size", P6bigint says 64), P6num has 32 or 64 (it refuses others itself); cases `compose.num16`, `compose.int3`, `compose.uint128` print those refusals |
| 1521-1550 | `describe_refs` (12 lines) | called by the heap snapshot profiler only (`src/profiler/heapsnapshot.c`), which writes a file and prints nothing; no case. For a unit test |
| 1554 | `MVMArray_initialize` | runs at VM start, before the breakpoints are set |

`unmanaged_size` is hit (the collector calls it when it promotes an array) but
nothing printed depends on it; the same holds for the growth policy's storage
sizes below the limit, which only the `limit` messages expose (they carry the
computed slot count). The peak-memory gate and the unit tests cover those.

### Throw sites

`grep -c MVM_exception_throw_adhoc src/6model/reprs/VMArray.c` is 111, with 59
distinct message formats. `va-differential-raw/coverage/messages.tsv`
(`messages.py` over the control's outputs): 55 of the 59 formats appear in the
outputs, the other four being the three unreachable "Unsupported ... size"
messages and the compiled-out "Array may not be used concurrently". The
outputs hold 254 distinct `DIED` messages in all (the array's own with their
numbers filled in, and those of Rakudo, the iterator, the serializer and the
ops in front of the array).

Per site (`coverage/sites.tsv`):

| sites | state |
|---|---|
| 60 | have code of their own in the optimized build and were hit by a breakpoint |
| 47 | have no code of their own: the compiler merged them with another arm that throws the same message (most arms of `push`, `pop`, `shift` and `unshift`, which have 12 throwing arms each and 4 distinct messages; the N arms of `at_pos` and `bind_pos`; the default arm of `push`). Each is reached by its kind's `<kind>.kind.<op>_<register>` case, which prints the message under that kind's name (`<kind>.recomposed.push_i` for the default arm of `push`); that it was this arm and not its twin cannot be shown by a breakpoint in this build |
| 3 | not reached, unreachable from the language (1259, 1294, 1310 above) |
| 1 | line 11, "Array may not be used concurrently": compiled out, `MVM_ARRAY_CONC_DEBUG` is 0 |

The sites that needed more than the obvious case:

| line | site | reached by |
|---|---|---|
| 154, 159 | `MVM_VMArray_at_pos_s`: index out of bounds; "atpos expected a string register, but %u is not MVM_ARRAY_STR" | `<kind>.mega.atpos_s.*` under spesh (compiled code without a known type calls `MVM_repr_at_pos_s`); in Raku, `<type>.ref.wrong.s` and `str.ref.oob.read` (a native str reference reads through `MVM_repr_at_pos_s`) in both settings |
| 173, 190, 207 | `MVM_VMArray_at_pos_i/_u/_n`: index out of bounds | Raku `int64.ref.oob.read`, `uint64.ref.oob.read`, `num64.ref.oob.read` (`nqp::atposref_*` on the 64-bit kinds), both settings; 173 and 190 under spesh also by the nqp `hot.loop.*` and `mega` cases |
| 225, 230 | `MVM_VMArray_at_pos_o`: index out of bounds; "atpos with an object register, but array type %u is not MVM_ARRAY_OBJ" | 230: `<kind>.kind.join`, `<kind>.kind.existspos` (C callers of `MVM_repr_at_pos_o`), both settings. 225: only `obj.mega.atpos_o.-9` under spesh; nothing in C passes a negative index to `MVM_repr_at_pos_o`, so the interpreter cannot reach it |
| 356 | `at_pos` default arm, "Unhandled slot type, got '%s'" | `<kind>.odd.atpos_*`; prints `'unknown'` or `'uint8'`: the slot kind number is passed to the register-kind name function |
| 400 | `zero_slots` default | `<kind>.odd.push_i` and the other `odd` growth cases (growth of an array without storage) |
| 558, 643, 721, 820, 897 | default arms of `bind_pos`, `push`, `pop`, `unshift`, `shift` | only `<kind>.recomposed.*`: an empty array of a kind without storage fails in `set_size_internal`/`zero_slots` or on the emptiness check first (643 is one of the merged sites) |
| 1000 | `write_buf` negative offset | `<kind>.buf.writeint.negoffset` |
| 1203, 1211, 1218 | `pos_as_atomic`, `pos_as_atomic_multidim` | Raku `<type>.atomic.*`: 1203 `int64.atomic.load.past`, 1211 `int32.atomic.load`, 1218 `int64.atomic.md.2` |
| 1424 | `deserialize` default | `u4.0.roundtrip` / `u4.0.read` of the serial program |
| 1473 | `serialize` default | `u4.recomposed.serialize`, the last case of the nqp program |
| 1568, 1592 | `vmarray_bind_pos_int64`, `vmarray_at_pos_int64`: index out of bounds | only `vmarray-devirt.nqp` under spesh (`i64.devirt.*.-11`, twice each). See below |

The two devirtualized functions run in the hot loops of both big programs
(every other line of theirs is hit there), but a call that ends in their own
error needs compiled code that knows the array's type at that call, and that
turned out to depend on the shape of the surrounding program, not on the call.
Measured with breakpoints on lines 1568 and 1592: a sub handed the array, or
the type, as an argument compiles the plain `MVM_repr_at_pos_i` call (line
173); a series of calls from the mainline reached one of the two lines or
neither depending on what ran before it; an exception through inlined code
deoptimizes the frame it passes. The one shape that reached both, with
`MVM_SPESH_BLOCKING=1` and without, three runs each, is the small program
`vmarray-devirt.nqp` (the mainline calls each wrapper a thousand times in a
loop, the calls that count follow in the same frame), so it is a program of
its own and `diff.sh` runs four programs where the plan named three. The
message is the same on every path, so its output does not show which path was
taken; only the breakpoint does.

### Functions of `VMArray_this_repr`

All 35 of the array's own functions are reached except `describe_refs`;
`coverage/sites.tsv` has the lines per function. A case for each:

| function | a case that reaches it |
|---|---|
| `type_object_for` | every `arrtype(...)` (the sized kinds), `compose.*` |
| `copy_to` | `<kind>.clone.*` |
| `MVM_VMArray_at_pos`, `MVM_VMArray_bind_pos`, `set_elems`, `MVM_VMArray_push`, `pop`, `unshift`, `shift` | `<kind>.at.*`, `.bind.*`, `.setelems.*`, `.push.*`, `.pop.*`, `.unshift.*`, `.shift.*`, and `<kind>.kind.*` for each arm's two sides |
| `aslice`, `asplice` | `<kind>.slice.*`, `<kind>.splice.*`, `.selfsplice.*`, `cross.*` |
| `at_pos_multidim`, `bind_pos_multidim`, `dimensions`, `set_dimensions` | `<kind>.nd.*` |
| `get_elem_storage_spec` | `<kind>.kind.iterator*`, `.flatten*`, `.join` (every arm; the default arm by OBJ and by the `odd` kinds) |
| `pos_as_atomic`, `pos_as_atomic_multidim` | Raku `<type>.atomic.*`, `atomicint.*` |
| `write_buf`, `read_buf` | `<kind>.buf.*`; Raku `buf8.*`, `Buf[...]`.nqp.*; `nqp::serializetobuf` in the serial program |
| `elems` | every dump; `<kind>.empty.elems` |
| `get_storage_spec` | `<kind>.kind.elemspec` (`nqp::objprimspec` of the array type; the plan's brief names this op for `get_elem_storage_spec`, but it asks the type for its own spec) |
| `serialize`, `deserialize`, `serialize_repr_data`, `deserialize_repr_data`, `deserialize_stable_size` | the serial program (every typed case carries its own STable) |
| `VMArray_gc_mark`, `gc_free`, `gc_mark_repr_data`, `gc_free_repr_data` | `<kind>.gc.*`, `gc.many`, and every run's collections |
| `compose` (and `spec_to_repr_data`) | `arrtype(...)`, `compose.*`, `recomposed.*` |
| `spesh` | hit under spesh only: `<kind>.hot.*` (`elems` to a field read, `create` to a fast create) |
| `unmanaged_size` | hit; nothing printed depends on it |
| `describe_refs` | not reached (above) |
| `MVM_VMArray_at_pos_s/_i/_u/_n/_o` (exported, not in the table) | flattening and `join` in both settings; `mega`, native references |
| `vmarray_at_pos_int64`, `vmarray_bind_pos_int64`, `MVM_VMArray_find_fast_impl_for_jit` | spesh only: hot loops; their errors in `vmarray-devirt.nqp` |

### Kinds

Reachable from nqp: all twelve kinds with storage (OBJ, STR, I64, N64 as
`nqp::list*`; the others and second types of the same four through
`nqp::newtype` + `nqp::composetype`), and the six without storage (U4, U2, U1,
I4, I2, I1). The design (section 4) counts sixteen kind constants, four
without storage; the header has eighteen, and six of them have no storage and
their own arms in `spec_to_repr_data`. Every `case MVM_ARRAY_*` arm
of every switch is executed (measured, except the 47 merged throw sites, by
argument). Not reachable from nqp: a uint64 register for `push`/`pop`/`shift`/
`unshift` (there are no `push_u`... ops), so "the U arms reject a uint64
register there" is not observable; `nqp::atposref_*` (no reference types in
nqp's HLL config) and the atomics, which is what the Raku program is for.

## 4. Per-kind differences in the C, as the outputs show them

Listed for `va-kind-differences.md` of the later task; each is in the record
as printed, none is smoothed.

- `at_pos`: the U64 arm's message ends ", got %d instead" (the register kind);
  no other arm's does. The N64 and N32 arms share one message, without the kind
  name; OBJ and STR have their own wording.
- `at_pos` and `bind_pos`: the U arms accept an int64 or a uint64 register, the
  I arms only int64 (`i64.kind.atpos_u` dies, `u64.kind.atpos_i` does not).
  `push`, `pop`, `shift`, `unshift`: every integer arm accepts int64 only.
- `MVM_VMArray_at_pos_i/_u/_n` check nothing but the index; `_s` and `_o` check
  the slot kind and word the error differently from `at_pos` (`*.mega.*`,
  `<kind>.kind.join`).
- A rejected `push` or `bindpos` has already grown the array (`*.kind.push_*.
  state` shows a zero element); a rejected `pop` has already dropped the last
  element without clearing its slot (growing back shows the old value); a
  rejected `unshift` has already moved `start` (and made front room): element 0
  is a zero and the last element is gone; a rejected `shift` changes nothing.
- `read_buf` checks `(start + elems) * elem_size` against the end of the read,
  so with `start > 0` it lets a read past the last element through
  (`*.buf.readint.shifted.past1`, `.past2` print 0; `.past3` dies).
  `write_buf` grows to `offset + count` elements where `count` is bytes
  (`u16.buf.writeint.f12` grows a 3-element array to 9 for an 8-byte write at
  element 1).
- `write_buf` and `read_buf` accept the num kinds (their check is "slot kind at
  least I64"), refuse OBJ and STR.
- `copy_elements` copies with `memcpy` when source and target have the same
  slot kind and element size, except STR always and OBJ when the target has
  been promoted, which go element by element through `at_pos`/`bind_pos`;
  across kinds it also goes element by element, with the register reinterpreted
  and not converted (`cross.splice.n64.from.i64`).
- `asplice` at offset 0 on an array with `start > 0` that grows moves `start`
  back over slots that were shifted off; a splice from another array overwrites
  them, a splice from the array itself copies them (`i8.selfsplice.shifted.
  prepend` begins with the four values that had been shifted off).
- The kinds without storage: `at_pos` names the slot kind with the register
  kind table (`'unknown'`, `'uint8'`); every growth dies in `zero_slots`
  ("Unhandled slot type") after `MVM_malloc(0)`/`MVM_realloc(..., 0)`;
  `get_elem_storage_spec` treats them as reference arrays.
- `compose` on a type that has live arrays changes their slot kind in place
  (`recomposed.i8.u8`, `recomposed.i64.n64`).
- `deserialize`'s U arms store through the signed members with unsigned casts,
  and it reads `elems` before it looks at the kind, so an array of a kind
  without storage serializes (empty) and then cannot be deserialized.

## 5. Splices from the array itself (Review Focus 3)

`asplice` ends with `copy_elements(from, root, 0, offset, elems1)`. When `from`
is the array itself and `0 < offset < elems1`, source and target ranges
overlap, and for the kinds copied with `memcpy` that is undefined behaviour in
C. The control prints what its `memcpy` leaves (libmoar has no `memcpy`
import: `nm -D` shows none, the build links its own). `va-differential-raw/
selfsplice.tsv` (`selfsplice.py`) compares each small `selfsplice` case with a
model of `asplice` whose last copy is a memmove, and one whose last copy runs
forward element by element:

| cases | STR | the eleven `memcpy` kinds |
|---|---|---|
| `prepend`, `append`, `past`, `replace.0.3`, `replace.all`, `replace.over`, `one`, `one.replace`, `empty`, `shifted.append`, and (numeric kinds only) `shifted.prepend`, `shifted.prepend20`, `shifted.replace` (150 lines) | no overlap that matters: both models agree with the output | the same |
| `middle`, `middle9`, `neg`, `replace.5.5`, `replace.tail`, `shifted.middle` (72 lines) | forward copy | forward copy (not a memmove) |
| `middle1`, `replace.2.3`, `replace.1.9`, `replace.1.20`, `shifted.replace.2.3` (60 lines) | forward copy (5 lines) | neither (55 lines): a pattern of the `memcpy`'s block order, different for 8-, 4-, 2- and 1-byte elements |
| `big.middle`, `big.replace` (9,000 elements; the dump is a SHA-1, which the models reproduce) | forward copy | forward copy |
| `big.1`, `big.shifted` | forward copy | neither (22 lines) |

So the lines whose value depends on how overlapping ranges are copied are not
only the 77 "neither" lines: the forward-copy lines of the memcpy kinds are
not what a memmove gives either. Counting every line where the two models
differ, for the eleven memcpy kinds: 15 cases x 11 kinds = 165 `selfsplice`
lines, plus `<kind>.selfsplice.twice` (two such splices; 11), plus, in the
Raku output, `<int type>.nqp.splice.self` (8), `num32/num64.splice.self` (2),
`Buf[...]`/`Blob[...]`.splice.self (8) and `array.reified.splice` (1): 195
lines. Not among them, because the C defines the result: every STR case;
`<kind>.gc.selfsplice.promoted` and `gc.splice.promoted` (a promoted OBJ array
is copied element by element, checked with a breakpoint on the loop of
`copy_elements`); self-splices at offset 0 or at the end; Rakudo's own
`.splice` with the array as the replacement (`int8.splice.self`,
`array.splice.self`), which copies the replacement first.

The ruling on these lines (the campaign's controller, after the review of this
task): the cases stay in the programs, and the Zig array copies overlapping
ranges with memmove semantics. It will therefore differ from the control in
these lines, and `diff.sh` is told so: `tools/bench/repr/undefined-lines.txt`
names the 195 lines (the `selfsplice` entries printed by `selfsplice.py
--list`, the rest by the same rule by hand), and when base and head differ
only in listed lines, with the same line count and the same case name on each
differing line, the script exits 3, "differs only in undefined self-splice
lines", and prints each differing line with both values. A head that reaches
exit 3 is not a pass: the result and the printed lines are recorded and put to
the user. Any difference outside the list is exit 1 as before, and each side
must still repeat the listed lines run to run (exit 2). `diff.sh` also refuses
prefixes of unequal length (exit 64), because the "neither" patterns can follow
the alignment of the storage.

## 6. Left out, with the reason

No case goes where the C array crashes, aborts or reads what it does not own:

| not driven | what the C does |
|---|---|
| `setelems` (or any growth) to 2**64 - 4096 or more on an array with 8,192+ slots | `(n + 0x1000) & ~0xfff` wraps to 0, passes the limit check, `MVM_realloc(slots, 0)`, then `zero_slots` clears from `elems` over a wrapped length: a crash. Reported as a C bug; kept |
| a size at or just under the limit (for example exactly 2**60 eight-byte elements) | the check is `>`, so the request goes to `MVM_malloc`/`MVM_realloc`, which panics the VM ("Memory allocation failed"); the first draft's `limit.large4095` case did exactly that |
| a splice from a non-empty object that is not a VMArray | `copy_elements` reads `s_repr_data->slot_type` with `s_repr_data` NULL: a crash. (`<kind>.splice.fromhash` splices from an empty hash, which only deletes) |
| a splice that copies elements into an array of a kind without storage | `slot_type_to_kind` reaches `abort()`. (Correction, 2026-11-16, from Task 3's review, see `va-kind-differences.md` row 22c: the abort needs a kind without storage on either side and differing kinds, `VMArray.c:957` for the target, `958` for the source; from the same kind without storage the fast path copies 0 bytes and nothing happens. Slices too.) |
| a cross-kind splice between OBJ/STR and a numeric kind, or STR and OBJ | the register is not converted: an integer stored as a pointer, or a pointer printed as an integer |
| growing an OBJ or STR array back over the slot a rejected `pop` left; a self-splice at offset 0 of an OBJ or STR array with `start > 0` | both make live elements of pointers the collector stopped tracking (the first draft's `obj.selfsplice.shifted.prepend` printed the shifted-off objects back: it worked because no collection fell in between). Reported; kept |
| a `read_buf` that passes the `start + elems` check but lies beyond the storage | a read past the allocation |
| `writeint` on a recomposed array without storage | `write_buf` copies the bytes to the start of the old storage |
| `describe_refs` | needs the heap snapshot profiler; prints nothing |
