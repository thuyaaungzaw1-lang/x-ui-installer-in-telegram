#!/bin/bash

# X-UI ALL IN ONE INSTALLER + TELEGRAM BOT CONTROL
# By ThuYaAungZaw - Enhanced Version

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
echo -e "${blue}X-UI ALL IN ONE INSTALLER + TELEGRAM BOT CONTROL${plain}"
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

# Fix installation issues
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
        apt install -y wget curl net-tools lsof sqlite3 >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum update -y >/dev/null 2>&1
        yum install -y wget curl net-tools lsof sqlite3 >/dev/null 2>&1
    fi
    
    echo -e "${green}✓ Pre-installation fixes applied${plain}"
}

# Install X-UI
install_xui() {
    echo -e "${green}=== Starting X-UI Installation ===${plain}"
    
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
        echo -e "${yellow}Unknown architecture, using amd64${plain}"
    fi
    
    # Get latest version
    latest_version=$(curl -s https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$latest_version" ] && latest_version="v1.0.0"
    
    # Download and install
    cd /usr/local/
    download_url="https://github.com/yonggekkk/x-ui-yg/releases/download/$latest_version/x-ui-linux-$arch.tar.gz"
    
    if ! wget -O x-ui-linux-$arch.tar.gz "$download_url"; then
        echo -e "${red}Download failed!${plain}"
        exit 1
    fi
    
    tar zxvf x-ui-linux-$arch.tar.gz
    rm -f x-ui-linux-$arch.tar.gz
    cd x-ui
    chmod +x x-ui
    [ -d "bin" ] && chmod +x bin/xray-linux-$arch 2>/dev/null
    
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
    sleep 8
    
    # Apply credentials
    systemctl stop x-ui
    sleep 2
    cd /usr/local/x-ui
    ./x-ui setting -username "$CUSTOM_USERNAME" -password "$CUSTOM_PASSWORD"
    ./x-ui setting -port "$CUSTOM_PORT"
    systemctl start x-ui
    sleep 5
    
    # Configure firewall
    iptables -A INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport 10000:50000 -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp --dport 10000:50000 -j ACCEPT 2>/dev/null
    
    # Test installation
    if curl -s http://localhost:$CUSTOM_PORT >/dev/null 2>&1; then
        panel_status="${green}✓ Accessible${plain}"
    else
        panel_status="${red}✗ Not accessible${plain}"
    fi
    
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
    
    # Send Telegram notification
    if [ "$TELEGRAM_ENABLED" = true ]; then
        safe_send_telegram_message "🎉 X-UI Installation Complete!

🖥️ Server: $SERVER_IP
🔗 Panel: http://$SERVER_IP:$CUSTOM_PORT
👤 Username: $CUSTOM_USERNAME
🔐 Password: $CUSTOM_PASSWORD

Status:
Panel: ✅ Accessible
Xray: ✅ Running

🤖 Bot Control Activated!
Use commands to manage your X-UI"
    fi
}

# TELEGRAM BOT CONTROL SYSTEM
setup_telegram_bot_control() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Telegram Bot Control System ===${plain}"
        
        # Create main bot control script
        cat > /usr/local/x-ui/bot_control.sh << 'EOFBOT'
#!/bin/bash

# Configuration
BOT_TOKEN="TOKEN_PLACEHOLDER"
CHAT_ID="CHATID_PLACEHOLDER"
XUI_DIR="/usr/local/x-ui"
DB_FILE="/etc/x-ui/x-ui.db"
LOG_FILE="/var/log/x-ui-bot.log"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Send telegram message
send_telegram() {
    local message="$1"
    local result=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" \
        -w "%{http_code}")
    
    if [ "$result" -ne 200 ]; then
        log_message "Failed to send Telegram message: $result"
    fi
}

# Get user statistics
get_user_stats() {
    if [ -f "$DB_FILE" ]; then
        sqlite3 "$DB_FILE" "SELECT username, traffic_up, traffic_down, expiry_time FROM client_traffic;" 2>/dev/null | while IFS='|' read -r user up down expiry; do
            if [ -n "$user" ]; then
                total=$((up + down))
                expiry_date=$(date -d "@$expiry" 2>/dev/null || echo "Never")
                echo "👤 $user | 📤 ${up} | 📥 ${down} | 📊 ${total} | ⏰ ${expiry_date}"
            fi
        done
    else
        echo "Database not found"
    fi
}

# Get server status
get_server_status() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local mem_usage=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    local disk_usage=$(df -h / | awk 'NR==2{print $5}')
    local uptime=$(uptime -p)
    
    echo "🖥️ CPU Usage: ${cpu_usage}%"
    echo "💾 Memory Usage: ${mem_usage}%"
    echo "💿 Disk Usage: ${disk_usage}"
    echo "⏰ Uptime: ${uptime}"
    echo "🔌 X-UI Status: $(systemctl is-active x-ui)"
}

