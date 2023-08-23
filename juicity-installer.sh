#!/bin/bash

# Function to print characters with delay
print_with_delay() {
    local text="$1"
    local delay="$2"

    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
}

# Introduction animation
intro_text="juicity-installer by DEATHLINE | nameless ghouls"
delay=0.1

echo ""
echo ""
print_with_delay "$intro_text" "$delay"
echo ""
echo ""

# Introduction Rainbow animation

colors=("31" "91" "33" "93" "32" "92" "34" "94" "35" "95" "36" "96")
text="update by samsesh"
delay=0.2

for ((i = 0; i < ${#text}; i++)); do
    color="${colors[$((i % ${#colors[@]}))]}"
    char="${text:$i:1}"
    echo -n -e "\e[${color}m$char\e[0m"
    sleep "$delay"
done
echo ""

req() {
    # Install required packages
    sudo apt-get update
    sudo apt-get install -y unzip jq uuid-runtime
}
install_juicity() {
    # Detect OS and download the corresponding release
    OS=$(uname -s)
    if [ "$OS" == "Linux" ]; then
        BINARY_NAME="juicity-linux-x86_64.zip"
    else
        echo "Unsupported OS: $OS"
        exit 1
    fi

    LATEST_RELEASE_URL=$(curl --silent "https://api.github.com/repos/juicity/juicity/releases" | jq -r '.[0].assets[] | select(.name == "'$BINARY_NAME'") | .browser_download_url')

    # Download and extract to /root/juicity
    mkdir -p /root/juicity
    curl -L $LATEST_RELEASE_URL -o /root/juicity/juicity.zip
    unzip /root/juicity/juicity.zip -d /root/juicity

    # Delete all files except juicity-server
    find /root/juicity ! -name 'juicity-server' -type f -exec rm -f {} +

    # Set permissions
    chmod +x /root/juicity/juicity-server
}

conf() {
    # Create config.json
    read -p "Enter listen port (or press enter to randomize): " PORT
    [[ -z "$PORT" ]] && PORT=$((RANDOM % 65500 + 1))
    read -p "Enter password: " PASSWORD
    UUID=$(uuidgen)

    # Generate private key
    openssl ecparam -genkey -name prime256v1 -out /root/juicity/private.key

    # Generate certificate using the private key
    # Ask the user for input
    read -p "Enter sni (or press enter to www.speedtest.net): " sni

    # Set default value if input is null
    if [ -z "$sni" ]; then
        sni="www.speedtest.net"
    fi

    # Generate the certificate
    openssl req -new -x509 -days 36500 -key /root/juicity/private.key -out /root/juicity/fullchain.cer -subj "/CN=$sni"

    cat >/root/juicity/config.json <<EOL
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
}
serviceC() {
    # Create systemd service file
    cat >/etc/systemd/system/juicity.service <<EOL
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
    sudo systemctl restart juicity
}

generate() {
    ipv4=$(curl -s ifconfig.me)
    ipv6=$(curl -6 ifconfig.co)
    config_file="/root/juicity/config.json"
    # Generate and print the share link
    input=$(/root/juicity/./juicity-server generate-sharelink -c /root/juicity/config.json)
    protocol=$(echo "$input" | awk -F '://' '{print $1}')
    path_and_query=$(echo "$input" | awk -F '?' '{print $2}' | awk -F '#' '{print $1}')
    hash=$(echo "$input" | awk -F '#' '{print $2}')
    uuid=$(jq -r '.users | keys[0]' "$config_file")
    password=$(jq -r '.users | .["'${uuid}'"]' "$config_file")
    port=$(jq -r '.listen' "$config_file")

    # Constructing the new output
    SHARE_LINK_IP_4="$protocol://${uuid}:${password}@${ipv4}${port}/?allow_insecure=true&${path_and_query}#juicity"
    SHARE_LINK_IP_6="$protocol://${uuid}:${password}@[${ipv6}]${port}/?allow_insecure=true&${path_and_query}#juicity"

    # Constructing the modified output
    if [ -n "$ipv4" ] && [ -n "$ipv6" ]; then
        echo "You have both IPv4 and IPv6 addresses."
        echo "Choose an option:"
        echo "1. Display IPv4 config"
        echo "2. Display IPv6 config"
        echo "3. Display both IPv4 and IPv6 config"

        read -p "Enter your choice (1, 2, or 3): " choice

        case $choice in
        1)
            echo "IPv4 config:"
            echo $SHARE_LINK_IP_4
            ;;
        2)
            echo "IPv6 address:"
            echo $SHARE_LINK_IP_6
            ;;
        3)
            echo "IPv4 config:"
            echo $SHARE_LINK_IP_4
            echo ""
            echo "IPv6 address:"
            echo $SHARE_LINK_IP_6
            ;;
        *)
            echo "Invalid choice. Exiting."
            ;;
        esac
    elif [ -n "$ipv4" ]; then
        echo "IPv4 config:"
        echo $SHARE_LINK_IP_4
    elif [ -n "$ipv6" ]; then
        echo "IPv6 address:"
        echo $SHARE_LINK_IP_6
    else
        echo "No IP address found."
    fi
}

service_file="/etc/systemd/system/juicity.service"

if [ -f "$service_file" ]; then
    echo "You have already installed the juicity.service script."
    echo "What would you like to do?"
    echo "1. View the configuration"
    echo "2. Remove the script"

    read -p "Enter your choice (1 or 2): " choice

    case $choice in
    1)
        generate
        exit
        ;;
    2)
        systemctl disable juicity
        systemctl stop juicity
        systemctl daemon-reload
        rm -rf "$service_file"
        rm -rf /root/juicity
        echo "The juicity.service script has been removed."
        exit
        ;;
    *)
        echo "Invalid choice. Exiting."
        ;;
    esac
else
    req
    install_juicity
    conf
    serviceC
    generate
fi
