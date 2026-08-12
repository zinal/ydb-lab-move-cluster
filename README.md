# 0\.1 Постановка задачи

Замена 12 существующих хостов на 12 новых хостов в работающем кластере YDB. На кластер в процессе переезда подаётся пишущая и читающая нагрузка.

Топология исходных и целевых хостов отличается:

- на исходной системе по 2 диска для данных на хост
- на целевой системе по 3 диска для данных на хост

# 0\.2 План мероприятий

 1. Создать первоначальные 12 виртуальных машин
 2. Развернуть кластер YDB в режиме mirror-3-dc
 3. Создать и проверить кластерное DNS-имя для адресации кластера
 4. Развернуть систему для подачи нагрузки TPC-C на ещё 3 виртуальных машинах
 5. Создать новые 12 виртуальных машин для переноса кластера
 6. Подать постоянную нагрузку
 7. Включить новые виртуальные машины в кластер, не прекращая подачу нагрузки
 8. Скорректировать кластерное DNS-имя
 9. Переместить vdisk со старых на новые хосты
10. Переместить статическую группу со старых на новые хосты
11. Переместить state storage со старых на новые хосты
12. Убрать со старых виртуальных машин узлы базы данных

# 0\.3 Репозиторий

https://github.com/zinal/ydb-lab-move-cluster

Все работы выполнялись на RED OS 7.3

# 1\. Создать первоначальные 12 виртуальных машин

Требования:

