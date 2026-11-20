# Fixing the open bugs in the port: design

Date: 2026-11-20. Source list: `traces/llm/bench/cfix-open-bugs.md` (ids OB1 to OB20). Port branch:
`zig-hash-engine` at 99f7ce8cd. Upstream reference: `origin/main` f112c3998.

## Intent

The cfix campaign (PRs #2076 to #2086) saw twenty more defects and did not fix them. The owner wants them
fixed in the port now, and the matching C fixes delivered upstream at a later date. The port exists to learn
MoarVM by porting it; a port that carries known bugs teaches the bugs.

## Goals

- Every fixable entry of the list is fixed in the port's tree, on both sides: the C code and, where the Zig
  port owns the same behaviour, the Zig code.
- The port's acceptance gate stays as it is: `tools/bench/repr/diff.sh` between a build with C REPRs
  (`-Dzig-reprs=false`) and a build with Zig REPRs exits 0, with an empty `undefined-lines.txt`.
- Each C fix is a separate commit that can later be turned into an upstream PR with little work.
- Each fix has a program that shows the bug before and its absence after, on both builds.

## Non-goals

- No upstream PRs, no pushes to the fork, no changes to the eleven open PRs. Delivery upstream is a later
  campaign.
- The three undiagnosed entries are not in this work: OB13 (`blocked.nqp --stress` cleanup segfault), OB14
  (ReleaseSafe abort), OB15a (`t/04-nativecall/02-simple-args.t` 17-18). They need diagnosis first and get
  their own plan. [controller's call]
- No AddressSanitizer build of the port (OB15c) and no run of the Perl build path (OB15b). [controller's call]
- No guard for the first-compose gap (OB11) beyond what the storage-less decision below gives. Every real
  guard needs an "instantiated" flag on allocation paths that bypass the REPR (`MVM_gc_allocate_object`,
  spesh `sp_fastcreate`, deopt); that is a design question for the maintainers. The gap is documented.
  [controller's call, stated to the owner]
- No porting of further C files to Zig. Bugs that live only in shared C are fixed in C.

## Anti-goals

- A Zig-only fix that makes the two builds differ. Then the gate needs an exclusion list again.
- A fix that changes behaviour outside its bug without saying so in the commit message and the record.
- Renaming or tidying code the fix does not touch.

## Constraints

- Work in the main checkout on a branch off `zig-hash-engine`; no git worktrees. Nothing is pushed or merged
  without the owner's say.
- New and touched code uses explicit, descriptive names in snake_case.
- The C in the port's tree already carries the eleven cherry-picked fixes. A new C fix may depend on one of
  them (OB8 on #2080, OB9 on #2083, OB12 on #2081). Each C commit message names the PR it depends on, if any.
- Exception messages are identical in C and Zig, byte for byte.
- Builds: `rm -f src/gen/config.h src/gen/config.c src/gen/config.o` before `zig build`; under
  `systemd-run --user --scope -q -p MemoryMax=8G`; load below 2.0; `ulimit -c 0` for anything that may crash.

## Approaches

Three ways were put to the owner:

1. **Fix both sides in the port's tree** (picked). Each fix is a small C commit plus its Zig mirror, as in
   the cfix mirror. The gate stays at exit 0 and the later PRs are cherry-picks. More work now.
2. **Zig only, with a list of expected differences.** Less work now. It brings back the exclusion list that
   the last campaign emptied, and the C fixes get written cold later.
3. **Zig only where Zig owns the code, skip the shared-C bugs.** Smallest. Leaves six bugs in the port.

The owner picked 1.

A second choice concerned the six element kinds without storage (1-, 2- and 4-bit signed and unsigned
integers; `elem_size` 0). They can be composed into an array type, but no operation can store an element.
nqp does not use them. Rakudo's core does not either, but `use experimental :smallnatives`
(`lib/experimental.rakumod`) declares `int1 int2 int4 uint1 uint2 uint4 bit`. Run on the port (vf-n-base,
2026-11-20): `my uint4 @a` declares and has 0 elements, `@a.push(3)` throws "MVMArray: Unhandled slot type",
and a scalar `my uint4 $x = 5` does not compile ("Unknown uint size 4"). So the kinds are reachable from Raku
behind an experimental pragma, and unusable there today. (The first version of this document said Rakudo did
not expose them; the builder check found the pragma.)

1. **Refuse composing an array with such a kind** (picked). OB6, OB17, OB20 and OB15d disappear, and so does
   the second half of OB18. OB11 shrinks to the type-confusion case. Cost: outside code that composes such an
   array type, even unused, starts to throw: under the pragma, `my uint4 @a` fails at the declaration and
   not at the first store.
2. **Keep them composable and fix each symptom.** No change for composers; about five more small fixes; the
   kinds stay useless.

The owner picked 1, and confirmed it on 2026-11-20 after seeing the `:smallnatives` finding above.

## What each fix defines

Decided by the owner: the two choices above. Everything in this section was proposed by the controller in
the conversation and not objected to; treat each as the controller's call.

### Area K: kinds without storage are refused at compose (OB6, OB17, OB18 second half, OB20, OB15d)

- `compose` (C: `spec_to_repr_data` / `compose` in `src/6model/reprs/VMArray.c`; Zig:
  `src/zig/6model/reprs/vmarray/serial.zig`) throws when the element type is an integer type of fewer than 8
  bits. Message, exact: `MVMArray: Cannot compose an array of %d-bit integers, element types need at least
  8 bits` with the bit count.
- `deserialize_repr_data` meets the same case when a serialized type names such a kind: it throws the same
  message. (No existing compiled file has such a type; this is for crafted or foreign input.)
- The check comes before the #2081 recompose check, so the message does not depend on the type's history.
- The arms and guards that handled these kinds (`Unhandled slot type` arms, #2079's storage-less guard,
  #2080's write_buf guard) become unreachable. They stay: they are upstream code or cherry-picks of open
  PRs, and removing them is not part of a bug fix. The Zig keeps its mirror of them.
- In Zig, the NULL-slots special case in `storage.zig` `grow` (OB15d) stays for the same reason.
- OB6 (wrong name table in the at_pos default arm) and OB17 (storage spec and debugger misreport) are not
  fixed separately: no array of such a kind can exist. The record says so.
- Harness: the `tools/bench/repr/` cases that build storage-less arrays (`<kind>.late.*`, the six kinds'
  rows) change to expect the compose throw. Note `odd_kinds()` in `vmarray-diff.nqp` composes outside its
  `t()` wrapper; a throw there would abort the whole program, so that part is restructured. `va-kind-differences.md` gets a dated note, not a rewrite.

### Area Y: a type object as splice source (OB2)

- `asplice` throws when the source is not concrete, whatever its REPR. Message, exact: `MVMArray: Cannot
  splice from a type object`. The check is the first thing done with the source: `asplice` reads the
  source's `elems` before #2079's REPR check (which sits inside `if (elems1 > 0)`), so the new check comes
  before that read. A type object of another REPR, which today may throw something else or nothing from its
  `elems`, gives this message too. [controller's call after the builder check]
- Whether `aslice` and other entry points read a type object's body the same way must be checked by the
  builder; if they do, the same throw applies there (message adapted to the operation), and the record lists
  each place found.

### Area Q: a rejected push or bind_pos leaves the array as it was (OB7)

- In `push` and `bind_pos`, the register kind is checked against the slot type before the array grows. The
  existing messages are kept. A rejected `bind_pos` past the end no longer grows the array.
- The JIT entry points (`vmarray_bind_pos_int64` and siblings) are only chosen for a matching kind; the
  builder confirms that by reading and says so in the record, and leaves them alone if it holds.

### Area W: write_buf grows by whole elements; the num message (OB8, OB16)

- `write_buf` grows the array to `offset + ceil(count / elem_size)` elements, not `offset + count`. The
  overflow rules of #2077 and #2080 are kept. This changes `elems` after a write into a wide Buf, which
  Raku code can observe (`buf16.new(1,2,3).write-uint64(1,1)` leaves 5 elements, not 9). The commit message
  says so.
- `read_buf` and `write_buf` keep accepting the num kinds. The message changes from "integer type" to name
  what is accepted. Exact new text: the existing message with `integer` replaced by `integer or num`. The
  builder quotes the old and new strings in the record.

### Area Z: growth within existing storage zeroes what it exposes (OB4)

- When `set_size_internal` (Zig: `setSize`) raises `elems` without reallocating, it zeroes the slots from
  the old `elems` to the new `elems`. One place; the five adopting sites are not changed.
- Cost: a memset on every such growth, including a push into spare room. There is no array throughput
  benchmark in the tree (`tools/bench/repr/` holds only the differential programs), so the builder adds one:
  `tools/bench/repr/vmarray-push-bench.nqp`, which for an int array and an object array (a) pushes 10 million
  elements one at a time into a fresh array, and (b) does 1 million rounds of push 8, pop 8 on a 1,000-element
  array (growth within storage every time). It prints wall time per case. Method: `MVM_SPESH_BLOCKING=1`,
  load below 2.0, 7 runs per case per build, compare medians, before (99f7ce8cd builds) and after, on the
  C-REPR and the Zig-REPR build. If a median gets worse by more than 5 % on either build, the builder stops
  and reports the numbers instead of choosing another design. [controller's call after the builder check]
- Growth that reallocates already zeroes; that path is not touched.

### Area V: deserialize checks the size before allocating (OB18 first half)

- `deserialize` applies the same limit as `set_size_internal` to `elems`, and checks that
  `elems * elem_size` does not wrap, before allocating. On failure it throws the existing `Unable to
  allocate an array of %PRIu64 elements` message.

### Area H: holes in object arrays read the same everywhere (OB19)

- `pop` and `shift` return `tc->instance->VMNull` for a NULL slot of an object array, as `at_pos` does.
- `copy_elements` is not changed: a hole may be stored as NULL or as VMNull, and every read now gives VMNull.
  Serialization's two forms stay. The builder checks what a serialized NULL slot reads back as and records
  it; no change is expected.

### Area M: the #2081 message for a type without a debug name (OB12)

- The message prints `<anon>` where the debug name is missing or empty. Exact result:
  `MVMArray: Type <anon> is already composed with another element kind`.

### Shared C only (no Zig mirror, because the port has no Zig for this code)

- **OB1** Win64 mask: `~0xfffUL` becomes a 64-bit constant in `set_size_internal`. The Zig is already right.
- **OB3** buffer ops: the JIT paths for readuint, writeint and writeuint apply the interpreter's checks
  (`(flags & 3) == 3`, `size > 8`); the simplest correct form is that the JIT does not compile the fast
  path for flags it cannot prove safe and falls back to the interpreter's op. writenum accepts only 4 or 8
  bytes, with the message shaped as readnum's (`Cannot write a num of %d bytes`). writenum's handling
  of `(flags & 3) == 3` follows what readnum does today for the same flags, whatever that is (refuse with
  readnum's wording adapted, or not refuse); the builder reads readnum and makes writenum its mirror.
  [controller's call after the builder check] The two items the record
  marks "uncertain, not followed" (`MVM_SC_WB_OBJ` and `IS_CONCRETE` on the JIT paths; the `int` shift) are
  checked by reading; if real, they are fixed in the same area and recorded, if not, the record says why.
  Evidence needs runs with the JIT on (the default on x86-64) and with `MVM_JIT_DISABLE=1`.
- **OB5** `MVMHash.c` deserialize: `key` is rooted across `MVM_serialization_read_ref`, the shape of #2086.
  Found by reading; no reproducer is required, as for #2086.
- **OB9** normalizecodes of empty input: the output array becomes empty (the non-empty path replaces the
  output, so the empty path does too).
- **OB10** encode: the encoded buffer is freed when the resize throws. Found by reading; reachability is
  doubtful and the record says so.

### Not changed, recorded as open

- **OB11** first-compose gap: after area K only the type-confusion case is left (a first compose to `str`
  or to a native kind over live object slots). Documented in the record and in `docs/`, not fixed.
- **OB13, OB14, OB15a, OB15b, OB15c**: see Non-goals.

## Order and shape of the work

- Branch `zig-open-bugs` off `zig-hash-engine`.
- One commit per C fix, then one commit for its Zig mirror (areas K, Y, Q, W, Z, V, H, M), in that order
  within an area. Shared-C-only fixes are one commit each. Area K goes first, because it removes cases the
  other areas would otherwise have to handle; M goes with K's neighbourhood but as its own commits.
- Tests: each Zig-owned area adds unit tests in `src/zig/6model/test/vmarray_elements_test.zig` in the
  style already there (throws run in a forked child). Each area adds or changes cases in
  `tools/bench/repr/vmarray-diff.nqp` / `.raku` so the differential harness drives the fixed path.
- Reproducers go in `traces/llm/bench/ob-repro/`, one per bug id, runnable on any prefix with the existing
  `cfix-repro/run.sh` conventions. The "before" outputs are taken on builds of 99f7ce8cd.
- Record: `traces/llm/bench/ob-fixes.md` (per area: the fix, before/after outputs on both builds, what was
  not verified), and `cfix-open-bugs.md` gets a status line per entry pointing to it.

## Acceptance

At the branch tip, on two fresh prefixes (C REPRs and Zig REPRs):

- `zig fmt --check` clean; unit tests pass on default, `-Dzig-reprs=false` and `-Dgc-debug=1`, with no fewer
  passing tests than at 99f7ce8cd.
- Exported symbol lists equal between the two builds.
- `diff.sh` exits 0; `undefined-lines.txt` stays empty; serialization bytes and cross-reads identical.
- nqp and Rakudo `make test`: per-file results equal on both builds and equal to those at 99f7ce8cd (which
  include the known `02-simple-args.t` 17-18 failure).
- Every reproducer: bug shown on the 99f7ce8cd builds, absent on the tip builds, C and Zig output equal.
- Area Z's benchmark numbers recorded.

## Left to the builder

- Where exactly each check sits inside its function, as long as nothing is changed before a throw.
- The wording of commit messages and record prose.
- How to group the work into plan tasks.
- Whether a shared-C fix needs a helper function.
