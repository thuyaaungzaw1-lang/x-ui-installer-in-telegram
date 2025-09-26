#!/bin/bash

# X-UI AUTO INSTALLER & FIXER With Telegram Bot By ThuYaAungZaw

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
magenta='\033[0;35m'
plain='\033[0m'

# Default credentials
XUI_USERNAME="admin"
XUI_PASSWORD="admin"
XUI_PORT="54321"

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN="7636671730:AAFs_QCAynp0WI4goAEwDArW8V_YkfnrnN0"
TELEGRAM_CHAT_ID="8231129863"
TELEGRAM_ENABLED=false

# Get system information
get_system_info() {
    # OS info
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os="$NAME $VERSION"
    else
        os=$(cat /etc/issue | head -n1 | awk '{print $1,$2,$3}')
    fi

    # Kernel
    kernel=$(uname -r)

    # Architecture
    arch=$(uname -m)
    if [[ $arch == "x86_64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" ]]; then
        arch="arm64"
    else
        arch="amd64"
    fi

    # Virtualization
    if systemd-detect-virt &>/dev/null; then
        virt=$(systemd-detect-virt)
    else
        virt="unknown"
    fi

    # BBR status
    if sysctl net.ipv4.tcp_congestion_control &>/dev/null; then
        bbr=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    else
        bbr="unknown"
    fi

    # IP addresses
    ipv4=$(curl -s4 ifconfig.me 2>/dev/null || echo "No IPv4")
    ipv6=$(curl -s6 ifconfig.me 2>/dev/null || echo "No IPv6")

    # Location
    location=$(curl -s ipinfo.io/city 2>/dev/null || echo "Unknown"), $(curl -s ipinfo.io/country 2>/dev/null || echo "Unknown")
}

# Telegram Bot Functions
setup_telegram_bot() {
    echo -e "${yellow}=== Telegram Bot Setup ===${plain}"
    read -p "Do you want to setup Telegram bot notifications? (y/n): " setup_bot
    
    if [ "$setup_bot" = "y" ] || [ "$setup_bot" = "Y" ]; then
        echo -e "${green}How to get Telegram Bot Token:${plain}"
        echo -e "1. Search for @BotFather on Telegram"
        echo -e "2. Send /newbot command"
        echo -e "3. Follow instructions to create bot"
        echo -e "4. Copy the bot token"
        echo -e ""
        echo -e "${green}How to get Chat ID:${plain}"
        echo -e "1. Send a message to your bot"
        echo -e "2. Visit: https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
        echo -e "3. Find 'chat' object and copy the 'id' value"
        echo -e ""
        
        read -p "Enter your Telegram Bot Token: " bot_token
        read -p "Enter your Chat ID: " chat_id
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
            TELEGRAM_CHAT_ID="$chat_id"
            TELEGRAM_ENABLED=true
            
            # Save to config file
            mkdir -p /etc/x-ui-telegram/
            cat > /etc/x-ui-telegram/config.conf << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
TELEGRAM_ENABLED=true
EOF
            echo -e "${green}Telegram bot configured successfully!${plain}"
            send_telegram_message "🔔 X-UI Installer Notification Test\n✅ Bot configured successfully!\n🖥️ Server: $ipv4"
        else
            echo -e "${red}Bot token and chat ID are required!${plain}"
            TELEGRAM_ENABLED=false
        fi
    else
        TELEGRAM_ENABLED=false
        echo -e "${yellow}Telegram notifications disabled${plain}"
    fi
}

