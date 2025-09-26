#!/bin/bash

# X-UI ALL IN ONE INSTALLER + UNINSTALLER + TELEGRAM BOT CONTROL
# By ThuYaAungZaw - Fixed Installation Version

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
magenta='\033[0;35m'
plain='\033[0m'

# Display THUYA banner
echo -e "${cyan}"
cat << "EOF"
 ████████╗██╗  ██╗██╗   ██╗██╗   ██╗ █████╗ 
 ╚══██╔══╝██║  ██║██║   ██║╚██╗ ██╔╝██╔══██╗
    ██║   ███████║██║   ██║ ╚████╔╝ ███████║
    ██║   ██╔══██║██║   ██║  ╚██╔╝  ██╔══██║
    ██║   ██║  ██║╚██████╔╝   ██║   ██║  ██║
    ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝
EOF
echo -e "${plain}"
echo -e "${blue}X-UI ALL IN ONE (INSTALLER + UNINSTALLER + BOT CONTROL)${plain}"
echo -e "${green}By ThuYaAungZaw${plain}"
echo -e "${yellow}=========================================${plain}"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: Run as root! Use: sudo su${plain}"
    exit 1
fi

# Global variables
CUSTOM_USERNAME="admin"
CUSTOM_PASSWORD="admin"
CUSTOM_PORT="54321"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_ENABLED=false
SERVER_IP=""
INSTALL_SUCCESS=false