# Get real-time traffic
get_realtime_traffic() {
    if pgrep xray >/dev/null; then
        netstat -an | grep :443 | grep ESTABLISHED | wc -l | awk '{print "🌐 Active Connections: " $1}'
        ifconfig | grep "bytes" | head -1 | awk '{print "📊 Total RX: " $3 " bytes | TX: " $7 " bytes"}'
    else
        echo "❌ Xray not running"
    fi
}

# Restart services
restart_services() {
    systemctl restart x-ui
    sleep 3
    echo "✅ Services restarted"
    echo "X-UI Status: $(systemctl is-active x-ui)"
}

# Add new user
add_user() {
    local username="$1"
    local password="$2"
    
    if [ -f "$XUI_DIR/x-ui" ]; then
        cd "$XUI_DIR"
        ./x-ui user add --username "$username" --password "$password"
        echo "✅ User $username added"
    else
        echo "❌ X-UI not found"
    fi
}

# Main command handler
handle_command() {
    local command="$1"
    local args="$2"
    
    case $command in
        "/start")
            send_telegram "🤖 *X-UI Bot Control Panel Activated*

Available Commands:
👥 /users - List all users
📊 /stats - Traffic statistics
🖥️ /status - Server status
🌐 /traffic - Real-time traffic
🔄 /restart - Restart services
👤 /adduser username password - Add new user
❌ /deluser username - Delete user
💾 /usage username - User data usage

📈 *Server Info:*
• IP: $SERVER_IP
• Panel: http://$SERVER_IP:$CUSTOM_PORT
• Admin: $CUSTOM_USERNAME"
            ;;
            
        "/users")
            local user_list=$(get_user_stats)
            if [ -n "$user_list" ]; then
                send_telegram "👥 *User List:*
                
$user_list"
            else
                send_telegram "❌ No users found or database error"
            fi
            ;;
            
        "/stats")
            local stats=$(get_user_stats | head -10)
            send_telegram "📊 *Traffic Statistics:*
            
$stats"
            ;;
            
        "/status")
            local status=$(get_server_status)
            send_telegram "🖥️ *Server Status:*
            
$status"
            ;;
            
        "/traffic")
            local traffic=$(get_realtime_traffic)
            send_telegram "🌐 *Real-time Traffic:*
            
$traffic"
            ;;
            
        "/restart")
            local result=$(restart_services)
            send_telegram "🔄 *Service Restart:*
            
$result"
            ;;
            
        "/adduser")
            if [ -n "$args" ]; then
                local username=$(echo "$args" | awk '{print $1}')
                local password=$(echo "$args" | awk '{print $2}')
                if [ -n "$username" ] && [ -n "$password" ]; then
                    local result=$(add_user "$username" "$password")
                    send_telegram "👤 *Add User Result:*
                    
$result"
                else
                    send_telegram "❌ Usage: /adduser username password"
                fi
            else
                send_telegram "❌ Usage: /adduser username password"
            fi
            ;;
            
        "/usage")
            if [ -n "$args" ]; then
                local usage=$(get_user_stats | grep "$args")
                if [ -n "$usage" ]; then
                    send_telegram "📊 *Usage for $args:*
                    
