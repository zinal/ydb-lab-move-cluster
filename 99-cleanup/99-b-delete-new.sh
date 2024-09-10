#! /bin/sh

for x in `seq 1 12`; do
  yc compute instance delete ydb-new-${x} --async
done
