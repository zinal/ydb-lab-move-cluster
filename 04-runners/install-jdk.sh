#! /bin/sh

set -e

N=3
JDK=`ls OpenJDK21U* | sort | tail -n 1`
U=yc-user

echo "Deploying JDKs!"

for x in `seq 1 ${N}`; do
  ssh ${U}@runner-${x} mkdir -pv Lab
  ssh ${U}@runner-${x} sudo mkdir -pv /opt/jdk21
done

set -x

for x in `seq 1 ${N}`; do
  scp ${JDK} ${U}@runner-${x}:Lab/ &
done

wait

for x in `seq 1 ${N}`; do
  ssh ${U}@runner-${x} sudo tar xf Lab/${JDK} --strip-component=1 -C /opt/jdk21 &
done

wait

set +x

for x in `seq 1 ${N}`; do
  ssh ${U}@runner-${x} sudo ln -sv /opt/jdk21/bin/java /usr/local/bin
done

echo "Done!"
