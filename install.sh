#!/bin/bash

# X-UI ALL IN ONE + TELEGRAM BOT CONTROL
# By ThuYaAungZaw - Fixed and Clean Version

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
magenta='\033[0;35m'
plain='\033[0m'

# Display banner
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
echo -e "${blue}X-UI + Telegram Bot Control${plain}"
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

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "${blue}Server IP: $SERVER_IP${plain}"
}

# Telegram message function
safe_send_telegram_message() {
    local message="$1"
    if [ "$TELEGRAM_ENABLED" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        timeout 10 curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" > /dev/null 2>&1 &
    fi
}

# Check existing installation
check_existing_installation() {
    if systemctl is-active x-ui >/dev/null 2>&1 || [ -f "/usr/local/x-ui/x-ui" ]; then
        return 0
    else
        return 1
    fi
}

# Fix installation issues
fix_installation_issues() {
    echo -e "${yellow}Applying fixes...${plain}"
    
    systemctl stop x-ui 2>/dev/null
    systemctl stop x-ui-bot 2>/dev/null
    pkill -f x-ui 2>/dev/null
    pkill -f xray 2>/dev/null
    
    rm -rf /usr/local/x-ui/ 2>/dev/null
    rm -rf /etc/x-ui/ 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service 2>/dev/null
    
    if lsof -i :$CUSTOM_PORT >/dev/null 2>&1; then
        fuser -k $CUSTOM_PORT/tcp 2>/dev/null
        sleep 2
    fi
    
    if command -v apt >/dev/null; then
        apt update -y >/dev/null 2>&1
        apt install -y wget curl sqlite3 >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum update -y >/dev/null 2>&1
        yum install -y wget curl sqlite3 >/dev/null 2>&1
    fi
    
    echo -e "${green}✓ Fixes applied${plain}"
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
    
    echo -e "${blue}Settings:${plain}"
    echo -e "Username: ${cyan}$CUSTOM_USERNAME${plain}"
    echo -e "Password: ${cyan}$CUSTOM_PASSWORD${plain}"
    echo -e "Port: ${cyan}$CUSTOM_PORT${plain}"
    
    read -p "Continue? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        get_custom_credentials
    fi
}

# Install X-UI
install_xui() {
    echo -e "${green}=== Installing X-UI ===${plain}"
    
    get_custom_credentials
    fix_installation_issues
    
    # Detect architecture
    arch=$(uname -m)
    if [[ $arch == "x86_64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" ]]; then
        arch="arm64" 
    else
        arch="amd64"
    fi
    
    # Download and install
    cd /usr/local/
    wget -O x-ui.tar.gz https://github.com/yonggekkk/x-ui-yg/releases/latest/download/x-ui-linux-$arch.tar.gz
    
    tar zxvf x-ui.tar.gz
    rm -f x-ui.tar.gz
    cd x-ui
    chmod +x x-ui
    
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

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    sleep 5
    
    # Apply settings
    systemctl stop x-ui
    sleep 2
    cd /usr/local/x-ui
    ./x-ui setting -username "$CUSTOM_USERNAME" -password "$CUSTOM_PASSWORD"
    ./x-ui setting -port "$CUSTOM_PORT"
    systemctl start x-ui
    sleep 5
    
    # Test installation
    if curl -s http://localhost:$CUSTOM_PORT >/dev/null 2>&1; then
        panel_status="${green}✓ Accessible${plain}"
    else
        panel_status="${red}✗ Not accessible${plain}"
    fi
    
    echo -e "${green}=== Installation Complete ===${plain}"
    echo -e "${cyan}Panel: http://$SERVER_IP:$CUSTOM_PORT${plain}"
    echo -e "${cyan}Username: $CUSTOM_USERNAME${plain}"
    echo -e "${cyan}Password: $CUSTOM_PASSWORD${plain}"
    echo -e "Status: $panel_status"
    
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🎉 X-UI Installed

Server: $SERVER_IP
Panel: http://$SERVER_IP:$CUSTOM_PORT
User: $CUSTOM_USERNAME
Pass: $CUSTOM_PASSWORD

Status: ✅ Ready"
    fi
}

# Setup telegram bot
setup_telegram_bot() {
    echo -e "${yellow}Enable Telegram bot? (y/n): ${plain}"
    read -p "" setup_bot
    
    if [ "$setup_bot" = "y" ] || [ "$setup_bot" = "Y" ]; then
        echo -e "${green}=== Telegram Setup ===${plain}"
        
        read -p "Enter Bot Token: " bot_token
        read -p "Enter Chat ID: " chat_id
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
            TELEGRAM_CHAT_ID="$chat_id"
            
            if timeout 10 curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q "ok"; then
                TELEGRAM_ENABLED=true
                echo -e "${green}✓ Bot connected${plain}"
            else
                echo -e "${red}✗ Bot connection failed${plain}"
                TELEGRAM_ENABLED=false
            fi
        else
            TELEGRAM_ENABLED=false
        fi
    else
        TELEGRAM_ENABLED=false
    fi
}

# Setup bot control system
setup_bot_control() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Bot Control ===${plain}"
        
        # Create bot script
        cat > /usr/local/x-ui/bot_control.sh << 'EOF'
#!/bin/bash

BOT_TOKEN="TOKEN_PLACEHOLDER"
CHAT_ID="CHATID_PLACEHOLDER"
DB_FILE="/etc/x-ui/x-ui.db"

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" \
        -d parse_mode="Markdown"
}

