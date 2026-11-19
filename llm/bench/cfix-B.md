# cfix area B: VMArray read_buf and write_buf bounds (B1, B2, B3) (Task 4)

```
Branch:    vmarray-buf-bounds, from origin/main f112c3998, in P (local only, not pushed)
Commits:   19624425dcc9254c965f20c1a92b4a0998f84dc0 "Bound VMArray read_buf by elems, not by start + elems" (B1)
           bbbccb01a1f932a852c0a81218051836c435ca23 "Compare VMArray read_buf and write_buf offsets in elements first" (B2)
           440b862c6d6bcf0e046c7f7a8cc5c1cdcb5d28d3 "Refuse VMArray write_buf on element kinds without storage" (B3)
Diff:      src/6model/reprs/VMArray.c, +8 -5, three hunks: write_buf's kind check (B3), write_buf's
           size check (B2), read_buf's bounds check (B1, B2)
Prefixes:  /tmp/claude-1000/cfix-B (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-B-asan
           (--asan --no-mimalloc), built from `git archive` copies /tmp/claude-1000/cfix-src-B{,-asan}
           (cfix-T-raw/build/export-build.sh, unchanged); the built VMArray.c is byte-identical to the
           branch's; make exit 0, 10 s / 20 s, no warning in VMArray.c (729 warnings in all, as cfix-T).
           (Built from 109f773a2, which has the same tree as 440b862c6: only B2's message was reworded
           after the build.)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b in cfix-base and /tmp/claude-1000/cfix-ws),
           only the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-B-raw/repro/ (run-all on both prefixes; the new programs also on cfix-base and cfix-asan),
           cfix-B-raw/cmp.txt and cmp-repro.sh (comparison; Task 4's copy, also used for R and M),
           cfix-B-raw/grid-check.py, predicates.py (the checks of section 2), cfix-B-raw/base-rerun/,
           cfix-B-raw/pr-repro/ (the PR text's programs on cfix-base, cfix-asan, cfix-B, cfix-B-asan),
           cfix-B-raw/hand/ (two seen-on-the-way checks, section 6), cfix-B-raw/suites/, cfix-B-raw/build/
           (logs, mkcommit.sh: commits made without checking the branch out, build-all.sh)
```

## 1. The fix

The three hunks (diff against f112c3998):

```c
@@ write_buf
-    /* Throw on invalid slot type */
-    if (repr_data->slot_type < MVM_ARRAY_I64) {
+    /* Throw on invalid slot type, and on the kinds without storage */
+    if (repr_data->slot_type < MVM_ARRAY_I64 || repr_data->elem_size == 0) {
         MVM_exception_throw_adhoc(tc, "MVMArray: write_buf requires an integer type");
@@ write_buf
-    /* No need to account for start, set_size_internal will take care of that */
-    if (elems * elem_size < offset * elem_size + count) {
+    /* No need to account for start, set_size_internal will take care of that.
+     * Compare in elements first, so that offset * elem_size cannot wrap. */
+    if ((MVMuint64)offset > elems || (elems - offset) * elem_size < count) {
         set_size_internal(tc, body, offset + count, repr_data);
@@ read_buf
-    if (offset < 0 || (start + body->elems) * elem_size < offset * elem_size + count) {
+    /* Compare in elements first, so that offset * elem_size cannot wrap. */
+    if (offset < 0 || (MVMuint64)offset > body->elems
+            || (body->elems - offset) * elem_size < count) {
```

B1's commit changes only `(start + body->elems)` to `body->elems`; B2's commit then rewrites both
comparisons in elements; B3's commit adds the `elem_size == 0` test.

