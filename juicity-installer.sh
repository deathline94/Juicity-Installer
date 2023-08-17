#!/bin/bash

# Function to print characters with delay
print_with_delay() {
    text=$1
    delay=$2
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
}

# Introduction animation
echo ""
echo ""
print_with_delay "j" 0.1
print_with_delay "u" 0.1
print_with_delay "i" 0.1
print_with_delay "c" 0.1
print_with_delay "i" 0.1
print_with_delay "t" 0.1
print_with_delay "y" 0.1
print_with_delay "-" 0.1
print_with_delay "i" 0.1
print_with_delay "n" 0.1
print_with_delay "s" 0.1
print_with_delay "t" 0.1
print_with_delay "a" 0.1
print_with_delay "l" 0.1
print_with_delay "l" 0.1
print_with_delay "e" 0.1
print_with_delay "r" 0.1
print_with_delay " " 0.1
print_with_delay "b" 0.1
print_with_delay "y" 0.1
print_with_delay " " 0.1
print_with_delay "D" 0.1
print_with_delay "E" 0.1
print_with_delay "A" 0.1
print_with_delay "T" 0.1
print_with_delay "H" 0.1
print_with_delay "L" 0.1
print_with_delay "I" 0.1
print_with_delay "N" 0.1
print_with_delay "E" 0.1
print_with_delay " " 0.1
print_with_delay "|" 0.1
print_with_delay " " 0.1
print_with_delay "n" 0.1
print_with_delay "a" 0.1
print_with_delay "m" 0.1
print_with_delay "e" 0.1
print_with_delay "l" 0.1
print_with_delay "e" 0.1
print_with_delay "s" 0.1
print_with_delay " " 0.1
print_with_delay "g" 0.1
print_with_delay "h" 0.1
print_with_delay "o" 0.1
print_with_delay "u" 0.1
print_with_delay "l" 0.1
print_with_delay ""
echo ""
echo ""

# Install required packages
sudo apt-get update
sudo apt-get install -y unzip jq uuid-runtime

# Define the download link and destination path
DOWNLOAD_LINK="https://github.com/juicity/juicity/releases/download/v0.1.3/juicity-linux-x86_64.zip"
DESTINATION_PATH="/root/juicity-linux-x86_64.zip"

# Download the binary using wget
wget -O $DESTINATION_PATH $DOWNLOAD_LINK

# Unzip the downloaded file to /root/juicity
unzip $DESTINATION_PATH -d /root/juicity

if [[ ! -f /root/juicity/juicity-server ]]; then
    echo "Error: juicity-server binary not found!"
    exit 1
fi


# Make the binary executable (assuming it's named juicity-server in the unzipped directory)
chmod +x /root/juicity/juicity-server

# Optionally, you can remove the downloaded zip file after extraction
rm $DESTINATION_PATH

# Delete all files except juicity-server
find /root/juicity ! -name 'juicity-server' -type f -exec rm -f {} +

# Set permissions
chmod +x /root/juicity/juicity-server

# Create config.json
read -p "Enter listen port (or press enter to randomize): " PORT
[[ -z "$PORT" ]] && PORT=$((RANDOM % 65500 + 1))
read -p "Enter password: " PASSWORD
UUID=$(uuidgen)

# Generate private key
openssl ecparam -genkey -name prime256v1 -out /root/juicity/private.key

# Generate certificate using the private key
openssl req -new -x509 -days 36500 -key /root/juicity/private.key -out /root/juicity/fullchain.cer -subj "/CN=bing.com"

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

# Create systemd service file
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

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable juicity
sudo systemctl start juicity

# Generate and print the share link
SHARE_LINK=$(/root/juicity/./juicity-server generate-sharelink -c /root/juicity/config.json)
echo "Share Link: $SHARE_LINK"