get_user_stats() {
    if [ -f "$DB_FILE" ]; then
        users=$(sqlite3 "$DB_FILE" "SELECT username, traffic_up, traffic_down FROM client_traffic;" 2>/dev/null)
        if [ -n "$users" ]; then
            message="👥 User Statistics:\n\n"
            while IFS='|' read -r user up down; do
                up_gb=$(echo "scale=2; $up/1024/1024/1024" | bc)
                down_gb=$(echo "scale=2; $down/1024/1024/1024" | bc)
                total_gb=$(echo "scale=2; $up_gb+$down_gb" | bc)
                message+="🔹 $user\n   📤 ${up_gb}GB | 📥 ${down_gb}GB | 📊 ${total_gb}GB\n\n"
            done <<< "$users"
            echo "$message"
        else
            echo "❌ No users found"
        fi
    else
        echo "❌ Database not found"
    fi
}

get_server_status() {
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    mem=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    disk=$(df -h / | awk 'NR==2{print $5}')
    xui_status=$(systemctl is-active x-ui)
    
    echo "🖥️ Server Status:
• CPU: ${cpu}%
• Memory: ${mem}%
• Disk: ${disk}
• X-UI: ${xui_status}"
}

# Command handler
case "$1" in
    "users")
        stats=$(get_user_stats)
        send_telegram "$stats"
        ;;
    "status")
        status=$(get_server_status)
        send_telegram "$status"
        ;;
    "restart")
        systemctl restart x-ui
        send_telegram "✅ Services restarted"
        ;;
esac
EOF

        # Replace placeholders
        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/bot_control.sh
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/bot_control.sh
        chmod +x /usr/local/x-ui/bot_control.sh
        
        # Create Python bot for better features
        cat > /usr/local/x-ui/telegram_bot.py << 'EOF'
#!/usr/bin/env python3
import sqlite3
import requests
import time
import os

BOT_TOKEN = "TOKEN_PLACEHOLDER"
CHAT_ID = "CHATID_PLACEHOLDER"
DB_PATH = "/etc/x-ui/x-ui.db"

