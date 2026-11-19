# cfix area T: a rejected pop or unshift changes the array (T1, T2) (Task 3)

(Revised at Task 3's fix round 1, section 6: the PR text's first paragraph no longer says "before
anything is touched", and it claims consistency only with shift. Branch and commits unchanged.)

```
Branch:    vmarray-stale-slots, from origin/main f112c3998, in P (local only, not pushed)
Commits:   27ebea0b8f7f421b4bc53b630fbc614c67959126 "Check the register kind before dropping the element in VMArray pop" (T1)
           fd53df2e04387d79830c4dfad405ded65c557a9b "Check the register kind before moving start in VMArray unshift" (T2)
Diff:      src/6model/reprs/VMArray.c, +18 -15, three hunks: pop (2), unshift (1)
Prefixes:  /tmp/claude-1000/cfix-T (defaults: gcc -O3, mimalloc), /tmp/claude-1000/cfix-T-asan
           (--asan --no-mimalloc), built from `git archive vmarray-stale-slots` copies
           /tmp/claude-1000/cfix-src-T{,-asan} (cfix-T-raw/build/export-build.sh, unchanged from Task 2's);
           the built VMArray.c is byte-identical to the branch's
nqp/rakudo: Task 1's builds (nqp 305ff2f77, rakudo c6d6fc3c6b in cfix-base and /tmp/claude-1000/cfix-ws),
           only the libmoar swapped through LD_LIBRARY_PATH
Raw:       cfix-T-raw/repro/ (run-all on both prefixes, plus the new program on cfix-base and cfix-asan),
           cfix-T-raw/cmp.txt (comparison), cfix-T-raw/pr-repro/ (the PR text's program and its outputs on
           cfix-base, cfix-asan, cfix-T, cfix-T-asan), cfix-T-raw/suites/, cfix-T-raw/build/
T3:        area S (vmarray-self-splice-memmove); asplice not touched here
```

## 1. The fix

**T1, pop** (VMArray.c:648-725). `body->elems--` (658) went before the switch whose arms check the
register kind and throw. It now comes after the switch, just before `zero_slots(slot, slot + 1)`:

```c
    }
    /* only once the register kind has been checked, so that a rejected
     * pop leaves the array as it was */
    body->elems--;
    zero_slots(tc, body, slot, slot + 1, repr_data->slot_type);
```

Checked against the C: `slot` is computed at the top from `start + elems - 1` before anything changes,
and nothing in the switch reads `elems`, so the read is the same slot as before. The empty-array check
(653) is unchanged. Caller-visible paths: a kind that matches reads, decrements, zeroes (as before); a
kind that does not match throws with elems, start and the slots unchanged (before: elems one less and
the slot not zeroed); the default arm (a kind without storage, reachable only after recomposing a live
array's type) throws "Unhandled slot type" and now also keeps elems (before: elems one less). That last
one is a behaviour change the bug report did not mention: same direction, no other effect.

**T2, unshift** (727-824). `body->start--` (757) went before the switch. Now the switch stores at
`body->start - 1` (12 index expressions changed, one per arm) and `body->start--` is moved after the
switch, together with the existing `body->elems++`. Checked: when the switch is reached, `start >= 1`
always holds (either it was, or the front-room block just set it to `n >= 8`), so `start - 1` is the
same slot the old code wrote after its decrement, and no index can wrap. `MVM_ASSIGN_REF` still gets the
same slot and the root for the barrier. Caller-visible paths:
- matching kind: same slot written, then start and elems updated: identical to before;
- wrong kind: throws with start, elems and the slots unchanged (before: start one less, so element 0 was
  the slot in front and the last element dropped out of the window);
- default arm (a kind without storage): the same, start now kept.

**Where the check is relative to making front room.** The ruling asked for the check before making
room at the front "if that is where the check can go without changing anything else". It cannot: the
kind check is the same switch that does the store, and moving it in front of the room-making block
would mean a second switch (or a separate kind table). So when start is 0 the room is still made first,
as before: set_size_internal grows the storage, the elements are moved up by n, start is set to n and
the front n slots zeroed. A rejected unshift then leaves the same elements and elems, at a larger start
and ssize. That is not visible through any op (the fixed-start case of `T-rejected-leaves-array.nqp`
shows the elements and elems unchanged), and it is what every successful unshift at start 0 also does.

Defined behaviour: a rejected pop or unshift leaves the array unchanged, as a rejected shift already
does (shift's switch reads before it moves start and decrements elems after it, 826-902). No new message.
That is the only consistency claimed: a rejected push or bind_pos still grows the array first (by a
zeroed slot, not a stale pointer; `va-differential.md` section 4, cfix-baseline.md section 5), which is
not in this area's scope and not changed.

Hunks: pop 655-661 and 719-727, unshift 755-827. Area S's hunks are in copy_elements and asplice, B's in
write_buf/read_buf, G's in set_size_internal: no overlap. `git merge-tree` of this branch with
vmarray-self-splice-memmove, vmarray-size-overflow and vmarray-splice-guards: all clean.

Two commits: pop and unshift are two places, each with its own defect.

## 2. Reproducers, before and after

| program | cfix-base / cfix-asan (before) | cfix-T / cfix-T-asan (after) |
|---|---|---|
| `T1-rejected-pop.nqp` | `elems now: 1`, grown back to 2, SIGSEGV using element 1 (ASAN: SEGV in MVM_interp_run) | `pop_i: DIED MVMArray: pop expected object register`, `elems now: 2`, `grown back: elems 2`, `element 1: VMArray, elems 3, first "second"`, exit 0, both builds, no ASAN report |
| `T1-rejected-pop.nqp control` | `element 1: null`, exit 0 | identical |
| `T2-rejected-unshift.nqp` | `elems 2, element 1 is "b"`, SIGSEGV using element 0 | `unshift_i: DIED ...`, `elems 2, element 1 is "c"`, `element 0: VMArray, first "b"`, exit 0, both builds |
| `T2-rejected-unshift.nqp control` | `element 1 is "c"`, `element 0: VMArray, first "b"` | identical |
| `T-rejected-leaves-array.nqp` (new) | see below | every "after" line equal to its "before" line (17 cases), plain and ASAN identical |

`T-rejected-leaves-array.nqp` (new, cfix-repro/): 17 cases, each prints elems and every element before
and after a rejected op and after one valid op of the same kind. pop with pop_i/pop_n/pop_s on an
object array (one after a shift), pop and pop_s on an int array, pop_i on str and num arrays, pop_n on a
uint8 array; a rejected shift_i as the reference; unshift_i on an object array at start 0 (front-room
path) and after a shift, unshift_s on an object array, unshift (object) on an int array at start 0,
unshift_s on an int array, unshift_i on str and num arrays, unshift_n on a uint8 array (all after a
shift). Shifted-off elements are kept alive by the program, so nothing depends on the collector.
- Before (cfix-base and cfix-asan identical): every pop case loses its last element (`before: elems 4:
  a b c d` → `after: elems 3: a b c`); the shift reference is unchanged; every unshift case moves the
  window: after a shift `b c d` → `a b c` (the shifted-off element is back, `d` gone), at start 0
  `a b c d` → `null a b c` (object) and `1 2 3 4` → `0 1 2 3` (int), and the valid op then works on
  the moved window (`z null a b c`).
- After (cfix-T and cfix-T-asan identical): all 17 "after" lines equal their "before" lines (checked by
  a script comparing the two lines per case: 0 differences), and the valid ops give `a b c`, `z a b c d`,
  `9 2 3 4` and so on.

## 3. Every other reproducer: unchanged

`run-all.sh -p cfix-T -o cfix-T-raw/repro` and `-p cfix-T-asan` (44 program/case pairs each, 88
outputs; run-all now also runs the four programs added in this task). `cfix-T-raw/cmp-repro.sh`
compares each with the unmodified builds' output of the same program, after the normalisation of
cfix-G-raw/cmp-repro.sh (upstream outputs: cfix-baseline-raw/repro/, cfix-S-raw/round1/ for the two
programs Task 2 added, and the cfix-base/cfix-asan runs of this task's new programs in
cfix-P-raw/repro/ and cfix-T-raw/repro/). Result: 81 same, 7 differ (at fix round 1, with the shaped-array program added, `cfix-T-raw/cmp.txt` has 94 outputs: 87 same, the same 7 differ):
- the expected flips: `T1-rejected-pop.nqp` and `T2-rejected-unshift.nqp` (plain and ASAN), and
  `T-rejected-leaves-array.nqp` (plain and ASAN);
- `B1-read-buf-past-storage.raku` plain: `past1: 1`, `past4: 16844807` against the baseline's 40 /
  1713899527. That program prints bytes read past a block (the B1 bug) and varies on cfix-base too
  (cfix-S-raw/base-rerun/). Noise.
The controls (T1 and T2 `control`) are among the same.

## 4. Suites

`cfix-maketest-driver.sh cfix-T-raw/suites cfix-T` (probes map `/tmp/claude-1000/cfix-T/lib/libmoar.so`):

| project | exit | Files / Tests | Result | per-file list vs cfix-base |
|---|---:|---|---|---|
| nqp 305ff2f77 | 0 | 150 / 13746 | PASS (19 s, load 1.66) | identical (`diff` empty) |
| rakudo c6d6fc3c6b | 0 | 599 / 11162 | PASS (128 s, load 1.81) | identical (`diff` empty) |

## 5. Draft PR text

Title: **Leave a VMArray unchanged when pop or unshift is given the wrong register kind**

Body:

> A pop or an unshift with a register of the wrong kind (for example `nqp::pop_i` on an object array)
> throws "pop expected object register" or "unshift expected object register", but by then the array
> had already been changed. This change makes both leave the array as it was, as a rejected shift
> already does: the register kind is now checked before the array's elements or size change. No
> message changes.
>
> In pop, `elems` was decremented before the switch that checks the kind, and the throw came before
> the slot was cleared. The array lost its last element, while the slot still held the object pointer.
> The collector marks only the first `elems` slots, so that object could be freed or moved without the
> slot being updated, and growing the array back within its storage (no zeroing then) made the stale
> pointer an element again. In unshift, `start` was moved back by one before the check, and `elems++`
> never ran: the array's window moved one slot to the left. Element 0 became whatever was in front:
> after a shift, the shifted-off element, which the collector no longer marks. The last element
> dropped out.
>
> A program that shows both, deterministically, on a stock nqp:
>
> ```
> my $a := nqp::list('a', 'b', 'c');
> try { nqp::pop_i($a); CATCH { say('pop_i: ' ~ nqp::getmessage($!)) } }
> say('after: elems ' ~ nqp::elems($a) ~ ': ' ~ nqp::join(' ', $a));
> my $b := nqp::list('a', 'b', 'c', 'd');
> my $shifted := nqp::shift($b);
> try { nqp::unshift_i($b, 7); CATCH { say('unshift_i: ' ~ nqp::getmessage($!)) } }
> say('after: elems ' ~ nqp::elems($b) ~ ': ' ~ nqp::join(' ', $b));
> ```
>
> Before:
>
> ```
> pop_i: MVMArray: pop expected object register
> after: elems 2: a b
> unshift_i: MVMArray: unshift expected object register
> after: elems 3: a b c
> ```
>
> After:
>
> ```
> pop_i: MVMArray: pop expected object register
> after: elems 3: a b c
> unshift_i: MVMArray: unshift expected object register
> after: elems 3: b c d
> ```
>
> The same with AddressSanitizer, before and after. Here the shifted-off "a" is still referenced by
> the program. When it is not, and collections run in between, the stale slot is a dangling pointer.
> Programs that do that (drop the reference, force two collections with some allocation in between,
> then use the element) crash with SIGSEGV before this change and print the right elements after it.
> That holds for pop (after growing the array back) and for unshift.
>
> In pop, the decrement now comes after the switch. In unshift, the value is stored at `start - 1`, and
> `start` is moved after the switch, together with `elems++`. The default arm (a kind without storage,
> "Unhandled slot type") now also leaves the array as it was. When there is no room at the front,
> unshift still makes room before the check, as before. That can grow the storage and moves the
> elements up, but the array holds the same elements. Moving the check in front of it would need a
> second switch.
>
> `make test` of nqp and Rakudo gives the same per-file results as before.
>
> Found while porting the VMArray REPR to Zig.
>
> 🤖 Generated with [Claude Code](https://claude.com/claude-code)

## 6. Fix round 1

- The PR text's first paragraph said "the register kind is checked before anything is touched". That
  contradicted the later paragraph saying unshift still makes front room first. It now reads
  "checked before the array's elements or size change".
- The only consistency claimed, in the PR text and in section 1, is "as a rejected shift already
  does". Section 1 now also says that a rejected push or bind_pos still grows the array by a zeroed
  slot. That is out of scope and unchanged.
- I checked both commit bodies for the same over-statement. T1's says a rejected pop "leaves the
  array as it was", and pop makes no room, so that is exact. T2's says a rejected unshift "leaves the
  elements and elems as they were", and it describes the front room explicitly. Neither needed a
  change, so branch `vmarray-stale-slots` is unchanged: 27ebea0b8f7f421b4bc53b630fbc614c67959126 and
  fd53df2e04387d79830c4dfad405ded65c557a9b, with the same trees.
- run-all now also runs `P1-splice-shaped-raku.raku`. It was run on cfix-T and cfix-T-asan, and is the
  same as upstream (SIGSEGV), which raises section 3's counts to 94 outputs: 87 same, and the same 7
  differing.