**Callers** (every caller-visible path): `write_buf` and `read_buf` are reached from the interpreter's
writeint/writeuint/writenum and readint/readuint/readnum (interp.c:5288-5435), from the JIT (graph.c:219-223
through MVM_repr_write_buf/read_buf, and graph.c:2397/2444 calling the REPR function directly), from
`MVM_repr_write_buf`/`MVM_repr_read_buf` (reprconv.c:323-328), and from `nqp::serializetobuf`
(serialization.c:933, offset 0, count = the serialized size). Raku reaches them through Blob's read-*/
write-* methods (Buf.rakumod), which do no bounds check of their own.

**Checked against the C.**
- read_buf, B1: the read is at `slots + (start + offset) * elem_size` and covers `count` bytes, so it lies
  within the elements iff `offset * elem_size + count <= elems * elem_size`; the old bound added
  `start * elem_size` of slack. Write_buf already used `elems`.
- B2, the arithmetic: storage is limited by set_size_internal to `ssize <= 2**(64 - a)` elements
  (a = 4, 3, 2, 1 for 8, 4, 2, 1 bytes), i.e. at most 2**63 bytes, and `start + elems <= ssize`. So
  `(elems - offset) * elem_size` (with `offset <= elems`) cannot wrap. The old expression
  `offset * elem_size + count` wraps for offset >= (2**64 - count) / elem_size: 2**61 and up for 8-byte
  kinds, 2**62 for 4-byte kinds, just under 2**63 for 2-byte kinds (the sum, not the product); never for
  1-byte kinds (offset < 2**63).
- B2, a write at a wrapping offset now grows: `set_size_internal(offset + count)`. For any wrapping offset,
  `offset + count > 2**63 / elem_size`, the limit, and the new ssize is at least n in both branches
  (`ssize < 8192`: max(2 * ssize, n); otherwise `(n + 0x1000) & ~0xfff`, which cannot wrap for
  n < 2**63 + 8), so it throws "Unable to allocate an array of N elements" before any realloc. That is
  what a write at a large offset that does not wrap already got (2**60 + 5 on an int64 array, on both
  builds). With start > 0, set_size_internal first moves the elements down to start 0 (before the throw);
  the elements and elems are unchanged, as for any too-large write today.
- B3: the six storage-less kinds (U4, U2, U1, I4, I2, I1; slot types 12-17) have elem_size 0. With elem_size
  0 the old size check `elems * 0 < offset * 0 + count` was true for every count > 0, so every such write
  called set_size_internal, which reallocs the slots to `ssize * 0 = 0` bytes and then throws in zero_slots
  ("Unhandled slot type") before it updates ssize. The new test refuses before anything. read_buf is not
  changed for B3: with elem_size 0 its check (old and new) throws for any count > 0; count 0 copies nothing.