send_telegram_message() {
    local message="$1"
    if [ "$TELEGRAM_ENABLED" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" > /dev/null 2>&1 &
    fi
}

load_telegram_config() {
    if [ -f /etc/x-ui-telegram/config.conf ]; then
        source /etc/x-ui-telegram/config.conf
        if [ "$TELEGRAM_ENABLED" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
            echo -e "${green}Telegram bot configuration loaded${plain}"
        else
            TELEGRAM_ENABLED=false
        fi
    fi
}

# Check service status
check_services() {
    if systemctl is-active x-ui &>/dev/null; then
        xui_status="Running"
    else
        xui_status="Not running"
    fi

    if systemctl is-enabled x-ui &>/dev/null; then
        xui_autostart="Enabled"
    else
        xui_autostart="Disabled"
    fi

    if systemctl is-active xray &>/dev/null; then
        xray_status="Active"
    else
        xray_status="Inactive"
    fi
}

# Fix firewall and port issues
fix_firewall_ports() {
    echo -e "${yellow}=== Fixing Firewall and Port Issues ===${plain}"
    
    # Detect which firewall is being used
    if command -v ufw &> /dev/null; then
        echo -e "${blue}UFW firewall detected${plain}"
        ufw allow $XUI_PORT/tcp
        ufw allow 10000:50000/udp
        ufw allow 10000:50000/tcp
        ufw reload
        echo -e "${green}UFW ports opened${plain}"
    fi
    
    if command -v firewall-cmd &> /dev/null; then
        echo -e "${blue}FirewallD detected${plain}"
        firewall-cmd --permanent --add-port=$XUI_PORT/tcp
        firewall-cmd --permanent --add-port=10000-50000/udp
        firewall-cmd --permanent --add-port=10000-50000/tcp
        firewall-cmd --reload
        echo -e "${green}FirewallD ports opened${plain}"
    fi
    
    # Always update iptables
    echo -e "${blue}Updating iptables${plain}"
    iptables -A INPUT -p tcp --dport $XUI_PORT -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport 10000:50000 -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp --dport 10000:50000 -j ACCEPT 2>/dev/null
    
    echo -e "${green}Firewall and port fixes applied${plain}"
}

# Fix xray service issues
fix_xray_service() {
    echo -e "${yellow}=== Fixing Xray Service ===${plain}"
    
    # Create xray service file if it doesn't exist
    if [ ! -f /etc/systemd/system/xray.service ]; then
        cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/x-ui/bin/xray-linux-${arch} run -config /usr/local/x-ui/bin/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
        echo -e "${green}Xray service file created${plain}"
    fi
    
    systemctl daemon-reload
    systemctl enable xray
    systemctl start xray
    
    # Wait and check status
    sleep 3
    if systemctl is-active xray &>/dev/null; then
        echo -e "${green}Xray service is now running${plain}"
    else
        echo -e "${red}Xray service failed to start${plain}"
        journalctl -u xray -n 10 --no-pager
    fi
}

# Fix configuration issues
fix_configuration() {
    echo -e "${yellow}=== Fixing Configuration Issues ===${plain}"
    
    # Ensure config directory exists
    mkdir -p /etc/x-ui/
    
    # Check if x-ui is installed
    if [ ! -f /usr/local/x-ui/x-ui ]; then
        echo -e "${red}x-ui is not installed! Please install first.${plain}"
        return 1
    fi
    
    # Restart services properly
    systemctl stop x-ui
    systemctl stop xray
    sleep 2
    
    systemctl start xray
    systemctl start x-ui
    sleep 3
    
    echo -e "${green}Configuration fixes applied${plain}"
}

# Comprehensive connection test
test_connection() {
    echo -e "${yellow}=== Testing Connection ===${plain}"
    
    local test_result="🔍 *Connection Test Results*\n\n"
    
    # Test panel access
    echo -e "${blue}Testing panel access...${plain}"
    if curl -s http://localhost:$XUI_PORT > /dev/null; then
        echo -e "${green}✓ Panel is accessible locally${plain}"
        test_result+="✅ Panel: Accessible locally\n"
    else
        echo -e "${red}✗ Panel not accessible locally${plain}"
        test_result+="❌ Panel: Not accessible locally\n"
    fi
    
    # Test xray process
    echo -e "${blue}Testing xray process...${plain}"
    if pgrep -x xray > /dev/null; then
        echo -e "${green}✓ Xray is running${plain}"
        test_result+="✅ Xray: Running\n"
    else
        echo -e "${red}✗ Xray is not running${plain}"
        test_result+="❌ Xray: Not running\n"
    fi
    
    # Test ports
    echo -e "${blue}Testing ports...${plain}"
    if netstat -tulpn | grep ":$XUI_PORT" > /dev/null; then
        echo -e "${green}✓ Panel port $XUI_PORT is listening${plain}"
        test_result+="✅ Port $XUI_PORT: Listening\n"
    else
        echo -e "${red}✗ Panel port $XUI_PORT is not listening${plain}"
        test_result+="❌ Port $XUI_PORT: Not listening\n"
    fi
    
    # Send test results to Telegram
    test_result+="\n🖥️ Server: $ipv4\n📍 Location: $location"
    send_telegram_message "$test_result"
    
    echo -e "${green}Connection test completed${plain}"
}

# Safe service control functions
safe_stop_service() {
    local service_name=$1
    if systemctl is-active "$service_name" &>/dev/null; then
        systemctl stop "$service_name"
        echo -e "${green}Stopped $service_name${plain}"
    else
        echo -e "${yellow}$service_name is not running or not found${plain}"
    fi
}

safe_disable_service() {
    local service_name=$1
    if systemctl is-enabled "$service_name" &>/dev/null; then
        systemctl disable "$service_name"
        echo -e "${green}Disabled $service_name${plain}"
    else
        echo -e "${yellow}$service_name is not enabled or not found${plain}"
    fi
}

safe_remove_file() {
    local file_path=$1
    if [ -f "$file_path" ] || [ -d "$file_path" ]; then
        rm -rf "$file_path"
        echo -e "${green}Removed: $file_path${plain}"
    else
        echo -e "${yellow}Not found: $file_path${plain}"
    fi
}

# Completely remove old x-ui installations
cleanup_old_installation() {
    echo -e "${yellow}Cleaning up old x-ui installations...${plain}"
    
    # Stop all possible x-ui related services safely
    echo -e "${blue}Stopping services...${plain}"
    safe_stop_service "x-ui"
    safe_stop_service "xui"
    safe_stop_service "xray"
    
    # Kill any remaining processes
    echo -e "${blue}Killing processes...${plain}"
    pkill -f x-ui 2>/dev/null && echo -e "${green}Killed x-ui processes${plain}" || echo -e "${yellow}No x-ui processes found${plain}"
    pkill -f xray 2>/dev/null && echo -e "${green}Killed xray processes${plain}" || echo -e "${yellow}No xray processes found${plain}"
    
    # Disable services safely
    echo -e "${blue}Disabling services...${plain}"
    safe_disable_service "x-ui"
    safe_disable_service "xui"
    safe_disable_service "xray"
    
    # Remove all possible x-ui directories
    echo -e "${blue}Removing directories...${plain}"
    safe_remove_file "/usr/local/x-ui/"
    safe_remove_file "/usr/local/xui/"
    safe_remove_file "/etc/x-ui/"
    safe_remove_file "/etc/xui/"
    safe_remove_file "/root/x-ui/"
    safe_remove_file "/home/x-ui/"
    
    # Remove all possible service files
    echo -e "${blue}Removing service files...${plain}"
    safe_remove_file "/etc/systemd/system/x-ui.service"
    safe_remove_file "/etc/systemd/system/xui.service"
    safe_remove_file "/usr/lib/systemd/system/x-ui.service"
    safe_remove_file "/usr/lib/systemd/system/xui.service"
    
    # Remove all possible binary files
    echo -e "${blue}Removing binary files...${plain}"
    safe_remove_file "/usr/local/bin/x-ui"
    safe_remove_file "/usr/bin/x-ui"
    safe_remove_file "/usr/local/bin/xray"
    safe_remove_file "/usr/bin/xray"
    
    # Remove all possible config files
    echo -e "${blue}Removing config files...${plain}"
    safe_remove_file "/etc/x-ui.db"
    safe_remove_file "/etc/xui.db"
    safe_remove_file "/root/x-ui.db"
    safe_remove_file "/home/x-ui.db"
    
    # Remove all possible log files
    echo -e "${blue}Cleaning log files...${plain}"
    safe_remove_file "/var/log/x-ui.log"
    safe_remove_file "/var/log/xui.log"
    safe_remove_file "/var/log/xray.log"
    
    # Remove all possible temporary files
    echo -e "${blue}Cleaning temporary files...${plain}"
    safe_remove_file "/tmp/x-ui*"
    safe_remove_file "/tmp/xray*"
    
    # Reload systemd
    echo -e "${blue}Reloading systemd...${plain}"
    systemctl daemon-reload 2>/dev/null && echo -e "${green}Systemd reloaded${plain}" || echo -e "${yellow}Systemd reload failed${plain}"
    systemctl reset-failed 2>/dev/null && echo -e "${green}Reset failed services${plain}" || echo -e "${yellow}Reset failed${plain}"
    
    echo -e "${green}Old x-ui installation cleanup completed!${plain}"
}

# Check if x-ui is already installed
check_existing_installation() {
    if [ -f /usr/local/x-ui/x-ui ] || [ -f /usr/local/bin/x-ui ] || [ -f /usr/bin/x-ui ] || \
       systemctl is-active x-ui &>/dev/null || systemctl is-active xui &>/dev/null || \
       pgrep -f x-ui &>/dev/null; then
        echo -e "${yellow}Existing x-ui installation detected${plain}"
        return 0  # Existing installation found
    else
        echo -e "${green}No existing x-ui installation found${plain}"
        return 1  # No existing installation
    fi
}

# Set custom credentials
set_credentials() {
    echo -e "${yellow}Set custom credentials for x-ui panel${plain}"
    echo -e "${green}Leave blank to use default values${plain}"
    
    read -p "Enter username [default: admin]: " custom_user
    read -p "Enter password [default: admin]: " custom_pass
    read -p "Enter port [default: 54321]: " custom_port
    
    if [ -n "$custom_user" ]; then
        XUI_USERNAME="$custom_user"
    fi
    
    if [ -n "$custom_pass" ]; then
        XUI_PASSWORD="$custom_pass"
    fi
    
    if [ -n "$custom_port" ]; then
        XUI_PORT="$custom_port"
    fi
    
    echo -e "${green}Credentials set:${plain}"
    echo -e "Username: ${cyan}$XUI_USERNAME${plain}"
    echo -e "Password: ${cyan}$XUI_PASSWORD${plain}"
    echo -e "Port: ${cyan}$XUI_PORT${plain}"
    
    read -p "Continue with these settings? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        set_credentials
    fi
}

# Install x-ui with automatic fixes
install_xui() {
    # Check for existing installation
    if check_existing_installation; then
        echo -e "${red}Existing x-ui installation detected!${plain}"
        read -p "Do you want to completely remove the old installation? (y/n): " remove_old
        if [ "$remove_old" = "y" ] || [ "$remove_old" = "Y" ]; then
            cleanup_old_installation
            echo -e "${green}Proceeding with fresh installation...${plain}"
        else
            echo -e "${yellow}Installation cancelled.${plain}"
            read -p "Press Enter to continue..."
            return
        fi
    fi
    
    echo -e "${green}Starting x-ui installation...${plain}"
    
    # Ask for custom credentials
    set_credentials
    
    # Create directory
    cd /usr/local/
    if [ -d "/usr/local/x-ui/" ]; then
        rm -rf /usr/local/x-ui/
    fi

    echo -e "${green}Architecture: ${arch}${plain}"

    # Get latest version
    echo -e "${yellow}Fetching latest version...${plain}"
    last_version=$(curl -s "https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$last_version" ]; then
        echo -e "${red}Failed to get latest version${plain}"
        return 1
    fi

    echo -e "${green}Latest version: ${last_version}${plain}"

    # Download
    echo -e "${yellow}Downloading x-ui...${plain}"
    wget -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/yonggekkk/x-ui-yg/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"

    if [ $? -ne 0 ]; then
        echo -e "${red}Download failed${plain}"
        return 1
    fi

    # Extract
    echo -e "${yellow}Extracting files...${plain}"
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm -f x-ui-linux-${arch}.tar.gz
    
    if [ ! -d "x-ui" ]; then
        echo -e "${red}Extraction failed${plain}"
        return 1
    fi

    # Set permissions
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}

    # Create config directory
    mkdir -p /etc/x-ui/
    if [ ! -f /etc/x-ui/x-ui.db ]; then
        cp x-ui.db /etc/x-ui/
    fi

    # Create service
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
    
    # Change to custom credentials
    if [ "$XUI_USERNAME" != "admin" ] || [ "$XUI_PASSWORD" != "admin" ] || [ "$XUI_PORT" != "54321" ]; then
        echo -e "${yellow}Applying custom credentials...${plain}"
        safe_stop_service "x-ui"
        /usr/local/x-ui/x-ui setting -username "$XUI_USERNAME" -password "$XUI_PASSWORD"
        /usr/local/x-ui/x-ui setting -port "$XUI_PORT"
        systemctl start x-ui
        sleep 2
    fi

    # Apply automatic fixes after installation
    echo -e "${yellow}Applying automatic fixes...${plain}"
    fix_firewall_ports
    fix_xray_service
    fix_configuration
    
    # Send installation success notification
    local install_msg="🎉 *X-UI Installation Completed!*

🖥️ Server: $ipv4
📍 Location: $location
🔗 Panel URL: http://$ipv4:$XUI_PORT
👤 Username: $XUI_USERNAME
🔐 Password: $XUI_PASSWORD
📊 Status: ✅ Running

⚠️ Please change default password after login!"
    
    send_telegram_message "$install_msg"
    
    echo -e "${green}Installation completed successfully!${plain}"
    echo -e "${yellow}Panel URL: http://${ipv4}:${XUI_PORT}${plain}"
    echo -e "${yellow}Username: ${cyan}$XUI_USERNAME${plain}"
    echo -e "${yellow}Password: ${cyan}$XUI_PASSWORD${plain}"
    echo -e "${red}Please keep these credentials safe!${plain}"
    
    # Test connection
    test_connection
    
    read -p "Press Enter to continue..."
}

# Complete uninstall x-ui
uninstall_xui() {
    echo -e "${red}=== COMPLETE X-UI UNINSTALL ===${plain}"
    echo -e "${yellow}This will remove ALL x-ui related files and configurations${plain}"
    read -p "Are you absolutely sure? (type 'YES' to confirm): " confirm
    
    if [ "$confirm" = "YES" ]; then
        cleanup_old_installation
        
        # Send uninstall notification
        send_telegram_message "🗑️ *X-UI Uninstalled*\n\n🖥️ Server: $ipv4\n✅ All files and configurations removed"
        
        echo -e "${green}x-ui completely uninstalled!${plain}"
    else
        echo -e "${yellow}Uninstall cancelled.${plain}"
    fi
    read -p "Press Enter to continue..."
}

# Fix all connection issues
fix_all_issues() {
    echo -e "${magenta}=== Applying All Fixes ===${plain}"
    fix_firewall_ports
    fix_xray_service
    fix_configuration
    
    # Send fix notification
    send_telegram_message "🔧 *X-UI Issues Fixed*\n\n🖥️ Server: $ipv4\n✅ Firewall, ports, and services repaired"
    
    test_connection
    echo -e "${green}All fixes applied!${plain}"
}

# Start/Stop/Restart x-ui
manage_xui() {
    echo -e "
${green}Manage x-ui Service${plain}
1. Start x-ui
2. Stop x-ui  
3. Restart x-ui
4. Check service status
5. Back to main menu
"
    read -p "Select option: " choice
    case $choice in
        1) 
            systemctl start x-ui && echo -e "${green}x-ui started${plain}" || echo -e "${red}Failed to start x-ui${plain}"
            send_telegram_message "▶️ *X-UI Started*\n\n🖥️ Server: $ipv4"
            ;;
        2) 
            safe_stop_service "x-ui"
            send_telegram_message "⏹️ *X-UI Stopped*\n\n🖥️ Server: $ipv4"
            ;;
        3) 
            systemctl restart x-ui && echo -e "${green}x-ui restarted${plain}" || echo -e "${red}Failed to restart x-ui${plain}"
            send_telegram_message "🔄 *X-UI Restarted*\n\n🖥️ Server: $ipv4"
            ;;
        4) systemctl status x-ui 2>/dev/null || echo -e "${yellow}x-ui service not found${plain}" ;;
        5) return ;;
        *) echo -e "${red}Invalid option${plain}" ;;
    esac
    read -p "Press Enter to continue..."
}

