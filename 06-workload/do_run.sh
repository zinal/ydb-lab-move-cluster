#! /bin/sh

while true; do
    ./run_ydb.sh                                        \
        --run-phase-only --no-load --no-drop-create     \
        --ydb-host zeit-cluster.zonne                   \
        --ydb-port 2135 --secure                        \
        --ca-file $HOME/Lab/ydb-ca.crt                  \
        --database /Domain0/testdb                      \
        --config tpcc_config_template.xml               \
        --hosts tpcc.hosts                              \
        --warehouses 2000                               \
        --warmup 600                                    \
        --time 72000                                    \
        --java-memory 4g                                \
        --log-dir $HOME/tpcc_logs
done
