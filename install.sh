#!/bin/bash

# X-UI ALL IN ONE + TELEGRAM BOT CONTROL
# By ThuYaAungZaw - With Full Bot Features

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

# Setup telegram bot
setup_telegram_bot() {
    echo -e "${yellow}Do you want Telegram bot control? (y/n): ${plain}"
    read -p "" setup_bot
    
    if [ "$setup_bot" = "y" ] || [ "$setup_bot" = "Y" ]; then
        echo -e "${green}=== Telegram Bot Setup ===${plain}"
        echo -e "Bot Token Example: 123456789:ABCdefGhIjKlmNoPQRsTUVwxyZ"
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

# Install X-UI (simplified version)
install_xui() {
    echo -e "${green}=== Installing X-UI ===${plain}"
    
    # Basic installation
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    
    # Apply custom settings if x-ui exists
    if [ -f "/usr/local/x-ui/x-ui" ]; then
        cd /usr/local/x-ui
        ./x-ui setting -username "$CUSTOM_USERNAME" -password "$CUSTOM_PASSWORD"
        ./x-ui setting -port "$CUSTOM_PORT"
        systemctl restart x-ui
    fi
    
    echo -e "${green}✓ X-UI installed${plain}"
}

# TELEGRAM BOT CONTROL SYSTEM
setup_telegram_bot_control() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Telegram Bot Control ===${plain}"
        
        # Create the main bot control script
        cat > /usr/local/x-ui/telegram_bot.py << 'EOF'
#!/usr/bin/env python3
import sqlite3
import subprocess
import requests
import time
import os
import logging
from datetime import datetime

# Configuration
BOT_TOKEN = "TOKEN_PLACEHOLDER"
CHAT_ID = "CHATID_PLACEHOLDER"
DB_PATH = "/etc/x-ui/x-ui.db"
XUI_PATH = "/usr/local/x-ui/x-ui"
LOG_FILE = "/var/log/x-ui-bot.log"

# Setup logging
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def send_telegram_message(message):
    """Send message to Telegram"""
    try:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        payload = {
            'chat_id': CHAT_ID,
            'text': message,
            'parse_mode': 'Markdown'
        }
        response = requests.post(url, data=payload, timeout=10)
        return response.status_code == 200
    except Exception as e:
        logging.error(f"Failed to send message: {e}")
        return False

def get_user_stats():
    """Get all user statistics from database"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Get user list with traffic
        cursor.execute("""
            SELECT username, traffic_up, traffic_down, expiry_time 
            FROM client_traffic 
            ORDER BY username
        """)
        
        users = cursor.fetchall()
        conn.close()
        
        if not users:
            return "No users found in database."
        
        result = "👥 *User Statistics:*\n\n"
        for user in users:
            username, up, down, expiry = user
            total = up + down
            up_gb = round(up / (1024**3), 2)
            down_gb = round(down / (1024**3), 2)
            total_gb = round(total / (1024**3), 2)
            
            # Format expiry date
            if expiry > 0:
                expiry_date = datetime.fromtimestamp(expiry).strftime('%Y-%m-%d')
            else:
                expiry_date = "Never"
            
            result += f"🔹 *{username}*\n"
            result += f"   📤 Upload: {up_gb} GB\n"
            result += f"   📥 Download: {down_gb} GB\n"
            result += f"   📊 Total: {total_gb} GB\n"
            result += f"   ⏰ Expiry: {expiry_date}\n\n"
        
        return result
        
    except Exception as e:
        logging.error(f"Database error: {e}")
        return f"❌ Database error: {e}"

def get_server_status():
    """Get server status information"""
    try:
        # CPU usage
        cpu_cmd = "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"
        cpu_usage = subprocess.getoutput(cpu_cmd)
        
        # Memory usage
        mem_cmd = "free -m | awk 'NR==2{printf \"%.1f\", $3*100/$2}'"
        mem_usage = subprocess.getoutput(mem_cmd)
        
        # Disk usage
        disk_cmd = "df -h / | awk 'NR==2{print $5}'"
        disk_usage = subprocess.getoutput(disk_cmd)
        
        # Uptime
        uptime_cmd = "uptime -p"
        uptime = subprocess.getoutput(uptime_cmd)
        
        # X-UI status
        xui_status = "Active" if subprocess.call(["systemctl", "is-active", "x-ui"]) == 0 else "Inactive"
        
        # Active connections
        conn_cmd = "netstat -an | grep :443 | grep ESTABLISHED | wc -l"
        connections = subprocess.getoutput(conn_cmd)
        
        status_msg = f"""🖥️ *Server Status:*

• 💻 CPU Usage: {cpu_usage}%
• 🧠 Memory Usage: {mem_usage}%
• 💿 Disk Usage: {disk_usage}
• ⏰ Uptime: {uptime}
• 🔌 X-UI Status: {xui_status}
• 🌐 Active Connections: {connections}"""

        return status_msg
        
    except Exception as e:
        logging.error(f"Status error: {e}")
        return f"❌ Status error: {e}"

def get_realtime_traffic():
    """Get real-time traffic information"""
    try:
        # Network traffic
        traffic_cmd = "ifconfig | grep 'RX packets' | head -1 | awk '{print $5}'"
        rx_bytes = subprocess.getoutput(traffic_cmd)
        traffic_cmd = "ifconfig | grep 'TX packets' | head -1 | awk '{print $5}'"
        tx_bytes = subprocess.getoutput(traffic_cmd)
        
        # Convert to MB
        rx_mb = round(int(rx_bytes) / (1024**2), 2) if rx_bytes.isdigit() else 0
        tx_mb = round(int(tx_bytes) / (1024**2), 2) if tx_bytes.isdigit() else 0
        
        traffic_msg = f"""📊 *Real-time Traffic:*

• 📥 Received: {rx_mb} MB
• 📤 Sent: {tx_mb} MB
• 📊 Total: {rx_mb + tx_mb} MB"""

        return traffic_msg
        
    except Exception as e:
        logging.error(f"Traffic error: {e}")
        return f"❌ Traffic error: {e}"

def restart_services():
    """Restart X-UI services"""
    try:
        subprocess.run(["systemctl", "restart", "x-ui"], check=True)
        time.sleep(3)
        status = "Active" if subprocess.call(["systemctl", "is-active", "x-ui"]) == 0 else "Inactive"
        return f"✅ Services restarted\nX-UI Status: {status}"
    except Exception as e:
        logging.error(f"Restart error: {e}")
        return f"❌ Restart failed: {e}"

def handle_command(command, args=""):
    """Handle Telegram bot commands"""
    command = command.lower()
    
    if command == "/start":
        return """🤖 *X-UI Bot Control Panel*

Available commands:
👥 /users - Show all users and traffic
📊 /stats - User statistics  
🖥️ /status - Server status
🌐 /traffic - Real-time traffic
🔄 /restart - Restart services
📈 /usage username - Check specific user

*Quick Stats:*
Use /users to see all user data"""

    elif command == "/users":
        return get_user_stats()
        
    elif command == "/stats":
        return get_user_stats()
        
    elif command == "/status":
        return get_server_status()
        
    elif command == "/traffic":
        return get_realtime_traffic()
        
    elif command == "/restart":
        return restart_services()
        
    elif command == "/usage":
        if args:
            return f"Usage check for: {args}\nUse /users to see all user data."
        else:
            return "❌ Usage: /usage username"
    
    else:
        return "❌ Unknown command. Use /start for help."

# Polling function (simple version)
def start_bot_polling():
    """Start simple polling for bot commands"""
    last_update_id = 0
    
    while True:
        try:
            # Get updates from Telegram
            url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates"
            params = {'offset': last_update_id + 1, 'timeout': 30}
            response = requests.get(url, params=params, timeout=35)
            
            if response.status_code == 200:
                data = response.json()
                if data['ok'] and data['result']:
                    for update in data['result']:
                        last_update_id = update['update_id']
                        
                        if 'message' in update and 'text' in update['message']:
                            message = update['message']['text']
                            chat_id = update['message']['chat']['id']
                            
                            # Only respond to authorized chat
                            if str(chat_id) == CHAT_ID:
                                # Parse command and arguments
                                parts = message.split(' ', 1)
                                command = parts[0]
                                args = parts[1] if len(parts) > 1 else ""
                                
                                # Handle command
                                result = handle_command(command, args)
                                send_telegram_message(result)
            
            time.sleep(1)
            
        except Exception as e:
            logging.error(f"Polling error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    # Check if required files exist
    if not os.path.exists(DB_PATH):
        logging.error("X-UI database not found!")
        exit(1)
    
    # Start the bot
    logging.info("Starting Telegram bot...")
    send_telegram_message("🤖 X-UI Bot Control Started!")
    start_bot_polling()
EOF

        # Replace placeholders with actual values
        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/telegram_bot.py
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/telegram_bot.py
        
        # Make executable
        chmod +x /usr/local/x-ui/telegram_bot.py
        
        # Install Python requirements
        echo -e "${yellow}Installing Python dependencies...${plain}"
        if command -v apt >/dev/null; then
            apt install -y python3 python3-pip >/dev/null 2>&1
        elif command -v yum >/dev/null; then
            yum install -y python3 python3-pip >/dev/null 2>&1
        fi
        
        pip3 install requests >/dev/null 2>&1
        
        # Create systemd service for bot
        cat > /etc/systemd/system/x-ui-bot.service << EOF
[Unit]
Description=X-UI Telegram Bot
After=network.target x-ui.service
Wants=x-ui.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/x-ui/telegram_bot.py
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
        
        # Send test message
        safe_send_telegram_message "🤖 *X-UI Bot Control Activated!*

✅ Bot system is now running
✅ User data monitoring enabled
✅ Server status monitoring active

*Available Commands:*
👥 /users - Show all users and traffic
📊 /stats - Detailed statistics
🖥️ /status - Server status
🌐 /traffic - Real-time data
🔄 /restart - Restart services

Try: /users to see your user data"
    fi
}

# Simple bash version bot (fallback)
setup_simple_bot() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Simple Bot Control ===${plain}"
        
        cat > /usr/local/x-ui/simple_bot.sh << 'EOF'
#!/bin/bash

BOT_TOKEN="TOKEN_PLACEHOLDER"
CHAT_ID="CHATID_PLACEHOLDER"

send_message() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" \
        -d parse_mode="Markdown"
}

# Simple command handler - you can extend this
case "$1" in
    "users")
        if [ -f "/etc/x-ui/x-ui.db" ]; then
            users=$(sqlite3 /etc/x-ui/x-ui.db "SELECT username FROM client_traffic;" 2>/dev/null | tr '\n' ' ')
            send_message "👥 Users: $users"
        fi
        ;;
    "status")
        status=$(systemctl is-active x-ui)
        send_message "🖥️ X-UI Status: $status"
        ;;
esac
EOF

        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/simple_bot.sh
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/simple_bot.sh
        chmod +x /usr/local/x-ui/simple_bot.sh
        
        echo -e "${green}✓ Simple bot control installed${plain}"
    fi
}

# Main installation flow
main() {
    get_server_ip
    
    if check_existing_installation; then
        echo -e "${green}✅ X-UI is already installed${plain}"
        echo -e "${yellow}Setting up Telegram bot control...${plain}"
    else
        echo -e "${red}❌ X-UI is not installed${plain}"
        echo -e "${yellow}Installing X-UI first...${plain}"
        install_xui
    fi
    
    setup_telegram_bot
    
    if [ "$TELEGRAM_ENABLED" = true ]; then
        # Try Python bot first, fallback to simple bot
        if command -v python3 >/dev/null; then
            setup_telegram_bot_control
        else
            setup_simple_bot
        fi
    fi
    
    # Final output
    echo -e "${cyan}"
    echo "========================================="
    echo "         SETUP COMPLETE"
    echo "========================================="
    echo -e "${plain}"
    echo -e "${green}Panel URL: http://$SERVER_IP:$CUSTOM_PORT${plain}"
    echo -e "${green}Username: $CUSTOM_USERNAME${plain}"
    echo -e "${green}Password: $CUSTOM_PASSWORD${plain}"
    echo -e "${blue}Telegram Bot: $([ "$TELEGRAM_ENABLED" = true ] && echo "✅ Enabled" || echo "❌ Disabled")${plain}"
    
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${yellow}🤖 Telegram Bot Commands:${plain}"
        echo -e "${cyan}/start - Show help${plain}"
        echo -e "${cyan}/users - User list with traffic data${plain}"
        echo -e "${cyan}/stats - Detailed statistics${plain}"
        echo -e "${cyan}/status - Server status${plain}"
        echo -e "${cyan}/traffic - Real-time traffic${plain}"
        echo -e "${cyan}/restart - Restart services${plain}"
        echo -e ""
        echo -e "${green}📊 Now you can check user data from Telegram!${plain}"
        echo -e "${yellow}Example: Send '/users' to your bot${plain}"
    fi
}

# Start installation
main
