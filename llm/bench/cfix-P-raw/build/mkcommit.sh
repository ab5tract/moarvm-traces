#!/bin/sh
# mkcommit.sh PARENT FILE MSG -> prints new commit id; tree = PARENT's with src/6model/reprs/VMArray.c = FILE
set -e
cd /home/longwalker/code/raku/x.core/zmoarz/rakudo/nqp/MoarVM
export GIT_INDEX_FILE=/tmp/claude-1000/t3/index.tmp
rm -f $GIT_INDEX_FILE
git read-tree "$1"
b=$(git hash-object -w "$2")
git update-index --cacheinfo 100644,$b,src/6model/reprs/VMArray.c
t=$(git write-tree)
rm -f $GIT_INDEX_FILE
git commit-tree "$t" -p "$1" -F "$3"
