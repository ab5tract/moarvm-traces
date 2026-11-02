# Migrating the Perl/make build (NQP::Config, MoarVM Configure.pl) to Zig

Date: 2026-11-01
Status: design approved in brainstorm, awaiting spec review
Scope: MoarVM, nqp, rakudo. MoarVM backend only.

## 1. Goal

Add a `build.zig` to each of MoarVM, nqp and rakudo so that

    zig build -Dprefix=/opt/raku install

produces a working `moar`, `nqp-m` and `rakudo-m` with settings, with no
Perl, make, or system C compiler required. The existing Perl path
(`Configure.pl`, `nqp-configure`, `Makefile.in` templates) stays untouched
and continues to work, so the zig path can be upstreamed incrementally and
Perl deprecated later.

## 2. Decisions made

| Question | Decision |
|---|---|
| Repos in scope | All three, MoarVM first |
| Backends | MoarVM only. JVM and JS remain Perl-only |
| Relationship to Perl build | Side by side, upstreamable. No Perl files are removed or changed in behaviour |
| How rakudo obtains nqp and MoarVM | Zig package manager (`build.zig.zon`), with path overrides for development |
| C toolchain | `zig cc` only on the zig path. No probing of the compiler |
| JIT code generators (`expr-template-compiler.pl`, `tiler-table-generator.pl`) | Ported to Zig, run as build-time tools |
| Zig version | 0.16.0 (`minimum_zig_version` in each `.zon`) |

## 3. What the Perl layer does today (survey)

### nqp-configure (shared submodule, about 2800 lines)
- `NQP::Config`: option parsing, backend detection, `@macro@` template
  expansion into a single generated `Makefile`, git cloning of nqp and
  MoarVM for `--gen-nqp` / `--gen-moar`.
- `NQP::Macros`: around 50 macros (`for_backends`, `for_specs`, `nfp`,
  `include`, `if`, `insert_filelist`, ...).
- Per-repo hooks `NQP::Config::NQP` and `NQP::Config::Rakudo` (about 1000
  lines): spec revisions, setting chain, runner, install layout.

### MoarVM (`Configure.pl` 1395 lines, `build/probe.pm` 1144, `build/setup.pm` 627)
- Probes: `static_inline`, `thread_local`, computed goto, `stdatomic`,
  `ptr_size`, unaligned access, substandard `pow`/`log`/trig, `isinf`,
  `malloc_trim`, `pthread_yield`, `pthread_setname_np`, `rdtscp`.
- Generates `src/gen/config.h` and `config.c` from `build/*.in` (already in
  `@var@` syntax), `Makefile`, `tools/check.mk`, `pkgconfig/moar.pc`.
- Third-party: libuv (per-OS source list), libtommath, mimalloc, sha1,
  cmp, rapidhash, libatomic_ops, zmij, dyncall (runs its own `./configure`
  and make).
- JIT pipeline: `minilua` (C) runs dynasm to turn `emit.dasc` into
  `emit.c`; two Perl generators produce `core_templates.h` and the tile
  tables. These are not committed.

### Perl at build time beyond configure
- MoarVM: the two JIT generators (about 1200 lines plus
  `tools/lib/sexpr.pm`), `mk-moar-pc.pl`, `ExtUtils::Command` for
  cp/mkpath/rm.
- nqp: `gen-cat.pl` (47 lines), `gen-version.pl` (64 lines).
- rakudo: `rakudo-m-early-build` (16-line wrapper assembling a `moar`
  command line), `check-nqp-version.pl`, `clean-precomps.pl`,
  `monitor-process.pl`, Windows `wrapper-compiler-helper.pl`.
- Tests: `t/harness5` and `prove` (out of scope here, see section 9).

## 4. Key insight

With `zig cc` as the only compiler, almost all MoarVM probes are redundant.
Compiler features are constants for clang. Target facts (pointer size,
endianness, JIT arch) come from `target.result`. Only a few libc behaviours
vary, and they vary by OS, so they become a small per-OS table rather than
runtime probes.

