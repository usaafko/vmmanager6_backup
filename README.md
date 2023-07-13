# vmmanager6_backup
Скрипт для сохранения бекапов VMmanager 6 с возможностью восстановления в новую VM

Необходимо разместить скрипт на узле VMmanager 6, на котором расположена VM, затем изменить vars.sh

## Бэкап
Берем в VMmanager id виртуальной машины и  запускаем `./backup.sh vm_id`

Скрипт 
- запустит процесс создания резервной копии в VMmanager
- по окончании скопирует архив и метаданные в `BACKUP_LOCATION`

## Восстановление
Находим в `BACKUP_LOCATION` нужную директорию с бекапом и используем её название в `./restore.sh backup_name`

Скрипт
- Если VM уже создана, проверит - есть ли этот бекап в интерфейсе и запустит восстановление через VMmanager. Если его нет - скопирует данные из `BACKUP_LOCATION` и запустит восстановление
- Если VM удалили, предложит создать её. Проверит, занят ли основной IP. Если занят - спросит, занять ли новый. Далее после создания VM с данными из бекапа, скрипт скопирует резервную копию в интерфейс и запустит восстановление
