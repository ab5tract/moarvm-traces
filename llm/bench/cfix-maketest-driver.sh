#!/bin/sh
# cfix-maketest-driver.sh OUTDIR [PREFIX-NAME]: nqp and rakudo `make test`
# for the VMArray C fixes campaign, in the build copies
# /tmp/claude-1000/cfix-ws/nqp (nqp 305ff2f77) and /tmp/claude-1000/cfix-ws/rakudo
# (rakudo c6d6fc3c6b), both built and installed against /tmp/claude-1000/cfix-base
# (cfix-logs/build-nqp-rakudo.sh). PREFIX-NAME (default cfix-base) picks the
# libmoar: LD_LIBRARY_PATH=/tmp/claude-1000/PREFIX-NAME/lib, which wins over
# the runners' RUNPATH; the same nqp and rakudo sources and bytecode for every
# prefix. The caller's MVM_*, RAKUDO_*, NQP_*, RAKU_*, PERL6* variables and
# RAKULIB are removed; before each run a probe through the copy's ./nqp-m or
# ./rakudo-m prints the libmoar.so it maps (OUTDIR/<project>-<prefix>.probe;
# a probe outside the prefix stops the driver, exit 4). Each run waits for a
# 1-minute load below 2.0 and runs under systemd-run --user --scope -q
# -p MemoryMax=8G. Writes OUTDIR/<project>-<prefix>.out, the sorted per-file
# verdict list OUTDIR/<project>-<prefix>.list (ok, skipped = the whole file
# skipped, notok) and a line per run to
# OUTDIR/summary.tsv.
O=$1; p=${2:-cfix-base}
[ -n "$O" ] || { echo "usage: cfix-maketest-driver.sh OUTDIR [PREFIX-NAME]" >&2; exit 64; }
mkdir -p "$O"
lib=/tmp/claude-1000/$p/lib
[ -e $lib/libmoar.so ] || { echo "$lib/libmoar.so missing" >&2; exit 64; }
scrub="-u LD_PRELOAD -u ASAN_OPTIONS $(env | sed -n 's/^\(\(MVM_\|RAKUDO_\|NQP_\|RAKU_\|PERL6\)[A-Za-z0-9_]*\|RAKULIB\)=.*/-u \1/p' | tr '\n' ' ')"
nqp_probe='for nqp::split("\n", slurp("/proc/self/maps")) { if nqp::index($_, "libmoar") >= 0 { say(nqp::substr($_, nqp::index($_, "/"))); last } }'
raku_probe='say "/proc/self/maps".IO.lines.first(*.contains("libmoar")).words[*-1]'
for proj in nqp rakudo; do
  dir=/tmp/claude-1000/cfix-ws/$proj
  until awk '{ exit !($1 < 2.0) }' /proc/loadavg; do sleep 60; done
  l=$(cut -d' ' -f1 /proc/loadavg)
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
  grep -E '^t/.* \.\.' $O/$proj-$p.out | sed -E 's/ \.+ / /; s/ +[0-9]+\/[0-9]+ *$//' | awk '{print $1, ($NF=="ok" ? "ok" : ($2=="skipped:" ? "skipped" : "notok"))}' | sort > $O/$proj-$p.list
  printf '%s\t%s\texit %s\t%ss\tload %s\t%s\t%s\t%s\n' $proj $p $rc $(( $(date +%s)-s )) $l "$(date '+%F %T')" "$(grep -E '^Files=' $O/$proj-$p.out)" "$(grep -E '^Result' $O/$proj-$p.out)" | tee -a $O/summary.tsv
done