# Get server IP function
get_server_ip() {
    SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "${blue}Server IP: $SERVER_IP${plain}"
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

# Check existing X-UI installation
check_existing_installation() {
    if systemctl is-active x-ui >/dev/null 2>&1 || [ -f "/usr/local/x-ui/x-ui" ] || [ -f "/etc/systemd/system/x-ui.service" ]; then
        return 0
    else
        return 1
    fi
}

# Fix installation issues
fix_installation_issues() {
    echo -e "${yellow}Applying pre-installation fixes...${plain}"
    
    # Clean up any existing installations
    systemctl stop x-ui 2>/dev/null
    systemctl stop x-ui-bot 2>/dev/null
    pkill -f x-ui 2>/dev/null
    pkill -f xray 2>/dev/null
    pkill -f "bot_control.sh" 2>/dev/null
    pkill -f "monitor.sh" 2>/dev/null
    
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
        apt install -y wget curl net-tools lsof sqlite3 jq >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum update -y >/dev/null 2>&1
        yum install -y wget curl net-tools lsof sqlite3 jq >/dev/null 2>&1
    fi
    
    echo -e "${green}✓ Pre-installation fixes applied${plain}"
}

# Get custom credentials
get_custom_credentials() {
    echo -e "${green}=== Custom Configuration ===${plain}"
    
    read -p "Enter username [default: admin]: " user_input
    [ -n "$user_input" ] && CUSTOM_USERNAME="$user_input"
    
    read -p "Enter password [default: admin]: " pass_input
    [ -n "$pass_input" ] && CUSTOM_PASSWORD="$pass_input"
    
    read -p "Enter port [default: 54321]: " port_input
    [ -n "$port_input" ] && CUSTOM_PORT="$port_input"
    
    echo -e "${blue}Custom Settings:${plain}"
    echo -e "Username: ${cyan}$CUSTOM_USERNAME${plain}"
    echo -e "Password: ${cyan}$CUSTOM_PASSWORD${plain}"
    echo -e "Port: ${cyan}$CUSTOM_PORT${plain}"
    
    read -p "Continue with these settings? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        get_custom_credentials
    fi
}

# Install X-UI function
install_xui() {
    echo -e "${green}=== Starting X-UI Installation ===${plain}"
    
    # Get credentials first
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
    
    # Get latest version
    echo -e "${yellow}Fetching latest version...${plain}"
    latest_version=$(curl -s https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$latest_version" ]; then
        latest_version="v1.0.0"
        echo -e "${yellow}Using default version: $latest_version${plain}"
    else
        echo -e "${green}Latest version: $latest_version${plain}"
    fi
    
    # Download x-ui
    echo -e "${yellow}Downloading x-ui...${plain}"
    cd /usr/local/
    
    download_url="https://github.com/yonggekkk/x-ui-yg/releases/download/$latest_version/x-ui-linux-$arch.tar.gz"
    
    if ! wget --timeout=30 -O x-ui-linux-$arch.tar.gz "$download_url"; then
        echo -e "${red}Download failed! Trying alternative URL...${plain}"
        download_url="https://github.com/yonggekkk/x-ui-yg/releases/latest/download/x-ui-linux-$arch.tar.gz"
        if ! wget --timeout=30 -O x-ui-linux-$arch.tar.gz "$download_url"; then
            echo -e "${red}All download attempts failed!${plain}"
            echo -e "${yellow}Please check your internet connection and try again.${plain}"
            return 1
        fi
    fi
    
    # Extract
    echo -e "${yellow}Installing...${plain}"
    if ! tar zxvf x-ui-linux-$arch.tar.gz; then
        echo -e "${red}Extraction failed!${plain}"
        return 1
    fi
    
    rm -f x-ui-linux-$arch.tar.gz
    
    if [ ! -d "x-ui" ]; then
        echo -e "${red}Installation directory not found!${plain}"
        return 1
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
    
    # Start service initially
    echo -e "${yellow}Starting x-ui service...${plain}"
    systemctl start x-ui
    
    # Wait for service to start
    echo -e "${yellow}Waiting for service to start...${plain}"
    sleep 10
    
    # Stop service to apply custom settings
    systemctl stop x-ui
    sleep 3
    
    # Apply custom credentials
    echo -e "${yellow}Applying custom credentials...${plain}"
    cd /usr/local/x-ui
    
    if [ -f "x-ui" ]; then
        ./x-ui setting -username "$CUSTOM_USERNAME" -password "$CUSTOM_PASSWORD"
        ./x-ui setting -port "$CUSTOM_PORT"
    else
        echo -e "${red}x-ui binary not found!${plain}"
        return 1
    fi
    
    # Restart with new settings
    echo -e "${yellow}Restarting with new settings...${plain}"
    systemctl start x-ui
    sleep 5
    
    # Check if service is running
    if systemctl is-active x-ui >/dev/null; then
        echo -e "${green}✓ X-UI service is running${plain}"
    else
        echo -e "${red}✗ X-UI service failed to start${plain}"
        echo -e "${yellow}Attempting manual start...${plain}"
        cd /usr/local/x-ui
        nohup ./x-ui > /var/log/x-ui.log 2>&1 &
        sleep 3
    fi
    
    # Configure firewall for custom port
    echo -e "${yellow}Configuring firewall for port $CUSTOM_PORT...${plain}"
    if command -v ufw >/dev/null && ufw status | grep -q "active"; then
        ufw allow $CUSTOM_PORT/tcp >/dev/null 2>&1
        ufw allow 10000:50000/udp >/dev/null 2>&1
        ufw allow 10000:50000/tcp >/dev/null 2>&1
        echo -e "${green}✓ UFW configured${plain}"
    fi
    
    # Add iptables rules
    iptables -A INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport 10000:50000 -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp --dport 10000:50000 -j ACCEPT 2>/dev/null
    
    # Test the installation
    echo -e "${yellow}Testing installation...${plain}"
    
    # Test panel access with custom port
    if curl -s --connect-timeout 10 http://127.0.0.1:$CUSTOM_PORT >/dev/null 2>&1; then
        panel_status="${green}✓ Accessible${plain}"
        INSTALL_SUCCESS=true
    else
        panel_status="${red}✗ Not accessible${plain}"
        INSTALL_SUCCESS=false
    fi
    
    # Test xray process
    if pgrep xray >/dev/null; then
        xray_status="${green}✓ Running${plain}"
    else
        xray_status="${red}✗ Not running${plain}"
    fi
    
    # Display results
    echo -e "${green}=== Installation Complete! ===${plain}"
    echo -e "${cyan}Panel URL: http://$SERVER_IP:$CUSTOM_PORT${plain}"
    echo -e "${cyan}Username: $CUSTOM_USERNAME${plain}"
    echo -e "${cyan}Password: $CUSTOM_PASSWORD${plain}"
    echo -e ""
    echo -e "${blue}Status Check:${plain}"
    echo -e "Panel: $panel_status"
    echo -e "Xray: $xray_status"
    
    if [ "$INSTALL_SUCCESS" = true ]; then
        echo -e "${green}✅ X-UI installed successfully!${plain}"
    else
        echo -e "${red}❌ X-UI installation may have issues${plain}"
    fi
    
    # Send Telegram notification
    if [ "$TELEGRAM_ENABLED" = true ] && [ "$INSTALL_SUCCESS" = true ]; then
        safe_send_telegram_message "🎉 X-UI Installation Complete!

🖥️ Server: $SERVER_IP
🔗 Panel: http://$SERVER_IP:$CUSTOM_PORT
👤 Username: $CUSTOM_USERNAME
🔐 Password: $CUSTOM_PASSWORD

Status:
Panel: ✅ Accessible
Xray: ✅ Running

⚠️ Keep credentials safe!"
    elif [ "$TELEGRAM_ENABLED" = true ] && [ "$INSTALL_SUCCESS" = false ]; then
        safe_send_telegram_message "⚠️ X-UI Installation Issues

🖥️ Server: $SERVER_IP
🔗 Panel: http://$SERVER_IP:$CUSTOM_PORT

Status:
Panel: ❌ Not Accessible
Xray: $([ "$xray_status" = "${green}✓ Running${plain}" ] && echo "✅ Running" || echo "❌ Not Running")

Please check the installation manually."
    fi
    
    return 0
}

# Setup telegram bot
setup_telegram_bot() {
    echo -e "${yellow}Do you want Telegram notifications and bot control? (y/n): ${plain}"
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
                    safe_send_telegram_message "🔔 X-UI Installer Started\n🖥️ Server IP: $SERVER_IP\n⏰ Time: $(date)"
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

# UNINSTALLER FUNCTION
uninstall_xui() {
    echo -e "${red}=== X-UI UNINSTALLER ===${plain}"
    
    if ! check_existing_installation; then
        echo -e "${yellow}No X-UI installation found!${plain}"
        return 1
    fi
    
    echo -e "${yellow}This will completely remove X-UI and all related data!${plain}"
    read -p "Are you sure you want to uninstall? (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${green}Uninstall cancelled.${plain}"
        return 0
    fi
    
    echo -e "${yellow}Starting uninstallation...${plain}"
    
    # Stop services
    echo -e "${yellow}Stopping services...${plain}"
    systemctl stop x-ui 2>/dev/null
    systemctl stop x-ui-bot 2>/dev/null
    pkill -f x-ui 2>/dev/null
    pkill -f xray 2>/dev/null
    
    # Disable services
    systemctl disable x-ui 2>/dev/null
    systemctl disable x-ui-bot 2>/dev/null
    
    # Remove systemd services
    echo -e "${yellow}Removing services...${plain}"
    rm -f /etc/systemd/system/x-ui.service 2>/dev/null
    rm -f /etc/systemd/system/x-ui-bot.service 2>/dev/null
    systemctl daemon-reload
    
    # Remove installed files
    echo -e "${yellow}Removing files...${plain}"
    rm -rf /usr/local/x-ui/ 2>/dev/null
    rm -rf /etc/x-ui/ 2>/dev/null
    rm -f /usr/local/bin/x-ui 2>/dev/null
    
    # Clean up processes
    pkill -f "bot_control.sh" 2>/dev/null
    pkill -f "monitor.sh" 2>/dev/null
    
    echo -e "${green}✓ X-UI uninstalled successfully!${plain}"
    
    # Send Telegram notification
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🗑️ X-UI Completely Uninstalled
        
✅ All services stopped
✅ Files removed
✅ System cleaned

Server: $SERVER_IP
Time: $(date)"
    fi
    
    return 0
}

# Show installation status
show_status() {
    echo -e "${green}=== X-UI STATUS ===${plain}"
    
    if check_existing_installation; then
        echo -e "X-UI Status: ${green}Installed${plain}"
        
        # Check services
        if systemctl is-active x-ui >/dev/null 2>&1; then
            echo -e "Service: ${green}Running${plain}"
        else
            echo -e "Service: ${red}Stopped${plain}"
        fi
        
        if pgrep xray >/dev/null; then
            echo -e "Xray: ${green}Running${plain}"
        else
            echo -e "Xray: ${red}Stopped${plain}"
        fi
        
        # Check panel access
        if curl -s --connect-timeout 5 http://127.0.0.1:$CUSTOM_PORT >/dev/null 2>&1; then
            echo -e "Panel: ${green}Accessible${plain}"
        else
            echo -e "Panel: ${red}Not Accessible${plain}"
        fi
        
    else
        echo -e "X-UI Status: ${red}Not Installed${plain}"
    fi
}

# Main menu function
show_main_menu() {
    echo -e "${cyan}"
    echo "========================================="
    echo "          X-UI MANAGEMENT MENU"
    echo "========================================="
    echo -e "${plain}"
    
    if check_existing_installation; then
        echo -e "${green}✅ X-UI is installed${plain}"
        show_status
        echo -e ""
        echo -e "${yellow}Available actions:${plain}"
        echo -e "1. ${blue}Reinstall/Update X-UI${plain}"
        echo -e "2. ${red}Uninstall X-UI${plain}"
        echo -e "3. ${green}Show Status${plain}"
        echo -e "4. ${magenta}Exit${plain}"
    else
        echo -e "${red}❌ X-UI is not installed${plain}"
        echo -e ""
        echo -e "${yellow}Available actions:${plain}"
        echo -e "1. ${green}Install X-UI${plain}"
        echo -e "2. ${cyan}Exit${plain}"
    fi
    
    echo -e ""
}

# Main execution flow
main() {
    get_server_ip
    
    while true; do
        show_main_menu
        
        read -p "Select option (number): " menu_choice
        
        case $menu_choice in
            1)
                if check_existing_installation; then
                    echo -e "${yellow}X-UI is already installed. Do you want to reinstall?${plain}"
                    read -p "This will remove the current installation. Continue? (y/n): " reinstall_confirm
                    if [ "$reinstall_confirm" = "y" ] || [ "$reinstall_confirm" = "Y" ]; then
                        uninstall_xui
                        sleep 2
                    else
                        echo -e "${green}Reinstall cancelled.${plain}"
                        continue
                    fi
                fi
                
                setup_telegram_bot
                install_xui
                
                if [ "$INSTALL_SUCCESS" = true ]; then
                    echo -e "${green}✅ Installation completed successfully!${plain}"
                else
                    echo -e "${red}❌ Installation may have issues. Please check manually.${plain}"
                fi
                ;;
            2)
                if check_existing_installation; then
                    uninstall_xui
                else
                    echo -e "${green}Goodbye!${plain}"
                    exit 0
                fi
                ;;
            3)
                show_status
                ;;
            4|"")
                echo -e "${green}Goodbye!${plain}"
                exit 0
                ;;
            *)
                echo -e "${red}Invalid option! Please try again.${plain}"
                ;;
        esac
        
        echo -e ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Start the script
main