def send_message(text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    data = {"chat_id": CHAT_ID, "text": text, "parse_mode": "Markdown"}
    requests.post(url, data=data, timeout=10)

def get_users():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT username, traffic_up, traffic_down FROM client_traffic")
    users = cursor.fetchall()
    conn.close()
    
    if not users:
        return "No users found"
    
    result = "👥 *User List:*\n\n"
    for user in users:
        name, up, down = user
        up_gb = round(up / (1024**3), 2)
        down_gb = round(down / (1024**3), 2)
        total_gb = up_gb + down_gb
        result += f"🔸 *{name}*\n📤 {up_gb}GB | 📥 {down_gb}GB | 📊 {total_gb}GB\n\n"
    
    return result

def get_status():
    cpu = os.popen("top -bn1 | grep 'Cpu(s)' | awk '{print $2}'").read().strip()
    mem = os.popen("free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'").read().strip()
    disk = os.popen("df -h / | awk 'NR==2{print $5}'").read().strip()
    status = os.popen("systemctl is-active x-ui").read().strip()
    
    return f"🖥️ *Server Status:*\n\n• CPU: {cpu}%\n• Memory: {mem}%\n• Disk: {disk}\n• X-UI: {status}"

# Simple polling
last_update = 0
while True:
    try:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates?offset={last_update+1}"
        response = requests.get(url, timeout=30).json()
        
        if response["ok"]:
            for update in response["result"]:
                last_update = update["update_id"]
                message = update.get("message", {}).get("text", "")
                
                if message == "/start":
                    send_message("🤖 *X-UI Bot*\n\nCommands:\n/users - User list\n/status - Server status")
                elif message == "/users":
                    send_message(get_users())
                elif message == "/status":
                    send_message(get_status())
                elif message == "/restart":
                    os.system("systemctl restart x-ui")
                    send_message("✅ Services restarted")
    
    except Exception as e:
        pass
    
    time.sleep(2)
EOF

        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/telegram_bot.py
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/telegram_bot.py
        chmod +x /usr/local/x-ui/telegram_bot.py
        
        # Install Python if needed
        if ! command -v python3 >/dev/null; then
            if command -v apt >/dev/null; then
                apt install -y python3 python3-pip >/dev/null 2>&1
            elif command -v yum >/dev/null; then
                yum install -y python3 python3-pip >/dev/null 2>&1
            fi
        fi
        
        pip3 install requests >/dev/null 2>&1
        
        # Create service
        cat > /etc/systemd/system/x-ui-bot.service << EOF
[Unit]
Description=X-UI Telegram Bot
After=x-ui.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/x-ui/telegram_bot.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable x-ui-bot
        systemctl start x-ui-bot
        
        echo -e "${green}✓ Bot control system installed${plain}"
        
        # Send welcome message
        safe_send_telegram_message "🤖 *X-UI Bot Control Active!*

*Commands:*
/users - Show all users and traffic
/status - Server status  
/restart - Restart services

Try: /users to see user data"
    fi
}

# Uninstall function
uninstall_xui() {
    echo -e "${red}=== Uninstall X-UI ===${plain}"
    read -p "Are you sure? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        return
    fi
    
    systemctl stop x-ui x-ui-bot 2>/dev/null
    systemctl disable x-ui x-ui-bot 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service /etc/systemd/system/x-ui-bot.service
    rm -rf /usr/local/x-ui/ /etc/x-ui/
    systemctl daemon-reload
    
    echo -e "${green}✓ X-UI uninstalled${plain}"
}

# Show menu
show_menu() {
    echo -e "${cyan}"
    echo "========================================="
    echo "           X-UI MANAGEMENT"
    echo "========================================="
    echo -e "${plain}"
    
    if check_existing_installation; then
        echo -e "${green}✅ X-UI is installed${plain}"
        echo -e ""
        echo -e "1. Install/Reinstall X-UI"
        echo -e "2. Setup Telegram Bot"
        echo -e "3. Uninstall X-UI"
        echo -e "4. Exit"
    else
        echo -e "${red}❌ X-UI is not installed${plain}"
        echo -e ""
        echo -e "1. Install X-UI"
        echo -e "2. Exit"
    fi
    echo -e ""
}

# Main function
main() {
    get_server_ip
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1)
                if check_existing_installation; then
                    read -p "Reinstall? (y/n): " reinstall
                    if [ "$reinstall" = "y" ]; then
                        uninstall_xui
                        sleep 2
                    fi
                fi
                setup_telegram_bot
                install_xui
                if [ "$TELEGRAM_ENABLED" = true ]; then
                    setup_bot_control
                fi
                ;;
            2)
                if check_existing_installation; then
                    setup_telegram_bot
                    if [ "$TELEGRAM_ENABLED" = true ]; then
                        setup_bot_control
                    fi
                else
                    echo -e "${red}Install X-UI first!${plain}"
                fi
                ;;
            3)
                if check_existing_installation; then
                    uninstall_xui
                else
                    echo -e "${yellow}Not installed${plain}"
                fi
                ;;
            4|"")
                echo -e "${green}Bye!${plain}"
                exit 0
                ;;
            *)
                echo -e "${red}Invalid option${plain}"
                ;;
        esac
        
        echo -e ""
        read -p "Press Enter to continue..."
    done
}

# Start
main