$usage"
                else
                    send_telegram "❌ User $args not found"
                fi
            else
                send_telegram "❌ Usage: /usage username"
            fi
            ;;
            
        *)
            send_telegram "❌ Unknown command. Use /start for available commands"
            ;;
    esac
}

# Webhook setup (for production)
setup_webhook() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
        -d url="https://your-domain.com/webhook$BOT_TOKEN" \
        -d max_connections=10
}

# Main loop for polling (simple version)
if [ "$1" = "daemon" ]; then
    LAST_UPDATE_ID=0
    while true; do
        UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((LAST_UPDATE_ID+1))&timeout=60")
        
        if echo "$UPDATES" | grep -q "ok"; then
            UPDATE_COUNT=$(echo "$UPDATES" | jq '.result | length')
            
            for i in $(seq 0 $((UPDATE_COUNT-1))); do
                UPDATE=$(echo "$UPDATES" | jq ".result[$i]")
                UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
                MESSAGE=$(echo "$UPDATE" | jq -r '.message.text // empty')
                CHAT_ID=$(echo "$UPDATE" | jq -r '.message.chat.id')
                
                if [ "$UPDATE_ID" -gt "$LAST_UPDATE_ID" ]; then
                    LAST_UPDATE_ID=$UPDATE_ID
                    
                    if [ -n "$MESSAGE" ]; then
                        log_message "Received command: $MESSAGE"
                        COMMAND=$(echo "$MESSAGE" | awk '{print $1}')
                        ARGS=$(echo "$MESSAGE" | cut -d' ' -f2-)
                        handle_command "$COMMAND" "$ARGS"
                    fi
                fi
            done
        fi
        
        sleep 1
    done
fi

EOFBOT

        # Replace placeholders
        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/bot_control.sh
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/bot_control.sh
        
        # Add server info to bot script
        sed -i "s/\\$SERVER_IP/$SERVER_IP/g" /usr/local/x-ui/bot_control.sh
        sed -i "s/\\$CUSTOM_PORT/$CUSTOM_PORT/g" /usr/local/x-ui/bot_control.sh
        sed -i "s/\\$CUSTOM_USERNAME/$CUSTOM_USERNAME/g" /usr/local/x-ui/bot_control.sh
        
        chmod +x /usr/local/x-ui/bot_control.sh
        
        # Create systemd service for bot
        cat > /etc/systemd/system/x-ui-bot.service << EOF
[Unit]
Description=X-UI Telegram Bot Control
After=network.target x-ui.service

[Service]
Type=simple
ExecStart=/bin/bash /usr/local/x-ui/bot_control.sh daemon
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable x-ui-bot
        systemctl start x-ui-bot
        
        echo -e "${green}✓ Telegram bot control system installed${plain}"
        echo -e "${blue}Bot commands available:${plain}"
        echo -e "${cyan}/start /users /stats /status /traffic /restart /adduser /usage${plain}"
        
        # Send initial bot message
        safe_send_telegram_message "🤖 *X-UI Bot Control System Activated!*

✅ All features are now available:
- User management 👥
- Traffic monitoring 📊  
- Server status 🖥️
- Real-time data 🌐
- Service control 🔄

Try: /status to check your server"
    fi
}

# MONITORING SYSTEM
setup_monitoring() {
    echo -e "${green}=== Setting Up Monitoring System ===${plain}"
    
    cat > /usr/local/x-ui/monitor.sh << 'EOF'
#!/bin/bash

# Monitoring configuration
BOT_TOKEN="TOKEN_PLACEHOLDER"
CHAT_ID="CHATID_PLACEHOLDER"
LOG_FILE="/var/log/x-ui-monitor.log"

# Log function
log() {
    echo "[$(date)] $1" >> $LOG_FILE
}

# Send alert
send_alert() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" \
        -d parse_mode="Markdown" > /dev/null 2>&1
}

