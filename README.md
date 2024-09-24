1. Сервис установки ShadowSocks-AEAD (SS-2022) - сервера
2. Сервис менеджмента этого сервера (ендпоинт настроек подключения к серверу)


Инструкция по установке.
1. Запустить 1_install_ss_server.sh
Данный скрипт устанавливает сервер ShadowSocks-AEAD 
и создаёт:
  - systemd сервис ss.service
  - папку логов сервиса: /var/log/ss
  - файл настроек сервера для сервиса менеджмента: data/api_config.yml

2. Проверить файл настроек SS-AEAD сервера data/api_config.yml
для корректной установки сервиса менеджмента.


3. Запустить 2_install_ss_api.sh
Скрипт установит сервис менеджмента ShadowSocks-AEAD сервера,
исходя из настроек data/api_config.yml. 
Сервис имеет 1 endpoint: host/link -- прямые настройки к серверу SS-AEAD
для любого клиента SS-AEAD (Xray-core).
Скрипт создает: 
  - systemd сервис ss_api.socket, ss_api.service
  - папку логов: ~/ss_api/log
