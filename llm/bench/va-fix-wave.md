# va fix wave: the library re-verified at 584d21d02 (unit tests, base prefixes, differential); exit 3, the same 390 lines, every output equal to Task 8's

```
va fix-wave record (after the final whole-branch review, 2026-11-17)
MoarVM:        zig-vmarray; library commit 584d21d02 ("VMArray: the final review's fix wave; wrap where the C's
               size_t wraps"), the only commit after 472cf7e92 that changes anything compiled into libmoar
Prefixes:      va-c-base (-Dzig-reprs=false) and va-n-base (defaults) rebuilt at 584d21d02; the other four
               (va-{c,n}-{oracle,stress}) untouched, still at 472cf7e92
Toolchain:     Zig 0.17.1; every build under systemd-run --user --scope -q -p MemoryMax=8G, after
               rm -f src/gen/config.{h,c,o} and a 1-minute load below 2.0 (polled every 60 s)
Raw:           va-fix-wave-raw/c1/ (unit-test logs, the '%' probe), c2/ (build rows, waits, export lists, sizes),
               c3/ (diff.sh's stderr, when, libmoar.log, load.log, undefined-*/model-* files, outputs.sha256),
               exports-va-{c,n}-base-472cf7e92.txt and before-rebuild.txt (the lists and sizes of the
               prefixes as Task 8 left them, taken before they were removed)
```

**Not re-taken.** The collector oracle (`va-oracle.md`), the stress prefixes'
runs (`va-cleanup.md` `--stress`, the stress crc-getter), the spectest
(`va-spectest.txt`), the crc-getter A/B (`va-crc-ab.md`), the suites
(`va-suites.md`) and the heap-snapshot runs were **not** run again: that
evidence stands at 472cf7e92, a library that differs from 584d21d02 by the
changes listed below. What was re-taken is C1-C3.

## What changed in the library since 472cf7e92

`git diff --stat 472cf7e92 584d21d02` outside traces and docs: six library
files and three test files. The commits between (bea13d101, 03e704609,
f24d7f997, 5f8cfedd4) touch only tests, docs and records. In 584d21d02:

- `storage.zig`: five products from plain `*` to wrapping `*%`, where the C's
  `size_t` arithmetic wraps or where the Zig computes a length the C never
  computes: `copyTo`'s `ssize * elem_size` and `start * elem_size`
  (VMArray.c:55-56), `grow`'s `ssize * elem_size` (466-467), `grow`'s old
  length `old_ssize * elem_size` and `free`'s `ssize * elem_size` (lengths
  handed to the allocator, which ignores them; the C's realloc and free take
  none). No path the differential drives reaches a wrap; at ReleaseFast a
  plain `*` that overflowed was undefined behaviour, `*%` is defined.
- `kinds.zig`: the kind table as named-field rows (`entry(.{ .kind = ...,
  ... })`, a `Row` struct) instead of seven positional arguments, the same
  twelve entries and the same comptime checks; `dispatch` refuses an
  `Otherwise.throw` message containing `%` at compile time; the "out of
  value order" error names the dense-prefix rule; the module doc lists the
  steps of adding a kind. Nothing here emits code differently: the table is
  comptime-only and its values are the same (the repr-test kind-table test
  and every differential output below agree).
- `repr.zig`: `declError` returns a message for an `R` that is not a struct
  type; doc corrections; long lines wrapped. Comptime only.
- `elements.zig`, `serial.zig`, `VMArray.zig`: comments only.

## C1. Unit tests and formatting

| command (after `rm -f src/gen/config.*`, under MemoryMax=8G) | when, load | result |
|---|---|---|
| `zig fmt --check src/zig build.zig build/zig tools/zig` | 2026-11-17 16:35 | clean |
| `zig build unit-test --summary all` | 16:36:15, 0.03 | 93/93 steps, 230/242 tests passed, 12 skipped; repr-test 54/54 |
| `zig build unit-test --summary all -Dzig-reprs=false` | 16:38:32, 1.65 | 93/93 steps, 230/242 passed, 12 skipped; repr-test 54/54 |
| `zig build unit-test --summary all -Dgc-debug=1` | 16:40:34, 1.77 | 93/93 steps, 235/242 passed, 7 skipped; repr-test 54/54 |

