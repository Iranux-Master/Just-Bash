#!/bin/bash

# ==============================================================================
# Iranux Ultimate Setup: PORT 22 EDITION (Stability First)
# Domain: iranux.nz
# Features: Node.js 22, BadVPN (Compiled), Telegram Bot, SSH Port 22
# Version: 1.4.0
# ==============================================================================
echo '#@INSTALL_START'
# Exit on critical errors
set -e

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

# --- CONSTANTS ---
APP_DIR="/opt/iranux-tunnel"
SECRET_PATH="/ssh-wss-tunnel"
CONFIG_FILE="${APP_DIR}/config.env"
BADVPN_PORT="7300"
FIXED_SSH_PORT=22  # <-- FIXED TO 22 TO PREVENT ERRORS

# ------------------------------------------------------------------------------
# PHASE 0: INITIAL CHECKS & INPUTS (INTERACTIVE)
# ------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[X] Error: Run as root.${RESET}"
   exit 1
fi

clear
echo -e "${CYAN}===================================================${RESET}"
echo -e "${CYAN}      IRANUX INSTALLER (SSH PORT 22 EDITION)       ${RESET}"
echo -e "${CYAN}===================================================${RESET}"

# 1. Get Domain (Always Ask)
echo -e "${YELLOW}[?] Please enter your Domain (e.g. sub.iranux.nz):${RESET}"
read -p ">> " DOMAIN

while [[ -z "$DOMAIN" ]]; do
    echo -e "${RED}[!] Domain cannot be empty.${RESET}"
    read -p ">> " DOMAIN
done

# 2. Get Bot Token (Ask if not set in script)
BOT_TOKEN="" 

if [[ -z "$BOT_TOKEN" || "$BOT_TOKEN" == "YOUR_TELEGRAM_BOT_TOKEN" ]]; then
    echo -e "\n${YELLOW}[?] Enter Telegram Bot Token:${RESET}"
    read -p ">> " BOT_TOKEN
fi

# 3. Get Admin ID (Ask if not set in script)
ADMIN_ID=""

if [[ -z "$ADMIN_ID" || "$ADMIN_ID" == "YOUR_TELEGRAM_USER_ID" ]]; then
    echo -e "\n${YELLOW}[?] Enter Your Numeric Admin ID:${RESET}"
    read -p ">> " ADMIN_ID
fi

echo -e "\n${GREEN}[+] Config Loaded:${RESET}"
echo -e "    Domain: $DOMAIN"
echo -e "    SSH   : Port 22 (Fixed)"
echo -e "${CYAN}Starting Installation in 3 seconds...${RESET}"
sleep 3

# ------------------------------------------------------------------------------
# PHASE 1: NUCLEAR CLEAN (PREPARATION)
# ------------------------------------------------------------------------------
echo -e "\n${RED}>>> INITIATING SYSTEM PREP...${RESET}"

# Install Essential Tools
echo -e "${YELLOW}[!] Installing Dependencies...${RESET}"
apt-get update -yqq > /dev/null
apt-get install -yqq psmisc lsof net-tools curl wget ufw openssl coreutils jq git whiptail cmake make gcc g++ > /dev/null

# Kill Conflicts
echo -e "${YELLOW}[!] Clearing Ports...${RESET}"
fuser -k 443/tcp > /dev/null 2>&1 || true
fuser -k 80/tcp > /dev/null 2>&1 || true
fuser -k ${BADVPN_PORT}/udp > /dev/null 2>&1 || true
systemctl stop nginx apache2 caddy badvpn badvpn-udpgw > /dev/null 2>&1 || true
systemctl disable nginx apache2 caddy badvpn badvpn-udpgw > /dev/null 2>&1 || true

# Stop Previous Iranux Services
systemctl stop iranux-proxy iranux-bot > /dev/null 2>&1 || true
systemctl disable iranux-proxy iranux-bot > /dev/null 2>&1 || true
rm -f /etc/systemd/system/iranux-proxy.service /etc/systemd/system/iranux-bot.service
systemctl daemon-reload

# Remove Previous SSH Tunnel Users (skip the current login user to avoid killing our own session)
echo -e "${YELLOW}[!] Removing Previous SSH Tunnel Users...${RESET}"
# Detect the actual login user (works even under sudo)
_CURRENT_LOGIN_USER="${SUDO_USER:-$(logname 2>/dev/null || id -un)}"
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    # Skip the current login user to prevent killing our own session
    [[ "$user" == "$_CURRENT_LOGIN_USER" ]] && continue
    # Skip common system/admin users that should not be removed
    [[ "$user" == "admin" ]] && continue
    pkill -u "$user" > /dev/null 2>&1 || true
    sleep 0.5  # Allow the OS time to clean up processes before removing the user
    userdel --force -r "$user" > /dev/null 2>&1 || true
done

# Clean Previous Installation Data
echo -e "${YELLOW}[!] Cleaning Previous Installation Data...${RESET}"
rm -f /root/usuarios.db
rm -rf /opt/iranux-tunnel
rm -rf /etc/bot
rm -rf /etc/SSHPlus
rm -f /tmp/cad.* /tmp/name-* /tmp/ph /tmp/Relatorio* /tmp/prts
rm -f /root/backup.vps
echo -e "${GREEN}[+] Previous installation cleaned successfully.${RESET}"

# System Upgrade
echo -e "${CYAN}[i] Updating System...${RESET}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -yqq
apt-get upgrade -yqq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# ------------------------------------------------------------------------------
# PHASE 2: NODE.JS & KERNEL OPTIMIZATION
# ------------------------------------------------------------------------------
echo -e "${CYAN}[i] Installing Node.js 22...${RESET}"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
apt-get install -yqq nodejs

echo -e "${CYAN}[i] Enabling TCP BBR...${RESET}"
if ! grep -q "tcp_bbr" /etc/modules-load.d/modules.conf 2>/dev/null; then
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
fi
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p > /dev/null

# ------------------------------------------------------------------------------
# PHASE 3: SSH CONFIGURATION (FORCED TO 22)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[i] Configuring Security...${RESET}"

# Force SSH to Port 22
sed -i 's/^#\?Port .*/Port 22/' /etc/ssh/sshd_config
# If Port line doesn't exist, append it
grep -q "^Port 22" /etc/ssh/sshd_config || echo "Port 22" >> /etc/ssh/sshd_config

# Enable password authentication
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Enable TCP forwarding for tunneling
sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
grep -q "^AllowTcpForwarding yes" /etc/ssh/sshd_config || echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config

# Ensure UsePAM is on
sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
grep -q "^UsePAM yes" /etc/ssh/sshd_config || echo "UsePAM yes" >> /etc/ssh/sshd_config

# Ensure PAM limits module is loaded for SSH sessions
grep -q "pam_limits.so" /etc/pam.d/sshd || echo "session required pam_limits.so" >> /etc/pam.d/sshd

# Restart SSH
systemctl restart ssh 2>/dev/null || systemctl restart sshd

# Firewall
ufw --force reset > /dev/null
ufw allow 22/tcp
ufw allow 443/tcp
ufw allow ${BADVPN_PORT}/udp
ufw --force enable > /dev/null

# ------------------------------------------------------------------------------
# PHASE 4: BADVPN (UDPGW) - COMPILE FROM SOURCE
# ------------------------------------------------------------------------------
echo -e "${CYAN}[i] Compiling BadVPN (UDPGW)...${RESET}"

rm -rf /tmp/badvpn
rm -f /usr/bin/badvpn-udpgw

set +e
git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn > /dev/null 2>&1
mkdir -p /tmp/badvpn/build
cd /tmp/badvpn/build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 > /dev/null 2>&1
make install > /dev/null 2>&1
set -e

if [ ! -f /usr/bin/badvpn-udpgw ]; then
    if [ -f /usr/local/bin/badvpn-udpgw ]; then
        cp /usr/local/bin/badvpn-udpgw /usr/bin/
    elif [ -f ./udpgw/badvpn-udpgw ]; then
        cp ./udpgw/badvpn-udpgw /usr/bin/
    else
        echo -e "${RED}[X] BadVPN compile failed! Continuing without UDPGW...${RESET}"
    fi
