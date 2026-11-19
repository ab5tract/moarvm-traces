#!/bin/sh
# export-moar.sh: the MoarVM source trees for the two baseline prefixes, as
# run for Task 1 (inline, recorded here). The checkout P was on branch
# cfix-baseline (= origin/main f112c3998) at the time; `git archive` of that
# branch plus each 3rdparty submodule at its recorded commit (the submodule
# working trees were at those commits, `git submodule status` clean), so
# nothing is built inside P. Without .git, Configure.pl skips its submodule
# update and takes the version from VERSION ("2026.11").
P=/home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
cd $P || exit 1
for d in cfix-src-base cfix-src-asan; do
  D=/tmp/claude-1000/$d; mkdir -p $D
  git archive cfix-baseline | tar -x -C $D
  for m in $(git ls-tree cfix-baseline 3rdparty/ | awk '$2=="commit"{print $4}'); do
    mkdir -p $D/$m; git -C $m archive HEAD | tar -x -C $D/$m
  done
done
# Then, in each copy (logs in this directory):
#   cfix-src-base: perl Configure.pl --prefix=/tmp/claude-1000/cfix-base
#   cfix-src-asan: perl Configure.pl --asan --no-mimalloc --prefix=/tmp/claude-1000/cfix-asan
#   build-moar.sh base; build-moar.sh asan   (make -j8 install, MemoryMax=8G)
# The first ASAN build used --asan alone (asan-mimalloc-*.log): mimalloc
# serves MVM_malloc there, so ASAN would not see heap overruns; it was
# rebuilt with --no-mimalloc into the same prefix.
