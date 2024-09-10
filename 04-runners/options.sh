# Настройки процесса создания виртуальных машин под кластер YDB

# Базовое имя хоста, создаваемые виртуалки называются по шаблону ${host_base}-s{host_number}
host_base=runner-
# Имя пользователя на виртуалках с правом на беспарольный sudo.
# Необходим беспарольный ssh-доступ с "хоста подскока".
host_user=yc-user
# Количество vCPU каждой виртуалки
yc_vm_cores=8
# Объем оперативной памяти на одну виртуалку, Гбайт
yc_vm_mem=32
# Размер диска для данных YDB на одну виртуалку, Гбайт
yc_data_disk_size=93G
yc_data_disk_type=network-ssd-nonreplicated
yc_boot_disk_size=100G
yc_boot_disk_type=network-ssd
# Количество узлов в кластере
ydb_nodes=3
# Количество дисков для данных YDB в каждом узле кластера
ydb_disk_count=0
# Если изменить с Y на N, то создание дисков будет пропущено
ydb_create_disks=N

# End Of File