# cfix area O: the async process read handler's buffer type (O1) (Task 5)

```
Branch:    procops-buf-type, from origin/main f112c3998, in P (local only, not pushed)
Commit:    30e6d43962477e960960fc3fec7d80e91687402d "Check spawnprocasync's buf_type at the spawn, and keep it" (O1)
Diff:      src/io/procops.c +37 -4: SpawnInfo field, async_read, a helper and a check in spawn_setup,
           spawn_gc_mark, MVM_proc_spawn_async
Prefixes:  /tmp/claude-1000/cfix-O (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-O-asan (--asan
           --no-mimalloc), from `git archive` copies /tmp/claude-1000/cfix-src-O{,-asan}
           (cfix-T-raw/build/export-build.sh; driver cfix-N-raw/build/build-all.sh); the built procops.c is
           byte-identical to the branch's; make exit 0, 10 s / 20 s, no warning in procops.c (729 / 725 in
           all); the new messages are in both libmoar.so (strings)
nqp/rakudo: Task 1's builds, only the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-O-raw/repro/ (run-all on both prefixes; the new program also on cfix-base and cfix-asan),
           cfix-O-raw/late/ (the racy mode, 10 runs each on cfix-base, cfix-O, cfix-O-asan),
           cfix-O-raw/pr-repro/, cfix-O-raw/cmp.txt, cfix-O-raw/suites/, cfix-O-raw/build/
```

## 1. The fix

What the code did (procops.c, f112c3998):
- `async_read` (658-746), on each successful read, looked up `buf_type` in `si->callbacks` (681-682).
  `si->callbacks` is the caller's config hash itself (`MVM_ASSIGN_REF ... si->callbacks, callbacks`,
  1323).
- It then did `MVM_repr_alloc_init` on that type and wrote a VMArray body into the result (683-687):
  slots = the libuv buffer, start 0, ssize = buffer length, elems = bytes read. Nothing checked the
  type's REPR or element kind.
- A missing key gives VMNull (`MVMHash_at_key`, MVMHash.c:99). Allocating VMNull throws "Cannot create
  an instance of null type" on the event loop thread, and that exception is treated as an oops and ends
  the process.

What it does now:
1. A helper, `reads_output(tc, callbacks)`, is true when the config has any of `merge_bytes`,
   `stdout_bytes`, `stderr_bytes` or `pty`. Those are the keys for which spawn_setup creates a pipe it
   reads from: `merge_bytes` 935-948, `stdout_bytes` 950-957, `stderr_bytes` 967-974, and pty mode creates
   `pipe_stdout` (834-837, and the self-made pty path). Reading only ever starts on those pipes
   (spawn_permit, 1129-1189).
2. `MVM_proc_spawn_async` checks `buf_type` when `reads_output` holds, right after the queue check and
   before anything is allocated (so a throw leaks nothing). It throws if buf_type is missing or invalid.
   - The check and its messages follow `asyncreadbytes` (asyncsocket.c:192-199, asyncsocketudp.c:226-233)
     and `decodertakebytes` (Decoder.c:320-324): a VMArray whose slot type is U8 or I8, otherwise
     "spawnprocasync buf_type must be an array" or "spawnprocasync buf_type must be an array of uint8 or
     int8". The key name is used instead of "buffer type" because it is what the caller has to fix.
   - A missing key gives VMNull, whose REPR is not VMArray, so it gets the first message.
3. The checked type is stored in a new `SpawnInfo.buf_type` (MVM_ASSIGN_REF on the task header, as
   `callbacks`). It is NULL when no output is read. It is rooted across the allocations in
   MVM_proc_spawn_async (MVMROOT3 becomes MVMROOT4, with the other three objects). It is marked in
   `spawn_gc_mark` next to `handle` and `callbacks`. `MVM_gc_worklist_add` skips NULL.
   - Heap snapshots: MVMAsyncTask has no describe_refs (MVMAsyncTask.c:99, NULL) and MVMAsyncTaskOps has
     no describe hook (eventloop.h:3-19). The neighbours are not described, so nothing is added.
   - spawn_gc_free needs nothing, because the type is a GC object.
