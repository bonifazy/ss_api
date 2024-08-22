#!/bin/bash

sudo systemctl status ss_api
sudo journalctl -u ss_api | tail -20
echo "
cat error.log:"
cat log/error.log | tail -20
