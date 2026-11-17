#!/bin/sh
# va fix wave, part B (spec 7 item 3, the whole-system check): build nqp
# from a plain copy of the nqp checkout against a copy of one moar prefix,
# and keep every .moarvm file it leaves. Usage: build-nqp.sh NAME PREFIX
#   NAME    the result's name (c1, c2, n1)
#   PREFIX  the moar prefix to copy (/tmp/claude-1000/va-c-base or va-n-base)
# Every build uses the same two paths, so nothing that embeds a path can
# differ between builds:
#   /tmp/claude-1000/va-ws/moar  the prefix copy (cp -a)
#   /tmp/claude-1000/va-ws/nqp   the nqp copy (cp -a of every top-level entry
#                                but MoarVM and .git: no git command can
#                                touch the checkout or a remote)
# Neither the prefix nor the nqp checkout is written to. Results go to
# /tmp/claude-1000/va-ws/out/NAME/: the .moarvm files at their relative
# paths, sha256.txt, configure.log, make.log, probe.txt, info.txt.
N=$1; SRC=$2
NQP=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
WS=/tmp/claude-1000/va-ws; O=$WS/out/$N
[ -n "$N" ] && [ -n "$SRC" ] && [ -x "$SRC/bin/moar" ] || { echo "usage: build-nqp.sh NAME PREFIX" >&2; exit 64; }
rm -rf "$WS/moar" "$WS/nqp" "$O"; mkdir -p "$WS/nqp" "$O"
cp -a "$SRC" "$WS/moar"
for e in "$NQP"/* "$NQP"/.[!.]*; do
  case "$(basename "$e")" in MoarVM|.git) continue ;; esac
  cp -a "$e" "$WS/nqp/"
done
scrub="-u MVM_SPESH_DISABLE -u MVM_SPESH_BLOCKING -u MVM_JIT_DISABLE -u NQP_HOME -u NQP_LIB -u RAKUDO_HOME -u RAKULIB -u PERL6LIB -u LD_LIBRARY_PATH"
for v in $(env | sed -n 's/^\(MVM_[A-Za-z0-9_]*\|RAKUDO_[A-Za-z0-9_]*\|NQP_[A-Za-z0-9_]*\|RAKU_[A-Za-z0-9_]*\|PERL6[A-Za-z0-9_]*\)=.*/\1/p'); do scrub="$scrub -u $v"; done
{
  echo "name $N"; echo "prefix copied from $SRC"
  echo "source libmoar $(sha256sum "$SRC/lib/libmoar.so")"
  echo "copied libmoar $(sha256sum "$WS/moar/lib/libmoar.so")"
  echo "moar --version: $("$WS/moar/bin/moar" --version)"
  echo "nqp checkout $(git -C "$NQP" rev-parse HEAD), status lines $(git -C "$NQP" status --short | wc -l)"
} > "$O/info.txt"
cd "$WS/nqp" || exit 1
# The copied Makefile and config.status are the checkout's (configured for
# tune-zig-prefix); configure afresh, then clean, so everything is rebuilt.
env $scrub perl Configure.pl --backends=moar --with-moar="$WS/moar/bin/moar" --prefix="$WS/moar" > "$O/configure.log" 2>&1 || { echo "configure failed" >> "$O/info.txt"; exit 1; }
env $scrub make clean >> "$O/configure.log" 2>&1
until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do echo "load $(cut -d' ' -f1 /proc/loadavg), waiting" >> "$O/info.txt"; sleep 60; done
echo "make start $(date '+%F %T %Z') load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$O/info.txt"
s=$(date +%s)
env $scrub systemd-run --user --scope -q -p MemoryMax=8G make > "$O/make.log" 2>&1
rc=$?
echo "make exit $rc, $(( $(date +%s) - s )) s, end $(date '+%F %T %Z') load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$O/info.txt"
[ $rc = 0 ] || exit 1
# Which libmoar the built nqp maps: the runner, the moar the build used.
env $scrub ./nqp-m -e 'for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }' > "$O/probe.txt" 2>&1
case "$(cat "$O/probe.txt")" in "$WS/moar/lib/libmoar.so") ;; *) echo "probe maps $(cat "$O/probe.txt")" >> "$O/info.txt"; exit 4 ;; esac
grep -n "moar" Makefile | grep -m3 "^[0-9]*:M_MOAR\|^[0-9]*:MOAR\|with-moar" >> "$O/info.txt"
find . -name '*.moarvm' | sort | while read f; do mkdir -p "$O/files/$(dirname "$f")"; cp -a "$f" "$O/files/$f"; done
(cd "$O/files" && find . -name '*.moarvm' | sort | xargs sha256sum) > "$O/sha256.txt"
echo "moarvm files $(wc -l < "$O/sha256.txt")" >> "$O/info.txt"