fi

if [ -f /usr/bin/badvpn-udpgw ]; then
    chmod +x /usr/bin/badvpn-udpgw
    echo -e "${GREEN}[+] BadVPN binary ready.${RESET}"
else
    echo -e "${RED}[!] BadVPN binary not found. Service will not start.${RESET}"
fi
cd /root
rm -rf /tmp/badvpn

cat << EOF > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN UDPGW
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:${BADVPN_PORT} --max-clients 1000
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable badvpn --now
echo -e "${GREEN}[+] BadVPN Running on port ${BADVPN_PORT}${RESET}"

# ------------------------------------------------------------------------------
# PHASE 5: PROXY SETUP
# ------------------------------------------------------------------------------
mkdir -p ${APP_DIR}/ssl
mkdir -p ${APP_DIR}/logs

# Save Config
echo "DOMAIN=${DOMAIN}" > ${CONFIG_FILE}
echo "SECRET_PATH=${SECRET_PATH}" >> ${CONFIG_FILE}
echo "SSH_PORT=${FIXED_SSH_PORT}" >> ${CONFIG_FILE}
echo "BADVPN_PORT=${BADVPN_PORT}" >> ${CONFIG_FILE}
echo "BOT_TOKEN=${BOT_TOKEN}" >> ${CONFIG_FILE}
echo "ADMIN_ID=${ADMIN_ID}" >> ${CONFIG_FILE}

echo -e "${CYAN}[i] Generating SSL Certificate for ${DOMAIN}...${RESET}"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout ${APP_DIR}/ssl/server.key \
  -out ${APP_DIR}/ssl/server.crt \
  -subj "/C=NZ/O=Iranux/CN=${DOMAIN}" || { echo -e "${RED}[X] SSL certificate generation failed!${RESET}"; exit 1; }

if [[ -f "${APP_DIR}/ssl/server.crt" && -f "${APP_DIR}/ssl/server.key" ]]; then
    echo -e "${GREEN}[+] SSL Certificate generated successfully.${RESET}"
else
    echo -e "${RED}[X] SSL files missing after generation!${RESET}"
    exit 1
fi

cat << EOF > ${APP_DIR}/server.js
const https = require('https');
const fs = require('fs');
const net = require('net');
const CONFIG = { LISTEN_PORT: 443, SSH_PORT: ${FIXED_SSH_PORT}, SSH_HOST: '127.0.0.1', SECRET_PATH: '${SECRET_PATH}' };
const serverOptions = { key: fs.readFileSync('${APP_DIR}/ssl/server.key'), cert: fs.readFileSync('${APP_DIR}/ssl/server.crt') };
const server = https.createServer(serverOptions, (req, res) => { res.writeHead(404); res.end('Not Found'); });
server.on('upgrade', (req, socket, head) => {
    if (req.url !== CONFIG.SECRET_PATH) { socket.destroy(); return; }
    const sshSocket = net.createConnection(CONFIG.SSH_PORT, CONFIG.SSH_HOST);
    sshSocket.on('connect', () => {
        socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n');
        if (head && head.length > 0) sshSocket.write(head);
        socket.pipe(sshSocket); sshSocket.pipe(socket);
    });
    sshSocket.on('error', () => socket.destroy()); socket.on('error', () => sshSocket.destroy());
});
server.listen(CONFIG.LISTEN_PORT, '0.0.0.0');
EOF

# ------------------------------------------------------------------------------
# PHASE 6: TELEGRAM BOT
# ------------------------------------------------------------------------------
cat << 'BOTEOF' > ${APP_DIR}/iranux-bot.sh
#!/bin/bash
exec >> /opt/iranux-tunnel/logs/bot.log 2>&1

source /opt/iranux-tunnel/config.env

API_BASE="https://api.telegram.org/bot${BOT_TOKEN}"
STATE_DIR="/opt/iranux-tunnel/state"
mkdir -p "${STATE_DIR}"
chmod 700 "${STATE_DIR}"

# --- Signal handling ---
_shutdown() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Bot shutting down..."
    tg_send_msg "${ADMIN_ID}" "🔴 <b>Iranux Bot is shutting down.</b>"
    exit 0
}
trap '_shutdown' SIGTERM SIGINT

# --- Telegram API wrapper functions ---
tg_api_call() {
    local method="$1"
    local data="$2"
    curl -s -X POST "${API_BASE}/${method}" \
        -H "Content-Type: application/json" \
        -d "${data}"
}

tg_send_msg() {
    local chat_id="$1"
    local text="$2"
    local data
    data=$(jq -n --arg c "${chat_id}" --arg t "${text}" \
        '{chat_id: $c, text: $t, parse_mode: "HTML"}')
    tg_api_call "sendMessage" "${data}" >> /opt/iranux-tunnel/logs/bot.log 2>&1
}

tg_send_msg_keyboard() {
    local chat_id="$1"
    local text="$2"
    local keyboard="$3"
    local data
    data=$(jq -n --arg c "${chat_id}" --arg t "${text}" --argjson k "${keyboard}" \
        '{chat_id: $c, text: $t, parse_mode: "HTML", reply_markup: {inline_keyboard: $k}}')
    tg_api_call "sendMessage" "${data}" >> /opt/iranux-tunnel/logs/bot.log 2>&1
}

tg_send_force_reply() {
    local chat_id="$1"
    local text="$2"
    local data
    data=$(jq -n --arg c "${chat_id}" --arg t "${text}" \
        '{chat_id: $c, text: $t, parse_mode: "HTML", reply_markup: {force_reply: true, selective: true}}')
    tg_api_call "sendMessage" "${data}" >> /opt/iranux-tunnel/logs/bot.log 2>&1
}

tg_answer_callback() {
    local callback_id="$1"
    local text="$2"
    local data
    data=$(jq -n --arg i "${callback_id}" --arg t "${text}" \
        '{callback_query_id: $i, text: $t}')
    tg_api_call "answerCallbackQuery" "${data}" >> /opt/iranux-tunnel/logs/bot.log 2>&1
}

tg_edit_msg() {
    local chat_id="$1"
    local msg_id="$2"
    local text="$3"
    local data
    data=$(jq -n --arg c "${chat_id}" --arg m "${msg_id}" --arg t "${text}" \
        '{chat_id: $c, message_id: ($m|tonumber), text: $t, parse_mode: "HTML"}')
    tg_api_call "editMessageText" "${data}" >> /opt/iranux-tunnel/logs/bot.log 2>&1
}

tg_send_document() {
    local chat_id="$1"
    local file_path="$2"
    local caption="$3"
    curl -s -F "chat_id=${chat_id}" \
        -F "document=@${file_path}" \
        -F "caption=${caption}" \
        -F "parse_mode=HTML" \
        "${API_BASE}/sendDocument" >> /opt/iranux-tunnel/logs/bot.log 2>&1
}

# --- Main menu ---
show_menu() {
    local chat_id="$1"
    local keyboard='[
        [{"text":"👤 Add User","callback_data":"_adduser"},{"text":"🗑 Del User","callback_data":"_deluser"}],
        [{"text":"📋 List Users","callback_data":"_listusers"},{"text":"👥 Online Users","callback_data":"_online"}],
        [{"text":"ℹ️ User Info","callback_data":"_userinfo"},{"text":"📊 Server Status","callback_data":"_status"}],
        [{"text":"🔑 Change Pass","callback_data":"_changepass"},{"text":"🔢 Change Limit","callback_data":"_changelimit"}],
        [{"text":"📅 Change Expiry","callback_data":"_changeexpiry"},{"text":"🧹 Remove Expired","callback_data":"_removeexpired"}],
        [{"text":"💾 Backup","callback_data":"_backup"},{"text":"⚡ Speed Test","callback_data":"_speedtest"}],
        [{"text":"❓ Help","callback_data":"_help"}]
    ]'
    tg_send_msg_keyboard "${chat_id}" "🔰 <b>Iranux Manager</b>
Select an option:" "${keyboard}"
}