- What else the hunks change (all checked by a program, section 2):
  - a read of zero bytes (flags 32: `1 << 8` truncated to 0 by the ops' unsigned char, which passes their
    `size > 8` check) starting past the last element but before `start + elems` now throws: the B1 change,
    for count 0;
  - a write to a fresh array of a storage-less kind now throws "write_buf requires an integer type" instead
    of "Unhandled slot type", and no longer allocates first;
  - nothing else: for every offset whose old byte expression does not wrap, the new checks give the same
    answer as the old ones (B1's check for reads, the original one for writes).

**Defined behaviour** (all existing messages, no new one):
- a read that does not lie within the elements throws "MVMArray: read_buf out of bounds ...", whatever
  start and offset are (B1, B2);
- a write at an offset whose byte position would wrap throws "Unable to allocate an array of N elements", as
  a too-large write already does (B2). Alternative for the maintainers: "MVMArray: Index out of bounds", as
  for a negative offset;
- a write to a storage-less kind throws "MVMArray: write_buf requires an integer type", the refusal object
  and string kinds already get (B3). The message is slightly off for int1/int2/int4, which are integer kinds
  VMArray cannot store; the alternative is "Unhandled slot type", which set_size_internal already throws.

Hunks: write_buf 994-1009 and read_buf 1026-1029. Area S's hunks are in copy_elements and asplice, P's in
asplice, T's in pop and unshift, G's in set_size_internal, R's in compose: `git merge-tree` of this branch with
each of the six other fix branches is clean.

Three commits: three defects (wrong bound, wrapping arithmetic, missing kind check), each separable. B1 and
B2 touch the same condition in read_buf, so B2's commit is on top of B1's.

## 2. Reproducers, before and after

| program | cfix-base / cfix-asan (before) | cfix-B / cfix-B-asan (after) |
|---|---|---|
| `B1-read-buf-past-storage.nqp` | `past1: 8`, `past4: 526343` (bytes after the 8-byte block); ASAN: heap-buffer-overflow READ in read_buf, 0 bytes after the 8-byte region | `last: 8`, `past1: DIED MVMArray: read_buf out of bounds offset 6 start 2 elems 6 count 1`, `past4: DIED ... offset 4 start 2 elems 6 count 4`; both builds, exit 0 |
| `B1-read-buf-past-storage.raku` | the same from `Buf.read-uint8/read-uint32` (other bytes each run) | the same as the nqp program |
| `B2-buf-offset-wrap.nqp` | `i64 read at 2305843009213693953: 2`, write returns, `i64 after: 1 99 3 4`; the same for i32 at 2**62+1; ASAN identical | read: `DIED MVMArray: read_buf out of bounds offset 2305843009213693953 start 0 elems 4 count 8`; write: `DIED Unable to allocate an array of 2305843009213693961 elements`; `i64 after: 1 2 3 4`; i32 the same (`... 4611686018427387909 elements`, `1 2 3 4`); both builds |
| `B2-buf-offset-wrap.raku` | `Buf[uint64]: read 2, write ok, after 1 99 3 4`, `Buf[uint32]` the same | `read DIED ...out of bounds..., write DIED Unable to allocate ..., after 1 2 3 4`, both lines |
| `B2-buf-offset-before-storage.nqp` (new) | `read: 65536`, `write: returned`, `after: elems 8: 8738 2 3 4 5 6 7 8` (two bytes written before the allocation); ASAN: heap-buffer-overflow READ of size 4 in read_buf, "2 bytes before 16-byte region" | `read: DIED ... out of bounds offset 9223372036854775807 start 0 elems 8 count 4`, `write: DIED Unable to allocate an array of 9223372036854775811 elements`, `after: elems 8: 1 2 3 4 5 6 7 8`; both builds |
| `B3-writeint-no-storage-kind.nqp` | first write returns, `elems 8`; second `DIED MVMArray: Unhandled slot type`; third returns; ASAN: SEGV on address 0 (memcpy) | every write `DIED MVMArray: write_buf requires an integer type`, `elems 3`, `survived`; both builds |
| `B3-write-no-storage-state.nqp live` (new) | as above, with elems after each write: 8, 8, 8; ASAN SEGV at the third | each write DIED (requires an integer type), elems 3 after each; both builds |
| `B3-write-no-storage-state.nqp fresh` (new) | each write `DIED MVMArray: Unhandled slot type`, elems 0 | each write `DIED MVMArray: write_buf requires an integer type`, elems 0 |
| `B-buf-grid.nqp` (new) | 2200 reads and 2200 writes (below); ASAN stops at the first B1 read (heap-buffer-overflow, 0 bytes after an 8-byte region, case `R kind=int8 start=1 elems=7 off=0 size=8`) | `grid-check.py`: 0 violations on cfix-B and cfix-B-asan (identical counts) |

In the B3 programs the element reads print `DIED MVMArray: Unhandled slot type, got 'unknown'` on every
build: VMArray has no element access for these kinds (the `got 'unknown'` part is Task 3's seen-on-the-way
note: at_pos passes a slot type to `MVM_reg_get_debug_name`).

**The grid** (`cfix-repro/B-buf-grid.nqp`): 10 kinds (int8 .. uint64, num32, num64) × start 0, 1, 3 ×
offsets -1 .. elems + 2 and 2**60 + 5, 2**61 + 1, 2**62 + 1, 2**63 - 1 × sizes 1, 2, 4, 8, 0: a read on the
array, and a write on a fresh array followed by elems and every element. Large writes that would reach malloc
(n <= the limit: an out-of-memory panic on both builds, G2's documented behaviour) are skipped (207).
`cfix-B-raw/grid-check.py base.txt cfix-B.txt` computes, with exact integers, what the old and the new checks
decide for each case and requires: identical output wherever they decide the same; where they differ, a read
must now print "read_buf out of bounds" and a write "Unable to allocate an array of" with the array as it was
made. Result, cfix-base vs cfix-B (cfix-B-asan the same):

```
   366  R decision changed (old passes, new refuses)
  1834  R same decision, identical
   180  W decision changed (old in place, new grows)
   150  W negative, identical
  1663  W same decision, identical
   207  W skipped
violations: 0
```

The 366 reads: 186 B1 cases (start > 0, reading past the last element) and 180 at wrapping offsets
(2**61 + 1 and up for 8-byte kinds, 2**62 + 1 and up for 4-byte kinds, 2**63 - 1 for 2-byte kinds); the 180
writes are all at wrapping offsets. The plain base's B1 lines print bytes from outside the array and vary
run to run (a second cfix-base run, `base-rerun/`, differs from the first on 100 such lines and nowhere else:
`grid-check.py --unchanged`, 0 violations).

**The arithmetic claims, by program** (`cfix-B-raw/predicates.py`): the checks as uint64 predicates, over
850265 cases (all element sizes; edge and random elems, start and offsets with start + elems within the
limit; count 0-8): B1 changes the read decision only when start > 0; B2 changes either decision only when
the old expression wraps; every access the new checks let through lies within `(start + elems) * elem_size`;
every wrapping write the new check sends to set_size_internal is over its limit. 0 violations.

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-B -o cfix-B-raw/repro` and `-p cfix-B-asan` (49 program/case pairs each, 98 outputs; run-all
now also runs the four programs added in this task). `cfix-B-raw/cmp-repro.sh cfix-B-raw/repro B` (Task 3's
script, extended for this task's prefixes and new upstream outputs). Result (`cfix-B-raw/cmp.txt`): 80 same,
18 differ, all of them the expected flips: B1 nqp and raku, B2 nqp and raku, B2-before-storage, B3, B3-state
live and fresh, and the grid, each on both builds. The usual noise (B1's raku program, O1 int64, N2's
RSS) is all inside these flips or the same this time: no other file differs.

## 4. Suites

`cfix-maketest-driver.sh cfix-B-raw/suites cfix-B` (probes map `/tmp/claude-1000/cfix-B/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (19 s, load 0.93) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (129 s, load 1.21) | identical (`diff` empty) |

## 5. Draft PR text

Title: **Fix the bounds checks of VMArray read_buf and write_buf**

Body:

> This fixes three bugs in the bounds checks of VMArray's read_buf and write_buf. They are behind
> `nqp::readint`, `readuint`, `readnum`, `writeint`, `writeuint`, `writenum`, and Raku's `Blob.read-*` and
> `Buf.write-*` methods. Every rejected access throws an exception that already exists. A read that does
> not lie within the elements throws "read_buf out of bounds". A write at an offset so large that its byte
> position wraps around throws "Unable to allocate an array of N elements". That is what a write at an
> offset past the array size limit that does not wrap already throws; "Index out of bounds", which a
> negative offset gets, would be the other choice. A write to an element kind VMArray has no storage for throws "write_buf
> requires an integer type", as object and string arrays already do. One commit per bug.
>
> 1. read_buf checked a read against `(start + elems) * elem_size`, but reads from
>    `slots + (start + offset) * elem_size`. Once elements had been shifted off the front, a read could
>    end up to `start * elem_size` bytes past the last element, and past the end of the allocation. The
>    check now uses `elems * elem_size`, as write_buf's already did.
> 2. Both functions compared `offset * elem_size + count` in 64 bits. That wraps for an offset of 2**61 or
>    more on an 8-byte kind, 2**62 on a 4-byte kind, and just under 2**63 on a 2-byte kind. The check then
>    saw a small position, and the access went to an aliased slot or, near 2**63, before the first element.
>    Both now first check that the offset is not past elems, and then compare the bytes from the offset to
>    the last element with count. Neither can wrap, because the storage is limited to 2**63 bytes. A write
>    at such an offset now asks set_size_internal for offset + count elements, which is over its limit, so
>    it throws. The array keeps its elements.
> 3. write_buf refused only the object and string kinds. On int1/int2/int4/uint1/uint2/uint4 (element size
>    0) every write called set_size_internal. That reallocates the slots to 0 bytes and then throws
>    "Unhandled slot type" before updating ssize. An array that had storage then wrote through the freed
>    pointer on the next write within the old size. Such an array can only exist if its type was
>    recomposed while it was alive. On a type composed with such a kind from the start, the message changes
>    from "Unhandled slot type" to the one above. read_buf needs no change for this: its check already
>    throws for any read of one byte or more there.
>
> Bugs 1 and 2 are reachable from plain Raku:
>
> ```
> my $b = Buf.new(1..8);
> $b.shift for ^2;
> say "elems {$b.elems}: {$b.list}";
> for 5, 6 -> $off {
>     say "read-uint8($off): ", (try $b.read-uint8($off)) // "died: {$!.message}";
> }
> say "read-uint32(4): ", (try $b.read-uint32(4)) // "died: {$!.message}";
> for (buf64, 2**61 + 1), (buf32, 2**62 + 1) -> ($type, $off) {
>     my $c = $type.new(1, 2, 3, 4);
>     my $r = (try $type ~~ buf64 ?? $c.read-int64($off) !! $c.read-int32($off)) // "died: {$!.message}";
>     my $w = (try { $type ~~ buf64 ?? $c.write-int64($off, 99) !! $c.write-int32($off, 99); 'ok' }) // "died: {$!.message}";
>     say "{$type.^name} at $off: read $r; write $w; now {$c.list}";
> }
> my $d = buf16.new(1..8);
> my $r = (try $d.read-uint32(2**63 - 1)) // "died: {$!.message}";
> my $w = (try { $d.write-uint32(2**63 - 1, 0x22221111); 'ok' }) // "died: {$!.message}";
> say "buf16 at {2**63 - 1}: read $r; write $w; now {$d.list}";
> ```
>
> Before (the two reads past the end print whatever bytes follow the 8-byte block, different each run):
>
> ```
> elems 6: 3 4 5 6 7 8
> read-uint8(5): 8
> read-uint8(6): 64
> read-uint32(4): 2118125575
> Buf[uint64] at 2305843009213693953: read 2; write ok; now 1 99 3 4
> Buf[uint32] at 4611686018427387905: read 2; write ok; now 1 99 3 4
> buf16 at 9223372036854775807: read 65536; write ok; now 8738 2 3 4 5 6 7 8
> ```
>
> With AddressSanitizer, the program stops at `read-uint8(6)` with a heap-buffer-overflow in read_buf,
> 0 bytes after the 8-byte region. Run alone, the buf16 read is a heap-buffer-overflow 2 bytes before the
> 16-byte region.
>
> After (plain and AddressSanitizer builds alike):
>
> ```
> elems 6: 3 4 5 6 7 8
> read-uint8(5): 8
> read-uint8(6): died: MVMArray: read_buf out of bounds offset 6 start 2 elems 6 count 1
> read-uint32(4): died: MVMArray: read_buf out of bounds offset 4 start 2 elems 6 count 4
> Buf[uint64] at 2305843009213693953: read died: MVMArray: read_buf out of bounds offset 2305843009213693953 start 0 elems 4 count 8; write died: Unable to allocate an array of 2305843009213693961 elements; now 1 2 3 4
> Buf[uint32] at 4611686018427387905: read died: MVMArray: read_buf out of bounds offset 4611686018427387905 start 0 elems 4 count 4; write died: Unable to allocate an array of 4611686018427387909 elements; now 1 2 3 4
> buf16 at 9223372036854775807: read died: MVMArray: read_buf out of bounds offset 9223372036854775807 start 0 elems 8 count 4; write died: Unable to allocate an array of 9223372036854775811 elements; now 1 2 3 4 5 6 7 8
> ```
>
> Bug 3, in nqp, with an int8 array whose type is recomposed to uint4 while it is alive:
>
> ```
> sub int_type(int $bits) {
>     my $t := nqp::newtype(nqp::null(), 'P6int');
>     nqp::composetype($t, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
>     $t
> }
> sub try_write($a, int $off) {
>     my $r := 'returned';
>     try { nqp::writeint($a, $off, 1, 12); CATCH { $r := 'died: ' ~ nqp::getmessage($!) } }
>     say("write at $off: $r; elems " ~ nqp::elems($a));
> }
> my $type := nqp::newtype(nqp::null(), 'VMArray');
> nqp::composetype($type, nqp::hash('array', nqp::hash('type', int_type(8))));
> my $a := nqp::create($type);
> nqp::push_i($a, 1); nqp::push_i($a, 4); nqp::push_i($a, 7);
> nqp::composetype($type, nqp::hash('array', nqp::hash('type', int_type(4))));
> try_write($a, 0);
> try_write($a, 8);
> try_write($a, 0);
> ```
>
> Before: `write at 0: returned; elems 8`, `write at 8: died: MVMArray: Unhandled slot type; elems 8`,
> `write at 0: returned; elems 8`. The last write goes through the pointer that `realloc(p, 0)` left;
> with AddressSanitizer it is a SEGV on address 0. After, on both builds, each of the three lines is
> `died: MVMArray: write_buf requires an integer type; elems 3`.
>
> I also checked the new conditions against the old ones over a grid: ten element kinds, start 0, 1 and 3,
> every offset from -1 to two past the end plus the large ones above, and sizes 0, 1, 2, 4 and 8, each a read
> and a write followed by the whole array. Output differs only where the old check let through a read past
> the elements or an offset that wraps; everywhere else it is identical. `make test` of nqp and Rakudo gives
> the same per-file results as before.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)

## 6. Seen on the way (reported, not fixed)

- **The JIT's readuint skips the size check.** The interpreter refuses readint/readuint flags whose size is
  over 8 bytes ("Invalid flags value"), but the JIT's readuint path (graph.c:2430-2460) passes the size from
  the flags straight to read_buf, which copies `count` bytes into its 8-byte `result`. `cfix-B-raw/hand/
  jit-readuint-size16.nqp` (flags 16, size 16, in a hot loop): plain cfix-base "*** stack smashing detected
  ***" (exit 134); cfix-asan and cfix-B-asan: stack-buffer-overflow WRITE of size 16 on `result` in read_buf.
  (The same JIT block also takes the type facts of operand 0, the destination register, not the buffer, so
  the direct-call branch is probably never taken for readuint.) A one-line fix would be `count > 8` in
  read_buf or the check in the JIT; not on this branch's list.
- **writenum has no size check.** Its default arm (any size but 4) copies `size` bytes from an 8-byte local:
  `cfix-B-raw/hand/writenum-size16.nqp`, `nqp::writenum($a, 0, 1.5, 16)`: plain cfix-base returns with elems
  16; cfix-asan: stack-buffer-overflow READ of size 16 in MVM_interp_run (the interpreter, no JIT).
- write_buf still grows to `offset + count` elements, with count in bytes (Task 1's note: over-allocation for
  wide kinds); unchanged here.
