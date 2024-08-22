#!/bin/bash

# Prepare to test header: Authorization.hash(SECRET)
source env/bin/activate
IPv4=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^10|^127|^172|^192')

echo ""
echo "In first, check SECRET and SUDO_PASS in api_config.yml !!!"
echo ""
echo "Test ss_api.service endpoint:"
echo "http://$IPv4/link"
echo "Try to connect with headers from any rest client:"
echo Authorization: $(python3 -c"from passlib.hash import pbkdf2_sha256; print(pbkdf2_sha256.hash('${SECRET}'))")
echo ""

# If api_2_nginx_start_ss_api.sh don't started gunicorn ss_api.service, run this:
# uvicorn main:app --host 0.0.0.0 --port 8000

sudo ufw allow 8000/tcp comment "test uvicorn run ss_api main:app"
sudo ufw reload

uvicorn data.main:app --reload --host 0.0.0.0 --port 8000