4. `async_read` uses `si->buf_type` and no longer reads the hash.
5. One more case had to be covered. spawn_setup itself reads the reading keys from the live hash again,
   on the event loop thread. So a reading key bound after `spawnprocasync` returned would give a pipe with
   no checked type, and the read handler would allocate from NULL. spawn_setup now checks, before it
   creates anything: if there is no stored type but `reads_output` holds, it reports "spawnprocasync
   buf_type was not given when the process was spawned" through the existing error path
   (`spawn_setup_error`). That path calls the `error` callback, removes the active work and does not
   start the process, as for a failed spawn.

**Behaviour changes, all directions:**
- A spawn whose config reads output and has an invalid or missing buf_type now throws synchronously from
  `nqp::spawnprocasync`. Before, it read into the wrong type (heap overrun, or a hash body overwritten),
  or, with no key, killed the process.
- Rebinding `buf_type` after the spawn no longer changes the type of later reads.
- A config that reads no output is not checked, as before: its buf_type is never used (`noread` mode:
  same output before and after, even with an int64 type).
- A config with `pty` and no `buf_type` now throws at the spawn. Before, the terminal was read into
  VMNull (oops). On a platform without pty support the error changes from the asynchronous "PTY support
  is missing" to this synchronous one, but only when buf_type is also missing or invalid.
- A reading key added to the hash after `spawnprocasync` returned, with no buf_type at the spawn, now gives
  an error through the error callback instead of reading. Before: an oops if setup saw the key, or reading
  into whatever buf_type then held.
- The four keys are now read from the hash on the caller's thread at the spawn, in addition to the setup.
  A `callbacks` that is not a hash fails there, synchronously, instead of on the event loop.
- Rakudo's `Proc::Async` (c6d6fc3c6b) always binds `buf_type` to `buf8` (Proc/Async.rakumod:465, also
  for pty, where it adds `stdout_bytes`) and is not affected. nqp's `run-command` in testing.nqp binds
  `create-buf(uint8)` (testing.nqp:106).

**The other places that take a buffer type** (whether each validates):

| site | validates | where |
|---|---|---|
| asyncsocket `read_bytes` (nqp::asyncreadbytes on a TCP socket) | yes, at task creation; type kept in ReadInfo, marked in read_gc_mark | asyncsocket.c:192-199, 209, 160 |
| asyncsocketudp `read_bytes` (nqp::asyncreadbytes on UDP) | yes, the same | asyncsocketudp.c:226-233, 243, 194 |
| `MVM_io_read_bytes_async` (io.c:201-210) | dispatches to the two above (the only async_readable tables: asyncsocket.c:459, asyncsocketudp.c:470) | |
| `nqp::readfh` (`MVM_io_read_bytes`) over syncfile / syncsocket / pipes | yes: the result object must be a concrete VMArray of U8/I8 (io.c:110-114); the handle's read_bytes returns a char buffer; old slots are freed | io.c:104-142 |
| `nqp::decodertakebytes` | yes | Decoder.c:320-324 |
| async process reads (`async_read`) | **no: fixed here** | procops.c |

## 2. Reproducers, before and after

`O-buf-type-cases.nqp` is new. It has six modes. The 100 bytes are `printf "%099d\n" 7`.