# Telegram bot management
manage_telegram_bot() {
    echo -e "
${green}Telegram Bot Management${plain}
1. Setup Telegram Bot
2. Test Telegram Bot
3. Disable Telegram Bot
4. Back to main menu
"
    read -p "Select option: " choice
    case $choice in
        1) setup_telegram_bot ;;
        2) 
            if [ "$TELEGRAM_ENABLED" = true ]; then
                send_telegram_message "🧪 *Bot Test Message*\n\n✅ Bot is working correctly!\n🖥️ Server: $ipv4"
                echo -e "${green}Test message sent!${plain}"
            else
                echo -e "${red}Telegram bot is not enabled!${plain}"
            fi
            ;;
        3) 
            TELEGRAM_ENABLED=false
            rm -f /etc/x-ui-telegram/config.conf
            echo -e "${green}Telegram bot disabled!${plain}"
            ;;
        4) return ;;
        *) echo -e "${red}Invalid option${plain}" ;;
    esac
    read -p "Press Enter to continue..."
}

# Show current credentials
show_credentials() {
    echo -e "
${blue}=== Current x-ui Credentials ===${plain}
Username: ${cyan}$XUI_USERNAME${plain}
Password: ${cyan}$XUI_PASSWORD${plain}
Port: ${cyan}$XUI_PORT${plain}
Panel URL: http://${ipv4}:${XUI_PORT}
${plain}"
}

