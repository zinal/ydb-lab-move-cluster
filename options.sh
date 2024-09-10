# Настройки процесса создания виртуальных машин под кластер YDB

# Имя промежуточного "хоста подскока", с которого видны создаваемые виртуалки
host_gw=gw0
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

# End Of File