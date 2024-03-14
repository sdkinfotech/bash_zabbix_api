#!/bin/bash

read -p "Введите ваш логин Zabbix: " zabbix_login
read -sp "Введите ваш пароль Zabbix: " zabbix_password
echo

response=$(curl -s -X POST -H "Content-Type: application/json-rpc" -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.login\",
    \"params\": {
        \"user\": \"$zabbix_login\",
        \"password\": \"$zabbix_password\"
    },
    \"id\": 1
}" 'https://zabbix.finam.ru/zabbix/api_jsonrpc.php')

echo "Ответ сервера Zabbix: $response"
