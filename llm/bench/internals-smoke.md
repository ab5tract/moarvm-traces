# Internal tables: startup smoke of the stats build (2026-11-03)

Branch `zig-hash-internals`. Stats build `zig build install --prefix
/tmp/claude-1000/stats-zig-prefix -Dhash-stats=true`; the tune-zig-prefix
`raku` run against its libmoar:

    LD_LIBRARY_PATH=/tmp/claude-1000/stats-zig-prefix/lib \
      MVM_HASH_STATS=<dir> /tmp/claude-1000/tune-zig-prefix/bin/raku -e 'say 1'
    tools/bench/hash-stats.pl <dir> --lib=/tmp/claude-1000/stats-zig-prefix/lib/libmoar.so --census

`say 1` prints 1 and leaves one `<pid>.tsv`. `raku -e 'exit 3'` exits 3 and
leaves its file (the exit path through `MVM_vm_exit` runs the `atexit`
handler); likewise `nqp-m -e 'nqp::exit(3)'` exits 3 and leaves a file.
`moar --version` and `--help` exit before any table is built, so they leave
no file (the handler is registered on the first counted use): the fixture
test's real-binary part therefore runs `nqp-m -e 1`.

## Resolution

GNU addr2line 2.47 returns `??:?` (or `ld-temp.o:?`) for this build's DWARF
(clang 21, LTO); `llvm-addr2line` reads it, so the aggregator retries with it.
A site offset is a return address; the lookup is for offset-1, which gives
the line of the build call (offset itself gives the next statement's line).
Inlined statics resolve to their own name (`add_to_hash` for the syscall
table at the return address; `MVM_disp_syscall_setup` at offset-1), clone
suffixes (`deserialize.2546`) are stripped.

## Sites at `raku -e 'say 1'` (17 rows: 16 sites and `other`)

Total 378.8M cycles, hash cycles 28.8M (7.6%). Resolved lines are those of the
build call; the census numbers the same sites by older lines.

| label | resolved | hash cycles | % of hash |
|---|---|---|---|
| s5 | `MVMHash_bind_key` MVMHash.c:115 | 19.8M | 68.6 |
| i2 | `MVM_bytecode_finish_frame` bytecode.c:667 | 2.65M | 9.2 |
| i1 | `MVM_vm_create_instance` moar.c:182 | 2.22M | 7.7 |
| u4 | `MVM_unicode_init` unicode_ops.c:959 (and :971, same label) | 1.21M | 4.2 |
| f8 | `MVM_disp_syscall_setup` syscall.c:1671 | 0.94M | 3.3 |
| u1 | `generate_property_codes_by_names_aliases` unicode_ops.c:915 | 0.51M | 1.8 |
| f4 | moar.c:195 | 0.41M | 1.4 |
| f1 | moar.c:186 | 0.39M | 1.4 |
| s1 | moar.c:203 | 0.29M | 1.0 |
| f6 | moar.c:207 | 64K | 0.2 |
| f3 | moar.c:191 | 39K | 0.1 |
| s6 | `deserialize` MVMHash.c:192 | 16K | 0.1 |
| p1 | `MVM_gc_object_id` objectid.c:28 | 15K | 0.1 |
| f7 | moar.c:210 | 13K | 0.0 |
| f5 | moar.c:199 | 11K | 0.0 |
| f2 | moar.c:187 | 37 | 0.0 |
| other | site 255 | 0.24M | 0.8 |

Not seen at startup (`--census`): i3 p2 s2 s3 s4 s7 s8 s9 u2 u3 (s2 needs the
debug server, p2 a heap snapshot, s7/s8 a native callback, u2/u3 the first
sequence-name or codepoint-name lookup; s3/s4/s9/i3 clones and HashAttrStore).

Notes:

- `other` (0.8% of hash cycles: 6346 fetch misses and 57 iterator starts) is
  operations the stats layer could not attribute to a site, probably those on
  handles never built through an attributed export (zero-filled tables).
  The cause was not investigated here; it is not an unresolved address.
- p1 appears at objectid.c:28 only; moar.c:214 (the census's p1 build) never
  counts, `object_ids` is built lazily by its first insert.
- s5 is two thirds of the hash cycles of startup: 72111 inserts, 31497 fetch
  hits, 23831 misses over 4472 tables, all in the `<=4` build bucket.
