#!/bin/bash

# X-UI COMPLETE BOT WITH FIXED DATABASE ACCESS
# By ThuYaAungZaw - Fixed Database Version

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
echo -e "${blue}X-UI Bot with Fixed Database Access${plain}"
echo -e "${green}By ThuYaAungZaw${plain}"
echo -e "${yellow}=========================================${plain}"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: Run as root! Use: sudo su${plain}"
    exit 1
fi

# Global variables
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

# Find correct database path
find_database_path() {
    # Common database paths
    local paths=(
        "/etc/x-ui/x-ui.db"
        "/usr/local/x-ui/x-ui.db"
        "/root/x-ui/x-ui.db"
        "/home/x-ui/x-ui.db"
    )
    
    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try to find using find command
    local found_path=$(find / -name "x-ui.db" 2>/dev/null | head -1)
    if [ -n "$found_path" ]; then
        echo "$found_path"
        return 0
    fi
    
    return 1
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

# FIXED BOT CONTROL SYSTEM WITH PROPER DATABASE ACCESS
setup_fixed_bot_control() {
    if [ "$TELEGRAM_ENABLED" = true ]; then
        echo -e "${green}=== Setting Up Fixed Bot Control ===${plain}"
        
        # Find database path
        DB_PATH=$(find_database_path)
        if [ -z "$DB_PATH" ]; then
            echo -e "${red}❌ X-UI database not found!${plain}"
            echo -e "${yellow}Please make sure X-UI is properly installed.${plain}"
            return 1
        fi
        
        echo -e "${green}✓ Database found: $DB_PATH${plain}"
        
        # Install required packages
        echo -e "${yellow}Installing dependencies...${plain}"
        if command -v apt >/dev/null; then
            apt update -y >/dev/null 2>&1
            apt install -y python3 python3-pip sqlite3 >/dev/null 2>&1
        elif command -v yum >/dev/null; then
            yum update -y >/dev/null 2>&1
            yum install -y python3 python3-pip sqlite3 >/dev/null 2>&1
        fi
        
        pip3 install requests >/dev/null 2>&1
        
        # Create the fixed bot script with proper database handling
        cat > /usr/local/x-ui/fixed_bot.py << 'EOF'
#!/usr/bin/env python3
import sqlite3
import requests
import time
import os
import subprocess
from datetime import datetime

BOT_TOKEN = "TOKEN_PLACEHOLDER"
CHAT_ID = "CHATID_PLACEHOLDER"
DB_PATH = "DB_PATH_PLACEHOLDER"

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
    except Exception as e:
        print(f"Send message error: {e}")
        return False

def get_database_tables():
    """Check what tables exist in the database"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        conn.close()
        return [table[0] for table in tables]
    except Exception as e:
        return f"Error: {str(e)}"

def get_user_stats_fixed():
    """Fixed function to get user statistics"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # First, check available tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [table[0] for table in cursor.fetchall()]
        print(f"Available tables: {tables}")
        
        # Try different table names and structures
        user_data = []
        
        # Try common table structures
        if 'client_traffic' in tables:
            try:
                cursor.execute("PRAGMA table_info(client_traffic)")
                columns = [col[1] for col in cursor.fetchall()]
                print(f"client_traffic columns: {columns}")
                
                if 'expiry_time' in columns:
                    cursor.execute("SELECT username, up, down, expiry_time, total FROM client_traffic")
                else:
                    cursor.execute("SELECT username, up, down, total FROM client_traffic")
                user_data = cursor.fetchall()
            except Exception as e:
                print(f"client_traffic error: {e}")
        
        # If no data, try other table names
        if not user_data and 'inbound' in tables:
            try:
                cursor.execute("PRAGMA table_info(inbound)")
                columns = [col[1] for col in cursor.fetchall()]
                print(f"inbound columns: {columns}")
                cursor.execute("SELECT remark, up, down, enable FROM inbound")
                user_data = cursor.fetchall()
            except Exception as e:
                print(f"inbound error: {e}")
        
        # If still no data, try to get any user-related data
        if not user_data:
            for table in tables:
                if 'user' in table.lower() or 'client' in table.lower():
                    try:
                        cursor.execute(f"SELECT * FROM {table} LIMIT 5")
                        sample_data = cursor.fetchall()
                        print(f"Table {table} sample: {sample_data}")
                    except:
                        pass
        
        conn.close()
        
        if not user_data:
            return "❌ No user data found in database.\n\nAvailable tables: " + ", ".join(tables)
        
        # Process user data
        result = "👥 *User Statistics - Fixed Version*\n\n"
        total_upload = 0
        total_download = 0
        active_users = 0
        
        for i, user in enumerate(user_data):
            if len(user) >= 3:  # At least username, up, down
                username = str(user[0])
                up = int(user[1]) if user[1] else 0
                down = int(user[2]) if user[2] else 0
                
                up_gb = round(up / (1024**3), 3)
                down_gb = round(down / (1024**3), 3)
                total_gb = up_gb + down_gb
                
                total_upload += up_gb
                total_download += down_gb
                active_users += 1
                
                # Check expiry if available
                expiry_info = ""
                if len(user) >= 4 and user[3]:
                    try:
                        expiry_time = int(user[3])
                        if expiry_time > 0:
                            if expiry_time > time.time():
                                expiry_date = datetime.fromtimestamp(expiry_time).strftime('%Y-%m-%d')
                                days_left = (expiry_time - time.time()) // 86400
                                expiry_info = f"⏰ {expiry_date} ({days_left}d)"
                            else:
                                expiry_info = "❌ EXPIRED"
                        else:
                            expiry_info = "♾️ Never"
                    except:
                        expiry_info = ""
                
                result += f"🔸 *{username}*\n"
                result += f"   📤 Upload: `{up_gb:.3f} GB`\n"
                result += f"   📥 Download: `{down_gb:.3f} GB`\n"
                result += f"   📊 Total: `{total_gb:.3f} GB`\n"
                if expiry_info:
                    result += f"   {expiry_info}\n"
                result += "   ───────────────────\n"
        
        # Add summary
        result += f"\n📈 *Summary:*\n"
        result += f"• 👥 Total Users: {len(user_data)}\n"
        result += f"• 📤 Total Upload: `{total_upload:.3f} GB`\n"
        result += f"• 📥 Total Download: `{total_download:.3f} GB`\n"
        result += f"• 📊 Grand Total: `{total_upload + total_download:.3f} GB`\n"
        
        return result
        
    except Exception as e:
        return f"❌ Database error: {str(e)}"

def get_simple_users():
    """Simple user list with basic info"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Try to get basic user info
        user_data = []
        try:
            cursor.execute("SELECT username, up, down FROM client_traffic")
            user_data = cursor.fetchall()
        except:
            try:
                cursor.execute("SELECT remark, up, down FROM inbound")
                user_data = cursor.fetchall()
            except:
                pass
        
        conn.close()
        
        if not user_data:
            return "❌ No user data available"
        
        result = "👥 *User List - Simple View*\n\n"
        for user in user_data:
            if len(user) >= 3:
                username, up, down = user
                up_gb = round((up or 0) / (1024**3), 2)
                down_gb = round((down or 0) / (1024**3), 2)
                total_gb = up_gb + down_gb
                
                result += f"• {username}: 📤{up_gb}G 📥{down_gb}G 📊{total_gb}G\n"
        
        return result
        
    except Exception as e:
        return f"❌ Error: {str(e)}"

def get_server_status():
    """Get server status"""
    try:
        # CPU usage
        cpu = subprocess.getoutput("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1")
        # Memory usage
        mem = subprocess.getoutput("free -m | awk 'NR==2{printf \"%.1f%%\", $3*100/$2}'")
        # Disk usage
        disk = subprocess.getoutput("df -h / | awk 'NR==2{print $5}'")
        # Uptime
        uptime = subprocess.getoutput("uptime -p")
        # X-UI status
        xui_status = subprocess.getoutput("systemctl is-active x-ui")
        
        status_msg = f"""🖥️ *Server Status*

• 💻 CPU Usage: `{cpu}%`
• 🧠 Memory Usage: `{mem}`
• 💿 Disk Usage: `{disk}`
• ⏰ Uptime: {uptime}
• 🔌 X-UI: `{xui_status}`"""

        return status_msg
        
    except Exception as e:
        return f"❌ Status error: {str(e)}"

def handle_command(command, args=""):
    """Handle bot commands"""
    command = command.lower().strip()
    
    if command == "/start":
        return """🤖 *X-UI Fixed Bot Control*

*Commands:*
👥 `/users` - User statistics with expiry
📊 `/list` - Simple user list
🖥️ `/status` - Server status
🔍 `/tables` - Check database tables

*Features:*
✅ Upload/download in GB
✅ Expiry dates
✅ Total usage tracking
✅ Server monitoring"""

    elif command in ["/users", "/stats"]:
        return get_user_stats_fixed()
        
    elif command in ["/list", "/simple"]:
        return get_simple_users()
        
    elif command == "/status":
        return get_server_status()
        
    elif command == "/tables":
        tables = get_database_tables()
        return f"📊 *Database Tables:*\n\n{tables}"
    
    else:
        return "❌ Unknown command. Use `/start` for help."

# Main bot loop
def main():
    print(f"Starting bot with database: {DB_PATH}")
    
    # Test database connection
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.close()
        send_message("✅ *Bot started successfully!*\nDatabase connected: " + DB_PATH)
    except Exception as e:
        send_message("❌ *Bot startup failed!*\nDatabase error: " + str(e))
        return
    
    last_update_id = 0
    
    while True:
        try:
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
                            
                            if str(chat_id) == CHAT_ID:
                                parts = message_text.split(' ', 1)
                                command = parts[0]
                                args = parts[1] if len(parts) > 1 else ""
                                
                                result = handle_command(command, args)
                                send_message(result)
            
            time.sleep(2)
            
        except Exception as e:
            print(f"Bot error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()
EOF

        # Replace placeholders
        sed -i "s/TOKEN_PLACEHOLDER/$TELEGRAM_BOT_TOKEN/g" /usr/local/x-ui/fixed_bot.py
        sed -i "s/CHATID_PLACEHOLDER/$TELEGRAM_CHAT_ID/g" /usr/local/x-ui/fixed_bot.py
        sed -i "s|DB_PATH_PLACEHOLDER|$DB_PATH|g" /usr/local/x-ui/fixed_bot.py
        
        chmod +x /usr/local/x-ui/fixed_bot.py
        
        # Create systemd service
        cat > /etc/systemd/system/x-ui-bot.service << EOF
[Unit]
Description=X-UI Fixed Telegram Bot
After=network.target x-ui.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/x-ui/fixed_bot.py
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable x-ui-bot
        systemctl start x-ui-bot
        
        echo -e "${green}✓ Fixed bot control system installed${plain}"
        echo -e "${yellow}Database path: $DB_PATH${plain}"
        
        # Wait a bit and test
        sleep 3
        echo -e "${yellow}Testing bot functionality...${plain}"
        
        # Send test message
        safe_send_telegram_message "🔧 *X-UI Fixed Bot Activated!*

✅ Database connected: \`$DB_PATH\`
✅ Bot system running
✅ User data monitoring ready

*Try these commands:*
👥 \`/users\` - Detailed user statistics
📊 \`/list\` - Simple user list  
🖥️ \`/status\` - Server status
🔍 \`/tables\` - Check database

Now you should see user data with expiry dates and GB usage! 🎉"
    fi
}

# Main menu
show_menu() {
    echo -e "${cyan}"
    echo "========================================="
    echo "       X-UI FIXED BOT CONTROL"
    echo "========================================="
    echo -e "${plain}"
    
    if check_existing_installation; then
        echo -e "${green}✅ X-UI is installed${plain}"
        DB_PATH=$(find_database_path)
        if [ -n "$DB_PATH" ]; then
            echo -e "${blue}Database: $DB_PATH${plain}"
        else
            echo -e "${red}❌ Database not found${plain}"
        fi
        echo -e ""
        echo -e "1. Setup Telegram Bot Control"
        echo -e "2. Check Database"
        echo -e "3. Exit"
    else
        echo -e "${red}❌ X-UI is not installed${plain}"
        echo -e ""
        echo -e "1. Exit"
    fi
    echo -e ""
}

# Main function
main() {
    get_server_ip
    
    if ! check_existing_installation; then
        echo -e "${red}Please install X-UI first!${plain}"
        exit 1
    fi
    
    # Find and display database info
    DB_PATH=$(find_database_path)
    if [ -z "$DB_PATH" ]; then
        echo -e "${red}❌ X-UI database not found!${plain}"
        echo -e "${yellow}Please check X-UI installation.${plain}"
        exit 1
    fi
    
    echo -e "${green}✓ Database found: $DB_PATH${plain}"
    
    # Check database structure
    echo -e "${yellow}Checking database structure...${plain}"
    if command -v sqlite3 >/dev/null; then
        tables=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null)
        echo -e "${blue}Database tables: $tables${plain}"
    fi
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1)
                setup_telegram_bot
                if [ "$TELEGRAM_ENABLED" = true ]; then
                    setup_fixed_bot_control
                fi
                ;;
            2)
                echo -e "${green}Database Info:${plain}"
                echo -e "Path: $DB_PATH"
                if command -v sqlite3 >/dev/null; then
                    echo -e "Tables: $(sqlite3 "$DB_PATH" ".tables" 2>/dev/null)"
                fi
                ;;
            3|"")
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
