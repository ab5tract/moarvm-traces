#!/bin/sh
# ob-repro/build-prefixes.sh: the "after" prefixes of the open-bugs fixes
# (plan traces/llm/plans/2026-11-23-open-bugs-port-fixes.md):
#   /tmp/claude-1000/ob-c   -Dzig-reprs=false (the C array)
#   /tmp/claude-1000/ob-n   defaults (the Zig array)
# built from HEAD of the checkout P. cfix-mirror-raw/build/build.sh (which
# built vf-c-base and vf-n-base) with two changes: each prefix is built from
# its own `git archive HEAD` copy (with the 3rdparty submodules at their
# recorded commits, as cfix-P-raw/build/export-build.sh copies them) under
# /tmp/claude-1000/ob-src-c and ob-src-n, so that nothing is built inside P
# and nothing uncommitted reaches a prefix; and the exported symbols of each
# libmoar are written next to the log (as cfix-mirror.md's "exports" row).
# The traces submodule is not copied (not part of the build).
# Refuses to run when tracked files of P other than the traces pointer
# differ from HEAD (they would not be in the copy). An earlier copy and
# prefix of the same name are removed first. Per prefix, as build.sh: wait
# for a 1-minute load below 2.0, rm -f src/gen/config.{h,c,o} (in the copy),
# zig build install under systemd-run --user --scope -q -p MemoryMax=8G, one
# line in builds.tsv. Without .git the version comes from the VERSION file
# (build/zig/version.zig), so `moar --version` shows no commit; builds.tsv
# names the commit.
# Output: traces/llm/bench/ob-fixes-raw/build/{builds.tsv,builds.log,<name>.out,exports-<name>.txt}.
# Usage: build-prefixes.sh [NAME...]   (NAME from ob-c ob-n; default both)
M=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
O=$M/traces/llm/bench/ob-fixes-raw/build; mkdir -p "$O"
cd "$M" || exit 1
if ! git diff --quiet HEAD -- . ':(exclude)traces'; then
  echo "build-prefixes.sh: tracked files differ from HEAD (not in a git archive copy); commit first" >&2
  git diff --stat HEAD -- . ':(exclude)traces' >&2; exit 1
fi
commit=$(git rev-parse --short HEAD)
[ $# -gt 0 ] || set -- ob-c ob-n
for name in "$@"; do
  case $name in
    ob-c) opts=-Dzig-reprs=false; src=/tmp/claude-1000/ob-src-c ;;
    ob-n) opts=; src=/tmp/claude-1000/ob-src-n ;;
    *) echo "build-prefixes.sh: unknown prefix $name (ob-c, ob-n)" >&2; exit 64 ;;
  esac
  prefix=/tmp/claude-1000/$name
  rm -rf "${src:?}" "${prefix:?}"
  mkdir -p "$src"
  git archive HEAD | tar -x -C "$src" || exit 1
  for m in $(git ls-tree HEAD 3rdparty/ | awk '$2=="commit"{print $4}'); do
    mkdir -p "$src/$m"; git -C "$m" archive "$(git ls-tree HEAD "$m" | awk '{print $3}')" | tar -x -C "$src/$m" || exit 1
  done
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "$name: load $(cut -d' ' -f1 /proc/loadavg), waiting" >> "$O/builds.log"; sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  rm -f "$src/src/gen/config.h" "$src/src/gen/config.c" "$src/src/gen/config.o"
  s=$(date +%s)
  # shellcheck disable=SC2086
  ( cd "$src" && env -u LD_LIBRARY_PATH systemd-run --user --scope -q -p MemoryMax=8G zig build install --prefix "$prefix" $opts ) > "$O/$name.out" 2>&1
  rc=$?
  t=$(( $(date +%s) - s ))
  v=$("$prefix/bin/moar" --version 2>&1)
  printf '%s\t%s\texit %s\t%ss\tload %s\tcommit %s\topts %s\t%s\n' "$(date '+%F %T %Z')" "$name" $rc $t "$l" "$commit" "$opts" "$v" | tee -a "$O/builds.tsv"
  [ $rc = 0 ] || exit 1
  nm -D --defined-only "$prefix/lib/libmoar.so" | awk '{print $3}' | sort > "$O/exports-$name.txt"
done
