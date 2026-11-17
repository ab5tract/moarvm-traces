# va prefixes: the builds of the VMArray REPR campaign

```
Toolchain:  Zig 0.17.1 (/usr/bin/zig)
Memory:     every build under systemd-run --user --scope -q -p MemoryMax=8G
Hygiene:    rm -f src/gen/config.h src/gen/config.c src/gen/config.o before every zig build; 1-minute load under 2.0
            (polled every 60 s); pgrep -a -x raku / moar empty before each long run
State:      /tmp/claude-1000 held no prefix (a reboot removed them); everything below is new
MoarVM:     branch zig-vmarray at 6b45869d9 ("Add the -Dzig-reprs switch and the [zig-reprs] section"),
            one commit on zig-hash-engine 0a13b95be; the [zig-reprs] section is empty
nqp:        branch zig-hash-strategies at 41e7210ba
rakudo:     branch zig-build-spec at 042608fb82; roast (t/spec) at fb1d87214, as pinned, nothing to check out
```

## The runner prefix

| step | when | command | duration | 1-min load before | result |
|---|---|---|---|---|---|
| moar | 2026-11-16 10:45:38 CET | `zig build install --prefix /tmp/claude-1000/tune-zig-prefix` in MoarVM | 46 s | 1.92 | exit 0; `moar --version`: "This is MoarVM version 2026.09-311-g6b45869d9 built with JIT support" |
| nqp | 2026-11-16 10:47:28 CET | `make install` in nqp (configured against the prefix; config.status untouched) | 17 s | 1.60 (after one 60 s wait at 2.28) | exit 0; the stages were up to date, so this installed; `nqp -e 'say(42)'` prints 42 |
| rakudo, check | 10:47 | `./rakudo-m -e 'say 42'` | | | failed: "Missing or wrong version of dependency 'gen/moar/stage2/NQPHLL.nqp' (from 'gen/moar/Pod.nqp')", so the build below |
| rakudo | 2026-11-16 10:47:53 CET | `make` in rakudo | 219 s | 1.77 | exit 0; `./rakudo-m -e 'say 42'` prints 42 |
| rakudo | 2026-11-16 10:51:43 CET | `make install` in rakudo | 15 s | 0.96 | exit 0; `/tmp/claude-1000/tune-zig-prefix/bin/raku` runs |

## The control prefixes (C array)

