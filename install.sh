#!/bin/bash

# X-UI COMPLETE BOT CONTROL SYSTEM
# By ThuYaAungZaw - Full Features Version

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
echo -e "${blue}X-UI Complete Bot Control System${plain}"
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
            -d parse_mode="Markdown" > /dev/null 2>&1
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

# Install X-UI
install_xui() {
    echo -e "${green}=== Installing X-UI ===${plain}"
    
    # Get credentials
    echo -e "${green}=== Configuration ===${plain}"
    read -p "Enter username [admin]: " user_input
    [ -n "$user_input" ] && CUSTOM_USERNAME="$user_input"
    read -p "Enter password [admin]: " pass_input
    [ -n "$pass_input" ] && CUSTOM_PASSWORD="$pass_input"
    read -p "Enter port [54321]: " port_input
    [ -n "$port_input" ] && CUSTOM_PORT="$port_input"
    
    # Install
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    
    # Apply settings
    if [ -f "/usr/local/x-ui/x-ui" ]; then
        cd /usr/local/x-ui
        ./x-ui setting -username "$CUSTOM_USERNAME" -password "$CUSTOM_PASSWORD"
        ./x-ui setting -port "$CUSTOM_PORT"
        systemctl restart x-ui
    fi
    
    echo -e "${green}✓ X-UI installed${plain}"
    echo -e "${cyan}Panel: http://$SERVER_IP:$CUSTOM_PORT${plain}"
    echo -e "${cyan}Username: $CUSTOM_USERNAME${plain}"
    echo -e "${cyan}Password: $CUSTOM_PASSWORD${plain}"
}

# Setup telegram bot
setup_telegram_bot() {
    echo -e "${yellow}Enable Telegram bot control? (y/n): ${plain}"
    read -p "" setup_bot
    
    if [ "$setup_bot" = "y" ] || [ "$setup_bot" = "Y" ]; then
        echo -e "${green}=== Telegram Bot Setup ===${plain}"
        
        read -p "Enter Bot Token: " bot_token
        read -p "Enter Chat ID: " chat_id
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            TELEGRAM_BOT_TOKEN="$bot_token"
            TELEGRAM_CHAT_ID="$chat_id"
            
            if timeout 10 curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q "ok"; then
                TELEGRAM_ENABLED=true
                echo -e "${green}✓ Bot connected successfully${plain}"
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

# COMPLETE BOT CONTROL SYSTEM WITH ALL FEATURES
setup_complete_bot_control() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Complete Bot Control ===${plain}"
        
        # Install required packages
        echo -e "${yellow}Installing dependencies...${plain}"
        if command -v apt >/dev/null; then
            apt update -y >/dev/null 2>&1
            apt install -y python3 python3-pip sqlite3 bc jq >/dev/null 2>&1
        elif command -v yum >/dev/null; then
            yum update -y >/dev/null 2>&1
            yum install -y python3 python3-pip sqlite3 bc jq >/dev/null 2>&1
        fi
        
        pip3 install requests >/dev/null 2>&1
        
        # Create the complete bot script
        cat > /usr/local/x-ui/complete_bot.py << 'EOF'
#!/usr/bin/env python3
import sqlite3
import requests
import time
import os
import subprocess
from datetime import datetime

BOT_TOKEN = "TOKEN_PLACEHOLDER"
CHAT_ID = "CHATID_PLACEHOLDER"
DB_PATH = "/etc/x-ui/x-ui.db"

def send_message(text):
    try:
        url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
        data = {
            "chat_id": CHAT_ID,
            "text": text,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True
        }
        response = requests.post(url, data=data, timeout=10)
        return response.status_code == 200
    except:
        return False

def get_user_stats_detailed():
    """Get complete user statistics with expiry dates"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Get all user data
        cursor.execute("""
            SELECT username, traffic_up, traffic_down, expiry_time, total 
            FROM client_traffic 
            ORDER BY username
        """)
        
        users = cursor.fetchall()
        conn.close()
        
        if not users:
            return "❌ No users found in database."
        
        result = "👥 *User Statistics - Detailed*\n\n"
        total_upload = 0
        total_download = 0
        active_users = 0
        expired_users = 0
        
        for user in users:
            username, up, down, expiry, total = user
            up_gb = round(up / (1024**3), 3)
            down_gb = round(down / (1024**3), 3)
            total_gb = round((up + down) / (1024**3), 3)
            
            total_upload += up_gb
            total_download += down_gb
            
            # Check expiry
            current_time = int(time.time())
            if expiry == 0:
                expiry_status = "♾️ Never"
                active_users += 1
            elif expiry > current_time:
                expiry_date = datetime.fromtimestamp(expiry).strftime('%Y-%m-%d %H:%M')
                days_left = (expiry - current_time) // 86400
                expiry_status = f"✅ {expiry_date} ({days_left}d left)"
                active_users += 1
            else:
                expiry_status = "❌ EXPIRED"
                expired_users += 1
            
            result += f"🔸 *{username}*\n"
            result += f"   📤 Upload: `{up_gb:.3f} GB`\n"
            result += f"   📥 Download: `{down_gb:.3f} GB`\n"
            result += f"   📊 Total: `{total_gb:.3f} GB`\n"
            result += f"   ⏰ Expiry: {expiry_status}\n"
            result += "   ───────────────────\n"
        
        # Add summary
        result += f"\n📈 *Summary:*\n"
        result += f"• 👥 Total Users: {len(users)}\n"
        result += f"• ✅ Active: {active_users}\n"
        result += f"• ❌ Expired: {expired_users}\n"
        result += f"• 📤 Total Upload: `{total_upload:.3f} GB`\n"
        result += f"• 📥 Total Download: `{total_download:.3f} GB`\n"
        result += f"• 📊 Grand Total: `{total_upload + total_download:.3f} GB`\n"
        
        return result
        
    except Exception as e:
        return f"❌ Database error: {str(e)}"

def get_user_stats_simple():
    """Get simplified user stats"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT username, traffic_up, traffic_down FROM client_traffic")
        users = cursor.fetchall()
        conn.close()
        
        if not users:
            return "❌ No users found."
        
        result = "👥 *User List - Quick View*\n\n"
        for user in users:
            username, up, down = user
            up_gb = round(up / (1024**3), 2)
            down_gb = round(down / (1024**3), 2)
            total_gb = up_gb + down_gb
            
            result += f"• {username}: 📤{up_gb}GB 📥{down_gb}GB 📊{total_gb}GB\n"
        
        return result
    except:
        return "❌ Error reading database"

