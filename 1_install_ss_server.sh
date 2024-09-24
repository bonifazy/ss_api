#!/bin/bash

sudo apt update -y && sudo apt upgrade -y &> /dev/null
sudo apt autoremove -y &> /dev/null

wget https://github.com/XTLS/Xray-core/releases/download/v1.8.23/Xray-linux-64.zip
if [ -e /etc/ss ]; then
    echo 'From ss_api: dir /etc/ss/ is exists.'
else
    sudo mkdir /etc/ss
    sudo apt install unzip -y &> /dev/null
    sudo unzip ./Xray-linux-64.zip -d /etc/ss
    sudo chmod +x /etc/ss/xray
    rm Xray-linux-64.zip
fi

if [ -e /var/log/ss ]; then
    echo 'From ss_api: dir /var/log/ss is exists.'
    sudo truncate --size 0 /var/log/ss/access.log
    sudo truncate --size 0 /var/log/ss/error.log
else
    echo 'From ss_api: dir /var/log/ss is created.'
    sudo mkdir /var/log/ss
    sudo touch /var/log/ss/access.log
    sudo touch /var/log/ss/error.log
    sudo chown -R dim:dim /var/log/ss
    sudo chmod 640 /var/log/ss/access.log
    sudo chmod 640 /var/log/ss/error.log
fi

if [ -e /home/dim/ss ]; then
    echo 'From ss_api: dir /home/dim/ss is exists.'
else
    mkdir /home/dim/ss
    cp data/ss_config.json /home/dim/ss/
    echo "
#!/bin/bash

sudo systemctl restart ss" > /home/dim/ss/restart.sh
    chmod +x /home/dim/ss/restart.sh
fi

ip4_name=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^10|^127|^172|^192')
# Check data/api_config.yml exists
if [ -e data/api_config.yml ]; then
    echo 'copy data/api_config.yml to data/backup.api_config.yml'
    cp data/api_config.yml data/backup.api_config.yml
fi

echo "From ss_api: create api_config.yml file.
"
read -rp "Enter secret word for Kot vpn bot server management: " -e SERVER_SECRET
read -rp "Enter server passwd (need to restart ss.service): " -e SERVER_PASS
# Create data/api_config.yml
echo "SECRET: !!str ${SERVER_SECRET}
SUDO_PASS: !!str ${SERVER_PASS}
HOST: !!str $ip4_name

# ShadowSocks-2022 actual config
SS_RESTART: !!str /home/dim/ss/restart.sh
SS_CONFIG: !!str /home/dim/ss/ss_config.json" > data/api_config.yml

sudo cp data/ss.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable ss
sudo systemctl restart ss
sudo journalctl -u ss | tail -20
sudo systemctl status ss

cp change_server_pass.sh /home/dim/ss
/home/dim/ss/change_server_pass.sh
echo "
cat ss_config.json:"
cat /home/dim/ss/ss_config.json

echo "
# From ss_api: clear log file (without error.log) and restart SS-2022 server
0 6,10,14,18,22 * * * truncate --size 0 /var/log/ss/access.log
0 6,10,14,18,22 * * * systemctl restart ss

# Every day change password and restart SS-2022 server
0 0 * * * /home/dim/ss/change_server_pass.sh
1 0 * * * /home/dim/ss/restart.sh
" | sudo tee -a /var/spool/cron/crontabs/root
sudo systemctl restart cron

echo "
********************************************

Please, check parameters in:
data/api_config.yml
~/ss/ss_config.json
and restart ss.service if need."