# Show status
show_status() {
    echo -e "
${blue}=== VPS Status ===${plain}
OS: $os   Kernel: $kernel
Processor: $arch   Virtualization: $virt
IPv4: $ipv4   IPv6: $ipv6
Location: $location
BBR Algorithm: $bbr

${blue}=== x-ui Status ===${plain}
x-ui Status: $xui_status
x-ui Auto-start: $xui_autostart  
xray Status: $xray_status

${blue}=== Telegram Bot ===${plain}
Status: $([ "$TELEGRAM_ENABLED" = true ] && echo "Enabled" || echo "Disabled")

${blue}=== Panel Access ===${plain}
URL: http://${ipv4}:${XUI_PORT}
Username: $XUI_USERNAME
Password: $XUI_PASSWORD
${plain}"
}

# Main menu
show_menu() {
    clear
    echo -e "
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}
${cyan}
 ████████╗██╗  ██╗██╗   ██╗██╗   ██╗ █████╗ 
 ╚══██╔══╝██║  ██║██║   ██║╚██╗ ██╔╝██╔══██╗
    ██║   ███████║██║   ██║ ╚████╔╝ ███████║
    ██║   ██╔══██║██║   ██║  ╚██╔╝  ██╔══██║
    ██║   ██║  ██║╚██████╔╝   ██║   ██║  ██║
    ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝
