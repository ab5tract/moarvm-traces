# VMArray adoption audit: C outside VMArray.c that owns an array's storage

Campaign `2026-11-16-zig-vmarray-repr`, Task 3. MoarVM at `a92476665`
(branch `zig-vmarray`; `src/6model/reprs/VMArray.c` last changed in
`c7ca550e8`). Nothing here is fixed; this record is what Task 5 (slot storage)
may and may not assume about the buffer behind `MVMArrayBody.slots`.

The question for every site: C code outside `VMArray.c` that writes a
VMArray's `slots`, `ssize`, `start` or `elems` directly, hands the array a
buffer it allocated itself ("adopts"), or frees the slots. Code that only
reads the fields, or writes element values through the slot pointer without
changing the fields, is listed separately (section 4), because it constrains
the layout but not the allocator.

## 1. How the hits reduce to the sites

`traces/llm/bench/va-adoption-audit-raw/greps.sh` runs all three greps from the
MoarVM root, writes `g1.txt`, `g2.txt`, `g3.txt` beside itself and prints the
counts below.

| grep | command (over `src`, `--include='*.c' --include='*.h' --include='*.dasc'`) | hits |
|---|---|---|
| G1 (the brief's) | `grep -rnE 'slots\.[a-z0-9]+ *=[^=]\|\.ssize *=[^=]\|->ssize *=[^=]\|body\.start *=[^=]\|body\.elems *=[^=]'` | 37 |
| G2 (the brief's) | `grep -rnE 'MVM_free\([^)]*slots\.'` | 4 |
| G3 (supplementary) | `grep -nE '(\.\|->)(start\|elems\|ssize\|slots\.[a-z0-9]+) *=[^=]'` over the 16 files that name `MVMArray` or `MVMArrayBody`, `VMArray.[ch]` and `MultiDimArray.[ch]` excepted | 39 |

(The `\|` in the table is a `|` in the shell; the script has the exact text.)

Reduction:

- G1: 37 hits, minus 7 in `VMArray.c` itself, = 30 outside; minus 2 in
  `MultiDimArray.c` (lines 252 and 383 write a `MVMMultiDimArrayBody`, a
  different body with its own `slots` union) = **28 lines on an MVMArray**.
- G2: 4 hits, minus `VMArray.c:114` (the REPR's own `gc_free`), minus
  `MultiDimArray.c:286` (MultiDimArray's `gc_free`) = **2 lines on an
  MVMArray** (`io.c:133`, `normalize.c:84`).
- G1 misses an assignment through an `MVMArrayBody *` pointer to `start` or
  `elems` (its pattern wants `body.start`, `body.elems`). G3 catches those: 39
  hits, minus 7 that write `MVMString` strand fields in `strings/ops.c`
  (850, 863, 1086, 1108, 1128, 1204, 1211), = 32, of which 28 are the G1 lines
  and **4 are new**: `io.c:137`, `io.c:141`, `normalize.c:88`, `normalize.c:89`.
- Searched and empty: `realloc\([^)]*slots` (the one hit, `spesh/optimize.c:127`,
  is `g->spesh_slots`), `slots\.[a-z0-9]+ *= *NULL`, any `.zig` file under
  `src/zig` writing the fields (only `gc/orchestrate.zig:739` reads
  `slots.u64`), the JIT expression templates (no `MVMArray` in `src/jit/*.expr`).

Total: **34 lines, in 8 sites** (a site = one function's block of writes):
28 from G1, 2 from G2, 4 from G3 only. The earlier scouting estimate of about
24 was low; how it was counted is not recorded, but 24 is what G1 gives
without the two free-and-replace sites (`io.c`, `normalize.c:84-90`), whose
`->` lines G1 only half sees.

## 2. The sites

"Matches" is whether `ssize * elem_size` equals the size of the buffer the
array now holds. Every site sets `start = 0` (or leaves the fresh object's 0).

| # | file:line (function) | what it does | buffer: allocated by, size | `ssize` set to | matches? | kind |
|---|---|---|---|---|---|---|
| 1 | `src/io/asyncsocket.c:48-51` (`on_read`) | adopts a buffer into a fresh array (`MVM_repr_alloc_init(ri->buf_type)` at 47, slots NULL before) | `on_alloc` (19-23): `MVM_malloc(suggested_size > 0 ? suggested_size : 4)`, `buf->len` = that size | `buf->len` | yes (elem size 1); `elems = nread <= len` | U8 or I8, checked in `read_bytes` (192-196) |
| 2 | `src/io/asyncsocketudp.c:111-114` (`on_read`) | the same, for UDP | `on_alloc` (22-26): same as #1 | `buf->len` | yes; a 0-byte datagram with an address is adopted with `elems = 0` (the `nread == 0 && addr == NULL` case frees instead, 86-93) | U8 or I8, checked (226-230) |
| 3 | `src/io/procops.c:684-687` (`async_read`) | adopts into a fresh array of the type in the `buf_type` key of the spawn callbacks hash (681-683) | `on_alloc` (639-655): `MVM_malloc(size)`, size 128, or the next power of two above the last read; `buf->len` = size | `buf->len` | only if the element size is 1: `buf_type` is **never checked** in MoarVM (nothing in `procops.c` tests its REPR or slot type); with elem size `e`, `ssize * e = e * len` and `elems = nread` elements cover `e * nread` bytes | whatever the caller passes; Rakudo passes `buf8` (`Proc/Async.rakumod:465`), so U8 in practice |
| 4 | `src/6model/reprs/Decoder.c:340-343` (`MVM_decoder_take_bytes`) | adopts into a fresh array (`MVM_repr_alloc_init(buf_type)` at 339) | `MVM_string_decodestream_bytes_to_buf` (`decode_stream.c:589-621`): one `MVM_malloc` of `bytes` (more chunks follow), `available` (last chunk, taken whole) or `required` (part of a chunk); NULL when `bytes == 0`. The caller has checked `bytes_available >= bytes` (330-331), so it always takes what it allocated | `read` | yes; `bytes == 0` gives `slots = NULL`, `ssize = 0` | U8 or I8, checked (320-324) |
| 5 | `src/io/io.c:133-141` (`MVM_io_read_bytes`) | **frees** the existing slots with `MVM_free` (132-133), then adopts the handle's buffer into the caller's array, which may have had any `start`/`ssize` | the handle's `read_bytes`. `syncfile.c:139-175`: `MVM_malloc(length)`, `MVM_realloc(buf, bytes_read)` only when `0 < bytes_read < length / 4`; on Windows a console read is clamped to 16,387 bytes after the allocation. `syncsocket.c:81-173`: an exact `MVM_malloc(bytes)` in three branches, or the whole 65,535-byte packet buffer handed over with `bytes = last_packet_end` (143-147), or NULL at EOF | `bytes_read` | no: `ssize <= allocation` (the comment at 138-139 says so). A `syncfile` read of 0 bytes keeps a `length`-byte buffer with `ssize = 0`, `elems = 0` | U8 or I8, checked (110-114) |
| 6 | `src/strings/normalize.c:84-90` (`MVM_unicode_normalize_codepoints`) | **frees** the output array's slots with `MVM_free` (83-84), then adopts the result | `MVM_malloc(result_alloc * 4)` (56), grown by `maybe_grow_result` (31-37: `MVM_realloc` in steps of 32 elements, always to more than needed) | `result_pos * sizeof(MVMuint32)`, **a byte count** | no, and the wrong way: `ssize * 4 = 16 * result_pos` bytes against `4 * result_alloc` allocated. `result_alloc` starts at the input length and ends just above `result_pos` unless normalization shrank the text a lot, so `ssize` is about four times the allocation. An empty input returns at 52-53 without touching `out` | I32 or U32, checked (`assert_codepoint_array`, 23-30) |
| 7 | `src/strings/normalize.c:200-203` (`MVM_unicode_string_to_codepoints`) | adopts the result into `out` **without freeing** what `out` held | `MVM_malloc(num_graphs * 4)` (161-162), grown by `maybe_grow_result` | `result_alloc` | yes. An empty string normalized to NFC keeps `MVM_malloc(0)` (non-NULL under glibc and mimalloc) with `ssize = 0`; the other forms grow to 32 elements at the end (`maybe_grow_result` with `needed = 0`) | I32 or U32, checked (160) |
| 8 | `src/strings/ops.c:1914-1917` (`MVM_string_encode_to_buf_config`) | adopts the encoder's output, only when `slots.any` is NULL (the other branch, 1907-1911, appends through `MVM_repr_pos_set_elems` and a `memmove`; see section 3) | the encoder behind `MVM_string_encode_config` (`MVM_malloc`/`MVM_realloc`; e.g. `utf8.c:565-576`: `2 * graphs + 4` bytes, doubled as needed); size >= `output_size`. The only plain-libc `malloc` calls in `src/strings` (`ascii.c:230`, `utf8.c:627`) are in the `*_malloc` C-string helpers, which this path does not reach | `output_size / elem_size` | no: `ssize * elem_size <= output_size <= allocation`. `output_size % elem_size` trailing bytes are in the buffer but outside `elems`. An empty string leaves a small non-NULL buffer (UTF-8: 4 bytes) with `ssize = 0` | any of the eight integer kinds I64, I32, I16, I8, U64, U32, U16, U8 (1884-1896); the num, OBJ, STR and six no-storage kinds are refused ("encode requires a native int array") |

What the sites have in common, for Task 5:

- Every adopted buffer comes from `MVM_malloc`/`MVM_realloc` (sites 1-8), and
  sites 5 and 6 free the array's previous slots with `MVM_free`. After
  adoption the array's own code grows the buffer with `MVM_realloc`
  (`set_size_internal`, `VMArray.c:465-467`) and `gc_free` frees it with
  `MVM_free` (`VMArray.c:114`). So the slot buffer must stay interchangeable
  with `MVM_malloc`/`MVM_free` in both directions.
- `ssize` is not "what the growth policy produced": these sites, and the
  array's own `copy_to` (`VMArray.c:53`) and `deserialize` (`VMArray.c:1370`),
  set it to an arbitrary value; it can be smaller than the allocation (sites
  5, 8) and, at site 6, larger.
- `slots.any != NULL` with `ssize == 0` happens (sites 1, 2, 5, 7, 8, and the
  array's own growth of a no-storage kind, see `va-kind-differences.md`
  section 3). The campaign rule "an array without storage has
  `slots.any == NULL`" holds for arrays the Zig code creates, but the Zig code
  must accept and free a non-NULL zero-capacity buffer it receives.
- The fields are written in the order slots, start, ssize, elems (sites 6 and
  7: slots, start, elems, ssize); no site holds a lock or the single-user flag,
  and none goes through `set_size_internal`.

## 3. Sites where `ssize` misstates the allocation (reported, not fixed)

| site | misstatement | consequence |
|---|---|---|
| `normalize.c:90` | `ssize = result_pos * sizeof(MVMuint32)`: bytes, not elements; about 4x the allocation | **report to the user.** `set_size_internal` (`VMArray.c:431-435`) believes there is room up to `ssize` elements, so a later `push`/`bindpos`/`setelems` on the result between `result_alloc` and `ssize` elements writes past the allocation without reallocating (a heap overflow, found by reading, not run). `unmanaged_size` overstates by the same factor. |
| `io.c:140` | `ssize = bytes_read`; the buffer may be up to `length` bytes (`syncfile`, when `bytes_read >= length / 4`) or 65,535 bytes (`syncsocket` packet handover) | understates; safe for the C (it reallocs earlier than needed), and `unmanaged_size` under-reports. Acknowledged in the code (138-139). |
| `ops.c:1916` | `ssize = output_size / elem_size`; the encoder's buffer has headroom (`2 * graphs + 4` for UTF-8) and the division drops a remainder | understates; safe for the C. |
| `procops.c:686` | `ssize = buf->len` bytes, correct only for a 1-byte element type; `buf_type` is unchecked | **report to the user.** A `buf_type` with wider elements (or not a VMArray at all: the code casts whatever `MVM_repr_alloc_init` returns to `MVMArray *`) makes `ssize` and `elems` overstate the buffer by the element size. Rakudo always passes `buf8`, so not reachable from Rakudo. |

Other C defects found at the sites (reported, not fixed):

- `normalize.c:200-203` overwrites `out`'s slots without freeing them: the old
  buffer leaks when `out` already had storage. **Report to the user.**
- `ops.c:1910`, the append branch of site 8: `memmove(slots.i8 + prev_elems,
  ...)` offsets by `prev_elems` **bytes**, ignoring both `start` and the
  element size, and `prev_elems` is a `MVMuint32` (1908) that truncates
  `elems`. Correct only for a 1-byte array with `start == 0` and fewer than
  2**32 elements; otherwise it overwrites existing elements and leaves some of
  the new ones zero. **Report to the user.**

## 4. Readers and in-place writers (not sites; they pin the layout)

These read `slots`/`start`/`elems`, or write element values through the slot
pointer, without changing ownership. They keep working as long as the body
layout is the C one and the elements of an array are contiguous from
`slots + start * elem_size`:

| file:line | what |
|---|---|
| `src/jit/x64/emit.dasc:2728-2732` | the JIT computes `slots + start * elem_size` inline for a VMArray native-call argument |
| `src/core/nativecall.c:507-510` | `MVM_nativecall_unmarshal_vmarray` hands native code `slots + start * elem_size`; native code may write elements through it |
| `src/6model/reprs/VMArray.c:1194-1213` (for completeness) | `pos_as_atomic` returns a pointer into the slots to the atomic ops |
| `src/core/loadbytecode.c:56-61`, `88-93`; `Decoder.c:220-231`; `io.c:154-170`; `normalize.c:50-51`, `146-147`; `ops.c:1957-1959` | read `slots + start` and `elems` (bytecode loading, decoder input, `write_fhb`, normalization input, decode from buf) |
| `src/profiler/configuration.c:544` | reads `slots.u8` **without adding `start`**: a confprog bytecode array that has been shifted is read from the wrong place (reported; minor) |
| `src/gc/orchestrate.c:514-532`, `src/zig/gc/orchestrate.zig:739`, `src/spesh/worker.c:138-144` (and the later `overview_data[...]` writes up to line 319) | `MVM_repr_pos_set_elems` on a fresh event array, then write elements through `slots.u64`/`slots.i64` directly, relying on `start == 0` for a fresh array |
| `src/debug/debugserver.c:2648-2655`, `2878-2898` | read `elems`, `start`, `ssize` for the debugger protocol |
| `src/6model/reprconv.c:95-170`, `sc.c:160`, `serialization.c:1816-1961`, `spesh/stats.c:644-690` | call the exported `MVM_VMArray_*` functions (their `_i`/`_u`/`_n` callers guard the slot kind first) |

## 5. What a non-`malloc` allocator would have to change

Today the slot buffer has to be MoarVM's own `MVM_malloc`/`MVM_realloc`/
`MVM_free` underneath, in both directions: the eight sites hand the array
`MVM_malloc` buffers, two of them free its old slots with `MVM_free`, and the
array reallocs and frees whatever it holds. With the default
`-Dmimalloc=true` (`build/zig/options.zig:142`) those functions are
`mi_malloc`/`mi_realloc`/`mi_free` (`src/core/alloc.h:1-60`), and the build
compiles `3rdparty/mimalloc/src/static.c` (`build/zig/moar.zig:142-143`)
without `MI_MALLOC_OVERRIDE` (defined nowhere in `build/zig` or
`3rdparty/mimalloc`), so libc's `malloc` is not replaced: a Zig allocator
built on `std.heap.c_allocator` would already be the wrong one. The allocator
must call `MVM_malloc`/`MVM_realloc`/`MVM_free` (or their mimalloc
equivalents under the same build switch). It must also ignore the length it
is given on `free`, and on `resize`/`remap` it must not copy by that length:
`ssize * elem_size` is not the allocation's size at sites 5, 6 and 8 (and at
3 for a wide `buf_type`). Where it understates (5, 8) a sized copy is merely
short of the slack; at site 6 it is four times too large, so a sized copy or
free would read or release memory the array does not own.

A genuinely different allocator (an arena, a size-class pool, Zig's debug
allocator) needs all eight sites changed first. Each would give its buffer to
the array through one exported entry point ("adopt this `MVM_malloc` buffer
of `n` bytes holding `elems` elements"), which either copies it into
allocator-owned storage and frees the original, or records its true size and
origin so the array can release it with `MVM_free` later. Sites 5 and 6 would
release the old storage through the array instead of calling `MVM_free`
themselves, and site 6 would have to pass the true element capacity
(`result_alloc`) instead of a byte count. The readers in section 4 are not
affected by the allocator, only by the layout; and no outside code takes a
buffer out of an array, so nothing else would have to give storage back.
