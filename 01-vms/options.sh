# Настройки процесса создания виртуальных машин под кластер YDB

# Имя промежуточного "хоста подскока", с которого видны создаваемые виртуалки
host_gw=gw0
# Базовое имя хоста, создаваемые виртуалки называются по шаблону ${host_base}-s{host_number}
host_base=ydb-old-
# Имя пользователя на виртуалках с правом на беспарольный sudo.
# Необходим беспарольный ssh-доступ с "хоста подскока".
host_user=yc-user

# Имя файла публичного ключа на "хосте подскока",
# который нужно прописать при создании виртуалок для беспарольного входа.
keyfile_gw=.ssh/id_ecdsa.pub

# AZ Яндекс Облака, в которой создаются виртуалки
yc_zone=ru-central1-d
# Существующая подсеть в Яндекс Облаке
yc_subnet=default-ru-central1-d
# Тип платформы виртуалок, standard-v2 или standard-v3
yc_platform=standard-v3
# Выбранный образ операционной системы виртуалок
yc_vm_image="image-folder-id=standard-images,image-name=redsoft-red-os-standart-server-7-3-v20240402"
#yc_vm_image="image-folder-id=standard-images,image-family=ubuntu-2204-lts"
#yc_vm_image="image-folder-id=standard-images,image-name=astralinux-alse-v20230215"
#yc_vm_image="image-folder-id=standard-images,image-name=redsoft-red-os-standart-server-7-3-v20220810"
#yc_vm_image="image-folder-id=standard-images,image-name=almalinux-9-v20230417"
#yc_vm_image="image-folder-id=standard-images,image-name=almalinux-v20230417"
# Количество vCPU каждой виртуалки
yc_vm_cores=16
# Объем оперативной памяти на одну виртуалку, Гбайт
yc_vm_mem=32
# Размер диска для данных YDB на одну виртуалку, Гбайт
yc_data_disk_size=186G
yc_data_disk_type=network-ssd-nonreplicated
yc_boot_disk_size=30G
yc_boot_disk_type=network-ssd

# Количество узлов в кластере
ydb_nodes=12
# Количество дисков для данных YDB в каждом узле кластера
ydb_disk_count=2

# Если изменить с Y на N, то создание дисков будет пропущено
ydb_create_disks=Y

# End Of File