# --- Callback handlers ---
handle_adduser() {
    local chat_id="$1"
    local callback_id="$2"
    tg_answer_callback "${callback_id}" "Add User"
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return
    rm -f "${STATE_DIR}/state.${chat_id}" "${STATE_DIR}/data.${chat_id}"
    echo "adduser_username" > "${STATE_DIR}/state.${chat_id}"
    tg_send_force_reply "${chat_id}" "👤 <b>Add User</b>
Enter the <b>username</b> for the new user:"
}

handle_deluser() {
    local chat_id="$1"
    local callback_id="$2"
    tg_answer_callback "${callback_id}" "Delete User"
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return
    rm -f "${STATE_DIR}/state.${chat_id}" "${STATE_DIR}/data.${chat_id}"
    echo "deluser_username" > "${STATE_DIR}/state.${chat_id}"
    tg_send_force_reply "${chat_id}" "🗑 <b>Delete User</b>
Enter the <b>username</b> to delete:"
}

handle_listusers() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Listing users..."
    local result
    result=$(iranux /list --json 2>/dev/null)
    local user_list=""
    if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
        user_list=$(echo "${result}" | jq -r \
            '.data.users[] | "• <code>\(.username)</code> | Exp: \(.expiry) | Logins: \(.max_logins)"' \
            2>/dev/null)
    fi
    if [[ -z "${user_list}" ]]; then
        tg_send_msg "${chat_id}" "📋 No users found."
    else
        tg_send_msg "${chat_id}" "📋 <b>User List:</b>
${user_list}"
    fi
}

handle_online() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Checking online users..."
    local online_list
    online_list=$(who | grep pts | awk '{print "• <code>"$1"</code> ("$2")"}')
    if [[ -z "${online_list}" ]]; then
        tg_send_msg "${chat_id}" "👥 No users currently connected."
    else
        tg_send_msg "${chat_id}" "👥 <b>Online Users:</b>
${online_list}"
    fi
}

handle_status() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Checking status..."
    local result
    result=$(iranux /status --json 2>/dev/null)
    local proxy_st badvpn_st uptime_val
    if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
        proxy_st=$(echo "${result}" | jq -r '.data.proxy_status // "unknown"')
        badvpn_st=$(echo "${result}" | jq -r '.data.badvpn_status // "unknown"')
        uptime_val=$(echo "${result}" | jq -r '.data.uptime // "unknown"')
    else
        proxy_st=$(systemctl is-active iranux-tunnel 2>/dev/null || echo "inactive")
        badvpn_st=$(systemctl is-active badvpn 2>/dev/null || echo "inactive")
        uptime_val=$(uptime -p 2>/dev/null || echo "unknown")
    fi
    tg_send_msg "${chat_id}" "📊 <b>Server Status</b>
Domain: <code>${DOMAIN}</code>
SSH Port: <code>22</code>
Proxy (443): <code>${proxy_st}</code>
UDPGW (${BADVPN_PORT}): <code>${badvpn_st}</code>
Uptime: <code>${uptime_val}</code>"
}

handle_userinfo() {
    local chat_id="$1"
    local callback_id="$2"
    tg_answer_callback "${callback_id}" "User Info"
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return
    rm -f "${STATE_DIR}/state.${chat_id}" "${STATE_DIR}/data.${chat_id}"
    echo "userinfo_username" > "${STATE_DIR}/state.${chat_id}"
    tg_send_force_reply "${chat_id}" "ℹ️ <b>User Info</b>
Enter the <b>username</b> to look up:"
}

handle_changepass() {
    local chat_id="$1"
    local callback_id="$2"
    tg_answer_callback "${callback_id}" "Change Password"
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return
    rm -f "${STATE_DIR}/state.${chat_id}" "${STATE_DIR}/data.${chat_id}"
    echo "changepass_username" > "${STATE_DIR}/state.${chat_id}"
    tg_send_force_reply "${chat_id}" "🔑 <b>Change Password</b>
Enter the <b>username</b>:"
}

handle_changelimit() {
    local chat_id="$1"
    local callback_id="$2"
    tg_answer_callback "${callback_id}" "Change Limit"
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return
    rm -f "${STATE_DIR}/state.${chat_id}" "${STATE_DIR}/data.${chat_id}"
    echo "changelimit_username" > "${STATE_DIR}/state.${chat_id}"
    tg_send_force_reply "${chat_id}" "🔢 <b>Change Max Logins</b>
Enter the <b>username</b>:"
}

handle_changeexpiry() {
    local chat_id="$1"
    local callback_id="$2"
    tg_answer_callback "${callback_id}" "Change Expiry"
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return
    rm -f "${STATE_DIR}/state.${chat_id}" "${STATE_DIR}/data.${chat_id}"
    echo "changeexpiry_username" > "${STATE_DIR}/state.${chat_id}"
    tg_send_force_reply "${chat_id}" "📅 <b>Change Expiry</b>
Enter the <b>username</b>:"
}

handle_removeexpired() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Removing expired users..."
    local removed=0
    local removed_list=""
    while IFS=: read -r uname _ uid _; do
        if [[ "$uid" -ge 1000 && "$uname" != "nobody" ]]; then
            local u_exp
            u_exp=$(chage -l "$uname" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
            if [[ -n "$u_exp" && "$u_exp" != "never" && "$u_exp" != "Never" ]]; then
                local exp_ts now_ts
                exp_ts=$(date -d "$u_exp" +%s 2>/dev/null || echo 0)
                now_ts=$(date +%s)
                if [[ "$exp_ts" -gt 0 && "$exp_ts" -lt "$now_ts" ]]; then
                    userdel -r "$uname" 2>/dev/null
                    sed -i "/^${uname}[[:space:]]\+soft[[:space:]]\+maxlogins/d" /etc/security/limits.conf
                    removed=$((removed + 1))
                    removed_list="${removed_list}• <code>${uname}</code>
"
                fi
            fi
        fi
    done < /etc/passwd
    if [[ "${removed}" -eq 0 ]]; then
        tg_send_msg "${chat_id}" "🧹 No expired users found."
    else
        tg_send_msg "${chat_id}" "🧹 <b>Removed ${removed} expired user(s):</b>
${removed_list}"
    fi
}

handle_backup() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Creating backup..."
    local backup_file="/tmp/iranux-backup-$(date +%Y%m%d%H%M%S).txt"
    {
        echo "# Iranux SSH Tunnel Backup - $(date)"
        echo "# Domain: ${DOMAIN}"
        echo ""
        echo "# Users:"
        while IFS=: read -r uname _ uid _; do
            if [[ "$uid" -ge 1000 && "$uname" != "nobody" ]]; then
                local u_exp u_limit
                u_exp=$(chage -l "$uname" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs || echo "Never")
                u_limit=$(grep "^$uname soft maxlogins" /etc/security/limits.conf 2>/dev/null | awk '{print $4}' || echo "Unlimited")
                echo "  ${uname} | Expiry: ${u_exp} | Max Logins: ${u_limit}"
            fi
        done < /etc/passwd
    } > "${backup_file}"
    tg_send_document "${chat_id}" "${backup_file}" "💾 Iranux Backup - $(date +%Y-%m-%d)"
    rm -f "${backup_file}"
}

handle_speedtest() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Running speed test..."
    tg_send_msg "${chat_id}" "⚡ Running speed test, please wait..."
    local result
    if command -v speedtest-cli >/dev/null 2>&1; then
        if ! result=$(speedtest-cli --simple 2>&1 | head -5) || [[ -z "${result}" ]]; then
            result="Speed test failed"
        fi
    elif command -v speedtest >/dev/null 2>&1; then
        if ! result=$(speedtest 2>&1 | grep -E "Download|Upload|Ping" | head -5) || [[ -z "${result}" ]]; then
            result="Speed test failed"
        fi
    else
        local dl_speed
        dl_speed=$(curl -s --max-time 15 -o /dev/null -w "%{speed_download}" \
            "http://speedtest.tele2.net/10MB.zip" 2>/dev/null || echo "0")
        local dl_mbps
        dl_mbps=$(awk "BEGIN {printf \"%.2f\", ${dl_speed}/125000}" 2>/dev/null || echo "N/A")
        result="Download: ~${dl_mbps} Mbps (approximate)"
    fi
    tg_send_msg "${chat_id}" "⚡ <b>Speed Test Result:</b>
