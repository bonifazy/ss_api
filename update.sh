#!/bin/bash

echo "Update ss_api"

cd ~/ss_api
echo "
git stash:"
git stash
echo "
git pull:"
git pull

sudo systemctl daemon-reload
sudo systemctl restart ss_api
sudo systemctl status ss_api
sudo journalctl -u ss_api | tail -20 && echo ""