1. Должен существовать "хост подскока" с доступом в интернет. Остальные виртуальные машины создаются в частной сети.
2. Установленные инструменты [YC CLI](https://yandex.cloud/ru/docs/cli/operations/install-cli)

```bash
vi options.sh      # Установить параметры размещения виртуальных машин
cd 01-vms
bash 01-vms.sh
```

# 2\. Развернуть кластер YDB

Действия выполняются на "хосте подскока".

 1. Скачать и распаковать плейбук:

    ```bash
    mkdir -v Lab
    cd Lab
    wget https://github.com/ydb-platform/ydb-ansible/archive/refs/tags/v0.10.tar.gz
    tar xf v0.10.tar.gz
    mv -v ydb-ansible-0.10 playbooks
    ```

 2. Скачать дистрибутив YDB:

    ```bash
    wget https://binaries.ясубд.рф/release/24.2.6.1/yasubd-24.2.6.1-linux-amd64.tar.xz
    ```

 3. Клонировать репозиторий с артефактами установки.

    ```bash
    git clone https://github.com/zinal/ydb-lab-move-cluster.git source
    ```

 4. Скопировать `ydb-ca-nodes.txt` в каталог `tls` плейбука.

    ```bash
    cp -v source/02-deploy/ydb-ca-nodes.txt playbooks/tls/
    ```

 5. Сгенерировать сертификаты для "старых" узлов кластера YDB. В результате будет создана ссылка `tls` на каталог со сгенерированными сертификатами

    ```bash
    cd playbooks/tls/
    ./ydb-ca-update.sh
    cd ../..
    P=playbooks/tls/CA/certs
    ln -sv ${P}/`ls ${P} | grep 202 | sort | tail -n 1` tls
    cp -v tls/ca.crt ydb-ca.crt
    ```

 6. Скопировать файл `hosts` в каталог `playbooks`

    ```bash
    cp -v source/02-deploy/hosts playbooks/
    ```

 7. Создать файл `playbooks/files/secrets` на основе примера

    ```bash
    cp -v playbooks/files/secret.example playbooks/files/secret
    vi playbooks/files/secret
    ```

 8. Создать и скорректировать файл `playbooks/group_vars/all`

    ```bash
    cp -v source/02-deploy/all playbooks/group_vars/all
    vi playbooks/group_vars/all
    ```

 9. Создать и скорректировать файл `playbooks/files/config.yaml`

    ```bash
    cp -v source/02-deploy/config.yaml playbooks/files/
    vi playbooks/files/config.yaml
    ```

10. Установка узлов хранения

    ```bash
    (cd playbooks && ./run-install-static.sh)
    ```

11. Создание базы данных

    ```bash
    (cd playbooks && ./run-create-database.sh)
    ```

12. Установка и запуск узлов базы данных

    ```bash
    (cd playbooks && ./run-install-dynamic.sh)
    ```

13. Убедиться, что консоль Embedded UI показывает базу данных в активном состоянии.

    - открыть туннель `ssh -L8765:ydb-old-12:8765 gw0 vmstat 5 9999999999`
    - в браузере перейти по адресу https://localhost:8765
    - открыть в разделе мониторинга список баз данных, затем проверить список узлов

# 3\. Создать и проверить кластерное DNS-имя для адресации кластера

1. Получить список сетей и их идентификаторов

   ```bash
   yc vpc network list
   ```

2. Создать зону DNS

   ```bash
   yc dns zone create --name zonne --network-ids NetId --zone zonne.
   ```

3. Получить список виртуальных машин и их адресов

   ```bash
   yc compute instances list
   ```

4. Создать сетевое имя, соответствующее IP-адресам хостов `yc-old-{1-3}`

   ```bash
   yc dns zone add-records --name zonne --record "zeit-cluster.zonne. A 10.131.0.29"
   yc dns zone add-records --name zonne --record "zeit-cluster.zonne. A 10.131.0.5"
   yc dns zone add-records --name zonne --record "zeit-cluster.zonne. A 10.131.0.38"
   ```

5. Установить на хосте подскока [YDB CLI](https://ydb.tech/docs/ru/reference/ydb-cli/install)

   ```bash
   ssh yc-user@runner-1
   curl -sSL https://install.ydb.tech/cli | bash
   ```

6. Настроить профиль YDB CLI на узле подскока и проверить возможность подключения

   ```bash
   ydb config profile create zeit
   -> grpcs://zeit-cluster.zonne:2135
   -> /Domain0/testdb
   -> root / P@$$w0rd+
   ydb config profile update --ca-file ~/Lab/ydb-ca.crt zeit
   ydb discovery list
   ydb scheme ls
   ```

# 4\. Развернуть систему для подачи нагрузки TPC-C на ещё 3 виртуальных машинах

## 4\.1. Создание виртуальных машин

Создать 3 дополнительные виртуальные машины:

```bash
# Запуск на хосте с установленным и настроенным YC CLI
cd 04-runners
bash 04-runners.sh
```

## 4\.2. Установка зависимостей

1. Скачать OpenJDK 21 https://adoptium.net/download/

2. Скопировать OpenJDK на "хост подскока"

   ```bash
   scp ~/Downloads/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz gw0:Lab
   ```

3. Развернуть OpenJDK на хостах для подачи нагрузки

   ```bash
   # Запуск команды на хосте подскока
   cd Lab
   bash source/04-runners/install-jdk.sh
   scp ydb-ca.crt yc-user@runner-1:Lab/
   ```

4. Установить на первом хосте для подачи нагрузки [YDB CLI](https://ydb.tech/docs/ru/reference/ydb-cli/install)

   ```bash
   ssh yc-user@runner-1
   curl -sSL https://install.ydb.tech/cli | bash
   ```

5. Создать на первом хосте для подачи нагрузки профиль YDB CLI для подключения к кластеру YDB

   - см. последнее действие на шаге 3

6. Установить на первом хосте для подачи нагрузки [зависимости Python](https://github.com/zinal/ydb-lab-move-cluster/blob/main/04-runners/python-deps.txt)

   ```bash
   ssh yc-user@runner-1
   cd Lab
   wget https://binaries.ясубд.рф/tpcc/python3-venv-redos73.tar.xz
   tar xf python3-venv-redos73.tar.xz
   . ./venv/bin/activate
   ```

7. Скопировать репозиторий YDB BenchHelpers

   ```bash
   ssh yc-user@runner-1
   sudo yum install git screen
   cd Lab
   git clone https://github.com/ydb-platform/benchhelpers.git
   ln -sv benchhelpers/tpcc/ydb helpers
   ```

8. Скачать и распространить BenchBase для YDB

   ```bash
   # Запуск на хосте подскока
   cd Lab
   wget https://storage.yandexcloud.net/ydb-benchmark-builds/benchbase-ydb.tgz
   N=3
   for x in `seq 1 ${N}`; do scp benchbase-ydb.tgz yc-user@runner-${x}:Lab/; done
   for x in `seq 1 ${N}`; do ssh yc-user@runner-${x} tar xf Lab/benchbase-ydb.tgz; done
   ```

## 4\.3. Настройка параметров YDB BenchHelpers для запуска теста TPC-C

1. Генерируем и раскладываем ssh-ключ на рабочих узлах

   ```bash
   # Запуск на хосте подскока
   cd Lab
   ssh-keygen -t ecdsa -f key_runners
   N=3
   for x in `seq 1 ${N}`; do scp key_runners yc-user@runner-${x}:.ssh/id_ecdsa; done
   for x in `seq 1 ${N}`; do scp key_runners.pub yc-user@runner-${x}:.ssh/id_ecdsa.pub; done
   for x in `seq 1 ${N}`; do ssh yc-user@runner-${x} "cat .ssh/id_ecdsa.pub >>.ssh/authorized_keys"; done
   for x in `seq 1 ${N}`; do scp ~/Lab/ydb-ca.crt yc-user@runner-${x}:Lab/ydb-ca.crt; done
   ```

2. Создаем на узле `runner-1` файл `Lab/helpers/tpcc.hosts` со следующим содержимым:

   ```
   runner-1
   runner-2
   runner-3
   ```

3. Дописываем логин и пароль для доступа к кластеру в переменные `YDB_USER` и `YDB_PASSWORD` в файле `Lab/helpers/run_ydb.sh`:

   ```bash
   #!/bin/bash
   
   export TZ=UTC
   export LC_ALL=en_US.utf8
   
   export YDB_USER=root
   export YDB_PASSWORD='P@$$w0rd+'
   export YDB_SSL_ROOT_CERTIFICATES_FILE=$HOME/Lab/ydb-ca.crt
   ...
   ```

4. Готовим скрипт запуска `Lab/helpers/do_all.sh` на основе [образца](https://github.com/zinal/ydb-lab-move-cluster/blob/main/04-runners/do_all.sh).

5. Выполняем первоначальный прогон, контролируем успешность по логам в `~/tpcc_logs`

   ```bash
   # Запуск выполняем на узле runner-1 
   screen
   cd Lab
   . ./venv/bin/activate
   cd helpers
   ./do_all.sh
   ```

# 5\. Создать новые 12 виртуальных машин для переноса кластера

Требования - аналогично шагу 1. Опции размещения виртуальных машин заданы на шаге 1.

```bash
cd 05-vms
bash 05-vms.sh
```

# 6\. Подать постоянную нагрузку

1. Готовим скрипт `Lab/helpers/do_run.sh` для постоянной подачи нагрузки на основе [образца](https://github.com/zinal/ydb-lab-move-cluster/blob/main/06-workload/do_run.sh).

2. Запускаем нагрузку

   ```bash
   ssh yc-user@runner-1
   screen
   cd Lab
   . ./venv/bin/activate
   cd helpers
   ./do_run.sh
   ```

3. Контролируем по логам в `tpcc_logs`, что через 10 минут нагрузка вышла на штатный уровень без ошибок

# 7\. Включить новые виртуальные машины в кластер, не прекращая подачу нагрузки

[Инструкции по расширению кластера в документации](https://ydb.tech/docs/ru/maintenance/manual/cluster_expansion)

 1. Подготовить набор TLS-сертификатов для новых узлов:

    ```bash
    cd Lab
    mv -v playbooks/tls/ydb-ca-nodes.txt playbooks/tls/nodes-old
    cp -v source/07-extend/ydb-ca-nodes.txt playbooks/tls/
    # Генерация ключей и сертификатов для новых узлов
    (cd playbooks/tls && ./ydb-ca-update.sh)
    # Копирование новых ключей и сертификатов в общий каталог
    P=playbooks/tls/CA/certs
    N=`ls ${P} | grep 202 | sort | tail -n 1`
    cp -r ${P}/${N}/* tls/
    ```

 2. Скопировать в рабочую область плейбука файл конфигурации кластера с добавленными новыми узлами хранения

    ```bash
    # Запасная копия старого файла настроек
    cp -v playbooks/files/config.yaml playbooks/files/config.yaml-old
    # Копируем новый файл настроек
    cp -v source/07-extend/config.yaml playbooks/files/
    vi  playbook/files/config.yaml
    ```

 3. Распространить новый конфигурационный файл на существующие узлы кластера

    ```bash
    (cd playbooks && ./run-update-config.sh)
    ```

 4. Выполнить пошаговый рестарт текущего набора узлов хранения

    ```bash
    (cd playbooks && ./run-rolling-static.sh)
    ```

 5. Выполнить пошаговый рестарт текущего набора узлов баз данных

    ```bash
    (cd playbooks && ./run-rolling-dynamic.sh)
    ```

 6. Скопировать обновленные файлы хостов и параметров в рабочую область плейбуков Ansible

    ```bash
    cp -v source/07-extend/hosts playbooks/hosts
    cp -v source/07-extend/all playbooks/group_vars/all
    ```

    Список хостов содержит только новые хосты.
    В переменных скорректирован состав дисков (соответствует новым хостам), а также выставлена переменная `ydb_cluster_extension: true`

 7. Запустить развертывание узлов базы данных на новых хостах

    ```bash
    (cd playbooks && ./run-install-dynamic.sh)
    ```

    Выполняется установка дистрибутива YDB, копирование фалов настроек, создание системных сервисов для узлов базы данных, запуск узлов базы данных.
    Этот этап можно перенести в самый конец, выполнив перед окончательным исключением из кластера "старых" хостов.

 8. Убедиться, что консоль Embedded UI показывает добавленные узлы в составе базы данных.

    - открыть туннель `ssh -L8765:ydb-old-12:8765 gw0 vmstat 5 9999999999`
    - в браузере перейти по адресу https://localhost:8765
    - открыть в разделе мониторинга список узлов

 9. Запустить процесс развертывания и добавления в кластер новых узлов хранения

    ```bash
    (cd playbooks && ./run-install-static.sh)
    ```

    Выполняется форматирование дисков, создание системных сервисов для узлов хранения, запуск узлов хранения и применение к кластеру новой конфигурации (`ydbd admin bs init`).

10. Проверить в интерфейсе Embedded UI, что для новых хостов отображаются их диски (объекты PDisk):

    - в разделе мониторинга открыть Storage, далее представление Nodes
    - посмотреть состав дисков для новых хостов

# 8\. Скорректировать кластерное DNS-имя

В интерфейсе консоли Yandex Cloud открыть нужную DNS-зону. Для записи `zeit-cluster.zonne` заменить состав IP-адресов на адреса, соответствующие хостам `ydb-new-{1-3}`.

# 9\. Переместить vdisk со старых на новые хосты

Операция выполняется путём декомиссии существующих PDisk. [Инструкция в документации](https://ydb.tech/docs/ru/devops/manual/decommissioning).

1. Получить токен аутентификации для работы программы `ydb-dstool`

   ```bash
   ydb auth get-token -f >token-file
   ```

2. Создать псевдоним для запуска `ydb-dstool` с нужными параметрами подключения

   ```bash
   alias dstool="ydb-dstool -e grpcs://zeit-cluster.zonne:2135 --ca-file ~/Lab/ydb-ca.crt --token-file token-file"
   dstool cluster list
   ```

3. Убедиться в том, что все PDisk на новых хостах находятся в корректном статусе (ACTIVE, DECOMMIT_NONE)

   ```bash
   dstool pdisk list --format tsv | grep ydb-new-
   ```

4. Получить список PDisk, размещенных на старых хостах

   ```bash
   dstool pdisk list --format tsv | grep ydb-old-
   ```

5. Запустить декомиссию всех PDisk, размещенных на старых хостах

   ```bash
   dstool pdisk list --format tsv | grep ydb-old- | while read id other; do
     dstool pdisk set --decommit-status DECOMMIT_IMMINENT --pdisk-ids ${id}
   done
   ```

6. Дождаться завершения процесса перемещения всех динамических VDisk со "старых" хостов на "новые". Процесс можно контролировать по разделу Storage / Nodes в составе Embedded UI.

# 10\. Переместить статическую группу со старых на новые хосты

[Инструкция в документации](https://ydb.tech/docs/ru/devops/manual/static-group-move)

Подготовительные операции:

1. Проверить, что файл `playbooks/hosts` содержит полный перечень всех узлов кластера (и старых, и новых):

   ```bash
   cp -v source/10-move-static/hosts playbooks/hosts
   ```

2. Получить токен аутентификации для работы программы `ydb-dstool`

   ```bash
   ydb auth get-token -f >token-file
   ```

3. Создать псевдоним для запуска `ydb-dstool` с нужными параметрами подключения

   ```bash
   alias dstool="ydb-dstool -e grpcs://zeit-cluster.zonne:2135 --ca-file ~/Lab/ydb-ca.crt --token-file token-file"
   dstool cluster list
   ```

4. Проверить, что размещение новых VDisk на "старых" хостах заблокировано (статус DECOMMIT_IMMINENT):

   ```bash
   dstool pdisk list --format tsv | grep ydb-old-
   ```

5. Определить GUID PDisk-ов, на которых будет размещаться статическая группа:

   ```bash
   dstool pdisk list --format tsv --columns NodeId:PDiskId FQDN Path Guid | sort -k 1 | grep ydb-new- | grep ydb_disk_1
   ```

   Удобно взять первый диск (`ydb_disk_1`) на первых 3 хостах в каждой зоне (в предлагаемом случае - на хостах `ydb-new-{1,2,3,5,6,7,9,10,11}`).
   Собранную информацию можно сохранить примерно в таком виде:

   ```
   [111:1002]      ydb-new-1       /dev/disk/by-partlabel/ydb_disk_1       5944565286971892152
   [112:1000]      ydb-new-2       /dev/disk/by-partlabel/ydb_disk_1       5013768546831743243
   [113:1002]      ydb-new-3       /dev/disk/by-partlabel/ydb_disk_1       378013750684201685
   [121:1000]      ydb-new-5       /dev/disk/by-partlabel/ydb_disk_1       15448986621769266242
   [122:1001]      ydb-new-6       /dev/disk/by-partlabel/ydb_disk_1       5238696652724385991
   [123:1002]      ydb-new-7       /dev/disk/by-partlabel/ydb_disk_1       9770394458529721617
   [131:1001]      ydb-new-9       /dev/disk/by-partlabel/ydb_disk_1       6057398190079722682
   [132:1002]      ydb-new-10      /dev/disk/by-partlabel/ydb_disk_1       360451652363666292
   [133:1002]      ydb-new-11      /dev/disk/by-partlabel/ydb_disk_1       13773152857447859481
   ```

   Нетрудно видеть, что мы выбрали диски с меткой `ydb_disk_1` на нужных хостах.

Далее необходимо 9 раз повторить следующие операции:

1. Заменить в файле настроек кластера `playbooks/files/config.yaml` в секции `blob_storage_config` / `service_set` / `groups` / `rings` / `fail_domains`, поле `node_id`, один "старый" хост на один "новый" хост в той же зоне доступности, без пересечений с другими узлами в той же секции.

2. Добавить для того же самого элемента поля `pdisk_id` и `pdisk_guid` со значениями, равным идентификаторам выбранного диска на соответствующем хосте. Пример файла на первом повторе:

   ```yaml
   blob_storage_config:
     service_set:
       groups:
       - erasure_species: mirror-3-dc
         rings:
         - fail_domains:
           - vdisk_locations:
             - node_id: 111
               pdisk_id: 1002
               pdisk_guid: 5944565286971892152
               pdisk_category: SSD
               path: /dev/disk/by-partlabel/ydb_disk_1
           - vdisk_locations:
             - node_id: 12
               pdisk_category: SSD
               path: /dev/disk/by-partlabel/ydb_disk_1
   ...
   ```

3. Установить обновленный файл настроек на все хосты кластера:

   ```bash
   (cd playbooks && ./run-update-config.sh)
   ```

4. Выполнить остановку узла хранения с заменяемым диском:

   ```bash
   ssh yc-user@ydb-old-1 sudo systemctl stop ydbd-storage
   ```

5. Очистить заменяемый диск на очередном узле хранения

   ```bash
   ssh yc-user@ydb-old-1 sudo /opt/ydb/bin/ydbd admin bs disk obliterate /dev/disk/by-partlabel/ydb_disk_1
   ```

6. Выполнить запуск узла хранения с заменяемым диском:

   ```bash
   ssh yc-user@ydb-old-1 sudo systemctl start ydbd-storage
   ```

7. Выполнить перезапуск узлов хранения с помощью утилиты `ydbops`

   ```bash
   ydbops -e grpcs://zeit-cluster.zonne:2135 --ca-file ~/Lab/tls/ca.crt --user root restart --storage \
     --systemd-unit ydbd-storage --exclude-hosts ydb-old-1
   ```

   В опции `--exclude-hosts` указываем текущий "старый" узел, с которого убираем очередной VDisk статической группы.

Ускорять процесс путём перемещения сразу нескольких узлов (например, 3 узлов из одной зоны доступности) **нельзя**, так как в случае наложения дополнительных отказов на такое перемещение возможна потеря кластера целиком.

# 11\. Переместить state storage со старых на новые хосты

[Инструкция в документации](https://ydb.tech/docs/ru/devops/manual/state-storage-move)

Выполняем 9 раз для перемещения всех 9 компонентов state storage со "старых" хостов на "новые" хосты.

1. Выбрать очередной исходный и целевой хост для перемещения хранилища state storage. Например, перемещаем с хоста `ydb-old-1` (идентификатор узла `11`) на хост `ydb-new-1` (идентификатор узла `111`).

2. Остановить сервис хранения данных на исходном и целевом хостах:

   ```bash
   ssh yc-user@ydb-old-1 sudo systemctl stop ydbd-storage
   ssh yc-user@ydb-new-1 sudo systemctl stop ydbd-storage
   ```

3. Скорректировать описание state storage в конфигурационном файле кластера `playbooks/files/config.yaml`:

   - исходное состояние:

     ```yaml
     domains_config:
        state_storage:
          - ring:
              node: [11, 12, 13, 21, 22, 23, 31, 32, 33]
              nto_select: 9
            ssid: 1
     ```

   - целевое состояние:

     ```yaml
     domains_config:
        state_storage:
          - ring:
              node: [111, 12, 13, 21, 22, 23, 31, 32, 33]
              nto_select: 9
            ssid: 1
     ```

> [!NOTE]
> Важно не менять позицию заменяемого элемента в списке и не перетасовывать другие элементы. Признак изменения позиции - при рестарте очередной узел "не видит" свои PDisk, и постоянно печатает ошибки следующего вида:
> `:METADATA_PROVIDER ERROR: fline=accessor_snapshot_base.cpp:68;action=cannot detect path existence;path=//Domain0/.metadata/cs_index/external;error=incorrect path status: LookupError;`

1. Установить обновленный файл настроек на все хосты кластера:

   ```bash
   (cd playbooks && ./run-update-config.sh)
   ```

2. Выполнить перезапуск узлов хранения с помощью утилиты `ydbops`

   ```bash
   ydbops -e grpcs://zeit-cluster.zonne:2135 --ca-file ~/Lab/tls/ca.crt --user root restart --storage \
     --systemd-unit ydbd-storage --exclude-hosts ydb-old-1,ydb-new-1
   ```

   В опции `--exclude-hosts` указываем текущие исходный и целевой хост

3. Выполнить перезапуск узлов баз данных:

   ```bash
   (cd playbooks && ./run-rolling-dynamic.sh)
   ```

4. Запустить сервис хранения данных на исходном и целевом хостах:

   ```bash
   ssh yc-user@ydb-new-1 sudo systemctl start ydbd-storage
   ssh yc-user@ydb-old-1 sudo systemctl start ydbd-storage
   ```

Ускорять процесс путём перемещения сразу нескольких узлов (например, 3 узлов из одной зоны доступности) **нельзя**, так как в случае наложения дополнительных отказов на такое перемещение возможна потеря кластера целиком.

# 12\. Убрать со старых виртуальных машин узлы базы данных