<code>${result}</code>"
}

handle_help() {
    local chat_id="$1"
    local callback_id="$2"
    [[ -n "${callback_id}" ]] && tg_answer_callback "${callback_id}" "Help"
    tg_send_msg "${chat_id}" "❓ <b>Iranux Bot Help</b>
Use the menu buttons to manage SSH users.

<b>Available actions:</b>
• <b>Add User</b> — Create a new SSH user
• <b>Del User</b> — Delete an existing SSH user
• <b>List Users</b> — Show all SSH users
• <b>Online Users</b> — Show currently connected users
• <b>User Info</b> — Show details of a specific user
• <b>Server Status</b> — Show server status
• <b>Change Pass</b> — Change a user's password
• <b>Change Limit</b> — Modify max logins for a user
• <b>Change Expiry</b> — Modify expiry date for a user
• <b>Remove Expired</b> — Clean up expired accounts
• <b>Backup</b> — Create and send user backup
• <b>Speed Test</b> — Run server speed test

Send /menu to open the menu at any time."
}

# --- Conversation state machine ---
handle_conversation() {
    local chat_id="$1"
    local text="$2"
    # Validate chat_id is numeric to prevent path traversal
    [[ ! "${chat_id}" =~ ^-?[0-9]+$ ]] && return 1
    local state_file="${STATE_DIR}/state.${chat_id}"
    local data_file="${STATE_DIR}/data.${chat_id}"
    [[ ! -f "${state_file}" ]] && return 1
    local state
    state=$(cat "${state_file}")

    case "${state}" in
        adduser_username)
            echo "${text}" > "${data_file}"
            echo "adduser_password" > "${state_file}"
            tg_send_force_reply "${chat_id}" "🔑 Enter the <b>password</b> for user <code>${text}</code>:"
            ;;
        adduser_password)
            local username
            username=$(cat "${data_file}")
            printf '%s\n%s\n' "${username}" "${text}" > "${data_file}"
            echo "adduser_days" > "${state_file}"
            tg_send_force_reply "${chat_id}" "📅 Enter <b>expiry days</b> (e.g. <code>30</code>), or <code>0</code> for no expiry:"
            ;;
        adduser_days)
            local username password
            username=$(sed -n '1p' "${data_file}")
            password=$(sed -n '2p' "${data_file}")
            printf '%s\n%s\n%s\n' "${username}" "${password}" "${text}" > "${data_file}"
            echo "adduser_limit" > "${state_file}"
            tg_send_force_reply "${chat_id}" "🔗 Enter <b>max logins</b> (e.g. <code>2</code>), or <code>0</code> for unlimited:"
            ;;
        adduser_limit)
            local username password days limit
            username=$(sed -n '1p' "${data_file}")
            password=$(sed -n '2p' "${data_file}")
            days=$(sed -n '3p' "${data_file}")
            limit="${text}"
            rm -f "${state_file}" "${data_file}"
            [[ "${days}" == "0" ]] && days=""
            [[ "${limit}" == "0" ]] && limit=""
            local result
            result=$(iranux /add "${username}" "${password}" "${days}" "${limit}" --json 2>/dev/null)
            if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
                local exp max_logins payload
                exp=$(echo "${result}" | jq -r '.data.expiry // "Never"')
                max_logins=$(echo "${result}" | jq -r '.data.max_logins // "Unlimited"')
                payload=$(echo "${result}" | jq -r '.data.payload // ""')
                tg_send_msg "${chat_id}" "✅ <b>Iranux Config Created</b>
--------------------------------
<b>Protocol:</b> <code>SSH-TLS-Payload</code>
<b>Remarks:</b> <code>${username}</code>
<b>SSH Host:</b> <code>${DOMAIN}</code>
<b>SSH Port:</b> <code>443</code>
<b>UDPGW Port:</b> <code>${BADVPN_PORT}</code>
<b>SSH Username:</b> <code>${username}</code>
<b>SSH Password:</b> <code>${password}</code>
<b>SNI:</b> <code>${DOMAIN}</code>
<b>Expiry:</b> <code>${exp}</code>
<b>Max Logins:</b> <code>${max_logins}</code>
--------------------------------
👇 <b>Payload (Copy Exact):</b>
<code>${payload}</code>"
            else
                local errmsg
                errmsg=$(echo "${result}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                tg_send_msg "${chat_id}" "❌ Failed to create user: ${errmsg}"
            fi
            ;;
        deluser_username)
            rm -f "${state_file}" "${data_file}"
            local result
            result=$(iranux /del "${text}" --json 2>/dev/null)
            if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
                tg_send_msg "${chat_id}" "✅ User <code>${text}</code> deleted successfully."
            else
                local errmsg
                errmsg=$(echo "${result}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                tg_send_msg "${chat_id}" "❌ Failed to delete user: ${errmsg}"
            fi
            ;;
        userinfo_username)
            rm -f "${state_file}" "${data_file}"
            local result
            result=$(iranux /info "${text}" --json 2>/dev/null)
            if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
                local exp max_logins
                exp=$(echo "${result}" | jq -r '.data.expiry // "Never"')
                max_logins=$(echo "${result}" | jq -r '.data.max_logins // "Unlimited"')
                tg_send_msg "${chat_id}" "ℹ️ <b>User Info: ${text}</b>
Expiry: <code>${exp}</code>
Max Logins: <code>${max_logins}</code>"
            else
                local errmsg
                errmsg=$(echo "${result}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                tg_send_msg "${chat_id}" "❌ ${errmsg}"
            fi
            ;;
        changepass_username)
            echo "${text}" > "${data_file}"
            echo "changepass_password" > "${state_file}"
            tg_send_force_reply "${chat_id}" "🔑 Enter the <b>new password</b> for user <code>${text}</code>:"
            ;;
        changepass_password)
            local cp_user
            cp_user=$(cat "${data_file}")
            rm -f "${state_file}" "${data_file}"
            if ! id "${cp_user}" &>/dev/null; then
                tg_send_msg "${chat_id}" "❌ User <code>${cp_user}</code> not found."
            elif echo "${cp_user}:${text}" | chpasswd 2>/dev/null; then
                tg_send_msg "${chat_id}" "✅ Password changed for <code>${cp_user}</code>."
            else
                tg_send_msg "${chat_id}" "❌ Failed to change password for <code>${cp_user}</code>."
            fi
            ;;
        changelimit_username)
            echo "${text}" > "${data_file}"
            echo "changelimit_value" > "${state_file}"
            tg_send_force_reply "${chat_id}" "🔢 Enter the <b>new max logins</b> for user <code>${text}</code> (or <code>0</code> for unlimited):"
            ;;
        changelimit_value)
            local cl_user
            cl_user=$(cat "${data_file}")
            rm -f "${state_file}" "${data_file}"
            if ! id "${cl_user}" &>/dev/null; then
                tg_send_msg "${chat_id}" "❌ User <code>${cl_user}</code> not found."
            else
                sed -i "/^${cl_user}[[:space:]]\+soft[[:space:]]\+maxlogins/d" /etc/security/limits.conf
                if [[ "${text}" != "0" && -n "${text}" ]]; then
                    echo "${cl_user} soft maxlogins ${text}" >> /etc/security/limits.conf
                    tg_send_msg "${chat_id}" "✅ Max logins for <code>${cl_user}</code> set to <code>${text}</code>."
                else
                    tg_send_msg "${chat_id}" "✅ Max logins for <code>${cl_user}</code> set to unlimited."
                fi
            fi
            ;;
        changeexpiry_username)
            echo "${text}" > "${data_file}"
            echo "changeexpiry_days" > "${state_file}"
            tg_send_force_reply "${chat_id}" "📅 Enter <b>new expiry days</b> for user <code>${text}</code> (or <code>0</code> to remove expiry):"
            ;;
        changeexpiry_days)
            local ce_user
            ce_user=$(cat "${data_file}")
            rm -f "${state_file}" "${data_file}"
            if ! id "${ce_user}" &>/dev/null; then
                tg_send_msg "${chat_id}" "❌ User <code>${ce_user}</code> not found."
            else
                if [[ "${text}" == "0" || -z "${text}" ]]; then
                    chage -E -1 "${ce_user}" 2>/dev/null
                    tg_send_msg "${chat_id}" "✅ Expiry removed for <code>${ce_user}</code> (no expiry)."
                elif [[ ! "${text}" =~ ^[0-9]+$ ]]; then
                    tg_send_msg "${chat_id}" "❌ Invalid input: please enter a number of days."
                else
                    local new_exp
                    new_exp=$(date -d "+${text} days" +%Y-%m-%d 2>/dev/null)
                    if [[ -z "${new_exp}" ]]; then
                        tg_send_msg "${chat_id}" "❌ Invalid number of days: <code>${text}</code>."
                    else
                        chage -E "${new_exp}" "${ce_user}" 2>/dev/null
                        tg_send_msg "${chat_id}" "✅ Expiry for <code>${ce_user}</code> set to <code>${new_exp}</code>."
                    fi
                fi
            fi
            ;;
        *)
            rm -f "${state_file}" "${data_file}"
            return 1
            ;;
    esac
    return 0
}

