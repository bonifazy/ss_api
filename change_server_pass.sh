#!/usr/bin/bash

sed -i "s/.*password.*/\t$(echo "\"password\": \"$(openssl rand -hex 16)\",")/;" /home/dim/ss/ss_config.json
sudo systemctl restart ss
sudo systemctl status ss | head