Task 8 had 227/239 (repr-test 51); the three new tests are the declError
branches, the null `name`/`ID` messages and the twin-array test (the
library's array and `E` driven through the same steps; with
`-Dzig-reprs=false` that is the C array against the Zig one: `elems`,
`start`, `ssize` and the live bytes equal after each of 13 steps, for all
twelve kinds). The skips are hash-str-test's 7 and gc-test's 5 (gc-test's
run under `-Dgc-debug=1`), as before.

The `%` check, by hand (16:43, load 1.77): with the message of
`storage.zig`'s `zeroSlots` changed to `"MVMArray: Unhandled slot type 100%"`,
`zig build unit-test` stops with `kinds.zig:441:21: error: dispatch: the
Otherwise.throw message "MVMArray: Unhandled slot type 100%" contains '%',
but it is passed as a printf format with no arguments; ...`
(`c1/a2-percent-probe.txt`); the file was restored (`cmp` against a copy
taken before: equal).

## C2. The two base prefixes, rebuilt

`sh traces/llm/bench/va-prefixes-raw/build.sh "va-c-base -Dzig-reprs=false" "va-n-base"`,
after `rm -rf` of the two old directories (their libmoar.so kept outside the
prefixes for the comparison below):

| prefix | built (completion) | time | load before | `moar --version` |
|---|---|---|---|---|
| va-c-base | 2026-11-17 16:44:44 CET | 47 s | 1.37 | This is MoarVM version 2026.09-332-g584d21d02 built with JIT support |
| va-n-base | 2026-11-17 16:46:23 CET | 39 s | 1.56 (after waits at 2.73, 2.01) | the same |

- Exports (`nm -D --defined-only | awk '{print $3}' | sort`): 2,850 names on
  each; c = n (`cmp` silent); each equal to its own 472cf7e92 list and to
  `va-prefixes-raw/exports-base.txt`.
- `.text` 2,380,325 bytes (c) and 2,372,325 (n), file 11,335,760 and
  11,328,016 bytes: the same as at 472cf7e92 to the byte. The `.text`
  sections (`objcopy --only-section=.text`) differ from the 472cf7e92 ones in
  10 bytes (c) and 9 bytes (n): on each side four single bytes and two short
  runs (3 and 3 bytes on c, 2 and 3 on n), the same shape on both; the C-array build compiles none of the
  changed source, so the shape is what a new commit alone gives. Not
  disassembled; nothing here shows a code change from the fix wave, and
  nothing more is claimed.

## C3. The differential on the rebuilt prefixes

`tools/bench/repr/diff.sh --base=/tmp/claude-1000/va-c-base --head=/tmp/claude-1000/va-n-base --out=/tmp/claude-1000/va/t9/diff`:
2026-11-17 16:47:02 CET, 311 s, 52 runs at 1-minute load 1.43-1.99 (each
waited for < 2.0). **Exit 3**: "differs only in undefined self-splice lines,
and equals memmove there (390 differing lines over the programs and
settings, all listed in tools/bench/repr/undefined-lines.txt; 390 of them
equal to memmove-model.py's memmove result, 0 accepted without a model
check ...; everything else and the cross-read identical)".

Against Task 8's final run (`va-differential-final-raw/`):

- every one of the 52 output files has the SHA-256 Task 8 recorded
  (`diff` of the two `outputs.sha256`: silent);
- the eight `undefined-*.txt` and `model-*.txt` files are byte-identical
  to Task 8's, so the 390 lines and their verdicts are the same;
- `libmoar.log` is identical (each side mapped the libmoar.so under its own
  prefix); every `.err` file is empty.

So the fix wave's library behaves as 472cf7e92's on everything the
differential prints.
