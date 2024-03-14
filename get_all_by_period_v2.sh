#!/bin/bash

# Каталог для результатов с префиксом "result_" и текущей датой и временем
CURRENT_DATE=$(date +%F_%H-%M-%S)
RESULT_DIR="zabbix_events/result_$CURRENT_DATE"
mkdir -p "$RESULT_DIR"

# Загружаем учетные данные из файла .env
if [ ! -f .env ]; then
    echo "Файл .env не найден!"
    exit 1
fi

source .env

# Аутентификация в Zabbix API для получения токена
auth_response=$(curl -s -X POST -H "Content-Type: application/json-rpc" \
    -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.login\", \"params\": \
    {\"user\": \"$ZABBIX_USER\", \"password\": \"$ZABBIX_PASS\"}, \"id\": 1}" \
    'https://your_host/zabbix/api_jsonrpc.php')
auth_token=$(echo "$auth_response" | jq -r '.result')

if [ -z "$auth_token" ]; then
    echo "Не удалось получить токен аутентификации. Проверьте логин и пароль."
    exit 1
fi

# Запрашиваем период времени у пользователя
echo "Введите период времени (например, 20m, 4h, 1d), максимум 7 дней:"
read -r period

# Парсим число и единицу измерения
value=$(echo $period | grep -o -E '[0-9]+')
unit=$(echo $period | grep -o -E '[mhd]')

# Определяем количество секунд в единице измерения
declare -A units=( ["m"]=60 ["h"]=3600 ["d"]=86400 )
if ! [[ $value =~ ^[0-9]+$ ]] || ! [[ -n ${units[$unit]} ]]; then
    echo "Некорректный ввод периода времени."
    exit 1
fi

seconds=$((value * ${units[$unit]}))

# Проверяем, что период не превышает 7 дней
max_seconds=$((7 * 86400))
if [ "$seconds" -gt "$max_seconds" ]; then
    echo "Период не может быть больше 7 дней."
    exit 1
fi

# Вычисляем timestamp начала событий
since_time=$(($(date +%s) - seconds))

# Получаем все события за заданный период времени
events_response=$(curl -s -X POST -H "Content-Type: application/json-rpc" \
    -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"event.get\",
    \"params\": {
        \"output\": \"extend\",
        \"selectHosts\": [\"hostid\", \"name\"],
        \"sortfield\": \"clock\",
        \"sortorder\": \"DESC\",
        \"time_from\": $since_time,
        \"limit\": 50
    },
    \"auth\": \"$auth_token\",
    \"id\": 2
}" 'https://your_host/zabbix/api_jsonrpc.php')

# Валидация ответа от API
if ! (echo "$events_response" | jq . &> /dev/null); then
    echo "Ответ от API Zabbix не является валидным JSON." >&2
    exit 1
fi

# Сохраняем результаты в файле
output_file="${RESULT_DIR}/top_events_since_${CURRENT_DATE}.json"
echo "$events_response" | jq -r '.result[] | {
  "event_id": .eventid,
  "host": (if .hosts then .hosts[0].name else "Unknown" end),
  "hostid": (if .hosts then .hosts[0].hostid else "Unknown" end),
  "name": .name,
  "start_time": (.clock | tonumber | . + 10800 | strftime("%Y-%m-%dT%H:%M:%S MSK")), # Преобразование в МСК
  "severity": .severity,
  "status": (if .value == "0" then "resolved" else "active" end),
  "tags": [.tags[]? | .tag]
}' > "$output_file"

echo "События за последние $period сохранены в файле $output_file"