Built by `va-prefixes-raw/build.sh` (the script of `ngc-prefixes-raw/build9.sh` with this campaign's list), one at a time; its record is `va-prefixes-raw/builds.tsv`, the load waits `va-prefixes-raw/builds.log`. The times in this table and in the scratch build below are completion times (the script stamps a row when the build ends); those in the runner table are start times.

| prefix | built | from | options | 1-min load before | notes |
|---|---|---|---|---|---|
| va-c-oracle | 2026-11-16 10:52:50 CET, 49 s | zig-vmarray at 6b45869d9 | `zig build install --prefix /tmp/claude-1000/va-c-oracle -Dzig-reprs=false -Dgc-debug=1` | 1.17 | `moar --version`: "This is MoarVM version 2026.09-311-g6b45869d9 built with JIT support". `nm -D --defined-only`: 2852 names (the 2850 of -base plus `MVM_gc_debug_find_region` and `MVM_gc_debug_log_collection`, as every gc-debug build has had). Oracle self-check below. |
| va-c-base | 2026-11-16 10:53:29 CET, 39 s | zig-vmarray at 6b45869d9 | `zig build install --prefix /tmp/claude-1000/va-c-base -Dzig-reprs=false` | 1.85 | Same version string. `nm -D --defined-only`: 2850 names (`va-prefixes-raw/exports-base.txt`); tune-zig-prefix has the same list. `.text` 2,380,325 bytes, file 11,335,760 bytes. |
| va-c-stress | 2026-11-16 10:55:17 CET, 48 s | zig-vmarray at 6b45869d9 | `zig build install --prefix /tmp/claude-1000/va-c-stress -Dzig-reprs=false -Dgc-debug=1 -Dnursery-size=524288` | 1.08 (after one 60 s wait at 2.10) | Same version string. 2852 names, the same list as va-c-oracle. |

## `-Dzig-reprs=true` against `-Dzig-reprs=false` with the section empty

A scratch prefix `va-x-base` (`build.sh "va-x-base"`: the default options, so `-Dzig-reprs=true`; 2026-11-16 10:56:53 CET, 36 s, load 1.56 after one 60 s wait at 2.41), compared with va-c-base and then removed.

- `cmp /tmp/claude-1000/va-c-base/lib/libmoar.so /tmp/claude-1000/va-x-base/lib/libmoar.so`: not byte-identical. `cmp -l` lists five differing bytes (offsets 2421708, 2466556, 2499841, 2607675, 3974912), each `c` in one file and `x` in the other: the five places the install path is baked into the library (`strings -a` finds "va-c-base" five times in one and "va-x-base" five times in the other). Nothing else differs; the files have the same size (11,335,760 bytes).
- So by the fallback of the plan: export lists equal (2850 names each, `cmp` of the sorted lists silent) and `.text` sizes equal (2,380,325 bytes each).

The switch changes nothing in the library while the section is empty.

## Sanity

- Oracle self-check, 2026-11-16 10:57:19 CET, load 1.57: `tools/bench/gc/oracle.sh --base=/tmp/claude-1000/va-c-oracle --head=/tmp/claude-1000/va-c-oracle --volume=10000 --out=<workspace>/oracle-self` exits 0, "identical (tier 1, 55 lines)", three runs a side, 36 s (`va-prefixes-raw/oracle-self.log`). The rebuilt toolchain repeats.
- Export count at the base: 2850.
- Unit tests on the tree that became 6b45869d9, before the builds, load 1.02: `zig build unit-test --summary all`, 91/91 steps, 194/206 tests passed, 12 skipped (the skips are hash-str-test's 7 and gc-test's 5, as before); `build/zig/sources.zig` 13 pass, `build/zig/options.zig` 3 pass (`va-prefixes-raw/zig-build-unit-test.log`).
- `zig build -Dzig-gc=false -Dzig-reprs=true` and `zig build -Dzig-impl=false -Dzig-reprs=true` both stop with "-Dzig-reprs needs -Dzig-impl=true and -Dzig-gc=true (the Zig REPRs call the Zig collector)".

## Task 8: all six campaign prefixes at one commit

Rebuilt together so that every comparison of Task 8 is same-commit (Task 7
had left va-c-oracle and va-c-stress at 6b45869d9, and there was no
va-n-oracle or va-n-stress). The six old directories were removed first.
Commit: zig-vmarray at **472cf7e92** ("repr.Ops: a slot may be declared
null; two test-hygiene fixes"), the last commit of this campaign that
changes anything compiled into libmoar; later Task 8 commits touch only
tests (`src/zig/6model/test/`, compiled into the `repr-test` root only),
records and drivers.

Command: `sh traces/llm/bench/va-prefixes-raw/build.sh "va-c-oracle -Dzig-reprs=false -Dgc-debug=1" "va-n-oracle -Dgc-debug=1" "va-c-base -Dzig-reprs=false" "va-n-base" "va-c-stress -Dzig-reprs=false -Dgc-debug=1 -Dnursery-size=524288" "va-n-stress -Dgc-debug=1 -Dnursery-size=524288"`
(each build after `rm -f src/gen/config.*` and a 1-minute load below 2.0,
polled every 60 s, under MemoryMax=8G). Raw: `va-prefixes-raw/t8/`
(`builds.tsv`, the waits in `builds.log`, `exports-gc-debug.txt`).

| prefix | built (completion) | time | load before | options | exports | `.text` bytes | file bytes |
|---|---|---|---|---|---|---:|---:|
| va-c-oracle | 2026-11-17 13:15:02 CET | 49 s | 1.62 (after a wait at 2.04) | `-Dzig-reprs=false -Dgc-debug=1` | 2,852 | 2,460,309 | 11,418,512 |
| va-n-oracle | 2026-11-17 13:16:43 CET | 41 s | 1.50 (after a wait at 2.13) | `-Dgc-debug=1` | 2,852 | 2,452,453 | 11,410,832 |
| va-c-base | 2026-11-17 13:17:30 CET | 47 s | 1.72 | `-Dzig-reprs=false` | 2,850 | 2,380,325 | 11,335,760 |
| va-n-base | 2026-11-17 13:19:10 CET | 40 s | 1.87 (after a wait at 2.73) | (defaults) | 2,850 | 2,372,325 | 11,328,016 |
| va-c-stress | 2026-11-17 13:20:59 CET | 49 s | 1.40 (after a wait at 2.09) | `-Dzig-reprs=false -Dgc-debug=1 -Dnursery-size=524288` | 2,852 | 2,460,309 | 11,418,512 |
| va-n-stress | 2026-11-17 13:21:40 CET | 41 s | 1.88 | `-Dgc-debug=1 -Dnursery-size=524288` | 2,852 | 2,452,453 | 11,410,832 |

- `moar --version` on all six: "This is MoarVM version 2026.09-327-g472cf7e92 built with JIT support".
- Exports (`nm -D --defined-only <P>/lib/libmoar.so | awk '{print $3}' | sort`):
  c and n equal in each pair (`cmp` silent); the two base lists equal
  `exports-base.txt` (2,850); the four gc-debug lists equal each other
  (2,852: the base list plus `MVM_gc_debug_find_region` and
  `MVM_gc_debug_log_collection`).
- The Zig array's library is 8,000 bytes (`.text`) smaller at the default
  options and 7,856 bytes smaller with `-Dgc-debug=1`, as at Task 7.
- During these builds a `cpptools` process (an editor's C/C++ language
  server, not this campaign's) held one core at 100 %; it stayed through the
  evidence runs below, so the 1-minute load sat near 1 at rest. Not killed
  (not ours).

Scratch, not campaign prefixes: `va-c-syms` (Task 2's coverage build at
ea8c48954, untouched), `va-n-syms` (Task 8's unstripped Zig build for the
breakpoint check, `va-suites.md` section 5; built 2026-11-17 15:31:07 CET at bea13d101, `-Dstrip=false`).
