#!/bin/bash

# X-UI ONE-CLICK INSTALLER + TELEGRAM BOT By ThuYaAungZaw

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
echo -e "${blue}X-UI ONE-CLICK INSTALLER + TELEGRAM BOT${plain}"
echo -e "${green}By ThuYaAungZaw${plain}"
echo -e "${yellow}=========================================${plain}"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: Run as root! Use: sudo su${plain}"
    exit 1
fi

# Telegram configuration
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_ENABLED=false

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
        echo -e "2. Get bot token"
        echo -e "3. Send message to your bot"
        echo -e "4. Visit: https://api.telegram.org/bot<TOKEN>/getUpdates"
        echo -e "5. Find and copy chat ID"
        echo -e ""
        
        read -p "Enter Bot Token: " bot_token
        read -p "Enter Chat ID: " chat_id
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
            TELEGRAM_CHAT_ID="$chat_id"
            TELEGRAM_ENABLED=true
            
            # Test bot
            echo -e "${yellow}Testing bot...${plain}"
            if timeout 10 curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q "ok"; then
                echo -e "${green}✓ Bot connected${plain}"
                safe_send_telegram_message "🔔 X-UI Installer Started\n🖥️ Server: $(curl -s ifconfig.me)\n⏰ Time: $(date)"
            else
                echo -e "${yellow}⚠️ Bot test failed (may be network issue)${plain}"
                TELEGRAM_ENABLED=false
            fi
        else
            echo -e "${yellow}⚠️ Skipping Telegram setup${plain}"
        fi
    fi
}

# Main installation function
install_xui() {
    echo -e "${green}=== Starting X-UI Installation ===${plain}"
    
    # Cleanup old installation
    echo -e "${yellow}Cleaning up...${plain}"
    systemctl stop x-ui 2>/dev/null
    systemctl stop xray 2>/dev/null
    pkill -f x-ui 2>/dev/null
    pkill -f xray 2>/dev/null
    
    # Remove old files
    rm -rf /usr/local/x-ui/ 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service 2>/dev/null
    
    # Detect architecture
    arch=$(uname -m)
    if [[ $arch == "x86_64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" ]]; then
        arch="arm64" 
    else
        arch="amd64"
    fi
    echo -e "${blue}Architecture: $arch${plain}"
    
    # Get latest version
    echo -e "${yellow}Fetching latest version...${plain}"
    latest_version=$(curl -s https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest | grep tag_name | cut -d'"' -f4)
    
    if [ -z "$latest_version" ]; then
        echo -e "${red}Failed to get version. Using default.${plain}"
        latest_version="0.8.8"
    fi
    
    echo -e "${green}Version: $latest_version${plain}"
    
    # Download x-ui
    echo -e "${yellow}Downloading x-ui...${plain}"
    cd /usr/local/
    wget -O x-ui-linux-$arch.tar.gz "https://github.com/yonggekkk/x-ui-yg/releases/download/$latest_version/x-ui-linux-$arch.tar.gz"
    
    if [ $? -ne 0 ]; then
        echo -e "${red}Download failed!${plain}"
        exit 1
    fi
    
    # Extract
    echo -e "${yellow}Installing...${plain}"
    tar zxvf x-ui-linux-$arch.tar.gz
    rm -f x-ui-linux-$arch.tar.gz
    
    if [ ! -d "x-ui" ]; then
        echo -e "${red}Extraction failed!${plain}"
        exit 1
    fi
    
    # Set permissions
    cd x-ui
    chmod +x x-ui bin/xray-linux-$arch
    
    # Create config directory
    mkdir -p /etc/x-ui/
    if [ ! -f /etc/x-ui/x-ui.db ]; then
        cp x-ui.db /etc/x-ui/
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

    # Start service
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    # Wait for service to start
    sleep 5
    
    # Get IP
    ipv4=$(curl -s ifconfig.me)
    
    # Open firewall ports
    echo -e "${yellow}Configuring firewall...${plain}"
    if command -v ufw >/dev/null; then
        ufw allow 54321/tcp
        ufw allow 10000:50000/udp
        ufw allow 10000:50000/tcp
    fi
    
    # Basic iptables rules
    iptables -A INPUT -p tcp --dport 54321 -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport 10000:50000 -j ACCEPT 2>/dev/null
    
    echo -e "${green}=== Installation Complete! ===${plain}"
    echo -e "${cyan}Panel URL: http://$ipv4:54321${plain}"
    echo -e "${cyan}Username: admin${plain}"
    echo -e "${cyan}Password: admin${plain}"
    echo -e "${red}⚠️ Change default password after login!${plain}"
    
    # Send Telegram notification
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🎉 X-UI Installation Complete!
        
🖥️ Server: $ipv4
🔗 Panel: http://$ipv4:54321
👤 Username: admin
🔐 Password: admin

⚠️ Change password after login!"
    fi
    
    # Test services
    echo -e "${yellow}Testing services...${plain}"
    if systemctl is-active x-ui >/dev/null; then
        echo -e "${green}✓ x-ui service is running${plain}"
    else
        echo -e "${red}✗ x-ui service failed${plain}"
    fi
    
    if pgrep xray >/dev/null; then
        echo -e "${green}✓ xray is running${plain}"
    else
        echo -e "${red}✗ xray failed${plain}"
    fi
    
    echo -e "${green}=========================================${plain}"
    echo -e "${green}Installation completed successfully!${plain}"
    echo -e "${yellow}Access your panel at: http://$ipv4:54321${plain}"
}

# Ask for Telegram setup
setup_telegram_bot

# Start installation
install_xui

# Final message
echo -e "${cyan}"
echo "========================================="
echo "  X-UI Installed by ThuYaAungZaw"
echo "  Telegram Bot: $([ "$TELEGRAM_ENABLED" = true ] && echo "Enabled" || echo "Disabled")"
echo "  Panel URL: http://$(curl -s ifconfig.me):54321"
echo "  Default credentials: admin/admin"
echo "========================================="
echo -e "${plain}"
