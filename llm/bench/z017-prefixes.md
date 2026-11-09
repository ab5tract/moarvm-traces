# zig-017 Task 5, Step 1: the six 0.17 prefixes

```
Date:       2026-11-08, about 22:55-00:05 CET
MoarVM:     zig-017 at b1bbb9dd4 (traces 175921d before these records)
Toolchain:  Zig 0.17.1 (/usr/bin/zig), zig cc = clang 22.1.8 (0.16 prefixes: Zig 0.16.0)
Runner:     no nqp/rakudo in any prefix; scripts reach a prefix with LD_LIBRARY_PATH=<P>/lib and the moar, nqp
            (zig-hash-strategies 41e7210ba) and rakudo (zig-build-spec 042608fb82) of /tmp/claude-1000/tune-zig-prefix
CPU:        AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Memory:     every build under systemd-run --user --scope -q -p MemoryMax=8G
Raw:        z017-prefixes-raw/ (build scripts, builds-*.tsv, cgc-tree.diff, backendconfig dumps)
```

## Configurations

| prefix | 0.16 counterpart | collector | hash engine | options |
|---|---|---|---|---|
| g7-c-oracle | gc-c-oracle | C | Zig | -Dgc-debug=1 (built from the scratch copy, below) |
| g7-z-oracle | gc-z-oracle | Zig | Zig | -Dgc-debug=1 |
| g7-c-base | gc-c-base | C | Zig | defaults (scratch copy) |
| g7-z-base | gc-z-base | Zig | Zig | defaults |
| g7-c-stress | gc-c-stress | C | Zig | -Dgc-debug=1 -Dnursery-size=524288 (scratch copy) |
| g7-z-stress | gc-z-stress | Zig | Zig | -Dgc-debug=1 -Dnursery-size=524288 |

Defaults: LTO, ReleaseFast, x86-64-v3, -Dzig-impl=true, nursery 16 MiB. Each build: `rm -f src/gen/config.{h,c,o}`,
1-minute load < 2.0, `zig build install --prefix /tmp/claude-1000/<name> <options>`.

### Why the C side is built from a copy

The plan's C side, `-Dzig-impl=false`, turns off the whole [zig] section of build/sources.list: the hash engine as
well as the collector. Campaign 4's C side (gc-c-*, 96d049123) was the C collector with the Zig hash engine. The
first build of g7-c-* used -Dzig-impl=false (all-C: 2820 exported symbols against gc-c-base's 2850) and its
oracle logs differed from every Zig-hash build from the first collection and were not repeatable (the C string
hash salts every table, src/core/str_hash_table.c:150); see z017-oracle.md. Ruling (controller): rebuild the
three g7-c-* prefixes as C collector + Zig hash engine from a plain directory copy of the checkout. The copy
(`rsync -a --exclude=.zig-cache --exclude=zig-out <MoarVM>/ /tmp/claude-1000/z017/cgc-tree/`, .git and zig-pkg
included) dropped the ten `src/zig/gc/*.zig: src/gc/*.c` lines of the [zig] section and the ten gc imports of
src/zig/root.zig (z017-prefixes-raw/cgc-tree.diff, the copy's `git diff` against b1bbb9dd4); nothing else
changed, the build needed no other adjustment, and the copy was deleted after the three builds. The repository
did not change. (A build switch for this configuration is a follow-up for the next campaign.)

## Builds

| prefix | exit | seconds | load before | moar --version |
|---|---:|---:|---:|---|
| g7-z-oracle | 0 | 50 | 1.10 | This is MoarVM version 2026.09-257-gb1bbb9dd4 built with JIT support |
| g7-z-base | 0 | 45 | 1.35 | (the same) |
| g7-z-stress | 0 | 47 | 0.99 | (the same) |
| g7-c-oracle (copy) | 0 | 60 | 0.49 | (the same) |
| g7-c-base (copy) | 0 | 45 | 1.98 | (the same) |
| g7-c-stress (copy) | 0 | 47 | 1.71 (after one 60 s wait at 2.05) | (the same) |
| superseded all-C g7-c-oracle / -base / -stress | 0 | 56 / 40 / 39 | 0.24 / 1.53 / 0.75 | (the same) |

Every version line is 68 characters, as are those of the gc- prefixes (2026.09-211-g139d404ed for gc-c-*,
2026.09-239-g64f82bf6d for gc-z-*); the copy's describe was "-dirty" with --dirty, but the build's version
string is the plain describe, identical to the checkout's. Prefix paths have equal length pairwise
(g7-c-oracle/gc-c-oracle 11, g7-c-base/gc-c-base 9, ...). Smoke: `moar --libpath=<nqp lib> nqp.moarvm -e
'say(42)'` with LD_LIBRARY_PATH=<P>/lib prints 42 for all six; ldd of tune-zig-prefix/bin/moar resolves
libmoar.so to <P>/lib.

## Configuration proof (C side)

| check | g7-c-oracle | g7-c-base | g7-c-stress |
|---|---|---|---|
| `nm -D --defined-only` names (gc-c-* counterpart) | 2852 (2852) | 2850 (2850) | 2852 (2852) |
| diff of the sorted name lists against gc-c-* | empty | empty | empty |
| backendconfig keys differing from gc-c-* | bindir ldflags ldrpath libdir mastdir prefix version versionpatch (paths and version only, equal length) | the same | the same |

The symbol set proves the Zig hash engine (the all-C build lacks 30 hash exports); the collector is shown by
the dynamic symbol sizes, which equal gc-c-base's and differ from the Zig collector's:

| `nm -D -S` size | gc-c-base | g7-c-base | gc-z-base | g7-z-base |
|---|---:|---:|---:|---:|
| MVM_gc_collect | 1627 | 1627 | 1456 | 1441 |
| MVM_gc_enter_from_allocator | 1184 | 1184 | 1268 | 1204 |
| MVM_gc_root_add_permanent_desc | 415 | 415 | 435 | 435 |

The backendconfig of g7-z-* also differs from gc-z-* only in the same eight path/version keys; the baked
`config` string spells -Doptimize=ReleaseFast on both toolchains (Task 1 ruling).
