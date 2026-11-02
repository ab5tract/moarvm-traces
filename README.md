# moarvm-traces

LLM-produced process documents ("traces") for the Zig build and the Zig
port of MoarVM: design specs, implementation plans, review ledgers and
spike results. They record how the work was designed and carried out;
they are not user-facing project documentation (that lives in MoarVM's
own `docs/` and `build/README.md` and is meant for upstream).

## Where this repository lives

- Mounted as the `traces/llm` git submodule of the MoarVM checkout
  (`rakudo/nqp/MoarVM`). Paths inside the documents are written relative
  to the MoarVM root, e.g. `traces/llm/specs/<name>`.
- Remote: `git@github.com:ab5tract/moarvm-traces.git` (the submodule
  checkout's own `origin`; the local sibling checkout at
  `/home/longwalker/code/raku/x.core/zmoarz/moarvm-traces` is the original
  import and is no longer updated).
- MoarVM's `.gitmodules` records the https form of that URL
  (`https://github.com/ab5tract/moarvm-traces.git`) with `update = none`,
  so a plain `git submodule update` (which MoarVM's `Configure.pl` runs on
  every submodule) skips this one and never needs access to the repository;
  `git submodule update --init traces/llm` checks it out explicitly.

## Layout

- `specs/` - design specs, one file per topic, named
  `YYYY-MM-DD-<topic>-design.md`.
- `plans/` - implementation plans, named `YYYY-MM-DD-<topic>.md`.

Both directories are flat; the file names carry date and topic.
`specs/` and `plans/` are the roots for new documents from now on
(previously these went to `docs/superpowers/specs/` and
`docs/superpowers/plans/` in the MoarVM checkout). Review ledgers and
spike results go alongside them in the directory matching their kind,
or in a new top-level directory named for the kind if neither fits.

## Provenance

- `specs/2026-11-02-*` and all of `plans/` were moved here from MoarVM's
  `docs/superpowers/` (removed there in the commit that added this
  submodule).
- `specs/2026-11-01-zig-build-migration-design.md` was copied from the
  rakudo checkout (branch `zig-build-spec`,
  `docs/superpowers/specs/2026-11-01-zig-build-migration-design.md`).
  The original has been left in place in rakudo for the user to remove.

References of the form `docs/superpowers/{specs,plans}/<name>` inside the
documents were rewritten to `traces/llm/{specs,plans}/<name>`.