## 5. MoarVM `build.zig`

### Layout
```
build.zig                 wiring only; exposes artifacts to dependents
build.zig.zon             name, version, minimum_zig_version, no deps
build/zig/options.zig     b.option() declarations
build/zig/platform.zig    per-OS table for config.h libc quirks
build/zig/config.zig      addConfigHeader for config.h, config.c, moar.pc
build/zig/thirdparty.zig  one fn per bundled library
build/zig/jit.zig         minilua, dynasm, generator tools
build/zig/sources.zig     list-file reader
build/sources.list        C source list shared with Makefile.in (see below)
tools/zig/expr-template-compiler.zig
tools/zig/tiler-table-generator.zig
tools/zig/sexpr.zig
```

### Exposed to dependents
- artifact `moar` (executable)
- artifact `libmoar` (shared by default, static with `-Dstatic`)
- a `WriteFile` step `moar_includes` containing `src/` headers and the
  generated `config.h`, for nqp and rakudo runners and for `moar.pc`

### Options
`-Dstatic`, `-Djit` (default true on x86_64), `-Dmimalloc` (default true),
`-Dprefix`, `-Dsystem-libuv`, `-Dsystem-libtommath`, `-Dsystem-libffi`
(each swaps a bundled static lib for `linkSystemLibrary`; libffi replaces
dyncall as the nativecall backend). Standard `-Dtarget` and `-Doptimize`.
Dropped relative to `Configure.pl`: `--cc`, `--ld`, `--build`/`--host`,
`--coverage`, `--asan`-style flags (use zig sanitizer options), all
MSVC-specific knobs.

### config.h, config.c, moar.pc
`b.addConfigHeader(.{ .style = .{ .cmake = b.path("build/config.h.in") } }, values)`
reuses the existing template unchanged. The 48 values fall into:
- compiler feature strings: constants for clang, with the `dllexport` /
  `dllimport` / `dlllocal` trio chosen by target OS
- target facts: `ptr_size`, `be`, `jit_arch`, `jit_platform` from
  `target.result`
- libc quirks: `has_substandard_pow/log/acos/asin`, `has_fn_malloc_trim`,
  `has_pthread_setname_np`, `has_pthread_yield`, `has_libuv_pty`,
  `has_isinf`, `has_isnan`, `has_signbit`, `has_rdtscp`, `do_pty_ourself`,
  `translate_newline_output` from `platform.zig`, seeded from what the
  Perl probes report today on linux, macos, freebsd, openbsd, windows
- version fields from the `VERSION` file plus `git describe` at configure
  time

`config.c.in` and `mk-moar-pc.in` get the same treatment.

### Third-party libraries
Each is a `std.Build.Step.Compile` static library built from the bundled
sources. libuv's source list is chosen by OS to mirror `setup.pm`. mimalloc
is the single `src/static.c`. dyncall skips its own `./configure`: the zig
build selects `.S` and `.c` files by `target.result.cpu.arch` and OS.
arm64 and Windows dyncall need checking in the portability phase.

### JIT pipeline
1. `minilua` built as a C executable.
2. `addRunArtifact(minilua)` runs `dynasm.lua` on `emit.dasc` (with
   `tiles.dasc` as input) producing `emit.c` into the cache.
3. `expr-template-compiler` and `tiler-table-generator`, ported to Zig,
   built for the host and run via `addRunArtifact` producing
   `core_templates.h` and the tile tables into a cache directory that is
   added as an include path.
Acceptance test for the ports: byte-identical output to the Perl tools on
the current `.expr` and `.tile` inputs. Kept as `zig build check-jit-tools`
while Perl is still present.

### Source lists
`OBJECTS1`, `OBJECTS2`, `JIT_OBJECTS`, `MAIN_OBJECTS` move out of
`build/Makefile.in` into a plain `build/sources.list` (one path per line,
`#` comments, sections marked `[core]`, `[jit]`, `[main]`). `Makefile.in`
includes it via a tiny Perl change in `Configure.pl` that expands the list
into the Makefile; `build.zig` reads it with `sources.zig`. This is the one
touch on the Perl side and keeps a single source of truth. Fallback if
upstream objects: `build.zig` parses `Makefile.in` directly.