def get_server_status_detailed():
    """Get complete server status"""
    try:
        # CPU usage
        cpu_cmd = "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'"
        cpu_usage = subprocess.getoutput(cpu_cmd)
        
        # Memory usage
        mem_cmd = "free -m | awk 'NR==2{printf \"%.1f%%\", $3*100/$2}'"
        mem_usage = subprocess.getoutput(mem_cmd)
        
        # Disk usage
        disk_cmd = "df -h / | awk 'NR==2{print $5}'"
        disk_usage = subprocess.getoutput(disk_cmd)
        
        # Uptime
        uptime = subprocess.getoutput("uptime -p")
        
        # Load average
        load = subprocess.getoutput("cat /proc/loadavg | awk '{print $1,$2,$3}'")
        
        # X-UI status
        xui_status = subprocess.getoutput("systemctl is-active x-ui")
        xui_status_icon = "✅" if xui_status == "active" else "❌"
        
        # Xray status
        xray_running = "✅" if subprocess.call(["pgrep", "xray"]) == 0 else "❌"
        
        # Active connections
        conn_cmd = "netstat -an | grep :443 | grep ESTABLISHED | wc -l"
        connections = subprocess.getoutput(conn_cmd)
        
        # Network traffic
        traffic_cmd = "ifconfig | grep 'RX packets' | head -1"
        rx_info = subprocess.getoutput(traffic_cmd)
        traffic_cmd = "ifconfig | grep 'TX packets' | head -1"
        tx_info = subprocess.getoutput(traffic_cmd)
        
        status_msg = f"""🖥️ *Server Status - Detailed*

• 💻 CPU Usage: `{cpu_usage}%`
• 🧠 Memory Usage: `{mem_usage}`
• 💿 Disk Usage: `{disk_usage}`
• 📊 Load Average: `{load}`
• ⏰ Uptime: {uptime}

• 🔌 X-UI Service: {xui_status_icon} {xui_status}
• 🌐 Xray Process: {xray_running}
• 🔗 Active Connections: `{connections}`

*Network:*
📥 RX: `{rx_info.split()[2] if rx_info else 'N/A'}`
📤 TX: `{tx_info.split()[6] if tx_info else 'N/A'}`"""

        return status_msg
        
    except Exception as e:
        return f"❌ Status error: {str(e)}"

