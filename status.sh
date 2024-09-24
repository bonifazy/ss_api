#!/bin/bash

sudo systemctl status ss_api
sudo journalctl -u ss_api | tail -20
echo "
cat error.log:"
tail -20 log/error.log
