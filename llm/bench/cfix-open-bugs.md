# MoarVM bugs seen and not fixed by the cfix campaign

```
Date:            2026-11-19
Upstream:        MoarVM origin/main f112c3998 ("Merge pull request #2067 ...")
Port:            branch zig-vmarray-c-fixes, tip 0d4149a90 (traces pointer commit), merged into zig-hash-engine
                 by fast-forward on 2026-11-19; last commit touching src/zig
                 0d759048a. The checked-out C carries the eleven cherry-picked fixes (#2076-#2086); upstream
                 C below is always read with `git show origin/main:<path> | sed -n <a>,<b>p`.
Campaign:        traces/llm/plans/2026-11-19-vmarray-c-fixes.md (Outcome, "Seen and not fixed")
Written by:      a read-only pass; nothing was built, nothing changed except this file.
```

What this file is for. The cfix campaign fixed eleven areas (PRs #2076-#2086). On the way it saw more defects
and did not fix them. This file lists them so that they can be fixed later: first in the Zig port of MoarVM,
then as C fixes upstream. Each item says where the code is, what goes wrong, how it was found, whether the Zig
port has it, and what a fix would have to decide.

Evidence levels:
- **reproduced**: a program and its output are known (from a record, or run in this pass, said which).
- **read**: found by reading code; the reasoning is given.
- **observed, undiagnosed**: a failure was seen, its cause is not known.

Marks used in the sections:
- "[checked]" means I checked it in this pass against the source, with the command or file:line given.
- "[record]" means it is taken from the named record and was not re-checked in this pass.
- "[ran]" means I ran it in this pass on an existing build (`ulimit -c 0`, `systemd-run --user --scope -q
  -p MemoryMax=4G` or 2G, the runner of /tmp/claude-1000/cfix-base with `LD_LIBRARY_PATH` set to the prefix's
  lib). Nothing was run on the port in this pass. (The pass did not find the port's builds vf-c-base and
  vf-n-base; they do exist under /tmp/claude-1000, checked afterwards by the controller.)

Line numbers: "VMArray.c" means src/6model/reprs/VMArray.c at origin/main unless the text says "port".
Zig paths are relative to src/zig/6model/reprs/ at the port tip.

## Summary

| id | description | where (origin/main) | evidence | consequence | reachable from | in the Zig port? |
|---|---|---|---|---|---|---|
| OB1 | `~0xfffUL` is 32 bits on Win64, the rounded size is truncated below n | VMArray.c:set_size_internal 447 | read | memory unsafety (upstream); spurious throw after #2077 | platform (Win64), nqp setelems | no: storage.zig:167 masks with `~@as(u64, 0xfff)` |
| OB2 | a VMArray type object as splice source is not refused; elems read past the type object | VMArray.c:asplice 1045 | reproduced | memory unsafety (out-of-bounds read), huge allocation or panic | Raku (`Buf.new(array[int])`), nqp | yes: vmarray/elements.zig:asplice 695 |
| OB3 | buffer op size checks missing: JIT readuint, JIT writeint/writeuint, writenum | jit/graph.c 2384-2476; core/interp.c:writenum 5313-5354 | reproduced (readuint JIT, writenum); read (writeint JIT) | memory unsafety (stack over-read/over-write) | nqp (flags are an operand) | yes: the JIT and interp.c are shared C; read_buf/write_buf are Zig (elements.zig readBuf 878, writeBuf 851) with the same copies |
| OB4 | adopted buffers leave room past elems unwritten; setelems exposes it | strings/normalize.c 86-90, 199-203; io/procops.c 684-687; io/asyncsocket.c 48-51; io/asyncsocketudp.c 111-114 | reproduced | wrong result, information leak (uninitialized heap) | nqp; Raku plausibly (Buf.reallocate on a received Buf), not run | yes: the sites are shared C; storage.zig:setSize 130-131 does not zero within ssize |
| OB5 | MVMHash deserialize holds `key` in a C local across read_ref | 6model/reprs/MVMHash.c:deserialize 194-200 | read | memory unsafety (stale pointer), if a collection can run there | serialization (any deserialize of a hash) | yes: the same C (port MVMHash.c 196-202); the Zig collector's behaviour there not checked |
| OB6 | at_pos default arm names a slot type with the register-kind name table | VMArray.c:MVM_VMArray_at_pos 355-356 | reproduced | cosmetic (wrong word in a message) | nqp (only with a storage-less kind that has elements) | yes: elements.zig:unhandledAtPos 338-344 |
| OB7 | rejected push / bind_pos (wrong register kind) has already grown the array | VMArray.c:MVM_VMArray_push 580, MVM_VMArray_bind_pos 490-491 | reproduced | wrong result (elems) | nqp | yes: elements.zig push 526, bindIndex 167 |
| OB8 | write_buf grows to `offset + count` elements with count in bytes | VMArray.c:write_buf 1006-1007 | reproduced | wrong result (elems too large) and over-allocation | Raku (`buf16.write-uint64`), nqp | yes: elements.zig:writeBuf 844-845 |
| OB9 | normalizecodes of empty input leaves the output untouched | strings/normalize.c:MVM_unicode_normalize_codepoints 52-53 | reproduced | wrong result | nqp (Rakudo passes fresh outputs) | yes: the same C (port normalize.c 52-53) |
| OB10 | nqp::encode leaks its buffer when the resize throws | strings/ops.c:MVM_string_encode_to_buf_config 1909-1911 | read | leak | nqp, only near the size limit | yes: the same C (port ops.c 1912-1919) |
| OB11 | first compose of a VMArray type that already has instances changes their kind (PR #2081 refuses only a second compose) | VMArray.c:compose 1320-1333 (port: 1377-1405) | reproduced | type confusion (str: an object read as a string; native: pointers read as integers); memory unsafety for storage-less kinds without #2079/#2080 | nqp (`nqp::newtype` + `nqp::create` before `nqp::composetype`) | yes: vmarray/serial.zig:compose 271-291 |
| OB12 | #2081's message has a double space for a type without a debug name | port VMArray.c:compose 1397-1399 (not in origin/main) | reproduced | cosmetic | nqp | yes: serial.zig:287 |
| OB13 | ~2 % of `blocked.nqp --stress` runs segfault in `--full-cleanup` | unknown | observed, undiagnosed | crash at exit | moar --full-cleanup, stress prefixes | seen on the port's C-array and Zig-array builds; never run on upstream |
| OB14 | under `-Doptimize=ReleaseSafe` every VM-booting unit test aborts ("cast causes pointer to be null") | unknown, Zig boot path | observed, undiagnosed | build (safety-checked builds unusable) | port build | port only (Zig code) |
| OB15a | t/04-nativecall/02-simple-args.t 17-18 fail on the port's stack, pass on upstream | unknown | observed, undiagnosed | test failure | Raku | port's stack only |
| OB15b | the Perl (Configure.pl) build path of the port's change was never exercised | Configure.pl | observed (not run) | build | build | port only |
| OB15c | the port has no AddressSanitizer build | build | observed | test coverage | - | port only |
| OB15d | storage-less kinds keep NULL slots in Zig where C stores malloc(0) | storage.zig:grow 188-199 | read | none observed (pointer value differs) | nqp, nativecall | port only (deliberate) |
| OB16 | write_buf/read_buf accept the num kinds; the message says "integer type" | VMArray.c:write_buf 995-997, read_buf 1022-1024 | reproduced | cosmetic / undefined intent | nqp | yes: elements.zig:writeBuf 840-841, readBuf 871 |
| OB17 | storage-less kinds misreported: get_elem_storage_spec says reference, the debugger says int | VMArray.c:get_elem_storage_spec 1185-1189; debug/debugserver.c 2535-2559 | read | wrong result (reflection) | nqp, debugger | yes for the spec: elements.zig:referenceSpec 436; the debugger is shared C |
| OB18 | deserialize allocates `elems * elem_size` with no limit (the product can wrap); storage-less kinds can never be deserialized | VMArray.c:deserialize 1369-1372, 1423-1424 | read | memory unsafety on crafted data; wrong result | nqp::deserialize of a crafted blob; serialization | yes: serial.zig:deserialize 222-228, storage.zig:alloc 57 |
| OB19 | OBJ holes come back as NULL from pop/shift but VMNull from at_pos; copy_elements turns holes into VMNull only for a gen2 target | VMArray.c:pop 663, copy_elements 933-967 | read (record: differential) | wrong result (inconsistent) | nqp | yes, by design (va-kind-differences.md rows 18b, 22b) |
| OB20 | growth of a storage-less kind stores `realloc(slots, 0)`'s result in slots, then throws before ssize | VMArray.c:set_size_internal 464-471 | read | stale state (no known memory unsafety after #2079/#2080) | nqp | no: storage.zig:grow 190 skips the allocator for 0 bytes (OB15d) |
| OB21 | a splice at offset 0 removing every element resets start and elems without clearing the slots; later growth brings the removed elements back | VMArray.c:asplice 1070-1075 with set_size_internal 431-434 | reproduced (Task 7, also on cfix-base) | memory unsafety (unmarked object pointers come back), wrong result | nqp | yes before area Z (elements.zig asplice, storage.zig setSize); fixed in the port |
| OB22 | P6opaque's oslice passes its own P6opaque `dest` to the delegate's slice, which treats it as an array | P6opaque.c:oslice 1502-1510; VMArray.c:aslice 969-974; interp.c OP(slice) 5196 | reproduced (Task 7: an allocation panic; ASAN allocation-size-too-big in aslice) | type confusion, memory unsafety | nqp (`is positional_delegate` + `nqp::slice`); no known caller | yes: shared C; Zig aslice the same |
| OB23 | the JIT's generic repr-op calls (op_to_func's MVM_repr_*) skip the interpreter's concreteness check | jit/graph.c consume_reprop, op_to_func; 6model/reprconv.c (e.g. MVM_repr_bind_pos_i 288-293) | reproduced (bindpos_i; ASAN wild write on cfix-asan) | memory unsafety | nqp, JIT-compiled code given a type object | yes: shared C |
| OB24 | deserialization holds the object being read (and body pointers) in unrooted C locals across calls that can allocate | serialization.c:deserialize_object 2671-; MVMHash.c:deserialize 194-200; every REPR's deserialize | read | memory unsafety, if the object could move there | serialization | yes: shared C; Zig VMArray deserialize the same shape |
| OB25 | strtocodes of an empty string calls MVM_malloc(0), which panics where malloc(0) returns NULL | strings/normalize.c:MVM_unicode_string_to_codepoints 162 | read | crash (panic) on such a C library | nqp (`nqp::strtocodes`); Rakudo callers not searched | yes: shared C |

Items 16-20 were added in this pass; where each was found is in its section. Items 21-25 were added on
2026-11-24 by the ob-fixes campaign (Task 7), with OB2's slice sibling; every entry now has a status line
under its heading (traces/llm/bench/ob-fixes.md has the details and the commits).

## OB1. Win64: `~0xfffUL` truncates the rounded size

Status 2026-11-24: fixed in the port (C 30134b931; the Zig already had a 64-bit mask), see ob-fixes.md "Shared
C". Not run (no Windows build).

**Location** [checked: `git show origin/main:src/6model/reprs/VMArray.c | sed -n 405,476p`]:
VMArray.c, `set_size_internal`, line 447.

```c
    if (ssize < 8192) {
        ...
    }
    else {
        ssize = (n + 0x1000) & ~0xfffUL;
    }
```

**What goes wrong.** `n` is `MVMuint64` [record: cfix-G.md section 6 cites src/moar.h:103]. Where
`unsigned long` is 32 bits (LLP64, 64-bit Windows), `~0xfffUL` is 0xFFFFF000. It is zero-extended for the `&`,
so the upper 32 bits of the sum are cleared. For `n >= 2**32 - 4096` (and an array that already has 8192 or
more slots) the new `ssize` is below `n`. Upstream then reallocates to that smaller size, `zero_slots` runs
from the old size to the smaller one, and `elems = n`: later accesses go past the buffer. With #2077 merged the
`ssize < n` check throws "Unable to allocate an array of N elements" instead: memory-safe, but a size that
would fit is refused.

The reasoning above is mine from the types [checked: the line]; the conclusion matches cfix-G.md section 6.
That `unsigned long` is 32 bits on Win64 is the LLP64 model, not checked on a Windows machine.

**How found.** Task 2 review of area G (cfix-ledger.md, Task 2 review line; cfix-G.md section 6 "Win64 mask").
Named as "a related observation" in #2077's text (cfix-G.md section 5).

**Reproducer.** None. It needs a 64-bit Windows build: `nqp::setelems($a, 8192)` on an int8 array, then
`nqp::setelems($a, 4294967296)`, then a read near the end. Upstream would be expected to crash; with #2077 to
throw.

**Zig port.** No. storage.zig:167 is `ssize = (n +% 0x1000) & ~@as(u64, 0xfff);` [checked], a 64-bit mask on
every target; storage.zig:171-172 also carry #2077's `ssize < n` check [checked].

**Fix sketch.** Use a 64-bit constant (`~(MVMuint64)0xfff` or `~UINT64_C(0xfff)`). No behaviour choice. With
#2077 merged the fix also removes a spurious throw on Win64.

**Uncertain.** Nothing was run on Windows.

## OB2. A VMArray type object as the splice source

Status 2026-11-24: fixed in the port (C 771b359b6, Zig 14b817180), see ob-fixes.md "Y and Q".

**Location** [checked: `sed -n 1040,1121p` of origin/main VMArray.c; `git show origin/main:src/core/interp.c |
sed -n 2321,2329p`; `git show origin/main:src/gc/allocation.c | sed -n 71,81p`]:
VMArray.c, `asplice`, line 1045.

```c
    MVMuint64 elems0 = body->elems;
    MVMuint64 elems1 = REPR(from)->elems(tc, STABLE(from), from, OBJECT_BODY(from));
```

**What goes wrong.** `OP(splice)` checks only the target with `CHECK_CONC(obj)` (interp.c:2323) [checked].
asplice never checks that `from` is concrete. A type object is allocated with `sizeof(MVMObject)` bytes
(allocation.c:74-76) [checked], so `OBJECT_BODY(from)` points just past it, and `elems` reads `body->elems`
from whatever follows the type object in memory. The target is then grown to `offset + elems1 + tail`, and
`copy_elements` reads `from`'s slots pointer from the same foreign memory. P's checks (#2079) do not catch it:
the REPR is VMArray, and the type object's REPR data is that of an object array [record: cfix-P.md section 6].
`MVM_repr_pos_splice` (reprconv.c:82-86) passes the source through unchecked as well [checked].

**How found.** Task 3 review (cfix-ledger.md Task 3 review, "Seen, out of scope"); cfix-P.md section 6; the
Raku route in cfix-P.md section 5 (table row `Buf.new(array[int])`, via Buf.rakumod:410 and the `int @values`
candidate) [record].

**Reproducer** (record: cfix-P-raw/round1/typeobj/typeobj.nqp, with its outputs in the same directory):

```
my $a := nqp::list(1, 2, 3);
my $t := nqp::what(nqp::list());
say("source is concrete: " ~ nqp::isconcrete($t));
my $r;
try { nqp::splice($a, $t, 1, 0); $r := 'returned, elems ' ~ nqp::elems($a); CATCH { $r := 'DIED ' ~ nqp::getmessage($!) } }
say("splice from a type object: $r");
```

- cfix-base, MemoryMax=2G: prints `source is concrete: 0`, then exit 137 (killed by the memory cap) [record,
  and ran: same output and exit 137].
- cfix-asan: `requested allocation size 0x16800000038 ... in set_size_internal` [record].
- Raku: `Buf.new(array[int])` gives "MoarVM panic: Memory allocation failed; could not allocate
  264965122424860 bytes" on cfix-base and cfix-P [record: cfix-P.md section 5 table].

The count read is whatever lies after the type object, so the result varies: a huge count fails the
allocation; a small count would copy from a garbage slots pointer. The second case was not seen.

**Zig port.** Yes. elements.zig:695 reads `elems1` through `moar.objectBody(from_obj)` with no concreteness
check [checked]; the P checks that follow (elements.zig:705-718) test the REPR ID and the kinds only.

**Fix sketch.** Refuse a non-concrete source in asplice (or in `OP(splice)` and `MVM_repr_pos_splice`).
Choices: throw (message such as "MVMArray: Cannot splice from a type object"), or treat a type object as an
empty source (a delete). Throwing matches `writeint`/`readint`, which throw "Cannot write to a %s type object".
The same question applies to `aslice`'s target and to `copy_elements`; not checked here.

**Sibling: `nqp::slice` of a type object** (added 2026-11-24; found and fixed in ob-fixes Task 3, the same
commits). `OP(slice)` (interp.c), `MVM_repr_pos_slice` (reprconv.c, the JIT's path) and P6opaque's `oslice`
never check that the array sliced from is concrete. `aslice` read `elems` from the type object's missing body:
`nqp::slice(nqp::what(nqp::list()), 0, 0)` segfaulted (exit 139) on vf-c-base, vf-n-base and the ob-c/ob-n
builds before Task 3 [record: ob-fixes.md "Y and Q"]. It now throws `MVMArray: Cannot slice from a type
object` before that read (C VMArray.c aslice, tip line 1103-1104; Zig elements.zig 701-702) [checked in
Task 7].
Reproducer: `ob-repro/OB2-typeobj-slice.nqp`. origin/main has the same aslice without the check
(`git show origin/main:src/6model/reprs/VMArray.c`, aslice 969-974) [checked]. Only `aslice` was fixed. An
`nqp::slice` of a *P6opaque* type object (with a positional delegate) is still unchecked: OP(slice) allocates
`dest`, then `oslice` (P6opaque.c 1502-1510) calls `MVM_p6opaque_real_data` on the type object's missing body
(it reads `replaced` from past the allocation) and fetches the delegate from a garbage offset [by reading in
fix round 1 of Task 7; not run]. A delegate attribute holding a type object, and P6opaque's own `dest` handed to
the delegate, are the same `oslice` path; the latter is OB22. The former is noted in ob-fixes.md "Y and Q",
"Not verified" (not run).

## OB3. Missing size checks on the buffer ops (JIT readuint, JIT writeint/writeuint, writenum)

Status 2026-11-24: fixed in the port (C f2c32559a, shared C; Zig readBuf/writeBuf unchanged by ruling), see
ob-fixes.md "Shared C".

**Location** [checked: `git show origin/main:src/jit/graph.c | sed -n 2375,2478p`;
`git show origin/main:src/core/interp.c | sed -n 5288,5440p`]:
- src/jit/graph.c, `case MVM_OP_writeuint`/`MVM_OP_writeint`, lines 2384-2430.
- src/jit/graph.c, `case MVM_OP_readuint`, lines 2432-2476.
- src/core/interp.c, `OP(writenum)`, lines 5313-5354.
- The interpreter checks for comparison: writeint/writeuint 5297-5299, readint/readuint 5381-5384.

```c
    /* interp.c:5294-5299, writeint/writeuint */
    unsigned char const size  = 1 << (flags >> 2);
    ...
    if ((flags & 3) == 3 || size > 8) {
        MVM_exception_throw_adhoc(tc, "Invalid flags (%"PRIu64") or size (%hhu) value for writeint", flags, size);
    }

    /* graph.c:2390-2392, the JIT's writeint/writeuint (readuint 2438-2440 is the same) */
    if (facts->flags & MVM_SPESH_FACT_KNOWN_VALUE) {
        if ((facts->value.i & 3) != MVM_SWITCHENDIAN) {
            unsigned char const size  = 1 << (facts->value.i >> 2);
```

**What goes wrong.**
- (a) JIT readuint. The interpreter refuses `(flags & 3) == 3` and `size > 8`. The JIT bails out only when the
  flags are not a known value or ask for an endian switch; then it calls `read_buf` (directly, or through
  `MVM_repr_read_buf`, graph.c:222) with `size` up to 128. `read_buf` copies `count` bytes into its 8-byte local
  `result` (VMArray.c:1018, 1030-1034) [checked]: a stack buffer overflow. The direct-call branch takes the type
  facts of operand 0, which for readuint is the destination register, not the buffer (graph.c:2441 vs 2433-2434)
  [checked], so that branch is probably never taken [record: cfix-B.md section 6 says "probably"].
- (b) JIT writeint/writeuint. Same shape: with flags 3 the value is written in native order (`MVM_SWITCHENDIAN`
  is 2 on little-endian, interp.h:99-103 [checked]), and a size of 16..128 makes `write_buf` copy that many bytes
  from the address of an 8-byte register (`MVM_JIT_REG_ADDR, value`) [checked: graph.c:2403, 2411]: a stack or
  register-file over-read.
- (c) writenum. Every size but 4 goes to the `default` arm, which passes `size` bytes of an 8-byte
  `double_memory` to `write_buf` (interp.c:5335-5346) [checked]. Sizes over 8 over-read the stack. Sizes 1 and 2
  (flags 0..7) write the low bytes of the double, which is in bounds but has no defined meaning. writenum also does
  not refuse `(flags & 3) == 3`. graph.c has no writenum case [checked: grep], so this is the interpreter.

**How found.** (a) and (c): Task 4 implementer, ASAN-confirmed (cfix-ledger.md Task 4 implementer line;
cfix-B.md section 6). (b): Task 4 review, by reading, "Not run" (cfix-B.md section 6, third bullet).

**Reproducers** [record: cfix-B-raw/hand/, outputs `*.cfix-base.txt`, `*.cfix-asan.txt`]:

(a) `cfix-B-raw/hand/jit-readuint-size16.nqp` (abridged; the full file defines `inttype` the same way):

```
my $at := nqp::newtype(nqp::null(), 'VMArray');
nqp::composetype($at, nqp::hash('array', nqp::hash('type', inttype(8, 1))));   # uint8 elements
my $a := nqp::create($at);
my int $i := 0; while $i < 64 { nqp::push_i($a, $i); $i++ }
sub rd($a) { nqp::readuint($a, 0, 16) }
my int $died := 0; my int $ret := 0; my $last := '';
$i := 0;
while $i < 200000 { try { $last := rd($a); $ret++; CATCH { $died++ } }; $i++ }
say("died $died, returned $ret, last $last");
```

- cfix-base: `*** stack smashing detected ***: terminated`, exit 134.
- cfix-asan: `stack-buffer-overflow ... WRITE of size 16`, in `read_buf`, on `'result' (line 1018)`.

(c) `cfix-B-raw/hand/writenum-size16.nqp`: the same uint8 array type, then
`nqp::writenum($a, 0, 1.5, 16); say("elems " ~ nqp::elems($a));`

- cfix-base: `elems 16`, exit 0.
- cfix-asan: `stack-buffer-overflow ... READ of size 16` in `MVM_interp_run`.

(b) None. It would need a hot loop like (a) calling `nqp::writeint($a, 0, 1, 16)` (flags 16: size 16) or
flags 3, so that the frame is JIT-compiled with the flags as a known value.

**Zig port.** Yes. graph.c and interp.c are the same C in the port (`git diff origin/main HEAD -- src/jit/graph.c`
is empty; interp.c differs only by the port's `hashstrategy` op) [checked]. The REPR functions they call are the
Zig ones under the default build: elements.zig:readBuf copies `count` bytes into the 8-byte `result`
(elements.zig:876-878, `@memcpy((to + at)[0..count], ...)` through a many-pointer, so no length check), and its
doc comment says so ("more would overrun `result`, as in the C", elements.zig:861-863); writeBuf copies `count`
bytes from `from` (elements.zig:851) [checked]. On a big-endian target `8 -% count` would also wrap (line 877).

**Fix sketch.** Put the interpreter's checks in the JIT: bail out (or throw) for `(flags & 3) == 3` and
`size > 8` in both cases, so the interpreter's exception is raised. Add a size check to writenum (4 or 8 only, as
readnum has: "Cannot read a num of %d bytes", interp.c:5432) and decide whether flags 3 is refused there too.
Optionally make `read_buf`/`write_buf` refuse `count > 8` themselves, as defence for C API callers
(`MVM_repr_read_buf`). Choice: whether sizes 1 and 2 for writenum become an error (today they write bytes).

**Uncertain, noticed in this pass, not followed.** The JIT writeint path does not emit the interpreter's
`MVM_SC_WB_OBJ(tc, buf)` (interp.c:5309), and neither JIT path checks `IS_CONCRETE(buf)` as the interpreter does;
whether spesh guarantees either elsewhere was not checked. `1 << (flags >> 2)` is an `int` shift and is undefined
for `flags >> 2 >= 31`; the interpreter evaluates it before any check. Not run.

## OB4. Adopted buffers: the room past elems is never written

Status 2026-11-24: fixed in the port by area Z (C 591f3c20b, 963665442, eb98fd0ba; Zig 8223cc952, 8b1ff900c,
30ce0ba0a), see ob-fixes.md "Z, first mechanism", "Z, second mechanism", "Z, fix round 1". The adopting sites
are unchanged; growth zeroes what it exposes.

**Location** [checked: `git show origin/main:<path> | sed -n` / `grep -n` on each]:
- strings/normalize.c, `MVM_unicode_normalize_codepoints`: malloc of `result_alloc` elements (56-57), adopted at
  86-90 (`ssize = result_pos * sizeof(MVMuint32)` at 90 upstream: that is N1, fixed by #2083 to `result_alloc`).
- strings/normalize.c, `MVM_unicode_string_to_codepoints`: malloc 161-162, adopted at 199-203
  (`ssize = result_alloc`).
- io/procops.c:684-687, io/asyncsocket.c:48-51, io/asyncsocketudp.c:111-114: a libuv read buffer adopted with
  `ssize = buf->len`, `elems = nread`.

```c
    /* asyncsocket.c:47-51 */
    res_buf      = (MVMArray *)MVM_repr_alloc_init(tc, ri->buf_type);
    res_buf->body.slots.i8 = (MVMint8 *)buf->base;
    res_buf->body.start    = 0;
    res_buf->body.ssize    = buf->len;
    res_buf->body.elems    = nread;
```

**What goes wrong.** VMArray keeps slots past `elems` zero: `set_size_internal` grows within `ssize` without
zeroing (VMArray.c:430-434, `if (n <= ssize) { body->elems = n; return; }`), because pop, shift and shrinking
zero what they give up [checked: 427-429, and record cfix-N.md section 5]. The adoption sites hand over buffers
whose tail was never written (`maybe_grow_result` reallocs without zeroing, normalize.c:31-37 [checked]; libuv's
buffer comes from `MVM_malloc`, asyncsocket.c:21 [checked]). So `nqp::setelems` (or a growth by
`bind_pos` past elems) inside `ssize` shows uninitialized heap bytes as elements. No out-of-bounds access: the
bytes are inside the allocation (once N1 is fixed; upstream's normalizecodes overstates ssize, which is N1's
heap overflow).

**How found.** Task 5 implementer (cfix-ledger.md Task 5 line "New bug seen, not fixed"); cfix-N.md section 5;
cfix-E.md section 1 ("Why the memset is needed") and section 5. Confirmed real by the Task 5 review.

**Reproducer** (record: cfix-E-raw/hand-unwritten-slot.nqp; outputs quoted in cfix-N.md section 5 and cfix-E.md):

```
my $t := nqp::newtype(nqp::null(), 'VMArray');
my $e := nqp::newtype(nqp::null(), 'P6int');
nqp::composetype($e, nqp::hash('integer', nqp::hash('bits', 32, 'unsigned', 1)));
nqp::composetype($t, nqp::hash('array', nqp::hash('type', $e)));
my $in := nqp::create($t); nqp::push_i($in, 101); nqp::push_i($in, 769); nqp::push_i($in, 97);
my $a := nqp::create($t);
nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $a);
nqp::setelems($a, 3);
say("normalized 233 97, setelems 3: element 2 = " ~ nqp::atpos_i($a, 2));
```

- cfix-base: `element 2 = 1450128640` [record]; in this pass `element 2 = 3597082224` [ran]: the value varies.
- cfix-asan, cfix-N-asan, cfix-E-asan: `3200171710` (0xbebebebe, ASAN's fill of new blocks) [record].
- The expected value is 0.

**Reach from Raku.** The record says every Rakudo caller of normalizecodes passes a fresh output and Raku cannot
grow NFC/NFD objects (cfix-N.md sections 1 and 5) [record]. For socket and process reads the result is a Buf the
user holds; `Buf.reallocate` is `nqp::setelems(self, $elements)` (src/core.c/Buf.rakumod:1343 in the port's
rakudo checkout, not in upstream c6d6fc3c6b) [checked], so a received Buf grown by `reallocate` within its libuv
capacity would show uninitialized bytes. Not run.

**Zig port.** Yes. The adoption sites are the same C in the port (normalize.c 52-56, 90, 207 [checked: grep];
the io files are unchanged against origin/main except procops.c's O fix). The Zig growth within ssize does not
zero: storage.zig:130-131 `if (n <= ssize) { body.elems = n; return; }` [checked].

**Fix sketch.** Two places, one choice:
- zero the tail `[elems, ssize)` at each adoption site (five sites; the libuv buffer can be large, suggested
  size 64 KiB, so this costs a memset per read), or
- zero `[elems, n)` in `set_size_internal` when it grows within ssize (one place; costs a memset on every growth
  within ssize, e.g. every push into spare room, unless restricted to the path that skips the realloc).
A third option is to have the adopting sites shrink `ssize` to `elems` (or realloc to it). Choose by cost. E's fix
(#2084) already zeroes the bytes it adds itself.

## OB5. MVMHash deserialize holds `key` across read_ref

Status 2026-11-24: fixed in the port (C fd8f245f5, shared C), by reading only, see ob-fixes.md "Shared C"
("OB5 and OB10 by reading"). `root` and the body pointers stay unrooted: OB24.

**Location** [checked: `git show origin/main:src/6model/reprs/MVMHash.c | sed -n 175,203p`]:
src/6model/reprs/MVMHash.c, `deserialize`, lines 194-200.

```c
            MVMString *key = MVM_serialization_read_str(tc, reader);
            if (!MVM_str_hash_key_is_valid(tc, key)) {
                MVM_str_hash_key_throw_invalid(tc, key);
            }
            MVMObject *value = MVM_serialization_read_ref(tc, reader);
            MVMHashEntry *entry = MVM_str_hash_insert_nocheck(tc, hashtable, key);
            MVM_ASSIGN_REF(tc, &(root->header), entry->value, value);
```

**What goes wrong.** This is the shape #2086 fixed in serialization.c's `read_hash_str_var`
(serialization.c:1827-1849 at origin/main [checked]): `key` is a C local across `MVM_serialization_read_ref`,
then inserted. The argument for why that matters is cfix-D.md section 1 steps 3-6 [record]: read_ref can block
on another SC's reentrant mutex; a collection can then run with this thread's work stolen, which marks the
thread's roots but not its C locals; `key` can be a nursery string (from a runtime string heap list) and move, so
the C local goes stale. I did not re-check those steps. `root` is also a C local here, but it is the object being
deserialized, reachable from its SC, and allocated during deserialization; I did not check whether it is always
in gen2 (cfix-D.md step 2 argues gen2 allocation for objects created under read_ref).

**How found.** Task 5 review of area D (cfix-ledger.md Task 5 review line: "D: MVMHash.c:194-200 holds its key
across read_ref (seen, not fixed)"). Not in cfix-D.md itself.

**Reproducer.** None. It would need two threads deserializing SCs that reference each other, with a
nursery-resident key string and a collection timed while one thread is blocked in `demand_object`. cfix-D.md
section 3 says D1 itself was not reproduced either.

**Zig port.** The REPR code is the same C: port MVMHash.c 196 (`key`) and 200 (`read_ref`) [checked: grep];
the port only changed the hash build call to `MVM_str_hash_build_strategy`. Whether the port's Zig collector has
the same stolen-work path: src/zig/gc/orchestrate.zig defines a `stolen` status and `addWork(tc, stolen_tc)`
(lines 53, 161) [checked: grep], so probably yes; not traced.

**Fix sketch.** `MVMROOT(tc, key) { value = MVM_serialization_read_ref(tc, reader); }`, as #2086 does in
`read_hash_str_var`. Check `root` at the same time. No behaviour choice.

## OB6. at_pos default arm uses the register-kind name table

Status 2026-11-24: gone with area K (C ce6393516, Zig 75e171c31): no array of a kind without storage can
exist, so the arm is unreachable; see ob-fixes.md "K and M".

**Location** [checked: `sed -n 340,358p` of origin/main VMArray.c; `git show origin/main:src/core/interp.h |
sed -n 66,77p` and `139-168`]: VMArray.c, `MVM_VMArray_at_pos`, lines 355-356.

```c
        default:
            MVM_exception_throw_adhoc(tc, "MVMArray: Unhandled slot type, got '%s'", MVM_reg_get_debug_name(tc, repr_data->slot_type));
```

**What goes wrong.** `MVM_reg_get_debug_name` (interp.h:139-168) maps register kinds (`MVM_reg_int8` = 1 ...
`MVM_reg_uint64` = 20). The default arm is reached only for the six storage-less slot types 12-17
(`MVM_ARRAY_U4` .. `MVM_ARRAY_I1`, VMArray.h:57-62). 12-16 are no register kind ("unknown"); 17 is `MVM_reg_uint8`
("uint8"). Only the message is wrong.

**How found.** va-kind-differences.md row 12e ("report to the user"); va-differential.md section 4 (the
differential printed `'unknown'`, `'uint8'`); cfix-P.md section 6; cfix-B.md section 3 note.

**Reproducer** [ran on cfix-base, program written for this pass]:

```
sub int_type(int $bits, int $u) { my $t := nqp::newtype(nqp::null(), "P6int");
    nqp::composetype($t, nqp::hash("integer", nqp::hash("bits", $bits, "unsigned", $u))); $t }
for (4, 2, 1) -> $bits { for (1, 0) -> $u {
    my $t := nqp::newtype(nqp::null(), "VMArray"); my $a := nqp::create($t); nqp::push($a, nqp::hash());
    nqp::composetype($t, nqp::hash("array", nqp::hash("type", int_type($bits, $u))));
    my $r := "returned"; try { nqp::atpos_i($a, 0); CATCH { $r := "DIED " ~ nqp::getmessage($!) } };
    say("bits $bits unsigned $u: atpos_i: $r") } }
```

Output: `got 'unknown'` for bits 4/2/1 unsigned and bits 4/2 signed; `got 'uint8'` for bits 1 signed (I1 = 17).
(Run as one line with `nqp-m -e`.) The array is made by the first-compose route of OB11.

**Zig port.** Yes, on purpose: elements.zig:336-344 `unhandledAtPos` calls `c.MVM_reg_get_debug_name(tc,
slot_type)` [checked].

**Fix sketch.** Name the slot type (a small table "u4", "u2", "u1", "i4", "i2", "i1", as debugserver.c's
`write_vmarray_slot_type` already has at 2526-2531), or use the plain "MVMArray: Unhandled slot type" of the
other arms. Choice of wording only.

## OB7. A rejected push or bind_pos has already grown the array

Status 2026-11-24: fixed in the port (C 981c4a8f2, restructured by b87b79815; Zig 7ff607fd1), see ob-fixes.md
"Y and Q" and "Push follow-up".

**Location** [checked: `sed -n 478,500p` and `576-600p` of origin/main VMArray.c]:
VMArray.c, `MVM_VMArray_push` line 580 (growth) before the kind checks from 581; `MVM_VMArray_bind_pos` lines
490-491 (growth) before the kind checks from 497.

```c
    set_size_internal(tc, body, body->elems + 1, repr_data);   /* push, 580 */
    switch (repr_data->slot_type) {
        case MVM_ARRAY_OBJ:
            if (kind != MVM_reg_obj)
                MVM_exception_throw_adhoc(tc, "MVMArray: push expected object register");
```

**What goes wrong.** The register kind is checked after the growth. A rejected push leaves one more element (a
zero, NULL or VMNull-on-read slot). A rejected bind_pos at an index past the end leaves the array grown to
`index + 1`, which can be many slots, not one. No memory hazard: the new slots were zeroed by the growth.
The vmarray-stale-slots PR (#2078) fixed the same order in pop and unshift and disclosed this sibling in its
body (cfix-ledger.md Task 7) [record].

**How found.** va-differential.md section 4 ("A rejected push or bindpos has already grown the array");
cfix-baseline.md section 5; cfix-T.md section 6; cfix-ledger.md Task 7 final review.

**Reproducer** [ran on cfix-base, program written for this pass, one line with `nqp-m -e`]:

```
my $a := nqp::list(1, 2); my $r := "returned";
try { nqp::push_i($a, 7); CATCH { $r := "DIED " ~ nqp::getmessage($!) } };
say("push_i: $r; elems " ~ nqp::elems($a));
my $b := nqp::list(1, 2); $r := "returned";
try { nqp::bindpos_i($b, 5, 7); CATCH { $r := "DIED " ~ nqp::getmessage($!) } };
say("bindpos_i 5: $r; elems " ~ nqp::elems($b) ~ "; element 5 isnull " ~ nqp::isnull(nqp::atpos($b, 5)));
```

Output: `push_i: DIED MVMArray: push expected object register; elems 3` and
`bindpos_i 5: DIED MVMArray: bindpos expected object register; elems 6; element 5 isnull 1`.
Expected: elems 2 in both.

**Zig port.** Yes, on purpose: elements.zig:522-531 `push` calls `S.setSize(... body.elems +% 1 ...)` (526) before
the dispatch; `bindPos` (502-510) calls `bindIndex`, which grows at 167, before the dispatch [checked].

**Fix sketch.** Check the register kind against the slot type before growing (as #2078 does for pop and
unshift). Choice: whether a rejected bind_pos with an index past the end should still grow (no: the operation
failed). The JIT entry points (`vmarray_bind_pos_int64`, VMArray.c:1559-1582) grow too; they are only chosen for
a matching kind, so not affected (by reading, not checked in depth).

## OB8. write_buf grows to `offset + count` elements, count being bytes

Status 2026-11-24: fixed in the port (C 48fd69052, on #2080; Zig 1c80e9440), see ob-fixes.md "W, V and H".

**Location** [checked: `sed -n 988,1012p` of origin/main VMArray.c]: VMArray.c, `write_buf`, lines 1006-1007.

```c
    /* No need to account for start, set_size_internal will take care of that */
    if (elems * elem_size < offset * elem_size + count) {
        set_size_internal(tc, body, offset + count, repr_data);
```

**What goes wrong.** `offset` is in elements, `count` in bytes. For elements wider than one byte the array grows
to `offset + count` elements where `offset + ceil(count / elem_size)` would hold the write. This is not only an
over-allocation (the description in the plan's Outcome): `elems` is set to that count, so the caller sees extra
zero elements. It happens only when the write needs growth.

**How found.** Task 1 (cfix-baseline.md section 5); va-differential.md section 4 (`u16.buf.writeint.f12` grows
a 3-element array to 9); cfix-B.md section 6.

**Reproducer** [ran on cfix-base, programs written for this pass]:

nqp (one line with `nqp-m -e`):

```
my $e := nqp::newtype(nqp::null(), "P6int");
nqp::composetype($e, nqp::hash("integer", nqp::hash("bits", 16, "unsigned", 1)));
my $t := nqp::newtype(nqp::null(), "VMArray"); nqp::composetype($t, nqp::hash("array", nqp::hash("type", $e)));
my $a := nqp::create($t); nqp::push_i($a, 1); nqp::push_i($a, 2); nqp::push_i($a, 3);
nqp::writeint($a, 1, 0x0102030405060708, 13);          # flags 13: 8 bytes, little endian
# print elems and the elements
my $b := nqp::list_i(); nqp::writeint($b, 0, 7, 13);  # empty int64 array
```

Output: `elems 9: 1 1800 1286 772 258 0 0 0 0` (5 would hold the write) and `elems 8` for the int64 array
(1 would). Raku: `my $b = buf16.new(1,2,3); $b.write-uint64(1, 1); say $b.elems` prints `9` [ran, rakudo-m
of cfix-base].

**Zig port.** Yes, on purpose: elements.zig:844-845 grow with `S.setSize(tc, body, u(offset) +% count, ...)`
[checked]. The growth condition was rewritten by #2080 (B2), but the target size is the same.

**Fix sketch.** Grow to `offset + (count + elem_size - 1) / elem_size` (with the #2077/#2080 overflow rules
kept). Behaviour choice: this changes `elems` after a write into a wide Buf, which Raku code could observe;
whether any code relies on the old count was not searched. Note that with a rounded-up count the spare bytes of
the last element must be zero (they are, since growth zeroes, except for OB4's adopted buffers).

## OB9. normalizecodes of empty input leaves the output untouched

Status 2026-11-24: fixed in the port (C a8bfc11fd, on #2083, shared C), see ob-fixes.md "Shared C".

**Location** [checked: `git show origin/main:src/strings/normalize.c | sed -n 38,57p`]:
strings/normalize.c, `MVM_unicode_normalize_codepoints`, lines 52-53.

```c
    input_codes = ((MVMArray *)in)->body.elems;
    if (input_codes == 0)
        return;
```

**What goes wrong.** The output keeps whatever it held. `MVM_unicode_string_to_codepoints` (strtocodes) of an
empty string replaces its output with an empty result (normalize.c:199-203) [checked]. Every Rakudo caller passes
a fresh output, so it shows only from nqp [record: cfix-N.md section 5].

**How found.** Task 5 implementer, cfix-N.md section 5; cfix-N.md section 2 records
`normalizecodes of empty input into 10 20 30: elems 3: 10 20 30` from N-adopt-state.nqp.

**Reproducer** [ran on cfix-base, program written for this pass, one line with `nqp-m -e`]:

```
my $t := nqp::newtype(nqp::null(), "VMArray"); my $e := nqp::newtype(nqp::null(), "P6int");
nqp::composetype($e, nqp::hash("integer", nqp::hash("bits", 32, "unsigned", 1)));
nqp::composetype($t, nqp::hash("array", nqp::hash("type", $e)));
my $in := nqp::create($t); my $out := nqp::create($t);
nqp::push_i($out, 10); nqp::push_i($out, 20); nqp::push_i($out, 30);
nqp::normalizecodes($in, nqp::const::NORMALIZE_NFC, $out);
say("elems " ~ nqp::elems($out) ~ ": " ~ nqp::atpos_i($out, 0) ~ " " ~ nqp::atpos_i($out, 1) ~ " " ~ nqp::atpos_i($out, 2));
my $o2 := nqp::create($t); nqp::push_i($o2, 10); nqp::strtocodes("", nqp::const::NORMALIZE_NFC, $o2);
say("strtocodes of empty: elems " ~ nqp::elems($o2));
```

Output: `elems 3: 10 20 30` and `strtocodes of empty: elems 0`.

**Zig port.** Yes: the port's normalize.c has the same early return at 52-53 [checked].

**Fix sketch.** Set the output's elems to 0 (keep or free its slots; with the #2083 rule, freeing first and
adopting an empty result is consistent with the non-empty path). Choice: whether normalizecodes replaces or
appends; the non-empty path replaces, so empty input should give an empty output.

## OB10. nqp::encode leaks the encoded buffer when the resize throws

Status 2026-11-24: fixed in the port (C 2c7d1dfb9, on #2084, shared C), by reading only, see ob-fixes.md
"Shared C". The commit message does not name #2084; the PR text must (ob-fixes.md "Commits by bug id").

**Location** [checked: `git show origin/main:src/strings/ops.c | sed -n 1871,1921p`]:
strings/ops.c, `MVM_string_encode_to_buf_config`, lines 1907-1912 (append branch).

```c
    if (((MVMArray *)buf)->body.slots.any) {
        MVMuint32 prev_elems = ((MVMArray *)buf)->body.elems;
        MVM_repr_pos_set_elems(tc, buf, ((MVMArray *)buf)->body.elems + output_size / elem_size);
        memmove(((MVMArray *)buf)->body.slots.i8 + prev_elems, (MVMint8 *)encoded, output_size);
        MVM_free(encoded);
    }
```

**What goes wrong.** `encoded` is a malloc'd buffer held in a C local. If `MVM_repr_pos_set_elems` throws, the
free is skipped and the buffer leaks. The throws set_size_internal can raise for an integer kind are the size
limit "Unable to allocate an array of N elements" (VMArray.c:451-460) and, after #2077, the wrap check; an
allocation failure panics instead. So this needs an array whose new size exceeds the limit (2**60 elements of 8
bytes, more for narrower kinds), which an existing array cannot practically have. Reachability is therefore
doubtful; I found no other throw on that path (not exhaustively checked; `enter_single_user` throws only with
`MVM_ARRAY_CONC_DEBUG`).

**How found.** Task 5 implementer, cfix-E.md section 5 ("This was so before as well; not changed").

**Reproducer.** None. It would need a target near the element limit, or a REPR whose set_elems throws for another
reason (VMArray only reaches here).

**Zig port.** The same C: port ops.c:1912 (`MVM_repr_pos_set_elems`) before 1919 (`MVM_free(encoded)`), after the
E fix [checked]. The resize itself is Zig (storage.zig:grow), which throws the same messages.

**Fix sketch.** Free `encoded` on the exception path: compute and check the new size before the resize, or wrap
with the exception-handler mechanism MoarVM uses elsewhere for temporary C buffers (e.g. a frame-cleanup /
`MVM_tc_set_ex_release_mem` style hook; whether that exists at origin/main was not checked). Low priority.

## OB11. Recompose gap: a first compose of a type that already has instances

Status 2026-11-24: not fixed: a design question for the maintainers (see Fix sketch). What remains: a first
compose of a type that already has instances, to `str` or to a native kind of 8 bits or more, reinterprets
their object slots (undefined; documented in docs/zig-build.md, "Fidelity to the C array"). A first compose to
4, 2 or 1 bits, and with it the storage-less states this entry describes, is gone with area K (ce6393516,
75e171c31).

**Location** [checked: `sed -n 1320,1333p` of origin/main VMArray.c; port VMArray.c `sed -n 1377,1405p`]:
origin/main has no check at all in `compose` (every recompose allowed). With #2081 (port VMArray.c:1395-1399):

```c
            if (repr_data->elem_type && (kind.slot_type != repr_data->slot_type
                    || kind.elem_size != repr_data->elem_size))
                MVM_exception_throw_adhoc(tc,
                    "MVMArray: Type %s is already composed with another element kind",
                    MVM_6model_get_stable_debug_name(tc, st));
```

**What goes wrong.** #2081 refuses a kind change only once `elem_type` is set. A type made with `nqp::newtype`,
instantiated with `nqp::create`, filled, and only then composed for the first time is allowed any kind, and its
live arrays are reinterpreted: object slots read as strings (type confusion), as a storage-less kind (then
`writeint` and splices hit the B3/P2 states, which #2080/#2079 make throw), or as a narrower native kind (object
pointers read back as integer bits; the buffer is larger than needed, so no overrun). A type without an element
type is OBJ with 8-byte slots (type_object_for, VMArray.c:33-35 [checked]), and no kind is wider than 8 bytes, so
X1's overflow shape (a narrow buffer read as a wide kind) needs a second compose, which #2081 refuses. The REPR
cannot know whether instances exist (cfix-R.md section 1 ruling) [record].

**How found.** Task 4 review (cfix-ledger.md Task 4 review: "a type with live instances composed for the FIRST
time ... gives the same state"; "a str first-compose over live object slots is a type confusion without a
crash"); cfix-R.md section 1 "What this closes, and what it does not"; named in #2081's PR text.

**Reproducers** [record: cfix-repro/R-first-compose-gap.nqp and cfix-repro/B3-write-first-compose.nqp;
outputs cfix-R.md section 2 table]:

```
my $t := nqp::newtype(nqp::null(), 'VMArray');
my $a := nqp::create($t);
nqp::push($a, nqp::hash('a', 1));
nqp::composetype($t, nqp::hash('array', nqp::hash('type', str)));
say("composed to str with a live object array");
my $s := nqp::atpos_s($a, 0);
say("chars: " ~ nqp::chars($s));
```

Output on cfix-base, cfix-asan, cfix-R and cfix-R-asan: `composed to str with a live object array`, `chars: 0`
(an MVMHash read as an MVMString; no crash in that run). B3-write-first-compose.nqp (first compose to uint4 of a
type with a 3-element object array, then 8-byte writeints) ends in SEGV on address 0 under ASAN on cfix-R; with
#2080 the writes throw [record: cfix-R.md section 1; cfix-mirror.md section 5 says it is "fixed" on the port].
The OB6 reproducer above also uses this route [ran].

**Zig port.** Yes: serial.zig:271-291 `compose` has the same `elem_type != null` condition (286) and its doc
comment names the gap (268-270) [checked].

**Fix sketch** (open design question for the maintainers, per the cfix-ledger Task 4 ruling):
- refuse a first compose with a non-object kind when the type has been instantiated: needs an "instantiated"
  flag on the STable or REPR data, set by `allocate`; but allocation of arrays does not always go through the
  REPR (cfix-ledger.md Task 4 re-review: `MVM_gc_allocate_object`, spesh `sp_fastcreate`, deopt bypass it), so
  every such path would need the flag;
- or refuse any compose with a kind other than OBJ unless it is the first thing done to the type (same flag);
- or accept the gap and document that composing after instantiation is undefined.
Also the str case: a STR array whose slots hold non-string objects; any rule that stops OBJ -> STR with live
elements closes it.

**Uncertain.** The statement that a first compose from OBJ cannot overflow (all kinds at most 8 bytes) is my
reading of spec_to_repr_data (VMArray.c:1224-1319, element sizes 8, 4, 2, 1, 0); not run for every kind. The
native case (a first compose to an integer kind over live object slots) was not run either.

## OB12. #2081's message has a double space for a type without a debug name

Status 2026-11-24: fixed in the port (C 02289298c, on #2081; Zig a1fa9aed7), see ob-fixes.md "K and M".

**Location** [checked]: port VMArray.c:1397-1399 (the #2081 hunk; not present at origin/main).
`MVM_6model_get_stable_debug_name` returns `""` when there is no debug name (origin/main src/6model/6model.h:
692-694 [checked]), so the format "Type %s is" gives "Type  is".

**How found.** Seen in cfix-R.md section 2 table notes ("these test types have none, hence `Type  is`"); listed
at Task 7 final review (cfix-ledger.md Task 7). Left as is in the PR.

**Reproducer** [ran on cfix-R, program written for this pass, one line with `nqp-m -e`]:

```
my $t := nqp::newtype(nqp::null(), "VMArray");
nqp::composetype($t, nqp::hash("array", nqp::hash("type", int)));
my $r := "returned";
try { nqp::composetype($t, nqp::hash("array", nqp::hash("type", str))); CATCH { $r := "DIED [" ~ nqp::getmessage($!) ~ "]" } };
say($r);
```

Output: `DIED [MVMArray: Type  is already composed with another element kind]`.

**Zig port.** Yes: serial.zig:287, same format and the same C helper [checked].

**Fix sketch.** Use `MVM_6model_get_debug_name`-style fallback text (e.g. "<anon>"), or drop the name when
empty ("MVMArray: Type is already composed ..."), or quote it. Wording choice only. If changed, change it in
the #2081 branch so C and Zig keep the same text (the port's differential compares messages).

## OB13. Intermittent segfault in full cleanup (`blocked.nqp --stress`)

Status 2026-11-24: not in this campaign.

**Location.** Unknown. Crash during `--full-cleanup` global destruction, in a background thread.

**What was observed** [record: va-cleanup.md; va-ledger.md Task 8; campaign 8 plan Outcome item 7]:
`tools/bench/gc/cleanup/blocked.nqp` starts an app-lifetime thread that loops on `nqp::sleep(0.001)` and
allocates between sleeps; the main thread sleeps 0.2 s and prints `main returning`. Run as
`<P>/bin/moar --full-cleanup ... nqp.moarvm blocked.nqp` with `cleanup.sh --stress` on the stress prefixes
(`-Dgc-debug=1 -Dnursery-size=524288`). About 2 % of runs die of SIGSEGV after `main returning`: pooled,
va-c-stress 2/120 and va-n-stress 3/120. The cores show the crashing (non-main) thread at an unmapped address,
called from libmoar at `MVM_interp_run+0x16aa0` from `MVM_interp_run+0x102` (nearest exported symbols, stripped
builds), at the same offsets on both builds. The record's reading: the background thread still runs interpreted
code while global destruction frees what it runs. Base (non-stress) prefixes: 120/120 clean.

Important for "C and Zig builds": va-c-stress is the port with C REPRs (`-Dzig-reprs=false`) but still the
port's Zig collector; neither side is unmodified upstream. It was never run on upstream MoarVM or with the C
collector (`-Dzig-gc=false` was not built, cfix-mirror.md section 6 / plan Outcome). So it is not shown to be an
upstream bug.

Small record discrepancy found in this pass: va-cleanup.md says the stress variant "allocates 4,000 hashes
between sleeps"; cleanup.sh's `--stress` rewrites `$j < 10` to `$j < 200` (tools/bench/gc/cleanup.sh:52-54)
[checked], and blocked.nqp's inner loop is `$j < 10` (blocked.nqp:8) [checked], so it is 200 hashes.

**How found.** Campaign 8 Task 8 gate (cleanup.sh --stress); ruled outside the array and not diagnosed.

**Reproducer.** `tools/bench/gc/cleanup.sh --prefix=/tmp/claude-1000/va-n-stress --runs=20 --stress` (needs
many runs; about 2 % failure rate). Not run in this pass.

**Zig port.** Seen on the port (both REPR settings). Unknown whether upstream has it.

**Next steps** (from the plan Outcome item 7): more runs per side; the same runs on a campaign-7 build and on
upstream with `--full-cleanup`; a diagnosis on unstripped `-syms` builds (va-c-syms and va-n-syms exist under
/tmp/claude-1000, not checked what they contain). A fix would have to define what full cleanup does with
app-lifetime threads that are still running (wait, stop at a safepoint, or skip freeing what they use).

## OB14. ReleaseSafe: VM-booting unit tests abort with "cast causes pointer to be null"

Status 2026-11-24: not in this campaign.

**What was observed** [record: va-ledger.md Task 5 "OBSERVATION for the user"; ngc-ledger.md Task 4 note; campaign
8 plan Outcome item 4; va-final-review.md minor 7 and "Declined to judge"]: `zig build unit-test
-Doptimize=ReleaseSafe` aborts every test that boots a VM with "panic: cast causes pointer to be null"
(shim-test 7 crashes, hash-str-test 31, repr-test 1 at that time). The reading in the record: some Zig code on the
VM boot path casts a null C pointer to a non-optional pointer; ReleaseFast hides it. Pre-existing since at least
campaign 6 (ngc-ledger.md). The tests that do not boot a VM pass under ReleaseSafe.

The description given for this file ("ReleaseSafe build aborts at boot") is wider than the record: the record
is about the unit tests under `zig build unit-test -Doptimize=ReleaseSafe`; no record says a full ReleaseSafe
`moar` was built and run.

**Location.** Unknown. The record does not name the cast. Not searched in this pass.

**Reproducer.** `zig build unit-test -Doptimize=ReleaseSafe` (raw output was W/task-5-safe.out in campaign 8's
work directory; not located in this pass). Not run (no builds allowed).

**Zig port.** Port only (Zig code). Whether it still happens at the tip 0d4149a90 is not known.

**Why it matters** (va-final-review.md minor 7): the Zig array has never run with runtime safety on a booted VM;
fixing the cast and running the differential against a ReleaseSafe build is the cheapest strong check left.

**Fix sketch.** Find the cast (a ReleaseSafe test run gives a stack trace), make the pointer optional and handle
NULL as the C does. No behaviour choice expected.

## OB15. Port-only notes

### OB15a. t/04-nativecall/02-simple-args.t tests 17-18

Status 2026-11-24: not in this campaign (still the only Rakudo `make test` failure on ob-c and ob-n).

[record: cfix-baseline.md section 6; cfix-mirror.md section 5; va-suites.md section 2] Fails (Wstat 512, subtests
17-18) on every port prefix since campaign 4, C and Zig REPRs alike; passes on cfix-base. The two runs differ in
more than MoarVM: cfix-base used upstream nqp 305ff2f77 and upstream rakudo c6d6fc3c6b; the port runs used the
checkout's nqp (41e7210ba) and rakudo (042608fb82, branch zig-build-spec per cfix-baseline.md). So the cause may be
in the port's MoarVM, its nqp, or its rakudo. Not investigated. Next step: run the test with upstream rakudo
against the port's libmoar, or the port's rakudo against upstream MoarVM (bytecode compatibility permitting).

### OB15b. The Perl build path was never exercised

Status 2026-11-24: not in this campaign.

[record: va-ledger.md Task 1 ruling; va-final-review.md minor 8] The three-line Configure.pl change for the Zig
REPR section was accepted without a Perl (Configure.pl + make) build. The record calls the risk low (it mirrors
the `zig-gc` change). Next step: one Configure.pl build of the port and its `make test`.

### OB15c. No AddressSanitizer build of the port

Status 2026-11-24: not in this campaign.

[record: cfix-mirror.md section 6; plan Outcome "Not run: ASAN"] The reproducers' ASAN halves were not run on the
port. Several cfix bugs show only under ASAN on glibc (S1, the B and P overruns). The Zig side has
`moar.nullDeref` checks and forked-child tests instead (va-kind-differences.md section 3). An ASAN-instrumented C
side of the port (zig cc supports `-fsanitize=address`; not checked how the build would enable it) would close
this.

### OB15d. Storage-less kinds: NULL slots in Zig, `malloc(0)` in C

Status 2026-11-24: gone with area K (ce6393516, 75e171c31): no array of a kind without storage can exist, so
the difference cannot be observed; see ob-fixes.md "K and M".

[checked: storage.zig:188-199, `if (len > 0) { ... }` around the allocator calls; storage.zig:56-58 `alloc`
returns null for 0 bytes; serial.zig:222-228 doc] Where the C passes 0 bytes to malloc or realloc (growth of a
kind without storage before zero_slots throws; copy_to and deserialize with elems > 0), the Zig array does not
call the allocator and keeps `slots` NULL (or its old value). Documented as the one deliberate difference
(va-kind-differences.md section 3, "The one deliberate difference"; cfix-ledger.md Task 6 ruling and Task 7
wider reason). Observable only through `MVM_nativecall_unmarshal_vmarray`, which passes `slots + start * 0`
to native code (NULL in Zig, a non-NULL zero-byte block in C) [record]. After #2079/#2080 every operation that
could read those slots throws first [record: cfix-ledger.md Task 6 ruling]. Fix choice: allocate as C does
(simple, but asks the allocator for 0 bytes, against the port's allocator rule), or leave documented.

## OB16. write_buf and read_buf accept the num kinds; the message says "integer type" (added)

Status 2026-11-24: fixed in the port, message only (C 48fd69052, Zig 1c80e9440), see ob-fixes.md "W, V and H".

**Where found.** va-kind-differences.md rows 24 and 25 ("report to the user (nums accepted, message says
integer)"); va-differential.md section 4. Not in the plan's Outcome list.

**Location** [checked: `sed -n 988,1024p` of origin/main VMArray.c]: `write_buf` 995-997, `read_buf` 1022-1024.

```c
    if (repr_data->slot_type < MVM_ARRAY_I64) {
        MVM_exception_throw_adhoc(tc, "MVMArray: write_buf requires an integer type");
    }
```

**What goes wrong.** The gate refuses only OBJ (0) and STR (1). N64 (6), N32 (7) and the six storage-less kinds
pass (VMArray.h:45-62) [checked]. `writeint`/`readint` on a num array therefore copy raw bytes. That is
memory-safe and may even be useful, but the message claims an integer type is required. (The storage-less kinds
are refused since #2080.)

**Reproducer** [ran on cfix-base, one line with `nqp-m -e`]:

```
my $n := nqp::list_n(1.5); nqp::writeint($n, 0, 4607182418800017408, 13);
say("num array after writeint: " ~ nqp::atpos_n($n, 0) ~ ", readint " ~ nqp::readint($n, 0, 13));
my $o := nqp::list(1); my $r := "returned";
try { nqp::writeint($o, 0, 1, 13); CATCH { $r := "DIED " ~ nqp::getmessage($!) } }; say("obj array: $r");
```

Output: `num array after writeint: 1, readint 4607182418800017408` and
`obj array: DIED MVMArray: write_buf requires an integer type`.

**Zig port.** Yes: elements.zig:840-841 (writeBuf, plus `elem_size == 0` from #2080) and 871 (readBuf) [checked].

**Fix sketch.** Decide the intent: either nums are allowed (change the message to "requires a native numeric
array" or similar) or they are not (gate on the integer kinds only, which would break any code that writes bytes
into a num buffer; not searched). Raku's `Blob.write-num*` work on Buf (uint8) and are not affected either way
(not checked in Rakudo).

## OB17. Storage-less kinds are misreported (added)

Status 2026-11-24: gone with area K (ce6393516, 75e171c31), see ob-fixes.md "K and M".

**Where found.** va-kind-differences.md row 28 ("the six reported as reference arrays"; va-differential.md
section 4) and section 3's debugger row. Not in the plan's Outcome list.

**Location** [checked]:
- VMArray.c `get_elem_storage_spec`, default arm 1185-1189: OBJ and the six get `MVM_STORAGE_SPEC_REFERENCE`,
  `BP_NONE`, `can_box = 0`.
- src/debug/debugserver.c `write_vmarray_slot_kind` 2535-2559: U4..I1 reported as "int" with `MVM_reg_int64`
  (2550-2556); `write_vmarray_slot_type` names them "u4".."i1" (2526-2531).

**What goes wrong.** Code that asks an array type for its element storage spec is told that a uint4 array holds
references. The debugger then reads such an array's elements with `at_pos` as int64, which throws (OB6's
message) [record: va-kind-differences.md section 3]. `bits` and `align` are 0 for every kind [checked: 1152-1153],
so the spec never states the element width.

**Reproducer.** None recorded as a program; the differential printed the spec [record]. A reproducer would compose
a uint4 array type and print `nqp::...` the element storage spec (I did not find an nqp op that exposes
`get_elem_storage_spec` directly; not searched).

**Zig port.** Yes: elements.zig:436 `referenceSpec` for OBJ and the six [checked]; the debugger is shared C.

**Fix sketch.** Decide what a storage-less kind is (the six are declared but cannot hold elements at all; every
storing op throws). Options: report them as `INLINED` + `BP_INT` with `bits` 4/2/1 (and make them work), or refuse
composing an array with them (simplest; then OB6, OB17, OB18's second half and OB20 disappear). The second option
changes behaviour for any code that composes such arrays without using them; not searched.

## OB18. deserialize: unchecked allocation size, and storage-less kinds cannot be deserialized (added)

Status 2026-11-24: first half fixed in the port (C ec2ad02f7, Zig 63a911508), see ob-fixes.md "W, V and H";
second half gone with area K (ce6393516, 75e171c31: such a type is refused at deserialize_repr_data). The
limit is set_size_internal's (`>`), so a count of 2**63 one-byte elements still reaches the allocator and
aborts (`could not allocate 9223372036854775808 bytes`): ob-fixes.md "Decisions for the owner", item 1.

**Where found.** va-kind-differences.md row 34b ("no limit check"; "the six cannot be deserialized"), and
va-differential.md section 4 last bullet. The wrap below is my reading.

**Location** [checked: `sed -n 1364,1426p` of origin/main VMArray.c]:

```c
    body->elems = MVM_serialization_read_int(tc, reader);
    body->ssize = body->elems;
    if (body->ssize)
        body->slots.any = MVM_malloc(body->ssize * repr_data->elem_size);
```

**What goes wrong.**
- No limit check, and `ssize * elem_size` is a 64-bit product that wraps for `elems >= 2**61` (8-byte kinds).
  A wrapped small malloc is followed by a loop that stores `elems` elements (1375-1422), each read with a
  bounds-checked reader (`MVM_serialization_read_int` calls `assert_can_read`, serialization.c:1584-1594
  [checked]), so the loop stops with an exception at the end of the data, but only after writing past the small
  block: a heap overflow driven by serialized data. Without wrap, a huge count panics in malloc. Reachable with
  crafted data through `nqp::deserialize` (interp.c:2994) [checked that the op exists]; not run. Serialized data
  is normally produced by MoarVM itself, so this matters for untrusted bytecode or blobs only.
- For a storage-less kind, `elems > 0` gives `MVM_malloc(0)` with `ssize = elems`, then the default arm throws
  (1423-1424); `elems == 0` throws too. An array of such a type serializes (empty) and then cannot be
  deserialized (va-differential.md section 4) [record].

**Reproducer.** None. The first needs a hand-made serialization blob with a large element count; the second a
serialized storage-less array (both would use `nqp::serialize`/`nqp::deserialize`).

**Zig port.** Yes: serial.zig:222-228 (`body.ssize = body.elems; ... S.alloc(body.ssize, elem_size)`), and
storage.zig:57 `const len = n_slots *% elem_size;` wraps on purpose ("a deserialized count is not checked
against any limit", storage.zig:52-55) [checked]. The Zig returns null for 0 bytes (OB15d).

**Fix sketch.** Apply set_size_internal's limit (and an overflow check on the product) before allocating; throw
the "Unable to allocate" exception or fail_deserialize. Decide what a storage-less kind should serialize to (see
OB17).

## OB19. Holes in OBJ arrays: NULL from pop/shift, VMNull from at_pos, generation-dependent copies (added)

Status 2026-11-24: fixed in the port for pop and shift (C bb0eda68f, Zig 922bbfb4d), see ob-fixes.md "W, V and
H".

**Where found.** va-kind-differences.md rows 12c, 18b, 22b, and section 4 ("Also new here, though not a crash:
the NULL-versus-VMNull holes of row 22b"). Kept as per-kind behaviour in campaign 8; listed here because the
record flags it for the user.

**Location** [checked: origin/main VMArray.c `sed -n`]: the at_pos OBJ arm turns a NULL slot into VMNull
(259-265: `value->o = found ? found : tc->instance->VMNull;`); `pop` returns the raw slot
`value->o = body->slots.o[slot];` (663); `copy_elements` (933-967) takes the memcpy path for OBJ only when the
target is not in gen2 (942 `d_needs_barrier = dest->header.flags2 & MVM_CF_SECOND_GEN`, 946), otherwise the
element path through at_pos/bind_pos (row 22b).

**What goes wrong.** A hole (made by setelems growth) reads as VMNull through at_pos but comes back as NULL from
pop/shift. Copying an OBJ array with holes keeps NULL holes into a nursery target and writes VMNull into a gen2
target, so the result of a splice or slice depends on the target's GC generation, and `serialize` then writes
`REFVAR_NULL` or `REFVAR_VM_NULL` [record: row 22b].

**Reproducer.** None as a standalone program; campaign 8's differential cases show it [record].

**Zig port.** Yes, on purpose: elements.zig readElem 220-235 maps NULL to VMNull only for at_pos, and its doc
says "pop and shift do not do this, row 18b" [checked]; the copy path follows the C's gen2 test (row 22b ruling)
[record].

**Fix sketch.** Decide one representation: either pop/shift also return VMNull for a NULL slot (cheap, matches
at_pos), and copy_elements' fast path is kept (holes stay NULL in storage, VMNull on every read), or holes are
filled with VMNull at growth (costly). The first makes reads consistent and leaves serialization's two forms;
check what `REFVAR_NULL` deserializes to.

## OB20. Growth of a storage-less kind stores realloc's result, then throws before ssize (added)

Status 2026-11-24: gone with area K (ce6393516, 75e171c31), see ob-fixes.md "K and M".

**Where found.** cfix-baseline.md section 5 ("set_size_internal for a kind without storage reallocs to 0 bytes,
stores the pointer and then dies in zero_slots before updating ssize"); va-kind-differences.md section 3.

**Location** [checked: `sed -n 462,476p` of origin/main VMArray.c]:

```c
    slots = (slots)
            ? MVM_realloc(slots, ssize * repr_data->elem_size)
            : MVM_malloc(ssize * repr_data->elem_size);
    body->slots.any = slots;
    zero_slots(tc, body, elems, ssize, repr_data->slot_type);   /* throws for the six */
    body->ssize = ssize;
```

**What goes wrong.** For elem_size 0 the allocation is 0 bytes. Under glibc and ASAN `realloc(p, 0)` frees `p` and
returns NULL; under mimalloc it returns a minimal block [record: cfix-baseline.md section 5]. The pointer is stored,
then zero_slots throws, so `ssize` and `elems` still describe the old storage. If the array had storage (the
first-compose route of OB11), it now has the old ssize over a freed or minimal buffer. #2080 (write_buf kind
check) and #2079 (splice) refuse the operations that would then use the slots [record: cfix-baseline.md section
5, cfix-ledger.md Task 4 review]; every other op throws on the kind. So no known memory unsafety remains after
those PRs; the state is still inconsistent (e.g. for gc_free, which frees `slots`, and nativecall unmarshal).

**Reproducer** [record: cfix-repro/B3-write-first-compose.nqp, see OB11]: upstream's second write "dies
'Unhandled slot type' after reallocating the slots to 0 bytes, the third writes through the pointer realloc left
(SIGSEGV on address 0 under AddressSanitizer)".

**Zig port.** No: storage.zig:190 skips the allocator for a 0-byte length and keeps `slots` (OB15d) [checked].

**Fix sketch.** Throw for a storage-less kind before allocating (check `elem_size == 0` at the top of the growth
path), or settle OB17 by refusing such kinds at compose.

## OB21. A splice at offset 0 removing every element leaves them in the slots (added 2026-11-24)

Status 2026-11-24: fixed in the port by area Z (C 591f3c20b, 963665442, eb98fd0ba; Zig 8223cc952, 8b1ff900c,
30ce0ba0a), see ob-fixes.md "Z, second mechanism", "OB21 (found in Task 5)" and "Z, fix round 1".

**Where found.** ob-fixes Task 5 (area Z), while listing which growth paths can expose non-zero slots
(ob-fixes.md "Which growth paths can expose non-zero slots"); the second route (through a reallocation) was
found by Task 5's review.

**Location** [checked in Task 7: `sed -n 1236,1252p` of VMArray.c at the branch tip d68a0ec8c;
`git show origin/main:src/6model/reprs/VMArray.c | sed -n 1060,1082p` and `sed -n 405,476p`]: VMArray.c,
`asplice`, the offset-0 adjustment, arm `if (n <= -(MVMint64)elems0)` (origin/main 1070-1075; tip 1240-1245):

```c
        if (n <= -(MVMint64)elems0) {
            elems0 = 0;
            count = 0;
            body->start = 0;
            body->elems = elems0;
        }
```

**What goes wrong.** The arm sets `start = 0, elems = 0` and leaves the removed elements in their slots.
Growth within the storage only set `elems` (origin/main set_size_internal, the `n <= ssize` branch:
`body->elems = n`, no zeroing), so a later setelems or bindpos past the end gave the removed elements back.
After a push and a shift (start 1), a growth past ssize moved the window to start 0 and reallocated, and
zeroed the new room only from the old ssize, so slots from the old window's end to the old ssize came back
too. For an object array those slots are pointers the collector no longer marks (it marks only the window),
so this is memory unsafety, not only a wrong result.

**Reproducers** [record: ob-fixes.md; ran in Task 7 on the four port prefixes and on cfix-base / cfix-asan,
outputs in ob-fixes-raw/gate-t7/]:
- `ob-repro/Z-splice-clear-setelems.nqp`: `splice($a, [], 0, 4)` on `11 22 33 44`, then `setelems 4`; and
  `splice($o, [], 0, 3)` on `a b c`, then `bindpos 2`.
- `ob-repro/Z-shift-realloc.nqp`: the same splice, a push and a shift, then setelems 20 / bindpos 19.

Outputs (Task 7):

| prefix | Z-splice-clear-setelems: int / obj | Z-shift-realloc: int / obj |
|---|---|---|
| cfix-base and cfix-asan (origin/main f112c3998) | `11 22 33 44` / `a b z` | `0 22 33 44 0 0 0 0` / `<null> b c <null>` |
| vf-c-base, vf-n-base [record: before-z, before-z-fix1] | the same | the same |
| ob-c, ob-n at the tip (after-t7) | `0 0 0 0` / `<null> <null> z` | `0 0 0 0 0 0 0 0` / `<null> <null> <null> <null>` |

ASAN reports nothing for either program on cfix-asan. The slots are inside the allocation, so the stale read
is not an out-of-bounds access. Upstream has the bug.

**Zig port.** Yes before the fix: elements.zig asplice has the same arm (`if (n <= @as(i64, 0) -% s(elems0))`,
tip line 765) [checked], and storage.zig setSize did not zero within ssize (OB4's entry).

**Fix (area Z).** Growth zeroes every slot it brings into the window, from the old window's end (taken at
entry), within the storage and after a reallocation; push and unshift, which write every slot they expose,
use an entry that does not zero. There is no separate clearing at the reset (controller's ruling in Task 5).

## OB22. P6opaque's slice hands its own P6opaque `dest` to the delegate's slice (added 2026-11-24)

Status 2026-11-24: not fixed: found by reading in ob-fixes Task 5, outside the campaign's areas; reproduced
in Task 7 (port prefixes and upstream).

**Where found.** ob-fixes Task 5 (third round), by reading (ob-fixes.md "Seen on the way (not verified, not
fixed; to be OB22)").

**Location** [checked in Task 7, the tip d68a0ec8c and `git show origin/main:<path>`, the same code in both]:
- src/core/interp.c `OP(slice)` (tip 5205-5214, origin/main 5196-): `dest = MVM_repr_alloc_init(tc,
  GET_REG(cur_op, 2).o)`, an instance of the *source's* type, then `REPR(src)->pos_funcs.slice(..., dest,
  ...)`. `MVM_repr_pos_slice` (reprconv.c 73-80, the JIT's path for `slice` through op_to_func) does the same.
- src/6model/reprs/P6opaque.c `oslice` (1502-1510 at both): finds the positional delegate `del` and calls
  `REPR(del)->pos_funcs.slice(tc, STABLE(del), del, OBJECT_BODY(del), dest, start, end)`, `dest` unchanged.
- VMArray.c `aslice` (tip 1094-1117, origin/main 969-): `d_body = (MVMArrayBody *)OBJECT_BODY(dest)` and
  `d_repr_data = STABLE(dest)->REPR_data`, then `set_size_internal(tc, d_body, elems, d_repr_data)` and
  `copy_elements(tc, src, dest, start, 0, elems)`. Zig `aslice` (elements.zig 697-711) takes the same two from
  `dest`.

**What goes wrong** (by reading). For `nqp::slice` of a P6opaque with a positional delegate, `dest` is a
P6opaque object: its body is the P6opaque's (attribute slots, `replaced` first) and its REPR data an
`MVMP6opaqueREPRData`. aslice reads `slot_type` and `elem_size` from that REPR data as if it were an
`MVMArrayREPRData` and writes `start`, `elems`, `ssize` and `slots` into the P6opaque body: type confusion,
and a write past the body if the P6opaque body is shorter than an `MVMArrayBody`. `osplice` passes the
caller's source array on, not an object of the P6opaque's type, so it does not have this shape.

**Reachability.** nqp classes declare a delegate with `has @!list is positional_delegate` (NQPCapture,
nqp src/core/NQPCapture.nqp:3). `grep -rn 'nqp::slice'` over nqp's and rakudo's src (without jvm/js) gives 58
call sites. Their sources, by reading the call sites: native arrays and Bufs (`self`/`SELF`), IterationBuffers
(`$!result`, `$reified`, `$!indices`), nqp lists and split results. None slices a P6opaque [checked]. How each
source is constructed was not followed further.

**Reproducer** [ran in Task 7 with `ulimit -c 0` and a 2G cap:
ob-fixes-raw/gate-t7/probes/oslice-delegate.nqp, outputs in probes/out/ and upstream/]. An nqp class with `has @!list is positional_delegate`, the list `a b c d`,
then `nqp::slice($h, 1, 2)`:
- vf-c-base, vf-n-base, ob-c, ob-n and cfix-base: `elems through the delegate: 4`, `atpos 1 ...: b`, then
  `MoarVM panic: Memory allocation failed; could not allocate 2251765453946888 bytes`, exit 1;
- cfix-asan: `AddressSanitizer: requested allocation size 0x7fff800000008 ... exceeds maximum supported
  size` in `aslice`, exit 1.

The size comes from reading the P6opaque REPR data as an array's, which confirms the reading. The garbage
happened to be a huge size here; a small one would write an array body into the P6opaque object. That was
not seen.

**Zig port.** Yes: the C OP(slice) and P6opaque are shared; the Zig aslice treats `dest` as the C does.

**Fix sketch.** Either `oslice` allocates its `dest` from the delegate's type (and the op returns that), or
OP(slice)/MVM_repr_pos_slice allocate `dest` through the REPR (a REPR hook, or P6opaque refusing slice). A
choice of what `nqp::slice` of a delegating object returns.

## OB23. The JIT's generic repr-op calls skip the concreteness check (added 2026-11-24)

Status 2026-11-24: not fixed: found in ob-fixes Task 6, outside its brief; the read_buf/write_buf pair is
fixed under OB3 (f2c32559a).

**Where found.** ob-fixes Task 6 (OB3's concreteness question), probe
ob-fixes-raw/adhoc-t6-ob3/probes/typeobj-bindpos-jit.nqp (ob-fixes.md "Shared C", "Seen on the way").

**Location** [checked in Task 7 at the tip; origin/main the same for the lines named]:
- src/jit/graph.c `consume_reprop` (661-): the REPR's own function is called directly only when the facts
  give a known type *and* `MVM_SPESH_FACT_CONCRETE` (757-760); otherwise the op is compiled as a call to
  `op_to_func`'s C function (176-218: `MVM_repr_push_*`, `pop_*`, `shift_*`, `unshift_*`, `at_pos_*`,
  `bind_pos_*`, `at_key_*`, `bind_key_*`, `exists_*`, `delete_key`, `pos_set_elems`, `pos_slice`,
  `pos_splice`; origin/main 213 `case MVM_OP_bindpos_i: return MVM_repr_bind_pos_i;` the same).
- src/6model/reprconv.c: of these, only `MVM_repr_at_pos_o` (160) and `MVM_repr_at_key_o` (600) test
  `IS_CONCRETE`; e.g. `MVM_repr_bind_pos_i` (288-293, origin/main the same) calls the REPR's `bind_pos` on
  `OBJECT_BODY(obj)` at once. The interpreter's `OP(bindpos_i)` does `CHECK_CONC(obj)` first
  (interp.c 2158-2166).

**What goes wrong.** A type object reaching one of these ops in JIT-compiled code is passed to the REPR, whose
body pointer then points past the `sizeof(MVMObject)` allocation (as in OB2). For VMArray `bind_pos` this
writes through garbage.

**Reproducer** [ran in Task 7, outputs in ob-fixes-raw/gate-t7/probes/]: typeobj-bindpos-jit.nqp `write`
(`nqp::bindpos_i(nqp::atpos($list, $k), 0, 7)`, the last 3 of 200,000 calls on the type object).

- vf-c-base, vf-n-base, ob-c and ob-n: SIGSEGV (exit 139), as Task 6 saw [ran];
- cfix-base (origin/main): SIGSEGV, exit 139; cfix-asan: `AddressSanitizer: unknown-crash ... WRITE of size
  9007199254740993` at a wild pointer, in `set_size_internal`, exit 1 [ran]. Upstream has the bug;
- Task 6: with `MVM_JIT_DISABLE=1` or `MVM_SPESH_DISABLE=1`, `bindpos_i requires a concrete object (got a
  type object instead)` [record: adhoc-t6-ob3/probes/probes.txt; not re-run].

Only bindpos_i was run; the other ops of the list are the same shape by reading.

**Zig port.** Yes: graph.c and reprconv.c are shared C; the Zig array's bind_pos gets the same body pointer.

**Fix sketch.** The fix OB3 used for the buffer ops: an `IS_CONCRETE` check with the interpreter's message in
each `MVM_repr_*` function the JIT calls (one compare per call), or the JIT emitting a guard. Which ops'
messages to copy is a list to settle (`CHECK_CONC`'s "%s requires a concrete object").

## OB24. Deserialization holds the object being read in unrooted C locals (added 2026-11-24)

Status 2026-11-24: not fixed: found by reading in ob-fixes Task 6's review; not verified.

**Where found.** ob-fixes Task 6 review (OB5's fix roots `key` only).

**Location** [checked in Task 7 at the tip; origin/main the same shape]:
- MVMHash.c `deserialize` (tip 177-207; origin/main 198-200 for the read and the insert): `root`, `hashtable =
  &body->hashtable` and `data` are C locals held across `MVM_serialization_read_ref` (204) and used after it
  (`MVM_str_hash_insert_nocheck(tc, hashtable, key)` 206, `MVM_ASSIGN_REF(tc, &(root->header), ...)` 207).
  Since OB5's fix only `key` is rooted there.
- serialization.c `deserialize_object` (tip 2685-2704; origin/main 2671-): `obj` is held while
  `REPR(obj)->deserialize(tc, STABLE(obj), obj, OBJECT_BODY(obj), reader)` runs.
- Every REPR's `deserialize` has that shape: e.g. VMArray.c `deserialize` (tip 1559-) holds `body`
  (`OBJECT_BODY(root)`) across `MVM_serialization_read_ref` in its OBJ loop.

**What goes wrong** (by reading). If a collection ran inside one of those calls and moved the object, the
locals would point at the old copy. What makes it safe in practice: deserialization allocates with gen2 as the
default (`MVM_gc_allocate_gen2_default_set`, serialization.c 1388, 2483, 2846, 2886, 2943, 2980, 3216), and
gen2 objects do not move; the object is also reachable from its SC's root_objects. Not shown: that an object
being deserialized (in particular a repossessed one) can never be in the nursery.

**Reproducer.** None.

**Zig port.** Yes: the C serialization code is shared, and the Zig VMArray deserialize (serial.zig) has the
same shape.

**Fix sketch.** Either a proof (an assertion that the object is in gen2 at `deserialize_object`) or rooting
`obj` in deserialize_object and re-deriving body pointers after each call that can allocate in every REPR.

## OB25. strtocodes of an empty string calls `MVM_malloc(0)` (added 2026-11-24)

Status 2026-11-24: not in this campaign (seen in ob-fixes Task 6, not fixed).

**Where found.** ob-fixes Task 6, while checking OB9 (task report, concern 4; ob-fixes.md "Shared C", "Seen on
the way").

**Location** [checked in fix round 1 of Task 7: `sed -n 164,174p src/strings/normalize.c` at the tip d68a0ec8c;
`git show origin/main:src/strings/normalize.c`, the function at 154, the line at 162; src/core/alloc.h
`MVM_malloc`]: normalize.c, `MVM_unicode_string_to_codepoints`:

```c
    result_alloc = s->body.num_graphs;
    result       = MVM_malloc(result_alloc * sizeof(MVMCodepoint));
```

**What goes wrong** (by reading). For `""`, `num_graphs` is 0, so this is `MVM_malloc(0)`. `MVM_malloc` calls
`mi_malloc` (with MVM_USE_MIMALLOC) or `malloc` and treats a NULL result as out of memory
(`MVM_panic_allocation_failed`). C allows `malloc(0)` to return NULL, so on such a C library (without mimalloc)
`nqp::strtocodes("", ...)` would panic. mimalloc and glibc return a non-NULL block, so it does not show on these
builds (the port's zig build compiles mimalloc, build/zig/moar.zig).

**Reproducer.** None (it needs a C library whose `malloc(0)` returns NULL).

**Zig port.** Yes: normalize.c is shared C.

**Fix sketch.** Skip the allocation for 0 (and hand the output an empty array, as OB9's fix does for
normalizecodes), or allocate at least one element.

## Not verified in this pass

- Nothing was run on the port: the pass did not find the builds vf-c-base and vf-n-base (they exist under
  /tmp/claude-1000; the controller checked afterwards). Every "Zig port: yes" is by reading the Zig source and
  still needs a run on those builds.
- No ASAN run was made in this pass; every ASAN output quoted is from the records.
- OB1: no Windows build; the LLP64 width of `unsigned long` is assumed, not observed.
- OB2: the case where the garbage count is small (copy from a garbage slots pointer) was not seen; whether
  `aslice` or other ops have the same concreteness gap was not checked.
- OB3 (b), the JIT writeint/writeuint path, was not run by anyone. Whether spesh/JIT ever compiles readuint's
  direct-call branch (record: "probably never") was not checked. The missing SC write barrier and concreteness
  check on the JIT paths are my reading only.
- OB4: the Raku route through a socket or process Buf and `Buf.reallocate` was not run; Buf.rakumod:1343 was read
  in the port's rakudo checkout, not in upstream rakudo c6d6fc3c6b.
- OB5: cfix-D.md's argument (blocking in demand_object, stolen work, nursery key move) was taken from the record,
  not re-checked; whether `root` is always in gen2 there was not checked; the Zig collector's equivalent path was
  only grepped.
- OB7: the JIT bind entry points were read only briefly.
- OB10: I did not prove that no realistic input makes `MVM_repr_pos_set_elems` throw there; I did not check
  which exception-path cleanup mechanism MoarVM offers for C buffers.
- OB11: the claim that a first compose from OBJ cannot overflow (no kind wider than 8 bytes) is by reading
  spec_to_repr_data, not run per kind; the native first-compose case (pointers read as integers) was not run.
- OB13: never run on upstream MoarVM or with the C collector; the crash offsets and rates are from va-cleanup.md;
  va-c-syms / va-n-syms were not inspected.
- OB14: not reproduced; not known whether it still happens at 0d4149a90; the cast was not located; the raw file
  W/task-5-safe.out was not found.
- OB15a: which of the port's MoarVM, nqp or rakudo causes the failure is not known.
- OB15b, OB15c: taken from the records.
- OB16: whether any nqp/Rakudo code relies on writing ints into num arrays was not searched.
- OB17: no reproducer; whether an nqp op exposes the element storage spec was not searched.
- OB18: the crafted-blob overflow was not run; the claim that `nqp::deserialize` accepts an arbitrary blob that
  reaches VMArray's deserialize with a chosen count is by reading only.
- OB19: the element path of copy_elements (at_pos then bind_pos storing VMNull) and the serialize difference
  (`REFVAR_NULL` vs `REFVAR_VM_NULL`) are from the record; I read lines 259-265, 663 and 940-947 only.
- Line numbers in Zig files are at the port tip 0d4149a90; line numbers in the port's C files are at the same tip.
- Considered and not listed as a bug: unshift making front room before rejecting a wrong register kind when
  `start == 0` (cfix-ledger.md Task 3, "not caller-visible"); G2 (cfix-baseline.md, ruled not a bug); the
  `MVM_realloc(p, 0)` allocator difference (an environment fact, used in OB20).
