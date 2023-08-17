#!/bin/bash

# ---- Install required packages ----
sudo apt-get update
sudo apt-get install -y unzip jq uuid-runtime

# ---- Download the binary ----
LATEST_RELEASE_URL="https://github.com/juicity/juicity/releases/download/v0.1.3/juicity-linux-x86_64.zip"
curl -L "$LATEST_RELEASE_URL" -o "/root/juicity/juicity.zip"

# ---- Extract the binary ----
mkdir -p /root/juicity
unzip /root/juicity/juicity.zip -d /root/juicity

# ---- Cleanup: Delete all files except juicity-server ----
find /root/juicity ! -name 'juicity-server' -type f -exec rm -f {} +

# ---- Set permissions ----
chmod +x /root/juicity/juicity-server

# ---- Generate config file ----
read -p "Enter listen port (or press enter to randomize): " PORT
[[ -z "$PORT" ]] && PORT=$((RANDOM % 65500 + 1))
read -p "Enter password: " PASSWORD
UUID=$(uuidgen)

# Generate private key and certificate
openssl ecparam -genkey -name prime256v1 -out /root/juicity/private.key
openssl req -new -x509 -days 36500 -key /root/juicity/private.key -out /root/juicity/fullchain.cer -subj "/CN=bing.com"

# Create config.json
cat > /root/juicity/config.json <<EOL
{
  "listen": ":$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "/root/juicity/fullchain.cer",
  "private_key": "/root/juicity/private.key",
  "congestion_control": "bbr",
  "log_level": "info"
}
EOL

# ---- Setup systemd service ----
cat > /etc/systemd/system/juicity.service <<EOL
[Unit]
Description=juicity-server Service
Documentation=https://github.com/juicity/juicity
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/root/juicity/./juicity-server run -c /root/juicity/config.json
StandardOutput=file:/root/juicity/juicity-server.log
StandardError=file:/root/juicity/juicity-server.log
Restart=on-failure
LimitNPROC=512
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOL

# ---- Start the service ----
sudo systemctl daemon-reload
sudo systemctl enable juicity
sudo systemctl start juicity

# ---- Generate and print the share link ----
SHARE_LINK=$(/root/juicity/./juicity-server generate-sharelink -c /root/juicity/config.json)
echo "Share Link: $SHARE_LINK"
