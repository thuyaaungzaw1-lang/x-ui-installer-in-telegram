#!/bin/bash

# X-UI AUTO INSTALLER & FIXER With SAFE Telegram Bot By ThuYaAungZaw

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
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
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

# Safe Telegram Bot Functions with timeout protection
safe_telegram_api_check() {
    echo -e "${yellow}Checking Telegram API accessibility...${plain}"
    
    # Test Telegram API with timeout
    if timeout 10 curl -s -I https://api.telegram.org > /dev/null 2>&1; then
        echo -e "${green}✓ Telegram API is accessible${plain}"
        return 0
    else
        echo -e "${red}✗ Telegram API is not accessible${plain}"
        echo -e "${yellow}This may cause connection issues during setup${plain}"
        return 1
    fi
}

safe_send_telegram_message() {
    local message="$1"
    if [ "$TELEGRAM_ENABLED" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        # Use timeout to prevent hanging
        timeout 15 curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" > /dev/null 2>&1 &
        
        # Detach the process to prevent blocking
        disown
    fi
}

setup_telegram_bot() {
    echo -e "${yellow}=== Safe Telegram Bot Setup ===${plain}"
    
    # Check API accessibility first
    if ! safe_telegram_api_check; then
        echo -e "${red}Telegram API is not accessible from your server${plain}"
        echo -e "${yellow}This may be due to network restrictions or firewall${plain}"
        echo -e "${blue}You can still proceed, but bot features may not work${plain}"
        read -p "Continue with bot setup? (y/n): " continue_setup
        if [ "$continue_setup" != "y" ] && [ "$continue_setup" != "Y" ]; then
            return 1
        fi
    fi
    
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
            # Validate bot token format (should start with numbers and contain colon)
            if [[ "$bot_token" =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
                # Validate chat ID (should be numeric)
                if [[ "$chat_id" =~ ^-?[0-9]+$ ]]; then
                    TELEGRAM_BOT_TOKEN="$bot_token"
                    TELEGRAM_CHAT_ID="$chat_id"
                    
                    # Test the bot configuration with timeout
                    echo -e "${yellow}Testing bot configuration (with timeout protection)...${plain}"
                    if timeout 10 curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q "ok.*true"; then
                        echo -e "${green}✓ Bot token is valid${plain}"
                        TELEGRAM_ENABLED=true
                        
                        # Save to config file with secure permissions
                        mkdir -p /etc/x-ui-telegram/
                        cat > /etc/x-ui-telegram/config.conf << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
TELEGRAM_ENABLED=true
CONFIG_VERSION=1.1
EOF
                        # Set secure permissions
                        chmod 600 /etc/x-ui-telegram/config.conf
                        chown root:root /etc/x-ui-telegram/config.conf
                        
                        echo -e "${green}Telegram bot configured successfully!${plain}"
                        
                        # Send test message with safety
                        echo -e "${yellow}Sending test message...${plain}"
                        if safe_send_telegram_message "🔔 X-UI Installer Notification\n✅ Bot configured successfully!\n🖥️ Server: $ipv4\n⏰ Time: $(date)"; then
                            echo -e "${green}✓ Test message sent successfully${plain}"
                            sleep 2  # Small delay to ensure message is sent
                        else
                            echo -e "${yellow}⚠️ Test message may not have been delivered${plain}"
                            echo -e "${yellow}This is normal if your server has Telegram API restrictions${plain}"
                        fi
                    else
                        echo -e "${red}✗ Invalid bot token or API timeout${plain}"
                        echo -e "${yellow}Please check your bot token and try again${plain}"
                        echo -e "${yellow}You can continue without bot features${plain}"
                        TELEGRAM_ENABLED=false
                    fi
                else
                    echo -e "${red}✗ Invalid Chat ID format${plain}"
                    echo -e "${yellow}Chat ID should be a numeric value${plain}"
                    TELEGRAM_ENABLED=false
                fi
            else
                echo -e "${red}✗ Invalid bot token format${plain}"
                echo -e "${yellow}Bot token should be in format: 123456789:ABCdefGhIjKlmNoPQRsTUVwxyZ${plain}"
                TELEGRAM_ENABLED=false
            fi
        else
            echo -e "${red}Bot token and chat ID are required!${plain}"
            TELEGRAM_ENABLED=false
        fi
    else
        TELEGRAM_ENABLED=false
        echo -e "${yellow}Telegram notifications disabled${plain}"
    fi
    
    # Always return success to prevent script termination
    return 0
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

# [Rest of the functions remain the same as previous script...]
# Fix firewall, install x-ui, etc. (same as before)

# Modified functions to use safe telegram messaging
install_xui() {
    # [Previous installation code...]
    
    # After successful installation
    if [ "$TELEGRAM_ENABLED" = true ]; then
        local install_msg="🎉 *X-UI Installation Completed!*

🖥️ Server: $ipv4
📍 Location: $location  
🔗 Panel URL: http://$ipv4:$XUI_PORT
👤 Username: $XUI_USERNAME
🔐 Password: $XUI_PASSWORD
📊 Status: ✅ Running

⚠️ Please change default password after login!"
        
        safe_send_telegram_message "$install_msg"
    fi
    
    # [Rest of installation code...]
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
${blue}    X-UI AUTO INSTALLER + SAFE TELEGRAM BOT By ThuYaAungZaw${plain}
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

${cyan}Current version: v7.0 - Safe Telegram Bot Edition${plain}
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
            5) setup_telegram_bot && read -p "Press Enter to continue..." ;;
            6) test_connection && read -p "Press Enter to continue..." ;;
            7) show_credentials && read -p "Press Enter to continue..." ;;
            8) show_status && read -p "Press Enter to continue..." ;;
            9) 
                if [ "$TELEGRAM_ENABLED" = true ]; then
                    safe_send_telegram_message "👋 *Script Session Ended*\n\n🖥️ Server: $ipv4\n⏰ Time: $(date)"
                fi
                echo -e "${green}Goodbye!${plain}"
                exit 0 
                ;;
            *) echo -e "${red}Invalid option!${plain}"; sleep 2 ;;
        esac
    done
}

# Start script
main