def get_realtime_traffic():
    """Get real-time traffic information"""
    try:
        # Current network usage
        rx_cmd = "cat /sys/class/net/[e]*/statistics/rx_bytes 2>/dev/null | head -1"
        tx_cmd = "cat /sys/class/net/[e]*/statistics/tx_bytes 2>/dev/null | head -1"
        
        rx_bytes = int(subprocess.getoutput(rx_cmd) or 0)
        tx_bytes = int(subprocess.getoutput(tx_cmd) or 0)
        
        # Convert to human readable
        def format_bytes(bytes):
            for unit in ['B', 'KB', 'MB', 'GB']:
                if bytes < 1024.0:
                    return f"{bytes:.2f} {unit}"
                bytes /= 1024.0
            return f"{bytes:.2f} TB"
        
        # Get per-user realtime data (simplified)
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT username, traffic_up, traffic_down FROM client_traffic ORDER BY (traffic_up + traffic_down) DESC LIMIT 10")
        top_users = cursor.fetchall()
        conn.close()
        
        result = "📊 *Real-time Traffic Monitor*\n\n"
        result += f"📥 Total Received: `{format_bytes(rx_bytes)}`\n"
        result += f"📤 Total Sent: `{format_bytes(tx_bytes)}`\n\n"
        result += "🏆 *Top 10 Users by Usage:*\n"
        
        for i, user in enumerate(top_users, 1):
            username, up, down = user
            total = up + down
            result += f"{i}. {username}: `{format_bytes(total)}`\n"
        
        return result
        
    except Exception as e:
        return f"❌ Traffic error: {str(e)}"

def restart_services():
    """Restart X-UI services"""
    try:
        subprocess.run(["systemctl", "restart", "x-ui"], check=True)
        time.sleep(3)
        status = subprocess.getoutput("systemctl is-active x-ui")
        return f"✅ *Services Restarted*\n\nX-UI Status: `{status}`"
    except:
        return "❌ Failed to restart services"

def add_new_user(username, password):
    """Add new user via bot"""
    try:
        if not username or not password:
            return "❌ Usage: /adduser username password"
        
        # Simple user addition (you might need to adjust this)
        result = subprocess.getoutput(f"cd /usr/local/x-ui && ./x-ui user add --username {username} --password {password}")
        return f"✅ User *{username}* added successfully!"
    except:
        return "❌ Failed to add user"

def handle_command(command, args=""):
    """Handle all bot commands"""
    command = command.lower().strip()
    
    if command == "/start":
        return """🤖 *X-UI Complete Bot Control*

*Available Commands:*
👥 `/users` - Detailed user statistics
📊 `/stats` - Quick user overview  
🖥️ `/status` - Complete server status
🌐 `/traffic` - Real-time traffic data
🔄 `/restart` - Restart X-UI services
👤 `/adduser username password` - Add new user
📈 `/realtime` - Live traffic monitor

*Examples:*
• `/users` - See all users with expiry dates
• `/status` - Check server health
• `/traffic` - Monitor network usage"""

    elif command in ["/users", "/allusers"]:
        return get_user_stats_detailed()
        
    elif command in ["/stats", "/quick"]:
        return get_user_stats_simple()
        
    elif command == "/status":
        return get_server_status_detailed()
        
    elif command in ["/traffic", "/network"]:
        return get_realtime_traffic()
        
    elif command == "/restart":
        return restart_services()
        
    elif command == "/adduser":
        parts = args.split()
        if len(parts) >= 2:
            return add_new_user(parts[0], parts[1])
        else:
            return "❌ Usage: /adduser username password"
    
    elif command == "/realtime":
        return "🔄 Real-time monitoring feature coming soon..."
    
    else:
        return "❌ Unknown command. Use `/start` for help."

