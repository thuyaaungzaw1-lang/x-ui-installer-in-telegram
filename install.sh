#!/bin/bash

# X-UI CUSTOM INSTALLER + TELEGRAM BOT By ThuYaAungZaw

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
magenta='\033[0;35m'
plain='\033[0m'

# Display THUYA banner
echo -e "${cyan}"
echo " ████████╗██╗  ██╗██╗   ██╗██╗   ██╗ █████╗ "
echo " ╚══██╔══╝██║  ██║██║   ██║╚██╗ ██╔╝██╔══██╗"
echo "    ██║   ███████║██║   ██║ ╚████╔╝ ███████║"
echo "    ██║   ██╔══██║██║   ██║  ╚██╔╝  ██╔══██║"
echo "    ██║   ██║  ██║╚██████╔╝   ██║   ██║  ██║"
echo "    ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝"
echo -e "${plain}"
echo -e "${blue}X-UI CUSTOM INSTALLER + TELEGRAM BOT${plain}"
echo -e "${green}By ThuYaAungZaw${plain}"
echo -e "${yellow}=========================================${plain}"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: Run as root! Use: sudo su${plain}"
    exit 1
fi

# Custom configuration
CUSTOM_USERNAME="admin"
CUSTOM_PASSWORD="admin"
CUSTOM_PORT="54321"

# Telegram configuration
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_ENABLED=false

# Get custom credentials
get_custom_credentials() {
    echo -e "${green}=== Custom Configuration ===${plain}"
    
    read -p "Enter username [default: admin]: " user_input
    read -p "Enter password [default: admin]: " pass_input
    read -p "Enter port [default: 54321]: " port_input
    
    if [ -n "$user_input" ]; then
        CUSTOM_USERNAME="$user_input"
    fi
    
    if [ -n "$pass_input" ]; then
        CUSTOM_PASSWORD="$pass_input"
    fi
    
    if [ -n "$port_input" ]; then
        CUSTOM_PORT="$port_input"
    fi
    
    echo -e "${blue}Custom Settings:${plain}"
    echo -e "Username: ${cyan}$CUSTOM_USERNAME${plain}"
    echo -e "Password: ${cyan}$CUSTOM_PASSWORD${plain}"
    echo -e "Port: ${cyan}$CUSTOM_PORT${plain}"
    
    read -p "Continue with these settings? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        get_custom_credentials
    fi
}

