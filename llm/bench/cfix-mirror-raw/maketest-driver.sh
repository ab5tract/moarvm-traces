#!/bin/sh
# cfix-mirror-raw/maketest-driver.sh OUTDIR [project:prefix ...]: Task 6 of the cfix campaign (va-maketest-driver.sh re-pointed at the vf-* prefixes); was: the VMArray campaign's
# suites (Task 8, Step 3; ngc-maketest-driver.sh re-pointed at the va-*
# prefixes). Each project:prefix pair runs `make test` in the nqp or rakudo
# checkout with LD_LIBRARY_PATH=/tmp/claude-1000/vf-<prefix>/lib.
# Default: nqp:c-base nqp:n-base rakudo:c-base rakudo:n-base.
# The caller's MVM_*, RAKUDO_*, NQP_*, RAKU_*, PERL6* variables and RAKULIB are
# removed (as diff.sh), and before each run a probe through the checkout's
# ./nqp-m or ./rakudo-m prints the libmoar.so it maps (OUTDIR/<project>-<prefix>.probe);
# a probe outside the prefix stops the driver (exit 4).
# Writes OUTDIR/<project>-<prefix>.out, the sorted per-file verdict list
# OUTDIR/<project>-<prefix>.list and a line per run to OUTDIR/summary.tsv.
O=$1; [ $# -gt 0 ] && shift
[ -n "$O" ] || { echo "usage: maketest-driver.sh OUTDIR [project:prefix ...]" >&2; exit 64; }
specs=${*:-nqp:c-base nqp:n-base rakudo:c-base rakudo:n-base}
mkdir -p $O
NQP=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp
RAK=/home/longwalker/code/raku/x.core/zmoarz/rakudo
scrub=$(env | sed -n 's/^\(\(MVM_\|RAKUDO_\|NQP_\|RAKU_\|PERL6\)[A-Za-z0-9_]*\|RAKULIB\)=.*/-u \1/p')
nqp_probe='for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }'
raku_probe='say "/proc/self/maps".IO.lines.first(*.contains("libmoar")).words[*-1]'
for spec in $specs; do
  proj=${spec%%:*}; p=${spec#*:}
  case $proj in nqp) dir=$NQP ;; rakudo) dir=$RAK ;; *) echo "unknown project $proj" >&2; exit 64 ;; esac
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
  lib=/tmp/claude-1000/vf-$p/lib
  [ -e $lib/libmoar.so ] || { echo "$lib/libmoar.so missing" >&2; exit 64; }
  # shellcheck disable=SC2086
  if [ $proj = nqp ]; then
    (cd $dir && env $scrub LD_LIBRARY_PATH=$lib ./nqp-m -e "$nqp_probe") > $O/$proj-$p.probe 2>&1
  else
    (cd $dir && env $scrub LD_LIBRARY_PATH=$lib ./rakudo-m -e "$raku_probe") > $O/$proj-$p.probe 2>&1
  fi
  case $(cat $O/$proj-$p.probe) in "$lib"/libmoar.so) ;; *) echo "$proj $p maps $(cat $O/$proj-$p.probe), not $lib/libmoar.so" | tee -a $O/summary.tsv; exit 4 ;; esac
  s=$(date +%s)
  # shellcheck disable=SC2086
  (cd $dir && env $scrub LD_LIBRARY_PATH=$lib systemd-run --user --scope -q -p MemoryMax=8G make test) > $O/$proj-$p.out 2>&1
  rc=$?
  grep -E '^t/.* \.\.' $O/$proj-$p.out | sed -E 's/ \.+ / /; s/ +[0-9]+\/[0-9]+ *$//' | awk '{print $1, ($NF=="ok" ? "ok" : "notok")}' | sort > $O/$proj-$p.list
  printf '%s\t%s\texit %s\t%ss\tload %s\t%s\t%s\t%s\n' $proj $p $rc $(( $(date +%s)-s )) $l "$(date '+%F %T')" "$(grep -E '^Files=' $O/$proj-$p.out)" "$(grep -E '^Result' $O/$proj-$p.out)" | tee -a $O/summary.tsv
done
