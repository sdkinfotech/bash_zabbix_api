#!/bin/bash

# Загружаем учетные данные из файла .env
if [ ! -f .env ]; then
    echo "Файл .env не найден!"
    exit 1
fi

source .env

# Аутентификация в Zabbix API для получения auth token
auth_response=$(curl -s -X POST -H "Content-Type: application/json-rpc" -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.login\",
    \"params\": {
        \"user\": \"$ZABBIX_USER\",
        \"password\": \"$ZABBIX_PASS\"
    },
    \"id\": 1
}" 'https://zabbix.finam.ru/zabbix/api_jsonrpc.php')
auth_token=$(echo "$auth_response" | jq -r '.result')

if [ -z "$auth_token" ]; then
    echo "Не удалось получить токен аутентификации. Проверьте логин и пароль."
    exit 1
fi

# Запрашиваем имя хоста
read -p "Введите имя хоста: " host_name

# Получаем ID хоста
hostid_response=$(curl -s -X POST -H "Content-Type: application/json-rpc" -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.get\",
    \"params\": {
        \"output\": [\"hostid\"],
        \"filter\": { \"host\": [\"$host_name\"] }
    },
    \"auth\": \"$auth_token\",
    \"id\": 2
}" 'https://zabbix.finam.ru/zabbix/api_jsonrpc.php')
hostid=$(echo "$hostid_response" | jq -r '.result[0].hostid // empty')

if [ -z "$hostid" ]; then
    echo "Хост с именем \"$host_name\" не найден."
    exit 1
fi

# Запрашиваем период времени
echo "Введите период времени (5m, 30m, 1h, 4h, 10h, 12h, 1d, 2d). Максимум 7 дней."
read -p "Период: " period

# Конвертируем период в секунды
declare -A times=( ["m"]=60 ["h"]=3600 ["d"]=86400 )
multiplier=${period: -1}
value=${period:0:-1}
let "seconds = $value * ${times[$multiplier]}"

# Проверка, что период не превышает 7 дней
max_seconds=$((7 * 86400))
if [ $seconds -gt $max_seconds ]; then
    echo "Ошибка: Период не может превышать 7 дней."
    exit 1
fi

# Устанавливаем время начала
since_time=$(date -d "@$(($(date +%s) - seconds))" +%s)

# Получаем события за указанный период времени для хоста
events_response=$(curl -s -X POST -H "Content-Type: application/json-rpc" -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"event.get\",
    \"params\": {
        \"output\": \"extend\",
        \"hostids\": [\"$hostid\"],
        \"sortfield\": \"clock\",
        \"sortorder\": \"DESC\",
        \"time_from\": $since_time,
        \"limit\": 50000
    },
    \"auth\": \"$auth_token\",
    \"id\": 3
}" 'https://zabbix.finam.ru/zabbix/api_jsonrpc.php')

# Выводим информацию о событиях в удобном для чтения формате
echo "$events_response" | jq '.result[] | {
  "event_id": .eventid,
  "name": .name,
  "start_time": (.clock | tonumber | strftime("%Y-%m-%dT%H:%M:%SZ")),
  "severity": .severity,
  "status": (if .value == "0" then "resolved" else "active" end)
}'
