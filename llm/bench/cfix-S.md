# cfix area S: splicing a VMArray into itself (S1, T3) (Task 2)

(Revised at Task 2's fix round 1: the defined result is the clone result, T3's count > elems
direction added, commits recreated with corrected messages and one comment changed; section 7.)

```
Branch:    vmarray-self-splice-memmove, from origin/main f112c3998, in P (local only, not pushed)
Commits:   b2cbdc57c49d4586a17ae05169cdb344a315b4f6 "Use memmove for a VMArray splice of an array into itself"
           6ee35f98a84ee5e8cd18c879b7cba79bf8617efd "Copy backwards in a VMArray self-splice that goes element by element"
           5febdef325774ecd6861631b4e8a0a938185a85b "Don't move start in a VMArray splice of an array into itself at offset 0"
           (fix round 1; before: 0593a9574, f1cd6bad9, 90a506f14 — same trees for the first two, the third
           differs from 90a506f14 only in the asplice comment; the prefixes were built from the old
           tips, see section 7)
Diff:      src/6model/reprs/VMArray.c only, +14 -6, three hunks: copy_elements' fast path (memcpy → memmove
           and its comment), copy_elements' element loop (backwards when src == dest and d_offset > s_offset),
           asplice's offset-0 adjustment (`&& from != root` and its comment)
Prefixes:  /tmp/claude-1000/cfix-S (defaults), /tmp/claude-1000/cfix-S-asan (--asan --no-mimalloc), and for the
           differential /tmp/claude-1000/cfix-S-df (defaults; same sources, a prefix as long as "cfix-base",
           which diff.sh requires), all from `git archive vmarray-self-splice-memmove` copies
           /tmp/claude-1000/cfix-src-S{,-asan,-df} (cfix-S-raw/build/export-build.sh)
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b), only the libmoar swapped
Raw:       cfix-S-raw/repro/, cfix-S-raw/base-rerun/ (noise check on cfix-base), cfix-S-raw/pr-repro/
           (the PR text's two reproducers and their outputs on cfix-base, cfix-asan, cfix-S, cfix-S-asan), cfix-S-raw/suites/,
           cfix-S-raw/differential/, cfix-S-raw/build/
```

## 1. The three changes, and why three commits

1. **S1, fast path** (VMArray.c:951): `memcpy` → `memmove`. With `nqp::splice($a, $a, $off, $cnt)`
   asplice ends in `copy_elements($a, $a, 0, $off, elems1)`, and for `0 < $off < elems1` the ranges
   overlap. That is undefined behaviour.
2. **S1, element path** (VMArray.c:956-965): this path serves STR, and OBJ when the target is in gen2.
   When `src == dest && d_offset > s_offset` the loop now runs from the last element down. Otherwise it
   runs forward as before.
3. **T3** (VMArray.c:1065): the offset-0 start adjustment is skipped when `from == root`.

They are three commits because they are three defects: undefined behaviour in a library call, a defined
but kind- and generation-dependent wrong result in a loop, and the offset-0 adjustment moving the source
(re-exposing dead slots, or dropping elements when count > elems) in asplice. Each
can be reviewed and reverted alone. (1) and (2) together give one definition, stated in both bodies.

