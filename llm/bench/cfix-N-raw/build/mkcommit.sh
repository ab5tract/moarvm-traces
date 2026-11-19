#!/bin/sh
# mkcommit.sh PARENT MSGFILE PATH=FILE... -> prints the new commit id; its tree
# is PARENT's with each PATH replaced by FILE's contents (mode 100644). The
# checked-out branch, index and work tree of P are not touched.
set -e
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
parent=$1; msg=$2; shift 2
export GIT_INDEX_FILE=/tmp/claude-1000/t5/index.tmp
rm -f $GIT_INDEX_FILE
git read-tree "$parent"
for pf in "$@"; do
  p=${pf%%=*}; f=${pf#*=}
  b=$(git hash-object -w "$f")
  git update-index --cacheinfo 100644,$b,"$p"
done
t=$(git write-tree)
rm -f $GIT_INDEX_FILE
git commit-tree "$t" -p "$parent" -F "$msg"
