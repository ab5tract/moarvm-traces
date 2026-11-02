# moarvm-traces

Process documents ("traces") for the Zig build and the Zig port of
MoarVM. They record how the work was designed and carried out; they are
not user-facing project documentation (that lives in MoarVM's own
`docs/` and `build/README.md` and is meant for upstream).

## Where this repository lives

- Mounted as the `traces` git submodule of the MoarVM checkout
  (`rakudo/nqp/MoarVM`), so this repository's root is MoarVM's `traces/`.
  Paths inside the documents are written relative to the MoarVM root,
  e.g. `traces/llm/specs/<name>` (directory `llm/` inside this
  repository).
- Remote: `git@github.com:ab5tract/moarvm-traces.git` (the submodule
  checkout's own `origin`). The local sibling repository at
  `/home/longwalker/code/raku/x.core/zmoarz/moarvm-traces` is the
  original import and is a mirror, fast-forwarded from the submodule
  checkout.
- MoarVM's `.gitmodules` records the https form of that URL
  (`https://github.com/ab5tract/moarvm-traces.git`) with `update = none`,
  so a plain `git submodule update` (which MoarVM's `Configure.pl` runs on
  every submodule) skips this one and never needs access to the repository;
  `git submodule update --init --checkout traces` checks it out explicitly.

## Layout

- `llm/` - LLM-produced documents:
  - `llm/specs/` - design specs, one file per topic, named
    `YYYY-MM-DD-<topic>-design.md`.
  - `llm/plans/` - implementation plans, named `YYYY-MM-DD-<topic>.md`.
  - `llm/bench/` - benchmark results (reports and raw TSV) cited by the
    specs and plans.

The directories are flat; the file names carry date and topic.
`llm/specs/` and `llm/plans/` are the roots for new LLM documents
(previously these went to `docs/superpowers/specs/` and
`docs/superpowers/plans/` in the MoarVM checkout). Review ledgers and
spike results go alongside them in the directory matching their kind,
or in a new directory under `llm/` named for the kind if none fits.
Other kinds of traces (not LLM-produced) get their own top-level
directory beside `llm/`.

## Provenance

- `llm/specs/2026-11-02-*` and all of `llm/plans/` were moved here from
  MoarVM's `docs/superpowers/` (removed there in the commit that added
  this submodule).
- `llm/specs/2026-11-01-zig-build-migration-design.md` was copied from the
  rakudo checkout (branch `zig-build-spec`,
  `docs/superpowers/specs/2026-11-01-zig-build-migration-design.md`).
  The original has been left in place in rakudo for the user to remove.
- The documents previously sat at this repository's root (`specs/`,
  `plans/`, `bench/`) with the repository mounted at MoarVM's
  `traces/llm`; they moved under `llm/` when the mount moved to `traces/`,
  so the `traces/llm/...` paths in them stayed valid.

References of the form `docs/superpowers/{specs,plans}/<name>` inside the
documents were rewritten to `traces/llm/{specs,plans}/<name>`.
