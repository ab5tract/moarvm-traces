# ngc Task 1, Step 7: the nine prefixes; ng-c-base equals Campaign 5's scratch control

```
Date:       2026-11-09, 09:40-09:47 CET
MoarVM:     zig-native-gc at f0582f365 ("Build: -Dzig-gc, the C-collector control from the tree"); traces fb6346e before
            these records
Toolchain:  Zig 0.17.1 (/usr/bin/zig), zig cc = clang 22.1.8
Runner:     no nqp/rakudo in any prefix; scripts reach a prefix with LD_LIBRARY_PATH=<P>/lib and the moar, nqp
            (zig-hash-strategies 41e7210ba) and rakudo (zig-build-spec 042608fb82) of /tmp/claude-1000/tune-zig-prefix
CPU:        AMD Ryzen 9 5900X (24 threads), 32 GB, no swap
Memory:     every build under systemd-run --user --scope -q -p MemoryMax=8G
Exports:    nm -D --defined-only libmoar.so: 2850 names in every -base prefix (2852 at -Dgc-debug=1), Zig hash engine
Raw:        ngc-prefixes-raw/ (build9.sh, builds.tsv, builds.log, backendconfig dumps and diff, gc-symbol-sizes.tsv)
```

## Configurations

| prefix | collector | hash engine | options |
|---|---|---|---|
| ng-c-oracle | C | Zig | -Dzig-gc=false -Dgc-debug=1 |
| ng-c-base | C | Zig | -Dzig-gc=false |
| ng-c-stress | C | Zig | -Dzig-gc=false -Dgc-debug=1 -Dnursery-size=524288 |
| ng-f-oracle | Zig (faithful port) | Zig | -Dgc-debug=1 |
| ng-f-base | Zig (faithful port) | Zig | defaults |
| ng-f-stress | Zig (faithful port) | Zig | -Dgc-debug=1 -Dnursery-size=524288 |
| ng-n-oracle | Zig (native head; identical to ng-f-oracle now) | Zig | -Dgc-debug=1 |
| ng-n-base | Zig (native head; identical to ng-f-base now) | Zig | defaults |
| ng-n-stress | Zig (native head; identical to ng-f-stress now) | Zig | -Dgc-debug=1 -Dnursery-size=524288 |

Defaults: LTO, ReleaseFast, x86-64-v3, -Dzig-impl=true, -Dzig-gc=true, nursery 16 MiB. Each build: 1-minute load
< 2.0 (polled every 60 s), `rm -f src/gen/config.{h,c,o}`, `zig build install --prefix /tmp/claude-1000/<name>
<options>` from the checkout at f0582f365. The ng-n-* prefixes are separate builds, not copies (the install path is
baked into libmoar's config strings). The C side comes from the tree through -Dzig-gc=false; no scratch copy.

## Builds

| prefix | exit | seconds | load before | moar --version |
|---|---:|---:|---:|---|
| ng-c-oracle | 0 | 73 | 1.02 | This is MoarVM version 2026.09-270-gf0582f365 built with JIT support |
| ng-c-base | 0 | 46 | 1.31 | (the same) |
| ng-c-stress | 0 | 47 | 0.90 (after one 60 s wait at 2.19) | (the same) |
| ng-f-oracle | 0 | 40 | 1.24 | (the same) |
| ng-f-base | 0 | 37 | 1.12 | (the same) |
| ng-f-stress | 0 | 40 | 1.07 | (the same) |
| ng-n-oracle | 0 | 37 | 1.09 | (the same) |
| ng-n-base | 0 | 35 | 1.04 | (the same) |
| ng-n-stress | 0 | 38 | 1.02 | (the same) |

Every version line is 68 characters, as are g7-*'s (2026.09-257-gb1bbb9dd4). Prefix names are equal length within
each comparison (ng-c-oracle/ng-f-oracle/ng-n-oracle 11, -base 9, -stress 11; ng-c-base and g7-c-base 9). Smoke:
`moar --libpath=<nqp lib> <nqp lib>/nqp.moarvm -e 'say(6*7)'` with LD_LIBRARY_PATH=<P>/lib prints 42 for all nine.

## Configuration proof: ng-c-base against /tmp/claude-1000/g7-c-base (Campaign 5's scratch-copy control)

| check | result |
|---|---|
| `nm -D --defined-only` names, sorted | 2850 and 2850; `cmp` of the sorted lists empty |
| `nqp::backendconfig` keys that differ | bindir ldflags ldrpath libdir mastdir prefix version versionpatch: paths and version only, every pair of equal length (backendconfig-diff.txt) |
| ng-f-base, ng-n-base names against ng-c-base | identical (2850) |

| `nm -D -S` size | g7-c-base | ng-c-base | ng-f-base | ng-n-base |
|---|---:|---:|---:|---:|
| MVM_gc_collect | 1627 | 1627 | 1441 | 1441 |
| MVM_gc_enter_from_allocator | 1184 | 1184 | 1204 | 1204 |
| MVM_gc_root_add_permanent_desc | 415 | 415 | 435 | 435 |

The sizes show the C collector in ng-c-base (equal to g7-c-base, Campaign 5's C17) and the Zig collector in ng-f-base
(equal to Campaign 5's g7-z-base: 1441 / 1204 / 435). The backendconfig dump format matches
z017-prefixes-raw/backendconfig-g7-c-base.txt (the re-dumped g7-c-base equals that file with the path renamed).
