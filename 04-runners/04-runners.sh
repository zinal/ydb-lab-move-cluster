#! /bin/sh
# Создание виртуальных машин Yandex Cloud для работы кластера YDB.

. ../options.sh
. ./options.sh

set -u
set +e

ydb_nodes_begin=1
ydb_nodes_end=${ydb_nodes}

. ../helpers/vms.sh
. ../helpers/host.sh

# End Of File