# Check services
check_services() {
    if ! systemctl is-active x-ui >/dev/null; then
        send_alert "⚠️ *X-UI Service Down!* 
        
Trying to restart automatically..."
        systemctl restart x-ui
        sleep 5
        if systemctl is-active x-ui >/dev/null; then
            send_alert "✅ *X-UI Restarted Successfully*"
        else
            send_alert "❌ *X-UI Restart Failed!* 
            
Manual intervention required."
        fi
    fi
    
    if ! pgrep xray >/dev/null; then
        send_alert "⚠️ *Xray Process Stopped!*
        
Restarting X-UI service..."
        systemctl restart x-ui
    fi
}

# Check resources
check_resources() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    local mem=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    
    if (( $(echo "$cpu > 80" | bc -l) )); then
        send_alert "🚨 *High CPU Usage: ${cpu}%* 
        
Consider optimizing your server."
    fi
    
    if (( $(echo "$mem > 85" | bc -l) )); then
        send_alert "🚨 *High Memory Usage: ${mem}%* 
        
Server memory is running low."
    fi
}

# Check traffic anomalies
check_traffic() {
    local connections=$(netstat -an | grep :443 | grep ESTABLISHED | wc -l)
    
    if [ "$connections" -gt 1000 ]; then
        send_alert "📈 *High Connection Count: ${connections}* 
        
Unusual traffic detected."
    fi
}

# Main monitoring loop
while true; do
    log "Running monitoring checks..."
    check_services
    check_resources
    check_traffic
    sleep 300  # Check every 5 minutes
done
EOF

    sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/monitor.sh
    sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/monitor.sh
    chmod +x /usr/local/x-ui/monitor.sh
    
    # Start monitoring in background
    nohup /usr/local/x-ui/monitor.sh > /dev/null 2>&1 &
    
    echo -e "${green}✓ Monitoring system activated${plain}"
}

# MAIN INSTALLATION FLOW
get_server_ip
setup_telegram_bot
install_xui

if [ "$TELEGRAM_ENABLED" = true ]; then
    setup_telegram_bot_control
    setup_monitoring
fi

# Final output
echo -e "${cyan}"
echo "========================================="
echo "  X-UI ALL IN ONE INSTALLATION COMPLETE"
echo "  By ThuYaAungZaw"
echo "========================================="
echo -e "${green}Panel URL: http://$SERVER_IP:$CUSTOM_PORT${plain}"
echo -e "${green}Username: $CUSTOM_USERNAME${plain}"
echo -e "${green}Password: $CUSTOM_PASSWORD${plain}"
echo -e "${blue}Telegram Bot: $([ "$TELEGRAM_ENABLED" = true ] && echo "✅ Enabled" || echo "❌ Disabled")${plain}"
echo -e "${blue}Bot Control: $([ "$TELEGRAM_ENABLED" = true ] && echo "✅ Active" || echo "❌ Inactive")${plain}"
echo -e "${blue}Monitoring: $([ "$TELEGRAM_ENABLED" = true ] && echo "✅ Active" || echo "❌ Inactive")${plain}"
echo -e "${cyan}=========================================${plain}"
echo -e "${yellow}Available Bot Commands:${plain}"
echo -e "${cyan}/start /users /stats /status /traffic /restart /adduser /usage${plain}"
echo -e "${cyan}=========================================${plain}"

# Send final notification
if [ "$TELEGRAM_ENABLED" = true ]; then
    safe_send_telegram_message "🎊 *X-UI All-in-One Setup Complete!*

✅ *Installation Successful*
✅ *Bot Control System Active* 
✅ *Monitoring System Running*

📋 *Quick Start:*
1. Access panel: http://$SERVER_IP:$CUSTOM_PORT
2. Login with: $CUSTOM_USERNAME / $CUSTOM_PASSWORD
3. Manage via Telegram commands

🔧 *Bot Commands:*
• /status - Check server
• /users - List users  
• /stats - Traffic data
• /restart - Restart services

💡 *Tip:* Use /start to see all commands"
fi
