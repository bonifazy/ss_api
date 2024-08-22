#!/bin/bash

# Edit default DNS server
sudo apt install -y resolvconf
sudo cp /etc/resolvconf/resolv.conf.d/head /etc/resolvconf/resolv.conf.d/backup.head
sudo echo "nameserver 84.200.69.80
nameserver 84.200.70.40" > /etc/resolvconf/resolv.conf.d/head
sudo chown root:root /etc/resolvconf/resolv.conf.d
sudo resolvconf --enable-updates
sudo resolvconf -u
sudo systemctl restart resolvconf.service
sudo systemctl restart systemd-resolved.service
sudo resolvectl status

# allow rule for REST API
sudo ufw allow from 62.113.113.93 to any port 80 proto tcp comment "SS 2022 management"
sudo ufw allow 23/tcp comment "SS 2022 Server"
sudo ufw enable
sudo ufw reload

# Install nginx
ip4_name=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^10|^127|^172|^192')
sed -e "s/server_name _.*/server_name $ip4_name;/" data/api_default_nginx > data/api_default_to_install
sudo apt install -y file
sudo apt install -y nginx
sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
sudo mv data/api_default_to_install /etc/nginx/sites-available/default
sudo nginx -t
echo ""
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl status nginx

# Install python3.10
# sudo apt install software-properties-common -y
# sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt install python3.10 -y
sudo apt install python3.10-venv -y
python3.10 -m venv env
source env/bin/activate
pip install --upgrade pip
pip install -r data/requirements.txt
deactivate

# prepare home profile and ss_api folder
sudo usermod -aG www-data dim
sudo chown dim:www-data /home/dim/ss_api/data/main.py
if [ -e log ]; then
    echo 'directory log/ exists.'
    truncate --size 0 log/access.log
    truncate --size 0 log/error.log
else
    mkdir log
    touch log/access.log
    touch log/error.log
fi
sudo chown -R dim:www-data /home/dim/ss_api/log

# Install ss_api systemd unit ans start it
sudo cp data/ss_api.socket /etc/systemd/system
sudo cp data/ss_api.service /etc/systemd/system
sudo chmod 664 /etc/systemd/system/ss_api.socket
sudo chmod 664 /etc/systemd/system/ss_api.service
sudo systemctl daemon-reload
sudo systemctl enable ss_api.socket
sudo systemctl start ss_api.socket
echo "
sudo systemctl status ss_api.socket:"
sudo systemctl status ss_api.socket
echo "
file /run/ss_api.sock:"
file /run/ss_api.sock
sudo systemctl enable ss_api.service
sudo systemctl start ss_api.service
echo "
sudo journalctl ss_api:"
sudo journalctl -u ss_api | tail -20
echo "
sudo systemctl status ss_api:"
sudo systemctl status ss_api

