#!/bin/sh
# build-nqp-rakudo.sh: build nqp and rakudo against the moar prefix
# /tmp/claude-1000/cfix-base and install both into that prefix.
# Sources: `git archive` of the upstream commits from the local checkouts
# (read only, no fetch): nqp 305ff2f77 (= nqp origin/main, the merge base of
# the checkout's zig-hash-strategies, which maps a `hashstrategy` op upstream
# MoarVM lacks), rakudo c6d6fc3c6b (= rakudo origin/main, the merge base of
# the checkout's zig-build-spec, which adds one doc file), and each one's
# nqp-configure submodule at its recorded commit. Without .git the configure
# scripts take the version from VERSION, so VERSION in each copy is set to
# `git describe` of that commit (what a git build would report).
# Copies: /tmp/claude-1000/cfix-ws/{nqp,rakudo}. Logs: /tmp/claude-1000/cfix-logs/.
NQP=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
RAK=/home/longwalker/code/raku/x.core/zmoarz/rakudo
NQPC=305ff2f7732aaf8855d685f99603e3d5281a6797
RAKC=c6d6fc3c6baa71a138e12f5eaca9fcca63f7c406
PFX=/tmp/claude-1000/cfix-base
WS=/tmp/claude-1000/cfix-ws; L=/tmp/claude-1000/cfix-logs
scrub="-u LD_LIBRARY_PATH -u LD_PRELOAD"
for v in $(env | sed -n 's/^\(MVM_[A-Za-z0-9_]*\|RAKUDO_[A-Za-z0-9_]*\|NQP_[A-Za-z0-9_]*\|RAKU_[A-Za-z0-9_]*\|PERL6[A-Za-z0-9_]*\|RAKULIB\)=.*/\1/p'); do scrub="$scrub -u $v"; done
waitload() { until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 30; done; }
export_tree() { # repo commit dest
  mkdir -p "$3"; git -C "$1" archive "$2" | tar -x -C "$3"
  git -C "$1" ls-tree -r "$2" | awk '$2=="commit"{print $3, $4}' | while read c p; do
    mkdir -p "$3/$p"; git -C "$1/$p" archive "$c" | tar -x -C "$3/$p"; done
  git -C "$1" describe --tags --match='20*' "$2" > "$3/VERSION"
}
rm -rf "$WS/nqp" "$WS/rakudo"
export_tree "$NQP" $NQPC "$WS/nqp"; export_tree "$RAK" $RAKC "$WS/rakudo"
{ echo "nqp source $NQPC ($(cat $WS/nqp/VERSION)); checkout HEAD $(git -C "$NQP" rev-parse HEAD), status lines $(git -C "$NQP" status --short | wc -l)"
  echo "rakudo source $RAKC ($(cat $WS/rakudo/VERSION)); checkout HEAD $(git -C "$RAK" rev-parse HEAD), status lines $(git -C "$RAK" status --short | wc -l)"
  echo "moar $("$PFX/bin/moar" --version)"; } > $L/nqp-rakudo.info
cd "$WS/nqp" || exit 1
env $scrub perl Configure.pl --backends=moar --with-moar="$PFX/bin/moar" --prefix="$PFX" > $L/nqp-configure.log 2>&1 || { echo "nqp configure failed" >> $L/nqp-rakudo.info; exit 1; }
waitload; echo "nqp make start $(date '+%F %T') load $(cut -d' ' -f1-3 /proc/loadavg)" >> $L/nqp-rakudo.info
env $scrub systemd-run --user --scope -q -p MemoryMax=8G make install > $L/nqp-make.log 2>&1 || { echo "nqp make failed" >> $L/nqp-rakudo.info; exit 1; }
echo "nqp make end $(date '+%F %T')" >> $L/nqp-rakudo.info
cd "$WS/rakudo" || exit 1
env $scrub perl Configure.pl --backends=moar --with-nqp="$PFX/bin/nqp" --prefix="$PFX" > $L/rakudo-configure.log 2>&1 || { echo "rakudo configure failed" >> $L/nqp-rakudo.info; exit 1; }
waitload; echo "rakudo make start $(date '+%F %T') load $(cut -d' ' -f1-3 /proc/loadavg)" >> $L/nqp-rakudo.info
env $scrub systemd-run --user --scope -q -p MemoryMax=8G make install > $L/rakudo-make.log 2>&1 || { echo "rakudo make failed" >> $L/nqp-rakudo.info; exit 1; }
echo "rakudo make end $(date '+%F %T')" >> $L/nqp-rakudo.info