${plain}
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}
${blue}    X-UI AUTO INSTALLER + TELEGRAM BOT By ThuYaAungZaw${plain}
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}

${yellow}1.${plain} Install x-ui (Auto-clean + Auto-fix)
${yellow}2.${plain} Complete uninstall x-ui
${yellow}3.${plain} Fix all connection issues
${yellow}4.${plain} Manage x-ui service
${yellow}5.${plain} Telegram Bot Management
${yellow}6.${plain} Test connection
${yellow}7.${plain} Show current credentials
${yellow}8.${plain} Check system status
${yellow}9.${plain} Exit

${cyan}Current version: v6.0 - Telegram Bot Edition${plain}
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}
"
}

# Main function
main() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}This script must be run as root${plain}"
        exit 1
    fi

    # Load Telegram config
    load_telegram_config

    while true; do
        get_system_info
        check_services
        show_menu
        
        echo -e "${blue}Current Status:${plain}"
        echo -e "x-ui: $xui_status | xray: $xray_status | Telegram: $([ "$TELEGRAM_ENABLED" = true ] && echo "On" || echo "Off")"
        echo -e "${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}"
        
        read -p "Please select option [1-9]: " choice
        
        case $choice in
            1) install_xui ;;
            2) uninstall_xui ;;
            3) fix_all_issues && read -p "Press Enter to continue..." ;;
            4) manage_xui ;;
            5) manage_telegram_bot ;;
            6) test_connection && read -p "Press Enter to continue..." ;;
            7) show_credentials && read -p "Press Enter to continue..." ;;
            8) show_status && read -p "Press Enter to continue..." ;;
            9) 
                send_telegram_message "👋 *Script Session Ended*\n\n🖥️ Server: $ipv4\n⏰ Time: $(date)"
                echo -e "${green}Goodbye!${plain}"
                exit 0 
                ;;
            *) echo -e "${red}Invalid option!${plain}"; sleep 2 ;;
        esac
    done
}

# Start script
main
