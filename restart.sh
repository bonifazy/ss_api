#!/bin/bash

sudo systemctl restart ss_api
sudo systemctl status ss_api
sudo journalctl -u ss_api | tail -20