# --- Process a single update ---
process_update() {
    local update="$1"

    # Handle callback_query
    if echo "${update}" | jq -e '.callback_query' > /dev/null 2>&1; then
        local cb_id cb_data from_id chat_id
        cb_id=$(echo "${update}" | jq -r '.callback_query.id')
        cb_data=$(echo "${update}" | jq -r '.callback_query.data')
        from_id=$(echo "${update}" | jq -r '.callback_query.from.id')
        chat_id=$(echo "${update}" | jq -r '.callback_query.message.chat.id')

        if [[ "${from_id}" != "${ADMIN_ID}" ]]; then
            tg_answer_callback "${cb_id}" "🚫 Access Denied"
            return
        fi

        case "${cb_data}" in
            _adduser)       handle_adduser       "${chat_id}" "${cb_id}" ;;
            _deluser)       handle_deluser       "${chat_id}" "${cb_id}" ;;
            _listusers)     handle_listusers     "${chat_id}" "${cb_id}" ;;
            _online)        handle_online        "${chat_id}" "${cb_id}" ;;
            _status)        handle_status        "${chat_id}" "${cb_id}" ;;
            _userinfo)      handle_userinfo      "${chat_id}" "${cb_id}" ;;
            _changepass)    handle_changepass    "${chat_id}" "${cb_id}" ;;
            _changelimit)   handle_changelimit   "${chat_id}" "${cb_id}" ;;
            _changeexpiry)  handle_changeexpiry  "${chat_id}" "${cb_id}" ;;
            _removeexpired) handle_removeexpired "${chat_id}" "${cb_id}" ;;
            _backup)        handle_backup        "${chat_id}" "${cb_id}" ;;
            _speedtest)     handle_speedtest     "${chat_id}" "${cb_id}" ;;
            _help)          handle_help          "${chat_id}" "${cb_id}" ;;
            *)              tg_answer_callback "${cb_id}" "" ;;
        esac
        return
    fi

    # Handle message
    local chat_id from_id msg_text
    chat_id=$(echo "${update}" | jq -r '.message.chat.id // empty')
    from_id=$(echo "${update}" | jq -r '.message.from.id // empty')
    msg_text=$(echo "${update}" | jq -r '.message.text // empty')

    [[ -z "${chat_id}" || -z "${from_id}" ]] && return

    if [[ "${from_id}" != "${ADMIN_ID}" ]]; then
        tg_send_msg "${chat_id}" "🚫 ACCESS DENIED 🚫"
        return
    fi

    [[ -z "${msg_text}" ]] && return

    # Check for active conversation state first
    handle_conversation "${chat_id}" "${msg_text}" && return

    # Handle commands
    case "${msg_text}" in
        /start|/menu)
            show_menu "${chat_id}"
            ;;
        /help)
            handle_help "${chat_id}" ""
            ;;
        /add*)
            read -r _ u_name u_pass u_days u_limit <<< "${msg_text}"
            if [[ -z "${u_name}" || -z "${u_pass}" ]]; then
                tg_send_msg "${chat_id}" "❌ Usage: <code>/add username password [days] [limit]</code>"
            else
                local result
                result=$(iranux /add "${u_name}" "${u_pass}" "${u_days}" "${u_limit}" --json 2>/dev/null)
                if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
                    local exp max_logins payload
                    exp=$(echo "${result}" | jq -r '.data.expiry // "Never"')
                    max_logins=$(echo "${result}" | jq -r '.data.max_logins // "Unlimited"')
                    payload=$(echo "${result}" | jq -r '.data.payload // ""')
                    tg_send_msg "${chat_id}" "✅ <b>Iranux Config Created</b>
--------------------------------
<b>Protocol:</b> <code>SSH-TLS-Payload</code>
<b>Remarks:</b> <code>${u_name}</code>
<b>SSH Host:</b> <code>${DOMAIN}</code>
<b>SSH Port:</b> <code>443</code>
<b>UDPGW Port:</b> <code>${BADVPN_PORT}</code>
<b>SSH Username:</b> <code>${u_name}</code>
<b>SSH Password:</b> <code>${u_pass}</code>
<b>SNI:</b> <code>${DOMAIN}</code>
<b>Expiry:</b> <code>${exp}</code>
<b>Max Logins:</b> <code>${max_logins}</code>
--------------------------------
👇 <b>Payload (Copy Exact):</b>
<code>${payload}</code>"
                else
                    local errmsg
                    errmsg=$(echo "${result}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                    tg_send_msg "${chat_id}" "❌ Failed to create user: ${errmsg}"
                fi
            fi
            ;;
        /del*)
            read -r _ u_del <<< "${msg_text}"
            if [[ -z "${u_del}" ]]; then
                tg_send_msg "${chat_id}" "❌ Usage: <code>/del username</code>"
            else
                local result
                result=$(iranux /del "${u_del}" --json 2>/dev/null)
                if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
                    tg_send_msg "${chat_id}" "✅ User <code>${u_del}</code> deleted successfully."
                else
                    local errmsg
                    errmsg=$(echo "${result}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                    tg_send_msg "${chat_id}" "❌ Failed to delete user: ${errmsg}"
                fi
            fi
            ;;
        /list)
            handle_listusers "${chat_id}" ""
            ;;
        /status)
            handle_status "${chat_id}" ""
            ;;
        /info*)
            read -r _ u_info <<< "${msg_text}"
            if [[ -z "${u_info}" ]]; then
                tg_send_msg "${chat_id}" "❌ Usage: <code>/info username</code>"
            else
                local result
                result=$(iranux /info "${u_info}" --json 2>/dev/null)
                if echo "${result}" | jq -e '.status == "success"' > /dev/null 2>&1; then
                    local exp max_logins
                    exp=$(echo "${result}" | jq -r '.data.expiry // "Never"')
                    max_logins=$(echo "${result}" | jq -r '.data.max_logins // "Unlimited"')
                    tg_send_msg "${chat_id}" "ℹ️ <b>User Info: ${u_info}</b>
Expiry: <code>${exp}</code>
Max Logins: <code>${max_logins}</code>"
                else
                    local errmsg
                    errmsg=$(echo "${result}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
                    tg_send_msg "${chat_id}" "❌ ${errmsg}"
                fi
            fi
            ;;
        *)
            show_menu "${chat_id}"
            ;;
    esac
}

