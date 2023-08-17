#!/bin/bash

# ---- Install required packages ----
sudo apt-get update
sudo apt-get install -y unzip curl jq uuid-runtime openssl

# ---- Define directories and URLs ----
DOWNLOAD_DIR="/root/juicity"
DOWNLOAD_LOCATION="$DOWNLOAD_DIR/juicity.zip"
LATEST_RELEASE_URL="https://github.com/juicity/juicity/releases/download/v0.1.3/juicity-linux-x86_64.zip"

# ---- Create the download directory ----
mkdir -p "$DOWNLOAD_DIR"

# ---- Download the binary ----
curl -L "$LATEST_RELEASE_URL" -o "$DOWNLOAD_LOCATION"

# ---- Extract the binary ----
unzip "$DOWNLOAD_LOCATION" -d "$DOWNLOAD_DIR"

# ---- Set permissions for the server binary ----
chmod +x "$DOWNLOAD_DIR/juicity-server"

# ---- Generate config file ----
read -p "Enter listen port (or press enter to randomize): " PORT
[[ -z "$PORT" ]] && PORT=$((RANDOM % 65500 + 1))
read -p "Enter password: " PASSWORD
UUID=$(uuidgen)

# Generate private key and certificate
openssl ecparam -genkey -name prime256v1 -out "$DOWNLOAD_DIR/private.key"
openssl req -new -x509 -days 36500 -key "$DOWNLOAD_DIR/private.key" -out "$DOWNLOAD_DIR/fullchain.cer" -subj "/CN=bing.com"

# Create config.json
cat > "$DOWNLOAD_DIR/config.json" <<EOL
{
  "listen": ":$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "$DOWNLOAD_DIR/fullchain.cer",
  "private_key": "$DOWNLOAD_DIR/private.key",
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
ExecStart=$DOWNLOAD_DIR/juicity-server run -c $DOWNLOAD_DIR/config.json
StandardOutput=file:$DOWNLOAD_DIR/juicity-server.log
StandardError=file:$DOWNLOAD_DIR/juicity-server.log
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
SHARE_LINK=$($DOWNLOAD_DIR/juicity-server generate-sharelink -c $DOWNLOAD_DIR/config.json)
echo "Share Link: $SHARE_LINK"