What the fix defines (ruling of fix round 1): a self-splice gives **the same result as splicing from
`nqp::clone($a)`**, whatever the kind and GC generation. (The first version of this record said the
result was "a copy of the array after the tail move", different from the before-the-splice result; that
was wrong, and so was its example.) Why, from the C, with all three changes in place (E = elems0 =
elems1 for a self-splice):
- No offset-0 adjustment runs (T3's change), so start, elems0 and count are as given.
- The shrinking memmove (`tail > 0 && count > elems1`) cannot run: count > E makes
  `tail = E - offset - count` negative, clamped to 0.
- set_size_internal grows to `offset + E + tail >= E`, so its downsizing clear does not run. Its
  compaction (start > 0, too little room at the end) moves the elements down unchanged. It zeroes only
  slots at E and above.
- The growing tail move writes only at `offset + E` and above.
- So `[0, E)` still holds the array as it was before the splice when the copy starts. The copy reads
  each element before it is overwritten: memmove on the fast path, the backwards loop on the element
  path. That is what the clone gives.

Example: `2,3` on 1 4 7 .. 28 grows the array (count 3 < 10). The tail 16 .. 28 moves right to
positions 12-16, and the copy of the untouched 1 .. 28 lands at 2-11:
`1 4 1 4 7 10 13 16 19 22 25 28 16 19 22 25 28`, the clone result. Checked over 2704 shapes by
`cfix-repro/S1-self-splice-vs-clone.nqp` (section 7).

Checked against the C before writing:
- **(2)** For a self-splice `s_offset` is always 0 and `d_offset = offset >= 0`, so the backwards
  branch is taken exactly when the target lies above the source. Reading backwards from the top is then
  what memmove does for `dst > src`.
- **(2)** Every index is in range. asplice has already resized the array to `offset + elems1 + tail`,
  so `at_pos(s_offset + j)` and `bind_pos(d_offset + j)` stay below elems. Neither allocates or grows
  in that range, so nothing moves under the loop.
- **(2)** `src == dest && d_offset < s_offset` would need a forward copy, and keeps it; no current
  caller produces it.
- **(2)** aslice (the other caller) copies into a different object.
- **(3)** The adjustment is wrong for a self-splice in both directions it moves start, not only T3's.
  For `n > 0` (slots in front of start, from earlier shifts) it re-exposes shifted-off slots. For
  `n < 0` (count > elems1; no shift needed) it moves start forward and drops source elements before
  they are copied. Skipping it whenever `from == root` covers both, and the ordinary path is correct
  for any count. The `n < 0` direction has its own reproducer, `cfix-repro/T3-self-splice-overcount.nqp`
  (section 7): an 8-element OBJ array 1 4 .. 22, `nqp::splice($a, $a, 0, 9)`, gives
  `4 7 10 13 16 19 22 null` on cfix-base and `1 4 7 10 13 16 19 22` on cfix-S. (Also checked by hand
  on a shifted STR array a..f with two shifted off, `nqp::splice($a, $a, 0, 6)`: cfix-base
  `4: e f null null`, cfix-S `4: c d e f`.)
- **(3)** In T3's case (start 2, elems 2, ssize 8), nothing moves in set_size_internal (`n + start =
  6 <= ssize`). The tail memmove copies `c d` to positions 2-3, and the self-copy at offset 0 is the
  identity: `c d c d`.

Flag for the maintainers: the element path's new order is a choice. Before it was a forward copy:
defined, but different from what the fast path gives for the same splice.

## 2. Reproducers, before and after

`cfix-repro/S1-self-splice-overlap.nqp`:

| build | lines that differ from the memmove result | ASAN |
|---|---|---|
| cfix-base | `obj gen2 1,0: 1 1 1 1 1 1 1 1 1 1 1 4 7 ...`, `str 1,0: 1 1 1 1 ...`, `str 2,3: 1 4 1 4 1 4 1 4 1 4 1 4 16 ...`, `str 5,0: 1 4 7 10 13 1 4 7 10 13 1 4 7 10 13 16 ...` (fast-path lines already print the memmove result: glibc 2.44 here binds memcpy and memmove to one address) | cfix-asan: `memcpy-param-overlap` in copy_elements at "obj nursery 1,0", run stops |
| cfix-S / cfix-S-asan | none: every one of the 17 small lines equals the memmove result in the program's header, all 12 "big" lines `same` | cfix-S-asan: no report, exit 0, output identical to cfix-S |

What flipped on the plain build: the three `str` lines and `obj gen2`. The fast path's evidence is the
ASAN report going away.

`cfix-repro/T3-self-splice-shifted.nqp`:

| build | case | control (splice from a clone) |
|---|---|---|
| cfix-base, cfix-asan | `spliced: elems 4`, then SIGSEGV (exit 139) using element 0 (the dead "a") | `elems 4: c d c d` |
| cfix-S, cfix-S-asan | `elems 4: c d c d`, exit 0 | `elems 4: c d c d` (unchanged) |

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-S -o cfix-S-raw/repro` and `-p cfix-S-asan` produced 68 outputs. They were compared
file by file with `cfix-baseline-raw/repro/` by `cfix-S-raw/cmp-repro.sh`, which first removes the
probe/run lines, addresses, PIDs, BuildIds, prefix names, 12+-digit decimals and ASAN's shadow-byte dump.
62 of 68 are identical. The 6 that differ:
- S1 and T3, plain and ASAN (4 files): the flips above.
- Two plain outputs, `B1-read-buf-past-storage.raku` (`past1`/`past4`) and `O1-procasync-buf-type.nqp
  int64` (`element 99`). Both print bytes read past a block, which is their own bug, and they vary
  between runs of unmodified cfix-base (`cfix-S-raw/base-rerun/1..3`): `past1` gave 8, 8, 104
  (baseline file: 40), and `element 99` gave 256, 5310563549536, 2986180870496. Noise, not a change.
  Their ASAN outputs are identical.

## 4. Suites

`cfix-maketest-driver.sh cfix-S-raw/suites cfix-S` (probes map `/tmp/claude-1000/cfix-S/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (18 s, load 1.09) | identical |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (127 s, load 1.20) | identical |

## 5. Differential (campaign 8's tools/bench/repr)

How it was run: the directory was copied from `zig-hash-engine` to a scratch tree laid out as
`<root>/tools/bench/repr/` (diff.sh finds its model and list through `$0/../../..`). It was not modified,
and it was run as

    diff.sh --base=/tmp/claude-1000/cfix-base --head=/tmp/claude-1000/cfix-S-df --out=<fresh dir> \
        --nqp=/tmp/claude-1000/cfix-base/bin/nqp-m --rakudo=/tmp/claude-1000/cfix-base/bin/rakudo-m

- **Runners.** The nqp and rakudo runners are Task 1's upstream builds. Their bytecode is the same for
  both sides, and LD_LIBRARY_PATH picks the libmoar.
- **The head prefix.** `cfix-S-df` is the S branch built a third time, under a prefix as long as
  `cfix-base`, because diff.sh refuses prefixes of unequal length (the install path is baked into
  libmoar).
- **Probes.** The probes found each side's own libmoar (`libmoar.log`).
- **Run and checks.** 3 runs per side, program and setting. Every side was repeatable, no run wrote to
  stderr, and both serialization cross-reads equal their expectations.

**diff.sh exits 1, as it must here.** Its exit 3 path only accepts lines in `undefined-lines.txt`, the
memcpy kinds' self-splices. On this glibc those lines already print the memmove result on cfix-base, so
none of them differs. The lines that do differ are ones the list does not name. Every differing line was
therefore classified and checked by hand (`cfix-S-raw/differential/`):

| program | lines (each setting) | differing | which lines | head value |
|---|---:|---:|---|---|
| serial | 196 | 0 | | identical |
| devirt | 10 | 0 | | identical |
| diff-nqp | 9987 | 54 | 16 `str.selfsplice.*` (element path) | memmove model (`memmove-model.py`): 16/16 |
| | | | 30 `<kind>.selfsplice.shifted.{prepend,prepend20,replace}` for the 10 numeric kinds i64..u8, n64, n32 (T3's path: offset 0 on an array with start > 0) | see below: the fixed model, 30/30 |
| | | | 8 `{obj,str}.gc.{selfsplice,splice,slice,clone}.promoted` (element path, gen2 target; `splice`/`slice`/`clone` print the array after `nqp::splice($old, $old, 5, 0)`, or a slice or clone of it) | `gc-model.py`, a model of `gc_cases()`, simulation checked on the `gc.survive`/`gc.barrier` lines: 8/8 |
| diff-raku | 2475 | 10 | 8 `<int type>.nqp.splice.self.front` (T3's path) | by hand: `shifted(^6)`, `splice($a, $a, 0, 2)` → `0 1 2 3 4 5 2 3 4 5` ✓ (base: `90 91 92 0 1 2 2 3 4 5`, the shifted-off values) |
| | | | 2 `str.splice.self`, `str.splice.self.1` (element path) | by hand, memmove: `a b c a b c d e f d e f`, `a a b c d e f b c d e f` ✓ |

The two settings (spesh, nospesh) give the same set of differing lines with the same values.

**Deviation from the expected outcome.** The brief expected only self-splice lines of the element-by-element
path to differ. The 30 + 8 T3-path lines differ as well. They are the T3 fix showing on the numeric kinds:
- At offset 0 on a shifted array, unmodified upstream re-exposes the shifted-off values. For numeric
  kinds these are stale numbers (90 91 92 ...), not dangling pointers, so they print instead of
  crashing.
- The program prints them, and campaign 8 counted them as defined.

Their value on the S build is the memmove result of the *fixed* asplice. `memmove-model.py` models the
old asplice, start adjustment included, so its expectation for these lines is the old output (base
matches it, head "mismatches" it 30 times: `model-head-nqp-*.txt`). With the adjustment taken out of
the model (`memmove-model-fixed.patch`, one line, for `from == root`, which every case it models is),
the head matches all 46 differing modelled lines and all 342 `<kind>.selfsplice.*` lines of the
program, changed or not (`modelfixed-*.txt`, exit 0).

Everything else is byte-identical: the other 9933 diff-nqp and 2465 diff-raku lines, serial, devirt and
the cross-reads.

## 6. Draft PR text

Title: **Define splicing a VMArray into itself: memmove semantics on every path**

Body:

> `nqp::splice($a, $a, $offset, $count)`, a splice of an array into itself, is handled wrongly in
> three ways. Each commit fixes one of them.
>
> **What the result is now.** After this PR a self-splice gives the same result as splicing from a
> clone of the array, `nqp::splice($a, nqp::clone($a), $offset, $count)`, whatever the element kind
> and whatever GC generation the array is in. Nothing asplice does before the copy touches the
> elements being copied, and the copy now reads every element before overwriting it. The code did
> not promise this before. It is the result the fast path already happened to give on common
> platforms, and the other two paths are brought in line with it.
>
> 1. **Overlapping memcpy.** copy_elements copies with `memcpy` for the numeric kinds, and for OBJ
>    while the array is not in the second generation. For a self-splice at `0 < $offset < elems`
>    source and target overlap: undefined behaviour. AddressSanitizer stops there with
>    `memcpy-param-overlap`. With glibc 2.44 on x86-64, memcpy and memmove resolve to the same code,
>    so a plain build happens to print the memmove result; nothing guarantees that. Now `memmove`.
> 2. **Forward element copy.** For STR arrays, and OBJ arrays in the second generation (which need
>    the write barrier), the copy goes element by element and forward, so it overwrites elements
>    before reading them. The leading elements repeat, and the same splice on the same OBJ array gave
>    different results before and after the array survived a collection. When the source is the
>    target and the target lies above the source, the loop now runs backwards.
> 3. **Shifted-off slots re-exposed.** At offset 0, asplice moves the array's start back over the
>    slots in front of it (left by earlier shifts) and widens the count to match. When the source is
>    the array itself, that moves the source too. The copy then reads the shifted-off slots and makes
>    them elements again. In a numeric array they are old values: `90 91 92 0 1 2 3 4 5` with three
>    shifted off, spliced into itself at 0 replacing 2, gave `90 91 92 0 1 2 2 3 4 5`. In an object or
>    string array they are pointers the collector no longer marks. When `$count` is larger than the
>    array, the same adjustment moves start forward instead and drops elements of the source before
>    they are copied: `nqp::splice($a, $a, 0, 9)` on an 8-element array `1 4 … 22` gave `4 7 … 22`
>    and a null. The adjustment is now skipped for a self-splice.
>
> Reproducer for 1 and 2:
>
> ```
> sub fill($a) { my int $i := 0; while $i < 10 { nqp::push($a, ~($i * 3 + 1)); $i++ } }
> sub show($name, $a) { my @p; for $a { nqp::push(@p, ~$_) }; say("$name: " ~ nqp::join(' ', @p)) }
> my $old := nqp::list(); fill($old);
> nqp::force_gc(); nqp::force_gc();          # promote it to the second generation
> nqp::splice($old, $old, 1, 0); show("obj gen2", $old);
> my $new := nqp::list(); fill($new);
> nqp::splice($new, $new, 1, 0); show("obj nursery", $new);
> my $s := nqp::list_s(); my int $i := 0;
> while $i < 10 { nqp::push_s($s, ~($i * 3 + 1)); $i++ }
> nqp::splice($s, $s, 1, 0); show("str", $s);
> ```
>
> Before:
>
> ```
> obj gen2: 1 1 1 1 1 1 1 1 1 1 1 4 7 10 13 16 19 22 25 28
> obj nursery: 1 1 4 7 10 13 16 19 22 25 28 4 7 10 13 16 19 22 25 28
> str: 1 1 1 1 1 1 1 1 1 1 1 4 7 10 13 16 19 22 25 28
> ```
>
> With AddressSanitizer, the "obj nursery" splice stops with `memcpy-param-overlap` in copy_elements.
> After, on both builds, all three lines are `1 1 4 7 10 13 16 19 22 25 28 4 7 10 13 16 19 22 25 28`.
>
> Reproducer for 3:
>
> ```
> my $a := nqp::list();
> for <a b c d> { nqp::push($a, nqp::list($_)) }
> nqp::shift($a); nqp::shift($a);
> nqp::force_gc();
> my @keep; my int $i := 0;
> while $i < 2000 { nqp::push(@keep, nqp::list('filler', $i)); $i++ }
> nqp::force_gc();
> nqp::splice($a, $a, 0, 0);
> my @p; for $a { nqp::push(@p, nqp::atpos($_, 0)) }
> say(nqp::join(' ', @p));
> ```
>
> Before, the first two elements are the dead "a" and "b", and the program crashes using them
> (SIGSEGV). After, it prints `c d c d`, the same as splicing from `nqp::clone($a)`.
>
> A program that compares `nqp::splice($a, $a, $offset, $count)` with the same splice from
> `nqp::clone($a)`, for object arrays (young and promoted), string and int arrays, with 0 to 3
> elements shifted off, offsets 0 to 12 and counts 0 to 12 on 8 elements (2704 cases), finds 0
> differences after this PR, with and without AddressSanitizer. Before, it finds 135 and then
> crashes on a re-exposed dead object.
>
> `make test` of nqp and Rakudo gives the same per-file results as before. A differential run of a
> larger program, which exercises every array operation over every slot kind, prints the same output
> as before except on self-splice lines. Those are the STR and promoted-OBJ self-splices, and the
> offset-0 self-splices of shifted numeric arrays, which used to return the shifted-off values. Each
> now gives the clone result.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)

## 7. Fix round 1

The review found the C correct and minimal. It found the definition of the result wrong in this
record, in the PR draft and in the commit bodies, and it found T3's description incomplete.

**Clone equivalence.** I checked the reviewer's argument against the C (section 1, rewritten) and
found it holds. The reviewer's program is adopted as `cfix-repro/S1-self-splice-vs-clone.nqp`, with a
header and the program unchanged. It compares a self-splice with the splice from a clone over 2704
shapes: obj in the nursery, obj in gen2, str and int; 0-3 shifted; offset 0-12; count 0-12.
Outputs are in `cfix-S-raw/round1/`:

| build | result |
|---|---|
| cfix-base | 135 DIFF lines (40 obj nursery, 95 obj gen2), then SIGSEGV (exit 139) before the str and int cases |
| cfix-asan | 4 DIFF lines (obj nursery, offset 0, counts 9-12: the count > elems direction of T3), then `memcpy-param-overlap` at offset 1 |
| cfix-S | `cases 2704, differing 0`, exit 0 |
| cfix-S-asan | `cases 2704, differing 0`, exit 0, no report |

**T3's other direction.** New reproducer `cfix-repro/T3-self-splice-overcount.nqp`, with a `control`
mode that splices from a clone. It runs counts 9-12 on an 8-element OBJ array 1 4 .. 22:

| build | case | control |
|---|---|---|
| cfix-base, cfix-asan | `count 9: elems 8: 4 7 10 13 16 19 22 null` … `count 12: elems 8: 13 16 19 22 null null null null` (no ASAN report: the lost slots read as null) | `1 4 7 10 13 16 19 22` for every count |
| cfix-S, cfix-S-asan | `1 4 7 10 13 16 19 22` for every count | the same |

Both programs were added to `run-all.sh`.

**Commits recreated.** I built them with `git commit-tree` and `git checkout -B`; no interactive tools
were used.
- 0593a9574 → b2cbdc57c and f1cd6bad9 → 6ee35f98a: messages only, same trees. The memmove and
  element-path bodies now say the result is the clone result.
- 90a506f14 → 5febdef32: new message, with the count > elems direction and the clone result.
- The asplice comment is now "Not when splicing SELF into itself: moving start would move the
  source too." The old text only fit the backward direction.
- `git diff 90a506f14 5febdef32` is that comment only (2 lines out, 1 in).

**Builds.** The prefixes cfix-S, cfix-S-asan and cfix-S-df were built from the old tips. The only
source difference is the comment, so they were not rebuilt. All the evidence above and in sections
2-5 comes from those builds.

Section 5's differential is unaffected. Its "memmove model" wording means the same values: on every
checked line the head equals the clone result.

**`S1-self-splice-overlap.nqp` header.** One comment line now reads "(memmove semantics; the same as
splicing from nqp::clone($a), since the tail move does not touch the elements being copied)". It used to
say "the array as it stands after the tail has been moved". The program and its outputs are unchanged.