## 6. Packaging and dependency flow

- MoarVM `build.zig.zon`: no dependencies.
- nqp `build.zig.zon`: dependency `moarvm` by URL plus hash. For
  development the nested checkout is used via a `.path = "MoarVM"` override
  or `--system`.
- rakudo `build.zig.zon`: dependency `nqp` only. nqp re-exports the `moar`
  artifact so rakudo never depends on MoarVM directly.
- `MOAR_REVISION` and `NQP_REVISION` stay for the Perl path. The zig pin is
  the `.zon` hash. At configure time `build.zig` warns if the dependency's
  `git describe` disagrees with the revision file, to stop drift while both
  paths are alive.

## 7. nqp `build.zig`

### Dependency
`b.dependency("moarvm", .{ .target, .optimize })` supplies `moar` and the
include tree. nqp re-exports `moar` with `b.installArtifact` and as a named
artifact for rakudo.

### Shared mini-tools (owned by nqp, exported as module `build-tools`)
- `tools/zig/gen-cat.zig`: concatenates files with the same `#line`-style
  markers `gen-cat.pl` emits. Args: `--prefix`, list file or paths.
- `tools/zig/listfile.zig`: reads source-list files (`#` comments,
  backslash continuations), about 40 lines.
- `tools/zig/tap-runner.zig`: minimal TAP runner for `zig build test`.
rakudo imports these through `nqp_dep.module("build-tools")`. MoarVM does
not need them.

### Stage chain
`build/zig/stages.zig` has `buildStage(b, prev: StageOutputs, idx) StageOutputs`.
- Stage 0 is the committed `src/vm/moar/stage0/*.moarvm` as `LazyPath`s.
- For stage N, each module (`nqpmo`, `ModuleLoader`, `NQPCORE.setting`,
  `QASTNode`, `MASTNodes`, `MASTOps`, `QRegex`, `NQPHLL`, `QAST`,
  `NQPP6QRegex`, then `nqp.moarvm`) is a `Run` step:
  `moar --libpath=<stage N-1> --libpath=<stage N so far> nqp.moarvm
  --target=mbc --output=<out> [--setting=NULL] [--stable-sc=stage1 for N=1]
  <combined.nqp>`
  Inputs via `addFileArg`, outputs via `addOutputFileArg`. Dependency edges
  mirror the `stage_precomp` lines in `Makefile-backend-common.in`.
- Source lists read at configure time from `tools/templates/moar/qast_sources`
  and the common lists in `Makefile-common.in` moved to list files where
  they are not already.
- `nqp-config.nqp` is a `WriteFile` step replacing `gen-version.pl`.
- Stage 2 output is the shipped library set. `NQPP5QRegex.moarvm` is built
  once from stage 2.

### Runner
`tools/templates/unix/nqp-m-build.c` compiled by `addExecutable` with
`-D` defines for the paths that `@var@` substitution fills today. Windows
uses the same file with its own defines.

### Install
`zig build install -Dprefix=...` produces `bin/nqp-m`, `share/nqp/lib/*.moarvm`,
and `moar` from the dependency, matching the moar backend install rules.

## 8. rakudo `build.zig`

- nqp version check: configure-time comparison of the `.zon` dependency's
  revision with `tools/templates/NQP_REVISION`, warning on mismatch.
- gencat steps for `Actions`, `RakuActions`, `Compiler`, `SysConfig`,
  `Grammar`, `RakuGrammar`, `Metamodel`, `ModuleLoader`, `Ops`,
  `Optimizer`, `Pod`, `World`, `rakudo`, `rakudo-debug`, with source lists
  from `tools/templates/common_metamodel_sources`, `raku_ast_sources`,
  `6.{c,d,e}/core_sources` and `bootstrap_sources`.