# --- Startup validation ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting Iranux Telegram Bot..."
if [[ -z "${BOT_TOKEN}" || -z "${ADMIN_ID}" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] BOT_TOKEN or ADMIN_ID not set in config.env"
    exit 1
fi
test_resp=$(curl -s --max-time 10 "${API_BASE}/getMe")
if ! echo "${test_resp}" | jq -e '.ok == true' > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Invalid BOT_TOKEN or Telegram unreachable. Response: ${test_resp}"
    exit 1
fi
bot_name=$(echo "${test_resp}" | jq -r '.result.username // "unknown"')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Bot validated: @${bot_name}"

tg_send_msg "${ADMIN_ID}" "🚀 <b>Iranux Server Online!</b>
Bot: @${bot_name}
------------------
Tap /menu to start."

# --- Main polling loop ---
last_update_id=0
err_count=0
while true; do
    offset=$((last_update_id + 1))
    response=$(curl -s --max-time 50 \
        "${API_BASE}/getUpdates?offset=${offset}&limit=100&timeout=30")
    curl_exit=$?

    if [[ ${curl_exit} -ne 0 || -z "${response}" ]]; then
        err_count=$((err_count + 1))
        delay=$((2 ** err_count > 60 ? 60 : 2 ** err_count))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] curl failed (attempt ${err_count}), retrying in ${delay}s..."
        sleep "${delay}"
        continue
    fi

    if ! echo "${response}" | jq -e '.ok == true' > /dev/null 2>&1; then
        err_count=$((err_count + 1))
        delay=$((2 ** err_count > 60 ? 60 : 2 ** err_count))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] API error (attempt ${err_count}), retrying in ${delay}s..."
        sleep "${delay}"
        continue
    fi
    err_count=0

    result_count=$(echo "${response}" | jq '.result | length')
    [[ -z "${result_count}" || "${result_count}" == "0" ]] && continue

    for i in $(seq 0 $((result_count - 1))); do
        update=$(echo "${response}" | jq ".result[${i}]")
        update_id=$(echo "${update}" | jq -r '.update_id')
        [[ -z "${update_id}" ]] && continue
        last_update_id=${update_id}
        ( process_update "${update}" ) &
    done
    wait
done
BOTEOF

chmod +x ${APP_DIR}/iranux-bot.sh

# ------------------------------------------------------------------------------
# PHASE 7: CLI MENU
# ------------------------------------------------------------------------------
cat << 'EOF' > /usr/local/bin/iranux
#!/bin/bash
CONFIG_FILE="/opt/iranux-tunnel/config.env"
if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; fi
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# JSON output helpers
json_success() {
    local cmd="$1"
    local data="$2"
    printf '{"status":"success","command":"%s","data":%s}\n' "$cmd" "$data"
}

json_error() {
    local cmd="$1"
    local code="$2"
    local msg="$3"
    printf '{"status":"error","command":"%s","code":%s,"message":"%s"}\n' "$cmd" "$code" "$msg"
    exit "$code"
}

has_json() {
    for arg in "$@"; do [[ "$arg" == "--json" ]] && return 0; done
    return 1
}