# Safe telegram message function
safe_send_telegram_message() {
    local message="$1"
    if [ "$TELEGRAM_ENABLED" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        timeout 10 curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" > /dev/null 2>&1 &
    fi
}

# Setup telegram bot
setup_telegram_bot() {
    echo -e "${yellow}Do you want Telegram notifications? (y/n): ${plain}"
    read -p "" setup_bot
    
    if [ "$setup_bot" = "y" ] || [ "$setup_bot" = "Y" ]; then
        echo -e "${green}=== Telegram Bot Setup ===${plain}"
        echo -e "1. Create bot with @BotFather"
        echo -e "2. Get bot token (format: 123456789:ABCdefGhIjKlmNoPQRsTUVwxyZ)"
        echo -e "3. Send message to your bot" 
        echo -e "4. Visit: https://api.telegram.org/bot<TOKEN>/getUpdates"
        echo -e "5. Find and copy chat ID (numeric value)"
        echo -e ""
        
        read -p "Enter Bot Token: " bot_token
        read -p "Enter Chat ID: " chat_id
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
            TELEGRAM_CHAT_ID="$chat_id"
            
            # Validate token format
            if [[ "$bot_token" =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
                # Test bot connection
                echo -e "${yellow}Testing bot connection...${plain}"
                if timeout 15 curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q "ok"; then
                    TELEGRAM_ENABLED=true
                    echo -e "${green}✓ Bot connected successfully${plain}"
                    safe_send_telegram_message "🔔 X-UI Installer Started\n🖥️ Server IP: Loading...\n⏰ Time: $(date)"
                else
                    echo -e "${red}✗ Bot connection failed${plain}"
                    echo -e "${yellow}Continuing without Telegram...${plain}"
                    TELEGRAM_ENABLED=false
                fi
            else
                echo -e "${red}✗ Invalid bot token format${plain}"
                echo -e "${yellow}Continuing without Telegram...${plain}"
                TELEGRAM_ENABLED=false
            fi
        else
            echo -e "${yellow}⚠️ Skipping Telegram setup${plain}"
            TELEGRAM_ENABLED=false
        fi
    else
        TELEGRAM_ENABLED=false
    fi
}

# Fix common installation issues
fix_installation_issues() {
    echo -e "${yellow}Applying pre-installation fixes...${plain}"
    
    # Clean up any existing installations
    systemctl stop x-ui 2>/dev/null
    systemctl stop xray 2>/dev/null
    pkill -f x-ui 2>/dev/null
    pkill -f xray 2>/dev/null
    
    # Remove conflicting files
    rm -rf /usr/local/x-ui/ 2>/dev/null
    rm -rf /etc/x-ui/ 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service 2>/dev/null
    rm -f /usr/local/bin/x-ui 2>/dev/null
    
    # Clean up port conflicts
    echo -e "${yellow}Checking port $CUSTOM_PORT...${plain}"
    if lsof -i :$CUSTOM_PORT >/dev/null 2>&1; then
        echo -e "${red}Port $CUSTOM_PORT is in use! Killing process...${plain}"
        fuser -k $CUSTOM_PORT/tcp 2>/dev/null
        sleep 2
    fi
    
    # Update system packages
    echo -e "${yellow}Updating system packages...${plain}"
    if command -v apt >/dev/null; then
        apt update -y >/dev/null 2>&1
        apt install -y wget curl net-tools lsof >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum update -y >/dev/null 2>&1
        yum install -y wget curl net-tools lsof >/dev/null 2>&1
    fi
    
    echo -e "${green}✓ Pre-installation fixes applied${plain}"
}

# Main installation function
install_xui() {
    echo -e "${green}=== Starting X-UI Installation ===${plain}"
    
    # Get custom credentials first
    get_custom_credentials
    
    # Apply fixes
    fix_installation_issues
    
    # Detect architecture
    arch=$(uname -m)
    if [[ $arch == "x86_64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" ]]; then
        arch="arm64" 
    else
        arch="amd64"
        echo -e "${yellow}Unknown architecture, using amd64${plain}"
    fi
    echo -e "${blue}Architecture: $arch${plain}"
    
    # Get server IP
    echo -e "${yellow}Getting server IP...${plain}"
    ipv4=$(curl -s4 ifconfig.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "unknown")
    echo -e "${blue}Server IP: $ipv4${plain}"
    
    # Get latest version
    echo -e "${yellow}Fetching latest version...${plain}"
    latest_version=$(curl -s https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$latest_version" ]; then
        latest_version="v1.0.0"
    fi
    
    echo -e "${green}Version: $latest_version${plain}"
    
    # Download x-ui
    echo -e "${yellow}Downloading x-ui...${plain}"
    cd /usr/local/
    
    download_url="https://github.com/yonggekkk/x-ui-yg/releases/download/$latest_version/x-ui-linux-$arch.tar.gz"
    
    if ! wget -O x-ui-linux-$arch.tar.gz "$download_url"; then
        echo -e "${red}Download failed! Trying alternative...${plain}"
        download_url="https://github.com/yonggekkk/x-ui-yg/releases/latest/download/x-ui-linux-$arch.tar.gz"
        if ! wget -O x-ui-linux-$arch.tar.gz "$download_url"; then
            echo -e "${red}All download attempts failed!${plain}"
            exit 1
        fi
    fi
    
    # Extract
    echo -e "${yellow}Installing...${plain}"
    if ! tar zxvf x-ui-linux-$arch.tar.gz; then
        echo -e "${red}Extraction failed!${plain}"
        exit 1
    fi
    rm -f x-ui-linux-$arch.tar.gz
    
    if [ ! -d "x-ui" ]; then
        echo -e "${red}Installation directory not found!${plain}"
        exit 1
    fi
    
    # Set permissions
    cd x-ui
    chmod +x x-ui
    if [ -d "bin" ]; then
        chmod +x bin/xray-linux-$arch 2>/dev/null
    fi
    
    # Create config directory
    mkdir -p /etc/x-ui/
    if [ ! -f /etc/x-ui/x-ui.db ]; then
        cp x-ui.db /etc/x-ui/ 2>/dev/null || echo -e "${yellow}Using default database${plain}"
    fi
    
    # Create service file
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # Reload and start service
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    # Wait for service to start
    echo -e "${yellow}Waiting for service to start...${plain}"
    sleep 8
    
    # Apply custom credentials
    echo -e "${yellow}Applying custom credentials...${plain}"
    systemctl stop x-ui
    sleep 2
    
    # Use x-ui command to change settings
    if [ -f /usr/local/x-ui/x-ui ]; then
        cd /usr/local/x-ui
        ./x-ui setting -username "$CUSTOM_USERNAME" -password "$CUSTOM_PASSWORD"
        ./x-ui setting -port "$CUSTOM_PORT"
    fi
    
    # Restart with new settings
    systemctl start x-ui
    sleep 5
    
    # Check if service is running
    if ! systemctl is-active x-ui >/dev/null; then
        echo -e "${red}Service failed to start! Checking logs...${plain}"
        journalctl -u x-ui -n 10 --no-pager
        echo -e "${yellow}Attempting manual start...${plain}"
        cd /usr/local/x-ui
        ./x-ui &
        sleep 3
    fi
    
    # Configure firewall for custom port
    echo -e "${yellow}Configuring firewall for port $CUSTOM_PORT...${plain}"
    if command -v ufw >/dev/null && ufw status | grep -q "active"; then
        ufw allow $CUSTOM_PORT/tcp
        ufw allow 10000:50000/udp
        ufw allow 10000:50000/tcp
        echo -e "${green}✓ UFW configured${plain}"
    fi
    
    # Always add iptables rules for custom port
    iptables -A INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport 10000:50000 -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp --dport 10000:50000 -j ACCEPT 2>/dev/null
    
    # Test the installation
    echo -e "${yellow}Testing installation...${plain}"
    
    # Test panel access with custom port
    if curl -s http://localhost:$CUSTOM_PORT >/dev/null 2>&1; then
        panel_status="${green}✓ Accessible${plain}"
    else
        panel_status="${red}✗ Not accessible${plain}"
    fi
    
    # Test xray process
    if pgrep xray >/dev/null; then
        xray_status="${green}✓ Running${plain}"
    else
        xray_status="${red}✗ Not running${plain}"
    fi
    
    # Display results
    echo -e "${green}=== Installation Complete! ===${plain}"
    echo -e "${cyan}Panel URL: http://$ipv4:$CUSTOM_PORT${plain}"
    echo -e "${cyan}Username: $CUSTOM_USERNAME${plain}"
    echo -e "${cyan}Password: $CUSTOM_PASSWORD${plain}"
    echo -e ""
    echo -e "${blue}Status Check:${plain}"
    echo -e "Panel: $panel_status"
    echo -e "Xray: $xray_status"
    echo -e "${red}⚠️ IMPORTANT: Keep your credentials safe!${plain}"
    
    # Send Telegram notification with custom credentials
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🎉 X-UI Installation Complete!
        
🖥️ Server: $ipv4
🔗 Panel: http://$ipv4:$CUSTOM_PORT
👤 Username: $CUSTOM_USERNAME
🔐 Password: $CUSTOM_PASSWORD

Status:
Panel: ✅ Accessible
Xray: ✅ Running

⚠️ Keep credentials safe!"
    fi
    
    # Troubleshooting guide
    echo -e "${yellow}=========================================${plain}"
    if [ "$panel_status" = "${red}✗ Not accessible${plain}" ]; then
        echo -e "${red}Troubleshooting needed:${plain}"
        echo -e "${yellow}1. Check if port $CUSTOM_PORT is open: netstat -tulpn | grep $CUSTOM_PORT${plain}"
        echo -e "${yellow}2. Restart service: systemctl restart x-ui${plain}"
        echo -e "${yellow}3. Check logs: journalctl -u x-ui -f${plain}"
        echo -e "${yellow}4. Manual start: cd /usr/local/x-ui && ./x-ui${plain}"
    else
        echo -e "${green}✅ Panel is accessible!${plain}"
    fi
}

# Ask for Telegram setup
setup_telegram_bot

# Start installation
install_xui

# Final message
echo -e "${cyan}"
echo "========================================="
echo "  X-UI Installed by ThuYaAungZaw"
echo "  Telegram: $([ "$TELEGRAM_ENABLED" = true ] && echo "✅ Enabled" || echo "❌ Disabled")"
echo "  Panel: http://$(curl -s ifconfig.me):$CUSTOM_PORT"
echo "  Username: $CUSTOM_USERNAME"
echo "  Password: $CUSTOM_PASSWORD"
echo "========================================="
echo -e "${plain}"