- `main-version.nqp`: `WriteFile` step fed by `VERSION`, `git describe`,
  `-Dprefix`, `-Drakudo-home`, `-Drelocatable`, and a source digest computed
  in `build.zig` over the same files `Rakudo.pm` hashes.
- `raku-ast-compiler.nqp` runs via `Run` with the nqp artifact, stdout
  captured to a file.
- Perl6 module graph (`RAKUDO_OPS` -> `RAKUDO_M` -> `RAKUDO_O` -> ... ->
  `rakudo.moarvm`) is a table `{name, source, deps}` in
  `build/zig/perl6_modules.zig`; one loop produces the `Run` steps.
- Settings: for each spec in `RAKU_SPECS` (c, d, e), one `Run` of
  `moar --libpath... rakudo.moarvm --setting=NULL.<spec> --ll-exception
  --optimize=3 --target=mbc --output=CORE.<spec>.setting.moarvm`, chained
  c -> d -> e. `rakudo-m-early-build` disappears.
- Runner: `rakudo-m-build.c.in` compiled with `-D` defines. `raku` and
  `perl6` aliases as copies controlled by `-Draku-alias`. Debug, gdb, lldb
  and valgrind wrappers become `WriteFile` outputs of small templates.
- Install mirrors `tools/templates/moar/Makefile-install.in` for moar only.
- Options: `-Dprefix`, `-Drakudo-home`, `-Dnqp-home`, `-Drelocatable`,
  `-Draku-alias`, `-Dsilent-build`. Dropped: `--backends`, `--gen-*`,
  `--with-nqp`, git-related options, `--makefile-timing`, `--expand`,
  `--set-var`, `--compiler`.

## 9. Testing

- MoarVM: `zig build test` runs the existing `t/` C tests and checks
  `moar --version`. `zig build check-jit-tools` diffs Zig generator output
  against Perl output.
- nqp: `zig build test` runs `t/nqp` and `t/qregex` with the built `nqp-m`
  through `tap-runner`.
- rakudo: `zig build test` runs `t/01-sanity` with `rakudo-m`. Spectest
  stays on `t/harness5` and Perl, out of scope.
- Parity: stage-2 `nqp.moarvm` and `CORE.c.setting.moarvm` built by the
  Perl path and the zig path from the same checkout must be byte-identical
  given identical source digests. This is the primary signal that the port
  is faithful.

## 10. Error handling

- Missing `git` at configure time: version strings fall back to the
  `VERSION` file content with a `-unknown` suffix, as `Configure.pl` does.
- Unsupported target OS or arch: `build.zig` fails at configure time with
  a message naming the missing `platform.zig` table entry or dyncall
  source selection, rather than emitting a broken `config.h`.
- `.zon` revision drift versus `*_REVISION` files: warning, not failure.
- Stage compile failures propagate as ordinary `Run` step failures with
  the full `moar` command line shown.

## 11. Phasing (each phase gets its own implementation plan)

1. MoarVM `build.zig` with `-Djit=false`, bundled 3rdparty, linux x86_64.
   Deliverable: a `moar` that runs nqp stage0.
2. JIT: `minilua`, dynasm step, Zig ports of the two generators with the
   byte-identical check. Deliverable: full MoarVM parity on linux.
3. nqp `build.zig` with path dependency on MoarVM: stage chain, runner,
   install, `build-tools` module, tests.
4. rakudo `build.zig`: module graph, settings chain, runner, install,
   tests, parity check.
5. Portability: macos, freebsd, Windows via `zig cc`, cross-compiling
   `moar`. Fill `platform.zig` and dyncall selections.
6. Upstreaming: PRs per repo, `.zon` URL pins replacing path deps, CI jobs
   for the zig path alongside the Perl path.

## 12. Out of scope

JVM and JS backends, spectest harness, removal of any Perl code, MSVC
builds, `--gen-moar`/`--gen-nqp` git cloning (replaced by the package
manager), Windows runner size validation (`wrapper-compiler-helper.pl`).