# --- Non-interactive argument mode ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        /add|add)
            u_name="$2"
            u_pass="$3"
            u_days="$4"
            u_limit="$5"
            if [[ -z "$u_name" || -z "$u_pass" ]]; then
                has_json "$@" && json_error "add" 5 "Invalid parameter: username and password required" || \
                    echo -e "${RED}Usage: iranux /add <username> <password> [days] [maxlogins]${NC}"
                exit 5
            fi
            if id "$u_name" &>/dev/null; then
                has_json "$@" && json_error "add" 3 "User already exists" || \
                    echo -e "${RED}[!] User '$u_name' already exists.${NC}"
                exit 3
            fi
            if ! useradd -m -s /bin/false "$u_name"; then
                has_json "$@" && json_error "add" 6 "System error creating user" || \
                    echo -e "${RED}[!] System error: failed to create user '$u_name'.${NC}"
                exit 6
            fi
            echo "$u_name:$u_pass" | chpasswd
            if [[ -n "$u_days" ]]; then
                exp_date=$(date -d "+$u_days days" +%Y-%m-%d)
                chage -E "$exp_date" "$u_name"
            else
                exp_date="Never"
            fi
            if [[ -n "$u_limit" ]]; then
                sed -i "/^$u_name/d" /etc/security/limits.conf
                echo "$u_name soft maxlogins $u_limit" >> /etc/security/limits.conf
            else
                u_limit="Unlimited"
            fi
            payload="GET ${SECRET_PATH} HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: Mozilla/5.0[crlf][crlf]"
            if has_json "$@"; then
                data=$(printf '{"username":"%s","password":"%s","expiry":"%s","max_logins":"%s","ssh_host":"%s","ssh_port":443,"udpgw_port":%s,"sni":"%s","protocol":"SSH-TLS-Payload","payload":"%s"}' \
                    "$u_name" "$u_pass" "$exp_date" "$u_limit" "$DOMAIN" "$BADVPN_PORT" "$DOMAIN" "$payload")
                json_success "add" "$data"
            else
                echo -e "\n${GREEN}=== HTTP CUSTOM CONFIG ===${NC}"
                echo -e "Protocol    : SSH-TLS-Payload"
                echo -e "Remarks     : ${u_name}"
                echo -e "SSH Host    : ${DOMAIN}"
                echo -e "SSH Port    : 443"
                echo -e "UDPGW Port  : ${BADVPN_PORT}"
                echo -e "SSH Username: ${u_name}"
                echo -e "SSH Password: ${u_pass}"
                echo -e "SNI         : ${DOMAIN}"
                echo -e "---------------------------------"
                echo -e "PAYLOAD:"
                echo -e "${payload}"
                echo -e "---------------------------------"
                echo -e "Expiry      : ${exp_date}"
                echo -e "Max Logins  : ${u_limit}"
            fi
            exit 0
            ;;
        /del|del)
            u_del="$2"
            if [[ -z "$u_del" ]]; then
                has_json "$@" && json_error "del" 5 "Invalid parameter: username required" || \
                    echo -e "${RED}Usage: iranux /del <username>${NC}"
                exit 5
            fi
            if id "$u_del" &>/dev/null; then
                userdel -r "$u_del" 2>/dev/null
                sed -i "/^$u_del/d" /etc/security/limits.conf
                if has_json "$@"; then
                    data=$(printf '{"username":"%s","message":"User deleted successfully"}' "$u_del")
                    json_success "del" "$data"
                else
                    echo -e "${GREEN}[+] User '$u_del' deleted.${NC}"
                fi
            else
                has_json "$@" && json_error "del" 4 "User not found" || \
                    echo -e "${RED}[!] User '$u_del' not found.${NC}"
                exit 4
            fi
            exit 0
            ;;
        /list|list)
            if has_json "$@"; then
                users_json=""
                total=0
                while IFS=: read -r uname _ uid _; do
                    if [[ "$uid" -ge 1000 && "$uname" != "nobody" ]]; then
                        u_expiry=$(chage -l "$uname" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs || echo "Never")
                        u_maxlogins=$(grep "^$uname soft maxlogins" /etc/security/limits.conf 2>/dev/null | awk '{print $4}' || echo "Unlimited")
                        [[ -n "$users_json" ]] && users_json+=","
                        users_json+=$(printf '{"username":"%s","expiry":"%s","max_logins":"%s","active":true}' "$uname" "$u_expiry" "$u_maxlogins")
                        total=$((total + 1))
                    fi
                done < /etc/passwd
                data=$(printf '{"users":[%s],"total":%s}' "$users_json" "$total")
                json_success "list" "$data"
            else
                echo -e "${GREEN}=== System Users ===${NC}"
                awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
            fi
            exit 0
            ;;
        /status|status)
            PROXY_STATUS=$(systemctl is-active iranux-tunnel 2>/dev/null || echo "inactive")
            BADVPN_STATUS=$(systemctl is-active badvpn 2>/dev/null || echo "inactive")
            UPTIME=$(uptime -p 2>/dev/null || echo "unknown")
            if has_json "$@"; then
                data=$(printf '{"domain":"%s","ssh_port":22,"proxy_port":443,"proxy_status":"%s","udpgw_port":%s,"udpgw_status":"%s","badvpn_status":"%s","uptime":"%s"}' \
                    "$DOMAIN" "$PROXY_STATUS" "$BADVPN_PORT" "$BADVPN_STATUS" "$BADVPN_STATUS" "$UPTIME")
                json_success "status" "$data"
            else
                echo -e "${CYAN}=== IRANUX STATUS ===${NC}"
                echo -e "Domain       : ${DOMAIN}"
                echo -e "SSH Port     : 22"
                echo -e "Proxy Port   : 443 (${PROXY_STATUS})"
                echo -e "UDPGW Port   : ${BADVPN_PORT} (${BADVPN_STATUS})"
                echo -e "Uptime       : ${UPTIME}"
            fi
            exit 0
            ;;
        /info|info)
            u_info="$2"
            if [[ -z "$u_info" ]]; then
                has_json "$@" && json_error "info" 5 "Invalid parameter: username required" || \
                    echo -e "${RED}Usage: iranux /info <username>${NC}"
                exit 5
            fi
            if ! id "$u_info" &>/dev/null; then
                has_json "$@" && json_error "info" 4 "User not found" || \
                    echo -e "${RED}[!] User '$u_info' not found.${NC}"
                exit 4
            fi
            u_expiry=$(chage -l "$u_info" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs || echo "Never")
            u_maxlogins=$(grep "^$u_info soft maxlogins" /etc/security/limits.conf 2>/dev/null | awk '{print $4}' || echo "Unlimited")
            if has_json "$@"; then
                data=$(printf '{"username":"%s","expiry":"%s","max_logins":"%s","active":true,"created_at":"unknown"}' \
                    "$u_info" "$u_expiry" "$u_maxlogins")
                json_success "info" "$data"
            else
                echo -e "${GREEN}=== User Info: $u_info ===${NC}"
                echo -e "Username   : $u_info"
                echo -e "Expiry     : $u_expiry"
                echo -e "Max Logins : $u_maxlogins"
            fi
            exit 0
            ;;
        --schema)
            cat << 'SCHEMA'
{
  "protocol": "iranux-json-rpc",
  "version": "1.0.0",
  "encoding": "utf-8",
  "transport": "ssh-stdout",
  "commands": {
    "add": {
      "description": "Create a new SSH tunnel user",
      "cli": "iranux /add {username} {password} [days] [max_logins] [--json]",
      "parameters": [
        { "name": "username", "type": "string", "required": true, "position": 1, "description": "SSH username", "validation": { "min_length": 3, "max_length": 32, "pattern": "^[a-z][a-z0-9_-]*$", "pattern_hint": "Lowercase letters, numbers, underscore, dash. Must start with a letter." } },
        { "name": "password", "type": "string", "required": true, "position": 2, "description": "SSH password", "validation": { "min_length": 6, "max_length": 64 } },
        { "name": "days", "type": "integer", "required": false, "position": 3, "default": null, "description": "Account expiry in days. Omit for no expiry.", "validation": { "min": 1, "max": 3650 } },
        { "name": "max_logins", "type": "integer", "required": false, "position": 4, "default": null, "description": "Max simultaneous logins. Omit for unlimited.", "validation": { "min": 1, "max": 100 } },
        { "name": "--json", "type": "flag", "required": false, "position": null, "description": "Output result as JSON instead of human-readable text" }
      ],
      "response": { "success": { "status": "success", "command": "add", "data": { "username": "string", "password": "string", "expiry": "string|null", "max_logins": "integer|string", "ssh_host": "string", "ssh_port": "integer", "udpgw_port": "integer", "sni": "string", "protocol": "string", "payload": "string" } }, "error": { "status": "error", "command": "add", "code": "integer", "message": "string" } }
    },
    "del": {
      "description": "Delete an existing SSH tunnel user",
      "cli": "iranux /del {username} [--json]",
      "parameters": [
        { "name": "username", "type": "string", "required": true, "position": 1, "description": "Username to delete", "validation": { "min_length": 1, "max_length": 32 } },
        { "name": "--json", "type": "flag", "required": false, "position": null, "description": "Output result as JSON instead of human-readable text" }
      ],
      "response": { "success": { "status": "success", "command": "del", "data": { "username": "string", "message": "string" } }, "error": { "status": "error", "command": "del", "code": "integer", "message": "string" } }
    },
    "list": {
      "description": "List all SSH tunnel users on the system",
      "cli": "iranux /list [--json]",
      "parameters": [
        { "name": "--json", "type": "flag", "required": false, "position": null, "description": "Output result as JSON instead of human-readable text" }
      ],
      "response": { "success": { "status": "success", "command": "list", "data": { "users": [ { "username": "string", "expiry": "string|null", "max_logins": "integer|string", "active": "boolean" } ], "total": "integer" } }, "error": { "status": "error", "command": "list", "code": "integer", "message": "string" } }
    },
    "status": {
      "description": "Get server and service status (proxy, UDPGW, uptime)",
      "cli": "iranux /status [--json]",
      "parameters": [
        { "name": "--json", "type": "flag", "required": false, "position": null, "description": "Output result as JSON instead of human-readable text" }
      ],
      "response": { "success": { "status": "success", "command": "status", "data": { "domain": "string", "ssh_port": "integer", "proxy_port": "integer", "proxy_status": "string", "udpgw_port": "integer", "udpgw_status": "string", "badvpn_status": "string", "uptime": "string" } }, "error": { "status": "error", "command": "status", "code": "integer", "message": "string" } }
    },
    "info": {
      "description": "Get info about a specific SSH tunnel user",
      "cli": "iranux /info {username} [--json]",
      "parameters": [
        { "name": "username", "type": "string", "required": true, "position": 1, "description": "Username to look up" },
        { "name": "--json", "type": "flag", "required": false, "position": null, "description": "Output result as JSON instead of human-readable text" }
      ],
      "response": { "success": { "status": "success", "command": "info", "data": { "username": "string", "expiry": "string|null", "max_logins": "integer|string", "active": "boolean", "created_at": "string" } }, "error": { "status": "error", "command": "info", "code": "integer", "message": "string" } }
    },
    "schema": {
      "description": "Print the full JSON-RPC schema for this CLI (this document)",
      "cli": "iranux --schema",
      "parameters": [],
      "response": { "success": { "note": "Prints this schema document to stdout. No --json flag needed." } }
    },
    "help": {
      "description": "Show CLI help and usage information",
      "cli": "iranux /help",
      "aliases": ["/help", "help", "--help", "-h"],
      "parameters": [],
      "response": { "success": { "note": "Prints human-readable help to stdout. No --json flag." } }
    }
  },
  "error_codes": {
    "1": "General error",
    "2": "Permission denied (not root)",
    "3": "User already exists",
    "4": "User not found",
    "5": "Invalid parameter",
    "6": "System error (useradd failed)",
    "7": "Service not running"
  },
  "meta": { "schema_command": "iranux --schema", "json_flag": "--json", "min_app_version": "1.0.0" }
}
SCHEMA
            exit 0
            ;;
        /help|help|--help|-h)
            echo -e "${CYAN}=== IRANUX CLI HELP ===${NC}"
            echo -e ""
            echo -e "${GREEN}USAGE:${NC}"
            echo -e "  iranux                                Open interactive menu"
            echo -e "  iranux /add <u> <p> [days] [lim]     Create user non-interactively"
            echo -e "  iranux /del <username>                Delete user non-interactively"
            echo -e "  iranux /list                          List all users"
            echo -e "  iranux /status                        Show service status"
            echo -e "  iranux /info <username>               Show user info"
            echo -e "  iranux --schema                       Print JSON-RPC schema"
            echo -e "  iranux /help                          Show this help"
            echo -e ""
            echo -e "${GREEN}FLAGS:${NC}"
            echo -e "  --json                                Output in JSON format"
            echo -e ""
            echo -e "${GREEN}EXAMPLES:${NC}"
            echo -e "  iranux /add ali P@ss123 30 2          Create user 'ali', 30 days, max 2 logins"
            echo -e "  iranux /add bob secret                Create user 'bob' with no expiry/limit"
            echo -e "  iranux /del ali                       Delete user 'ali'"
            echo -e "  iranux /list                          Show all users"
            echo -e "  iranux /list --json                   Show all users in JSON format"
            echo -e "  iranux /status --json                 Show service status in JSON format"
            echo -e "  iranux /info ali --json               Show user info in JSON format"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Unknown command: $1${NC}"
            echo -e "Run 'iranux /help' for usage."
            exit 1
            ;;
    esac