| program | cfix-base / cfix-asan (before) | cfix-O / cfix-O-asan (after) |
|---|---|---|
| `O1-procasync-buf-type.nqp int64` | `got 100 elements`, element 99 garbage, exit 0; ASAN: heap-buffer-overflow READ in MVM_VMArray_at_pos | `spawn: DIED spawnprocasync buf_type must be an array of uint8 or int8`, `reads: 0`. The program then fails by itself ("elems requires a concrete object") because it was written to inspect a read that never comes; exit 1; both builds |
| `O1-procasync-buf-type.nqp hash` | SIGSEGV in `nqp::elems` on the overwritten hash | `spawn: DIED spawnprocasync buf_type must be an array`, then the same program-side failure; both builds |
| `O-buf-type-cases.nqp valid` | 1 read, 100 elements, element 0: 48, element 99: 10 | the same |
| `... missing` | `MoarVM exception in event loop thread treated as oops: Cannot create an instance of null type`, exit 1; both builds | `spawn: DIED spawnprocasync buf_type must be an array`, `reads: 0`, exit 0; both builds |
| `... rebind` | plain: 100 elements, element 0: 3472328296227680304, element 99: garbage (varies); ASAN: heap-buffer-overflow READ in MVM_VMArray_at_pos | 100 elements, element 0: 48, element 99: 10 (the type checked at the spawn); both builds |
| `... noread` | the line on the inherited stdout, `spawn: returned`, `reads: 0`, exit 0 | identical |
| `... pty-missing` | the oops as for `missing`, exit 1; both builds | `spawn: DIED spawnprocasync buf_type must be an array`, exit 0; both builds |
| `... late` (not in run-all: a race) | 10 of 10 runs on cfix-base: the oops, exit 1 | 10 of 10 runs on cfix-O and 10 of 10 on cfix-O-asan: `error callback: spawnprocasync buf_type was not given when the process was spawned`, `spawn: returned`, `reads: 0`, exit 0 (`cfix-O-raw/late/`) |

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-O -o cfix-O-raw/repro` and `-p cfix-O-asan` (124 outputs). `cfix-N-raw/cmp-repro.sh
cfix-O-raw/repro O` (`cfix-O-raw/cmp.txt`): 111 same, 13 differ.
- 10 expected flips: O1 int64 and hash, and O-buf-type-cases missing, rebind and pty-missing, each on both
  builds.
- 3 noise: B1's raku program and B-buf-grid (plain), and E-encode-state (plain). E-encode-state crashes
  after an E2 overrun at a varying point, and agrees with upstream as far as both go
  (`cfix-E-raw/prefix-cmp.txt`).

## 4. Suites

`cfix-maketest-driver.sh cfix-O-raw/suites cfix-O` (probes map `/tmp/claude-1000/cfix-O/lib/libmoar.so`;
run on the branch's final tree):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 1.36) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (124 s, load 1.45) | identical (`diff` empty) |

## 5. Draft PR text

Title: **Check spawnprocasync's buf_type when the process is spawned, and keep it**

Body:

> The async process read handler allocates an object of the config's `buf_type` for every chunk of output.
> It then writes the libuv buffer into that object as a VMArray body: slots, start, ssize and elems, all
> in bytes. It never checked that `buf_type` is a VMArray of 8-bit integers, as `asyncreadbytes` and
> `decodertakebytes` do. It also looked `buf_type` up in the caller's config hash again at every read.
>
> - With an int64 array type, 100 bytes of output came back as 100 eight-byte elements, and reading the
>   last one went past the buffer.
> - With a non-array type, the four fields were written over that object's body.
> - With no `buf_type` key, the event loop thread died on "Cannot create an instance of null type" and took
>   the process with it.
> - A type that was right at the spawn could be swapped for any other by rebinding the key afterwards.
>
> Now `nqp::spawnprocasync` checks `buf_type` before it sets anything up, whenever the config asks for
> output to be read: `merge_bytes`, `stdout_bytes`, `stderr_bytes`, or `pty`, whose terminal is read
> through stdout. It throws "spawnprocasync buf_type must be an array" (a missing key included) or "...
> must be an array of uint8 or int8". The checked type is kept in the spawn info and marked by the task's
> gc_mark, and the read handler uses it instead of the hash. A config that reads no output is not checked, as before,
> since its `buf_type` is never used.
>
> The keys that decide which pipes are read are themselves read from the hash again by the event loop when
> it sets the process up. So one more case needs covering: a reading key added after spawnprocasync
> returned, with no `buf_type` given at the spawn. In that case the setup now reports "spawnprocasync
> buf_type was not given when the process was spawned" through the `error` callback, like other setup
> failures, and does not start the process.
>
> Rakudo's Proc::Async always passes buf8 and is not affected. In nqp, run with `int64`, `missing` or
> `rebind`:
>
> ```
> # nqp o.nqp int64|missing|rebind
> my class Queue is repr('ConcBlockingQueue') { }
> sub int_array(int $bits) {
>     my $int := nqp::newtype(nqp::null(), 'P6int');
>     nqp::composetype($int, nqp::hash('integer', nqp::hash('bits', $bits, 'unsigned', 1)));
>     my $t := nqp::newtype(nqp::null(), 'VMArray');
>     nqp::composetype($t, nqp::hash('array', nqp::hash('type', $int)));
>     $t
> }
> sub MAIN($prog, $case) {
>     my $queue := nqp::create(Queue);
>     my $done := 0; my $eof := 0; my @got;
>     my $config := nqp::hash(
>         'done',  -> $status { $done := 1 },
>         'error', -> $err, $code? { say("error: $err"); $done := 1; $eof := 1 },
>         'stdout_bytes', -> $seq, $data, $err {
>             nqp::isconcrete($data) ?? nqp::push(@got, $data) !! ($eof := 1)
>         });
>     $config<buf_type> := int_array(64) if $case eq 'int64';
>     $config<buf_type> := int_array(8)  if $case eq 'rebind';
>     my $task;
>     try {
>         # 100 bytes on stdout
>         $task := nqp::spawnprocasync($queue, '/bin/sh', nqp::list('/bin/sh', '-c', 'printf "%099d\n" 7'),
>             nqp::cwd(), nqp::getenvhash(), $config);
>         CATCH { say("spawnprocasync died: " ~ nqp::getmessage($!)) }
>     }
>     return 0 unless nqp::isconcrete($task);
>     $config<buf_type> := int_array(64) if $case eq 'rebind';
>     nqp::permit($task, 1, -1);
>     while !$done || !$eof {
>         my $t := nqp::shift($queue);
>         if nqp::islist($t) { my $code := nqp::shift($t); $code(|$t) } else { $t() }
>     }
>     my $buf := @got[0];
>     say("read " ~ nqp::elems($buf) ~ " elements; element 0: " ~ nqp::atpos_i($buf, 0)
>         ~ ", element 99: " ~ nqp::atpos_i($buf, 99));
> }
> ```
>
> Before (plain build; element 99 is whatever lies 664 bytes past the 128-byte buffer):
>
> ```
> $ nqp o.nqp int64
> read 100 elements; element 0: 3472328296227680304, element 99: 256
> $ nqp o.nqp missing
> MoarVM exception in event loop thread treated as oops: Cannot create an instance of null type
> $ nqp o.nqp rebind
> read 100 elements; element 0: 3472328296227680304, element 99: 256
> ```
>
> With AddressSanitizer, `int64` and `rebind` are a heap-buffer-overflow READ in `MVM_VMArray_at_pos`.
>
> After (plain and AddressSanitizer builds alike):
>
> ```
> $ nqp o.nqp int64
> spawnprocasync died: spawnprocasync buf_type must be an array of uint8 or int8
> $ nqp o.nqp missing
> spawnprocasync died: spawnprocasync buf_type must be an array
> $ nqp o.nqp rebind
> read 100 elements; element 0: 48, element 99: 10
> ```
>
> `make test` of nqp and Rakudo gives the same per-file results as before.
>
> Found while auditing, for the port of the VMArray REPR to Zig, the places outside the REPR that build or
> adopt an array's storage directly.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)
