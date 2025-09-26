#!/bin/bash

# X-UI ALL IN ONE INSTALLER + UNINSTALLER + TELEGRAM BOT CONTROL
# By ThuYaAungZaw - Enhanced Version with Uninstaller

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
        return 0  # Installation exists
    else
        return 1  # No installation found
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
    pkill -f "bot_control.sh" 2>/dev/null
    pkill -f "monitor.sh" 2>/dev/null
    
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
    rm -f /var/log/x-ui-bot.log 2>/dev/null
    rm -f /var/log/x-ui-monitor.log 2>/dev/null
    
    # Remove cron jobs
    echo -e "${yellow}Cleaning up cron jobs...${plain}"
    crontab -l | grep -v "x-ui" | crontab - 2>/dev/null
    crontab -l | grep -v "bot_control" | crontab - 2>/dev/null
    
    # Remove iptables rules (optional - be careful)
    echo -e "${yellow}Cleaning firewall rules...${plain}"
    iptables -D INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport 10000:50000 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 10000:50000 -j ACCEPT 2>/dev/null
    
    # Send Telegram notification
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🗑️ *X-UI Completely Uninstalled*
        
✅ All services stopped
✅ Files removed
✅ System cleaned

Server: $SERVER_IP
Time: $(date)

X-UI has been completely removed from the system."
    fi
    
    echo -e "${green}✓ X-UI uninstalled successfully!${plain}"
    return 0
}

# Backup function
backup_xui() {
    echo -e "${green}=== X-UI BACKUP ===${plain}"
    
    if ! check_existing_installation; then
        echo -e "${red}No X-UI installation found to backup!${plain}"
        return 1
    fi
    
    local backup_dir="/root/x-ui-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${yellow}Creating backup...${plain}"
    
    # Backup database
    if [ -f "/etc/x-ui/x-ui.db" ]; then
        cp /etc/x-ui/x-ui.db "$backup_dir/" 2>/dev/null
        echo -e "${green}✓ Database backed up${plain}"
    fi
    
    # Backup config
    if [ -f "/usr/local/x-ui/config.json" ]; then
        cp /usr/local/x-ui/config.json "$backup_dir/" 2>/dev/null
        echo -e "${green}✓ Config backed up${plain}"
    fi
    
    # Backup user data
    if [ -d "/etc/x-ui/" ]; then
        cp -r /etc/x-ui/ "$backup_dir/etc-x-ui-backup/" 2>/dev/null
        echo -e "${green}✓ User data backed up${plain}"
    fi
    
    # Create restore script
    cat > "$backup_dir/restore.sh" << 'EOF'
#!/bin/bash
echo "X-UI Restore Script"
echo "Copy files back to their original locations:"
echo "sudo cp x-ui.db /etc/x-ui/"
echo "sudo cp config.json /usr/local/x-ui/"
echo "sudo systemctl restart x-ui"
EOF
    chmod +x "$backup_dir/restore.sh"
    
    # Create archive
    tar -czf "$backup_dir.tar.gz" -C /root/ "x-ui-backup-$(date +%Y%m%d-%H%M%S)"
    rm -rf "$backup_dir"
    
    echo -e "${green}✓ Backup created: $backup_dir.tar.gz${plain}"
    
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "💾 *X-UI Backup Created*
        
📁 Backup file: $backup_dir.tar.gz
📍 Location: /root/
🕒 Time: $(date)

Use this to restore your X-UI configuration if needed."
    fi
}

# Restore function
restore_xui() {
    echo -e "${green}=== X-UI RESTORE ===${plain}"
    
    local backup_files=($(ls /root/x-ui-backup-*.tar.gz 2>/dev/null))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        echo -e "${red}No backup files found in /root/${plain}"
        return 1
    fi
    
    echo -e "${yellow}Available backups:${plain}"
    for i in "${!backup_files[@]}"; do
        echo "$((i+1)). ${backup_files[$i]}"
    done
    
    read -p "Select backup to restore (number): " backup_choice
    local selected_backup="${backup_files[$((backup_choice-1))]}"
    
    if [ -z "$selected_backup" ]; then
        echo -e "${red}Invalid selection!${plain}"
        return 1
    fi
    
    echo -e "${yellow}Restoring from $selected_backup...${plain}"
    
    # Extract backup
    local temp_dir="/tmp/x-ui-restore-$(date +%s)"
    mkdir -p "$temp_dir"
    tar -xzf "$selected_backup" -C "$temp_dir"
    
    # Stop services
    systemctl stop x-ui 2>/dev/null
    
    # Restore files
    if [ -f "$temp_dir/etc-x-ui-backup/x-ui.db" ]; then
        cp "$temp_dir/etc-x-ui-backup/x-ui.db" /etc/x-ui/ 2>/dev/null
        echo -e "${green}✓ Database restored${plain}"
    fi
    
    if [ -f "$temp_dir/config.json" ]; then
        cp "$temp_dir/config.json" /usr/local/x-ui/ 2>/dev/null
        echo -e "${green}✓ Config restored${plain}"
    fi
    
    # Restart services
    systemctl start x-ui 2>/dev/null
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${green}✓ Restore completed!${plain}"
    
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🔄 *X-UI Configuration Restored*
        
✅ Backup restored successfully
🔄 Services restarted
📁 From: $selected_backup

X-UI should now be running with restored configuration."
    fi
}