fi

while true; do
    clear
    echo -e "${CYAN}=== IRANUX TERMINAL MANAGER ===${NC}"
    echo -e " 1) Create User"
    echo -e " 2) Delete User"
    echo -e " 3) List Users"
    echo -e " 4) User Info"
    echo -e " 5) Server Status"
    echo -e " 0) Exit"
    echo -e "-------------------------------"
    read -p " Select: " choice
    case $choice in
        1)
            read -p "Username: " u_name
            read -p "Password: " u_pass
            read -p "Expiry days (leave blank = never): " u_days
            read -p "Max logins (leave blank = unlimited): " u_limit
            if id "$u_name" &>/dev/null; then
                echo -e "${RED}[!] User already exists.${NC}"
                read -p "Press Enter..."
                continue
            fi
            if ! useradd -m -s /bin/false "$u_name"; then
                echo -e "${RED}[!] Failed to create user.${NC}"
                read -p "Press Enter..."
                continue
            fi
            echo "$u_name:$u_pass" | chpasswd
            if [[ -n "$u_days" ]]; then
                exp_date=$(date -d "+$u_days days" +%Y-%m-%d)
                chage -E "$exp_date" "$u_name"
            else
                exp_date="Never"
            fi
            if [[ -n "$u_limit" ]]; then
                sed -i "/^$u_name[[:space:]]/d" /etc/security/limits.conf
                echo "$u_name soft maxlogins $u_limit" >> /etc/security/limits.conf
            else
                u_limit="Unlimited"
            fi
            payload="GET ${SECRET_PATH} HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: Mozilla/5.0[crlf][crlf]"
            echo -e "\n${GREEN}=== HTTP CUSTOM CONFIG ===${NC}"
            echo -e "Protocol    : SSH-TLS-Payload"
            echo -e "Remarks     : ${u_name}"
            echo -e "SSH Host    : ${DOMAIN}"
            echo -e "SSH Port    : 443"
            echo -e "UDPGW Port  : ${BADVPN_PORT}"
            echo -e "SSH Username: ${u_name}"
            echo -e "SSH Password: ${u_pass}"
            echo -e "Expiry      : ${exp_date}"
            echo -e "Max Logins  : ${u_limit}"
            echo -e "SNI         : ${DOMAIN}"
            echo -e "---------------------------------"
            echo -e "PAYLOAD:"
            echo -e "${payload}"
            echo -e "---------------------------------"
            read -p "Press Enter..."
            ;;
        2)
            read -p "Username to DELETE: " u_del
            if id "$u_del" &>/dev/null; then
                userdel -r "$u_del"
                sed -i "/^$u_del/d" /etc/security/limits.conf
                echo -e "${RED}User deleted.${NC}"
            else echo "User not found."; fi
            read -p "Press Enter..."
            ;;
        3)
            echo -e "${GREEN}Users:${NC}"
            awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
            read -p "Press Enter..."
            ;;
        4)
            read -p "Username: " u_info
            if ! id "$u_info" &>/dev/null; then
                echo -e "${RED}[!] User not found.${NC}"
            else
                u_expiry=$(chage -l "$u_info" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs || echo "Never")
                u_maxlogins=$(grep "^$u_info soft maxlogins" /etc/security/limits.conf 2>/dev/null | awk '{print $4}' || echo "Unlimited")
                echo -e "${GREEN}=== User Info: $u_info ===${NC}"
                echo -e "Username   : $u_info"
                echo -e "Expiry     : $u_expiry"
                echo -e "Max Logins : $u_maxlogins"
            fi
            read -p "Press Enter..."
            ;;
        5)
            PROXY_STATUS=$(systemctl is-active iranux-tunnel 2>/dev/null || echo "inactive")
            BADVPN_STATUS=$(systemctl is-active badvpn 2>/dev/null || echo "inactive")
            UPTIME=$(uptime -p 2>/dev/null || echo "unknown")
            echo -e "${CYAN}=== IRANUX STATUS ===${NC}"
            echo -e "Domain       : ${DOMAIN}"
            echo -e "SSH Port     : 22"
            echo -e "Proxy Port   : 443 (${PROXY_STATUS})"
            echo -e "UDPGW Port   : ${BADVPN_PORT} (${BADVPN_STATUS})"
            echo -e "Uptime       : ${UPTIME}"
            read -p "Press Enter..."
            ;;
        0) exit 0 ;;
        *) echo "Invalid";;
    esac
done
EOF
chmod +x /usr/local/bin/iranux

# ------------------------------------------------------------------------------
# PHASE 8: FINALIZING SERVICES
# ------------------------------------------------------------------------------
cat << EOF > /etc/systemd/system/iranux-tunnel.service
[Unit]
Description=Iranux Tunnel
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/node ${APP_DIR}/server.js
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/iranux-bot.service
[Unit]
Description=Iranux Bot
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
ExecStart=/bin/bash ${APP_DIR}/iranux-bot.sh
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable iranux-tunnel --now
systemctl enable iranux-bot --now

# Final Check
sleep 2
if lsof -i :443 > /dev/null; then PROXY_STATUS="${GREEN}ONLINE${RESET}"; else PROXY_STATUS="${RED}ERROR${RESET}"; fi
if lsof -i :7300 > /dev/null; then BADVPN_STATUS="${GREEN}ONLINE${RESET}"; else BADVPN_STATUS="${RED}ERROR${RESET}"; fi
# ── At the end of installation, BEFORE the while true menu loop ── Installation Flag for Installation App
echo '#@INSTALL_COMPLETE'
# ------------------------------------------------------------------------------
# PHASE 9: FULL INSTALLATION REPORT
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}==========================================${RESET}"
echo -e "${GREEN}   IRANUX SYSTEM INSTALL COMPLETE         ${RESET}"
echo -e "${GREEN}==========================================${RESET}"
echo -e "   SSH Port   : ${YELLOW}${FIXED_SSH_PORT}${RESET}"
echo -e "   Proxy 443  : ${PROXY_STATUS}"
echo -e "   UDPGW 7300 : ${BADVPN_STATUS}"
echo -e "   Domain     : ${YELLOW}${DOMAIN}${RESET}"
echo -e "   Secret Path: ${YELLOW}${SECRET_PATH}${RESET}"
echo -e "------------------------------------------"
echo -e "   MANAGEMENT OPTIONS:"
echo -e "   1. Telegram: Send ${CYAN}/menu${RESET} to your bot"
echo -e "   2. Terminal: Type ${CYAN}iranux${RESET} to open menu"
echo -e "=========================================="

echo -e "\n${CYAN}===========================================${RESET}"
echo -e "${CYAN}        IRANUX CLI COMMAND REFERENCE       ${RESET}"
echo -e "${CYAN}===========================================${RESET}"
echo -e ""
echo -e "  ${GREEN}INTERACTIVE MODE:${RESET}"
echo -e "    iranux                            Open interactive menu"
echo -e ""
echo -e "  ${GREEN}NON-INTERACTIVE COMMANDS:${RESET}"
echo -e "    iranux /add <user> <pass> [days] [maxlogins]"
echo -e "                                      Create a new SSH user"
echo -e "    iranux /del <username>             Delete a user"
echo -e "    iranux /list                       List all users"
echo -e "    iranux /help                       Show full help"
echo -e ""
echo -e "  ${GREEN}EXAMPLES:${RESET}"
echo -e "    ${CYAN}iranux /add ali P@ss 30 2${RESET}         Create 'ali', 30-day expiry, max 2 logins"
echo -e "    ${CYAN}iranux /add bob secret${RESET}            Create 'bob' with no expiry or login limit"
echo -e "    ${CYAN}iranux /del ali${RESET}                   Delete user 'ali'"
echo -e "    ${CYAN}iranux /list${RESET}                      Show all system users"
echo -e ""
echo -e "  ${GREEN}TELEGRAM BOT COMMANDS:${RESET}"
echo -e "    /menu                              Show bot menu"
echo -e "    /add <user> <pass> <days> <limit>  Create user via Telegram"
echo -e ""
echo -e "${CYAN}===========================================${RESET}"