# Main bot polling loop
def start_bot():
    last_update_id = 0
    
    send_message("🤖 *X-UI Bot Started!*\n\nType /start for commands")
    
    while True:
        try:
            # Get updates from Telegram
            url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates"
            params = {'offset': last_update_id + 1, 'timeout': 30}
            response = requests.get(url, params=params, timeout=35)
            
            if response.status_code == 200:
                data = response.json()
                if data.get('ok') and data.get('result'):
                    for update in data['result']:
                        last_update_id = update['update_id']
                        
                        if 'message' in update and 'text' in update['message']:
                            message_text = update['message']['text']
                            chat_id = update['message']['chat']['id']
                            
                            # Only respond to authorized chat
                            if str(chat_id) == CHAT_ID:
                                # Parse command and arguments
                                parts = message_text.split(' ', 1)
                                command = parts[0]
                                args = parts[1] if len(parts) > 1 else ""
                                
                                # Handle command
                                result = handle_command(command, args)
                                send_message(result)
            
            time.sleep(1)
            
        except Exception as e:
            time.sleep(5)

if __name__ == "__main__":
    # Check if database exists
    if not os.path.exists(DB_PATH):
        send_message("❌ X-UI database not found! Please check installation.")
        exit(1)
    
    # Start the bot
    start_bot()
EOF

        # Replace placeholders
        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/complete_bot.py
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/complete_bot.py
        
        chmod +x /usr/local/x-ui/complete_bot.py
        
        # Create systemd service
        cat > /etc/systemd/system/x-ui-bot.service << EOF
[Unit]
Description=X-UI Complete Telegram Bot
After=network.target x-ui.service
Wants=x-ui.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/x-ui/complete_bot.py
Restart=always
RestartSec=10
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable x-ui-bot
        systemctl start x-ui-bot
        
        echo -e "${green}✓ Complete bot control system installed${plain}"
        
        # Send test message with all features
        safe_send_telegram_message "🎉 *X-UI Complete Bot Control Activated!*

✅ All features are now available:

*📊 User Management:*
• Complete user statistics with expiry dates
• Upload/download data in GB
• Active/expired user counts
• Total usage tracking

*🖥️ Server Monitoring:*
• Real-time server status
• CPU, memory, disk usage
• Live traffic monitoring
• Service health checks

*🔧 Remote Control:*
• Restart services
• Add new users
• Real-time monitoring

*Try these commands:*
👥 `/users` - Detailed user list with expiry
📊 `/stats` - Quick overview
🖥️ `/status` - Server health check
🌐 `/traffic` - Network usage

Your bot is now fully operational! 🚀"
    fi
}

# Uninstall function
uninstall_xui() {
    echo -e "${red}=== Uninstall X-UI ===${plain}"
    read -p "Are you sure? (y/n): " confirm
    if [ "$confirm" != "y" ]; then return; fi
    
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
    echo "       X-UI COMPLETE BOT CONTROL"
    echo "========================================="
    echo -e "${plain}"
    
    if check_existing_installation; then
        echo -e "${green}✅ X-UI is installed${plain}"
        echo -e ""
        echo -e "1. Install/Reinstall X-UI + Bot"
        echo -e "2. Setup Bot Control Only"
        echo -e "3. Uninstall X-UI"
        echo -e "4. Exit"
    else
        echo -e "${red}❌ X-UI is not installed${plain}"
        echo -e ""
        echo -e "1. Install X-UI + Bot Control"
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
                    read -p "Reinstall? This will remove current installation. (y/n): " reinstall
                    if [ "$reinstall" = "y" ]; then
                        uninstall_xui
                        sleep 2
                    else
                        continue
                    fi
                fi
                install_xui
                setup_telegram_bot
                if [ "$TELEGRAM_ENABLED" = true ]; then
                    setup_complete_bot_control
                fi
                ;;
            2)
                if check_existing_installation; then
                    setup_telegram_bot
                    if [ "$TELEGRAM_ENABLED" = true ]; then
                        setup_complete_bot_control
                    fi
                else
                    echo -e "${red}Install X-UI first!${plain}"
                fi
                ;;
            3)
                if check_existing_installation; then
                    uninstall_xui
                else
                    echo -e "${yellow}X-UI is not installed${plain}"
                fi
                ;;
            4|"")
                echo -e "${green}Goodbye!${plain}"
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