# Show installation status
show_status() {
    echo -e "${green}=== X-UI STATUS ===${plain}"
    
    # Check X-UI service
    if systemctl is-active x-ui >/dev/null 2>&1; then
        echo -e "X-UI Service: ${green}Running${plain}"
    else
        echo -e "X-UI Service: ${red}Stopped${plain}"
    fi
    
    # Check Xray process
    if pgrep xray >/dev/null; then
        echo -e "Xray Process: ${green}Running${plain}"
    else
        echo -e "Xray Process: ${red}Stopped${plain}"
    fi
    
    # Check Bot service
    if systemctl is-active x-ui-bot >/dev/null 2>&1; then
        echo -e "Bot Service: ${green}Running${plain}"
    else
        echo -e "Bot Service: ${red}Stopped${plain}"
    fi
    
    # Check panel access
    if curl -s http://localhost:$CUSTOM_PORT >/dev/null 2>&1; then
        echo -e "Panel Access: ${green}Accessible${plain}"
    else
        echo -e "Panel Access: ${red}Not Accessible${plain}"
    fi
    
    # Show installed version
    if [ -f "/usr/local/x-ui/x-ui" ]; then
        echo -e "Installation: ${green}Found at /usr/local/x-ui/${plain}"
    else
        echo -e "Installation: ${red}Not Found${plain}"
    fi
    
    # Show database
    if [ -f "/etc/x-ui/x-ui.db" ]; then
        local user_count=$(sqlite3 /etc/x-ui/x-ui.db "SELECT COUNT(*) FROM client_traffic;" 2>/dev/null || echo "0")
        echo -e "User Count: ${cyan}$user_count users${plain}"
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
        echo -e "3. ${green}Backup Configuration${plain}"
        echo -e "4. ${cyan}Restore Configuration${plain}"
        echo -e "5. ${yellow}Show Status${plain}"
        echo -e "6. ${magenta}Restart Services${plain}"
        echo -e "7. ${green}Exit${plain}"
    else
        echo -e "${yellow}❌ X-UI is not installed${plain}"
        echo -e ""
        echo -e "${yellow}Available actions:${plain}"
        echo -e "1. ${green}Install X-UI${plain}"
        echo -e "2. ${cyan}Exit${plain}"
    fi
    
    echo -e ""
    read -p "Select option (number): " menu_choice
}

# Setup telegram bot (same as before)
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
            
            if [[ "$bot_token" =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
                if timeout 15 curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q "ok"; then
                    TELEGRAM_ENABLED=true
                    echo -e "${green}✓ Bot connected successfully${plain}"
                else
                    echo -e "${red}✗ Bot connection failed${plain}"
                    TELEGRAM_ENABLED=false
                fi
            else
                echo -e "${red}✗ Invalid bot token format${plain}"
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

# Install X-UI function (same as before but shorter for brevity)
install_xui() {
    echo -e "${green}=== Installing X-UI ===${plain}"
    # ... [installation code from previous script] ...
    # Include all the installation logic here
}

# Telegram bot control setup (same as before)
setup_telegram_bot_control() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Telegram Bot Control ===${plain}"
        # ... [bot control setup code] ...
    fi
}

# Main execution flow
main() {
    get_server_ip
    
    # Check if script is run with arguments
    case "$1" in
        "install")
            setup_telegram_bot
            install_xui
            ;;
        "uninstall")
            uninstall_xui
            exit 0
            ;;
        "backup")
            backup_xui
            exit 0
            ;;
        "restore")
            restore_xui
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        *)
            # Interactive mode
            while true; do
                show_main_menu
                
                case $menu_choice in
                    1)
                        if check_existing_installation; then
                            echo -e "${yellow}Reinstalling X-UI...${plain}"
                            uninstall_xui
                            sleep 2
                        fi
                        setup_telegram_bot
                        install_xui
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
                        backup_xui
                        ;;
                    4)
                        restore_xui
                        ;;
                    5)
                        show_status
                        ;;
                    6)
                        echo -e "${yellow}Restarting services...${plain}"
                        systemctl restart x-ui 2>/dev/null
                        systemctl restart x-ui-bot 2>/dev/null
                        echo -e "${green}✓ Services restarted${plain}"
                        ;;
                    7|"")
                        echo -e "${green}Goodbye!${plain}"
                        exit 0
                        ;;
                    *)
                        echo -e "${red}Invalid option!${plain}"
                        ;;
                esac
                
                echo -e ""
                read -p "Press Enter to continue..."
            done
            ;;
    esac
}

# Start the script
main "$@"
