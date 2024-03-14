# Zabbix API скрипты

Этот репозиторий содержит bash скрипты для работы с Zabbix API. 
Скрипты позволяют аутентифицироваться в Zabbix API, 
получать идентификаторы хостов и извлекать информацию о событиях для заданного хоста на основе введенного пользовательского временного диапазона.

## Установка

Перед использованием скриптов необходимо установить `curl` и `jq`. Они используются для выполнения HTTP-запросов и обработки JSON данных соответственно.

## Конфигурация

Для работы скриптов требуется файл `.env`, содержащий учетные данные пользователя Zabbix:

Убедитесь, что этот файл находится в том же каталоге, что и скрипты, и он недоступен для неавторизованных пользователей.

