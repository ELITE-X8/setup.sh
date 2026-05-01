#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  ELITE-X v3.8 - FALCON ULTRA C + SERVER MSG + TEXTMEBOT WA
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
ORANGE='\033[0;33m'; LIGHT_RED='\033[1;31m'; LIGHT_GREEN='\033[1;32m'; GRAY='\033[0;90m'
NC='\033[0m'

STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

# WhatsApp Configuration - TEXTMEBOT API
TEXTMEBOT_APIKEY="rpdvLo9UTQ7v"
TEXTMEBOT_API_URL="https://api.textmebot.com/send.php"
ADMIN_PHONE="0713628699"

USER_DB="/etc/elite-x/users"
USAGE_DB="/etc/elite-x/data_usage"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
PIDTRACK_DIR="$BANDWIDTH_DIR/pidtrack"
BANNED_DB="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"
DELETED_DB="/etc/elite-x/deleted"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
SERVER_MSG_DIR="/etc/elite-x/server_msg"
NOTIFY_DIR="/etc/elite-x/notifications"

show_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}  ELITE-X SLOWDNS v3.8 - FALCON + SERVER MSG + TEXTMEBOT WA ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}  GB Limits • Bandwidth • C Boosters • Auto-Delete • WhatsApp  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}${BOLD}         TURBO BOOST EDITION - BBR + FQ + C ENGINE            ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_color() { echo -e "${2}${1}${NC}"; }
set_timezone() { timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true; }

# ═══════════════════════════════════════════════════════════
# TEXTMEBOT WHATSAPP NOTIFICATION FUNCTION
# ═══════════════════════════════════════════════════════════
send_whatsapp_textmebot() {
    local phone="$1"
    local message="$2"
    local apikey="${3:-$TEXTMEBOT_APIKEY}"
    
    if [ -z "$apikey" ]; then
        echo -e "${YELLOW}⚠️ API Key haijawekwa${NC}" >&2
        return 1
    fi
    
    # Clean phone number - remove +, spaces, etc
    phone=$(echo "$phone" | sed 's/[^0-9]//g')
    
    # URL encode message
    local encoded_msg
    if command -v python3 &>/dev/null; then
        encoded_msg=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$message'''))" 2>/dev/null)
    else
        encoded_msg=$(echo "$message" | sed 's/ /%20/g' | sed 's/\n/%0A/g' | sed 's/#/%23/g' | sed 's/&/%26/g')
    fi
    
    # Send via TextMeBot API
    local response
    response=$(curl -s -k "${TEXTMEBOT_API_URL}?apikey=${apikey}&phone=${phone}&text=${encoded_msg}" 2>/dev/null)
    
    # Log
    mkdir -p /var/log/elite-x
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] To: ${phone} | Response: ${response}" >> /var/log/elite-x/whatsapp.log
    
    if echo "$response" | grep -qi "success\|queued\|sent\|ok\|true"; then
        echo -e "${GREEN}✅ WhatsApp sent to ${phone}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ Response: ${response}${NC}" >&2
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# SEND TO BOTH ADMIN AND CUSTOMER
# ═══════════════════════════════════════════════════════════
send_dual_notification() {
    local customer_phone="$1"
    local admin_msg="$2"
    local customer_msg="$3"
    
    # Send to Admin always
    send_whatsapp_textmebot "$ADMIN_PHONE" "$admin_msg" "$TEXTMEBOT_APIKEY"
    
    # Send to Customer if phone provided
    if [ -n "$customer_phone" ] && [ "$customer_phone" != "0" ]; then
        send_whatsapp_textmebot "$customer_phone" "$customer_msg" "$TEXTMEBOT_APIKEY"
    fi
}

# ═══════════════════════════════════════════════════════════
# NOTIFICATION: ACCOUNT CREATED
# ═══════════════════════════════════════════════════════════
notify_account_created() {
    local username="$1"
    local customer_phone="$2"
    local nameserver="$3"
    local expire_date="$4"
    local conn_limit="$5"
    local bandwidth="$6"
    local password="$7"
    
    local bw_disp="Unlimited"
    [ "$bandwidth" != "0" ] && bw_disp="${bandwidth} GB"
    
    # Admin message
    local admin_msg
    admin_msg=$(cat <<EOF
📢 *NEW ACCOUNT CREATED*
━━━━━━━━━━━━━━━━━━━━━
👤 *Username:* ${username}
🔑 *Password:* ${password}
🌐 *NS:* ${nameserver}
📅 *Expire:* ${expire_date}
🔗 *Connection:* ${conn_limit}
📊 *Bandwidth:* ${bw_disp}
📱 *Phone:* ${customer_phone:-Not provided}
━━━━━━━━━━━━━━━━━━━━━
💬 _Always remember ELITE-X when you X_
EOF
)
    
    # Customer message
    local customer_msg
    customer_msg=$(cat <<EOF
🎉 *ACCOUNT CREATED SUCCESSFULLY*
━━━━━━━━━━━━━━━━━━━━━
👤 *Username:* ${username}
🔑 *Password:* ${password}
🌐 *Nameserver:* ${nameserver}
📅 *Expired:* ${expire_date}
🔗 *Connection:* ${conn_limit}
📊 *Bandwidth:* ${bw_disp}
━━━━━━━━━━━━━━━━━━━━━
💬 _Always remember ELITE-X when you X_
EOF
)
    
    send_dual_notification "$customer_phone" "$admin_msg" "$customer_msg"
}

# ═══════════════════════════════════════════════════════════
# NOTIFICATION: EXPIRY REMINDER
# ═══════════════════════════════════════════════════════════
notify_expiry_reminder() {
    local username="$1"
    local customer_phone="$2"
    local nameserver="$3"
    
    # Admin message
    local admin_msg
    admin_msg=$(cat <<EOF
⚠️ *EXPIRY REMINDER*
━━━━━━━━━━━━━━━━━━━━━
👤 *User:* ${username}
🌐 *NS:* ${nameserver}
📱 *Phone:* ${customer_phone:-N/A}
⏰ *Status:* 1 DAY REMAINING
━━━━━━━━━━━━━━━━━━━━━
📌 _User needs renewal soon_
EOF
)
    
    # Customer message
    local customer_msg
    customer_msg=$(cat <<EOF
⚠️ *EXPIRY REMINDER - ELITE-X*
━━━━━━━━━━━━━━━━━━━━━
Ndugu mteja *${username}*
Nameserver yako ni: *${nameserver}*

Unakumbushwa kuwa file lako
limebaki *SIKU 1* kuexpire.

Wasiliana na ELITE-X uweze
kufanya *RENEW* kuongezewa siku
kabla halijawa expired.
━━━━━━━━━━━━━━━━━━━━━
🙏 *THANKS FOR USING ELITE-X*
💬 _Always remember ELITE-X when you X_
EOF
)
    
    send_dual_notification "$customer_phone" "$admin_msg" "$customer_msg"
}

# ═══════════════════════════════════════════════════════════
# NOTIFICATION: ACCOUNT EXPIRED
# ═══════════════════════════════════════════════════════════
notify_account_expired() {
    local username="$1"
    local customer_phone="$2"
    local nameserver="$3"
    
    # Admin message
    local admin_msg
    admin_msg=$(cat <<EOF
❌ *ACCOUNT EXPIRED*
━━━━━━━━━━━━━━━━━━━━━
👤 *User:* ${username}
🌐 *NS:* ${nameserver}
📱 *Phone:* ${customer_phone:-N/A}
⛔ *Status:* EXPIRED
━━━━━━━━━━━━━━━━━━━━━
📌 _User anahitaji renewal_
EOF
)
    
    # Customer message
    local customer_msg
    customer_msg=$(cat <<EOF
❌ *ACCOUNT EXPIRED - ELITE-X*
━━━━━━━━━━━━━━━━━━━━━
Ndugu mteja unakumbushwa
kuweza kulipia file lako
lililo kuwa *EXPIRED*.

Unaweza kuwasiliana na *ELITE-X*
aweze kurenew file lako
hilo hilo.

📋 *ACCOUNT DETAILS:*
👤 *Username:* ${username}
🌐 *Nameserver:* ${nameserver}
━━━━━━━━━━━━━━━━━━━━━
🙏 *THANKS FOR USING ELITE-X*
💬 _Always remember ELITE-X when you X_
EOF
)
    
    send_dual_notification "$customer_phone" "$admin_msg" "$customer_msg"
}

# ═══════════════════════════════════════════════════════════
# NOTIFICATION SCHEDULER
# ═══════════════════════════════════════════════════════════
create_notification_scheduler() {
    echo -e "${YELLOW}📝 Creating TextMeBot Notification Scheduler...${NC}"
    
    mkdir -p "$NOTIFY_DIR"
    
    cat > /usr/local/bin/elite-x-notify-scheduler <<'NOTIFYEOF'
#!/bin/bash
USER_DB="/etc/elite-x/users"
NOTIFY_DIR="/etc/elite-x/notifications"
NS=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Unknown")
APIKEY="rpdvLo9UTQ7v"
ADMIN_PHONE="0713628699"
API_URL="https://api.textmebot.com/send.php"

send_wa() {
    local phone="$1"; local message="$2"
    phone=$(echo "$phone" | sed 's/[^0-9]//g')
    local encoded_msg
    if command -v python3 &>/dev/null; then
        encoded_msg=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$message'''))" 2>/dev/null)
    else
        encoded_msg=$(echo "$message" | sed 's/ /%20/g')
    fi
    curl -s -k "${API_URL}?apikey=${APIKEY}&phone=${phone}&text=${encoded_msg}" >/dev/null 2>&1
}

while true; do
    if [ -d "$USER_DB" ] && [ -n "$APIKEY" ]; then
        CURRENT_TS=$(date +%s)
        
        for userfile in "$USER_DB"/*; do
            [ ! -f "$userfile" ] && continue
            
            username=$(basename "$userfile")
            expire_date=$(grep "Expire:" "$userfile" | awk '{print $2}')
            [ -z "$expire_date" ] && continue
            
            customer_phone=$(grep "Phone:" "$userfile" | awk '{print $2}')
            customer_phone=${customer_phone:-0}
            
            expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
            [ "$expire_ts" -eq 0 ] && continue
            
            days_left=$(( (expire_ts - CURRENT_TS) / 86400 ))
            
            # 1-day reminder
            reminder_file="$NOTIFY_DIR/${username}_reminder"
            if [ "$days_left" -eq 1 ] && [ ! -f "$reminder_file" ]; then
                # Admin msg
                admin_msg="⚠️ *EXPIRY REMINDER*%0A━━━━━━━━━━━━━━━━━━━━━%0A👤 *User:* ${username}%0A🌐 *NS:* ${NS}%0A📱 *Phone:* ${customer_phone}%0A⏰ *Status:* 1 DAY LEFT%0A━━━━━━━━━━━━━━━━━━━━━"
                send_wa "$ADMIN_PHONE" "$admin_msg"
                
                # Customer msg
                if [ "$customer_phone" != "0" ] && [ -n "$customer_phone" ]; then
                    cust_msg="⚠️ *EXPIRY REMINDER - ELITE-X*%0A━━━━━━━━━━━━━━━━━━━━━%0ANdugu mteja *${username}*%0ANameserver: *${NS}*%0A%0AUnakumbushwa file lako%0Alimebaki *SIKU 1* kuexpire.%0A%0AWasiliana na ELITE-X%0Aufanye RENEW mapema.%0A━━━━━━━━━━━━━━━━━━━━━%0A🙏 *THANKS FOR USING ELITE-X*%0A💬 _Always remember ELITE-X when you X_"
                    send_wa "$customer_phone" "$cust_msg"
                fi
                touch "$reminder_file"
                echo "[$(date)] Sent 1-day reminder for $username" >> /var/log/elite-x/notify.log
            fi
            
            # Expired notice
            expired_file="$NOTIFY_DIR/${username}_expired"
            if [ "$days_left" -le 0 ] && [ ! -f "$expired_file" ]; then
                admin_msg="❌ *ACCOUNT EXPIRED*%0A━━━━━━━━━━━━━━━━━━━━━%0A👤 *User:* ${username}%0A🌐 *NS:* ${NS}%0A📱 *Phone:* ${customer_phone}%0A⛔ *Status:* EXPIRED"
                send_wa "$ADMIN_PHONE" "$admin_msg"
                
                if [ "$customer_phone" != "0" ] && [ -n "$customer_phone" ]; then
                    cust_msg="❌ *ACCOUNT EXPIRED - ELITE-X*%0A━━━━━━━━━━━━━━━━━━━━━%0ANdugu mteja, file lako%0Alimeexpire.%0A%0AWasiliana na *ELITE-X*%0Aili kurenew account yako.%0A%0A👤 *Username:* ${username}%0A🌐 *NS:* ${NS}%0A━━━━━━━━━━━━━━━━━━━━━%0A🙏 *THANKS FOR USING ELITE-X*%0A💬 _Always remember ELITE-X when you X_"
                    send_wa "$customer_phone" "$cust_msg"
                fi
                touch "$expired_file"
                echo "[$(date)] Sent expired notice for $username" >> /var/log/elite-x/notify.log
            fi
        done
    fi
    
    sleep 1800  # Check every 30 minutes
done
NOTIFYEOF
    chmod +x /usr/local/bin/elite-x-notify-scheduler
    
    cat > /etc/systemd/system/elite-x-notify.service <<EOF
[Unit]
Description=ELITE-X TextMeBot Notification Scheduler
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-notify-scheduler
Restart=always
RestartSec=30
CPUQuota=5%
MemoryMax=20M

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ Notification Scheduler created${NC}"
}

# ═══════════════════════════════════════════════════════════
# SYSTEM OPTIMIZATION FOR VPN
# ═══════════════════════════════════════════════════════════
optimize_system_for_vpn() {
    echo -e "${YELLOW}🔧 Optimizing system for VPN connections...${NC}"
    
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_mtu_probing=1 >/dev/null 2>&1
    sysctl -w net.ipv4.ip_no_pmtu_disc=0 >/dev/null 2>&1
    sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.core.rmem_default=262144 >/dev/null 2>&1
    sysctl -w net.core.wmem_default=262144 >/dev/null 2>&1
    sysctl -w net.ipv4.udp_mem='65536 131072 262144' >/dev/null 2>&1
    sysctl -w net.ipv4.udp_rmem_min=16384 >/dev/null 2>&1
    sysctl -w net.ipv4.udp_wmem_min=16384 >/dev/null 2>&1
    
    cat > /etc/sysctl.d/99-elite-x-vpn.conf <<SYSCTL
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_no_pmtu_disc=0
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=262144
net.core.wmem_default=262144
net.ipv4.udp_mem=65536 131072 262144
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384
SYSCTL
    sysctl -p /etc/sysctl.d/99-elite-x-vpn.conf >/dev/null 2>&1
    
    iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true
    iptables -A FORWARD -i lo -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -o lo -j ACCEPT 2>/dev/null || true
    
    echo -e "${GREEN}✅ System optimized for VPN${NC}"
}

# ═══════════════════════════════════════════════════════════
# SSH CONFIGURATION + SERVER MESSAGE
# ═══════════════════════════════════════════════════════════
configure_ssh_for_vpn() {
    echo -e "${YELLOW}🔧 Configuring SSH for VPN + Server Message...${NC}"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null
    
    cat > /etc/ssh/sshd_config.d/elite-x-vpn.conf <<'SSHCONF'
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
AllowTcpForwarding yes
AllowAgentForwarding yes
GatewayPorts yes
PermitTunnel yes
PermitOpen any
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3
MaxStartups 100:30:200
MaxSessions 100
UseDNS no
LogLevel VERBOSE
Banner /etc/elite-x/server_msg/banner
SSHCONF

    echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    
    echo -e "${GREEN}✅ SSH configured with Server Message${NC}"
}

# ═══════════════════════════════════════════════════════════
# SERVER MESSAGE GENERATOR
# ═══════════════════════════════════════════════════════════
create_server_message_updater() {
    echo -e "${YELLOW}📝 Creating Server Message System...${NC}"
    
    mkdir -p "$SERVER_MSG_DIR"
    
    cat > /usr/local/bin/elite-x-banner-updater <<'BANNEREOF'
#!/bin/bash
USER_DB="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
MSG_DIR="/etc/elite-x/server_msg"
mkdir -p "$MSG_DIR"

generate_banner() {
    local username="$1"
    
    cat > "$MSG_DIR/banner" <<'DEFAULTBAN'
╔═══════════════════════════════════════════╗
║     ⚡ ELITE-X SLOWDNS VPN ⚡            ║
║     v3.8 FALCON ULTRA C + WA            ║
╠═══════════════════════════════════════════╣
║  🔐 Connected Successfully!             ║
╠═══════════════════════════════════════════╣
║  🚀 Enjoy Fast & Stable Connection!     ║
╚═══════════════════════════════════════════╝
DEFAULTBAN

    if [ -n "$username" ] && [ -f "$USER_DB/$username" ]; then
        local expire_date=$(grep "Expire:" "$USER_DB/$username" | awk '{print $2}')
        local bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$username" | awk '{print $2}')
        local conn_limit=$(grep "Conn_Limit:" "$USER_DB/$username" | awk '{print $2}')
        local phone=$(grep "Phone:" "$USER_DB/$username" | awk '{print $2}')
        
        bandwidth_gb=${bandwidth_gb:-0}
        conn_limit=${conn_limit:-1}
        
        local usage_bytes=$(cat "$BW_DIR/${username}.usage" 2>/dev/null || echo 0)
        local usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")
        
        local current_conn=0
        current_conn=$(who | grep -wc "$username" 2>/dev/null || echo 0)
        [ "$current_conn" -eq 0 ] && current_conn=$(ps aux 2>/dev/null | grep "sshd:" | grep "$username" | grep -v grep | wc -l)
        current_conn=${current_conn:-0}
        
        local now_ts=$(date +%s)
        local expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
        local remaining_seconds=$((expire_ts - now_ts))
        local remaining_days=$((remaining_seconds / 86400))
        local remaining_hours=$(((remaining_seconds % 86400) / 3600))
        
        [ $remaining_days -lt 0 ] && remaining_days=0
        [ $remaining_hours -lt 0 ] && remaining_hours=0
        
        local bw_display="Unlimited"
        [ "$bandwidth_gb" != "0" ] && bw_display="${bandwidth_gb} GB"
        
        local status="🟢 ACTIVE"
        if [ $remaining_days -le 0 ]; then status="⛔ EXPIRED"
        elif [ $remaining_days -le 3 ]; then status="⚠️ EXPIRING SOON"; fi
        
        cat > "$MSG_DIR/banner" <<BANNER
╔═══════════════════════════════════════════╗
║     ⚡ ELITE-X SLOWDNS VPN ⚡            ║
║     v3.8 FALCON ULTRA C + WA            ║
╠═══════════════════════════════════════════╣
║  ACCOUNT STATUS
║
║  USERNAME   : $username
║  EXPIRE     : $expire_date
║  REMAINING  : ${remaining_days} day(s) + ${remaining_hours} hr(s)
║  LIMIT GB   : $bw_display
║  USAGE GB   : ${usage_gb} GB
║  CONNECTION : ${current_conn}/${conn_limit}
║  STATUS     : $status
╠═══════════════════════════════════════════╣
║  🚀 Enjoy Fast & Stable Connection!     ║
╚═══════════════════════════════════════════╝
BANNER
        
        chmod 644 "$MSG_DIR/banner"
    fi
}

if [ -n "${1:-}" ]; then generate_banner "$1"; else generate_banner ""; fi
BANNEREOF
    chmod +x /usr/local/bin/elite-x-banner-updater
    /usr/local/bin/elite-x-banner-updater
    
    cat > /etc/systemd/system/elite-x-banner-refresh.service <<'EOF'
[Unit]
Description=ELITE-X Banner Refresh
After=network.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for user in /etc/elite-x/users/*; do [ -f "$user" ] && /usr/local/bin/elite-x-banner-updater "$(basename "$user")" 2>/dev/null; done'
EOF

    cat > /etc/systemd/system/elite-x-banner-refresh.timer <<'EOF'
[Unit]
Description=ELITE-X Banner Refresh Timer
[Timer]
OnBootSec=30sec
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable elite-x-banner-refresh.timer 2>/dev/null || true
    systemctl start elite-x-banner-refresh.timer 2>/dev/null || true
    
    echo -e "${GREEN}✅ Server Message System ready${NC}"
}

# ═══════════════════════════════════════════════════════════
# PAM CONFIGURATION
# ═══════════════════════════════════════════════════════════
configure_pam_banner() {
    echo -e "${YELLOW}🔧 Configuring PAM...${NC}"
    sed -i '/elite-x-banner-updater/d' /etc/pam.d/sshd 2>/dev/null
    sed -i '1i session    optional     pam_exec.so seteuid /usr/local/bin/elite-x-banner-updater' /etc/pam.d/sshd
    echo -e "${GREEN}✅ PAM configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# C COMPONENTS (Compressed for space)
# ═══════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}📝 Compiling C EDNS Proxy...${NC}"
    cat > /tmp/ep.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <errno.h>
#include <pthread.h>
#define BZ 4096
#define DP 53
#define BP 5300
#define MX 1800
#define MN 512
static volatile int r=1;
void h(int s){r=0;}
int sk(const unsigned char*d,int o,int m){while(o<m){unsigned char l=d[o];o++;if(l==0)break;if((l&0xC0)==0xC0){o++;break;}o+=l;}return o;}
void me(unsigned char*d,int*ln,unsigned short ms){if(*ln<12)return;int o=12;unsigned short qc,ac,nc,rc;memcpy(&qc,d+4,2);qc=ntohs(qc);memcpy(&ac,d+6,2);ac=ntohs(ac);memcpy(&nc,d+8,2);nc=ntohs(nc);memcpy(&rc,d+10,2);rc=ntohs(rc);int i;for(i=0;i<qc;i++){o=sk(d,o,*ln);if(o+4>*ln)return;o+=4;}for(i=0;i<ac+nc;i++){o=sk(d,o,*ln);if(o+10>*ln)return;unsigned short rl;memcpy(&rl,d+o+8,2);rl=ntohs(rl);o+=10+rl;}for(i=0;i<rc;i++){o=sk(d,o,*ln);if(o+10>*ln)return;unsigned short rt;memcpy(&rt,d+o,2);rt=ntohs(rt);if(rt==41){unsigned short s=htons(ms);memcpy(d+o+2,&s,2);return;}unsigned short rl;memcpy(&rl,d+o+8,2);rl=ntohs(rl);o+=10+rl;}}
typedef struct{int s;struct sockaddr_in ca;socklen_t cl;unsigned char*d;int dl;}ta;
void*ph(void*arg){ta*a=(ta*)arg;int bs=socket(AF_INET,SOCK_DGRAM,0);if(bs<0){free(a->d);free(a);return NULL;}struct timeval tv;tv.tv_sec=5;tv.tv_usec=0;setsockopt(bs,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));struct sockaddr_in ba;memset(&ba,0,sizeof(ba));ba.sin_family=AF_INET;ba.sin_addr.s_addr=inet_addr("127.0.0.1");ba.sin_port=htons(BP);unsigned char re[BZ];int ln=a->dl;me(a->d,&ln,MX);sendto(bs,a->d,ln,0,(struct sockaddr*)&ba,sizeof(ba));socklen_t bl=sizeof(ba);int rn=recvfrom(bs,re,BZ,0,(struct sockaddr*)&ba,&bl);if(rn>0){ln=rn;me(re,&ln,MN);sendto(a->s,re,ln,0,(struct sockaddr*)&a->ca,a->cl);}close(bs);free(a->d);free(a);return NULL;}
int main(){signal(SIGTERM,h);signal(SIGINT,h);int s=socket(AF_INET,SOCK_DGRAM,0);if(s<0)return 1;int reuse=1;setsockopt(s,SOL_SOCKET,SO_REUSEADDR,&reuse,sizeof(reuse));struct sockaddr_in ad;memset(&ad,0,sizeof(ad));ad.sin_family=AF_INET;ad.sin_addr.s_addr=INADDR_ANY;ad.sin_port=htons(DP);system("fuser -k 53/udp 2>/dev/null");usleep(1000000);if(bind(s,(struct sockaddr*)&ad,sizeof(ad))<0){system("fuser -k 53/udp 2>/dev/null");usleep(2000000);if(bind(s,(struct sockaddr*)&ad,sizeof(ad))<0){close(s);return 1;}}struct timeval tv;tv.tv_sec=1;tv.tv_usec=0;setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));while(r){struct sockaddr_in ca;socklen_t cl=sizeof(ca);unsigned char*b=malloc(BZ);if(!b){usleep(10000);continue;}int n=recvfrom(s,b,BZ,0,(struct sockaddr*)&ca,&cl);if(n<0){free(b);if(errno==EAGAIN||errno==EWOULDBLOCK)continue;if(!r)break;usleep(10000);continue;}ta*args=malloc(sizeof(ta));if(!args){free(b);continue;}args->s=s;args->ca=ca;args->cl=cl;args->d=b;args->dl=n;pthread_t th;pthread_attr_t at;pthread_attr_init(&at);pthread_attr_setdetachstate(&at,PTHREAD_CREATE_DETACHED);pthread_create(&th,&at,ph,args);pthread_attr_destroy(&at);}close(s);return 0;}
CEOF
    gcc -O3 -pthread -o /usr/local/bin/elite-x-edns-proxy /tmp/ep.c 2>/dev/null
    rm -f /tmp/ep.c
    [ -f /usr/local/bin/elite-x-edns-proxy ] && { chmod +x /usr/local/bin/elite-x-edns-proxy; echo -e "${GREEN}✅ EDNS Proxy compiled${NC}"; }
}

create_c_bandwidth_monitor() {
    echo -e "${YELLOW}📝 Compiling C Bandwidth Monitor...${NC}"
    cat > /tmp/bw.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <signal.h>
#include <pwd.h>
#include <ctype.h>
#define UD "/etc/elite-x/users"
#define BD "/etc/elite-x/bandwidth"
#define PD "/etc/elite-x/bandwidth/pidtrack"
#define BND "/etc/elite-x/banned"
#define SI 30
#define GB 1073741824.0
static volatile int r=1;
void h(int s){r=0;}
long long gio(int p){char pa[256];snprintf(pa,sizeof(pa),"/proc/%d/io",p);FILE*f=fopen(pa,"r");if(!f)return 0;long long rc=0,wc=0;char l[256];while(fgets(l,sizeof(l),f)){if(strncmp(l,"rchar:",6)==0)sscanf(l+7,"%lld",&rc);else if(strncmp(l,"wchar:",6)==0)sscanf(l+7,"%lld",&wc);}fclose(f);return rc+wc;}
int in(const char*s){for(;*s;s++)if(!isdigit(*s))return 0;return 1;}
int gp(const char*u,int*p,int m){int c=0;DIR*pr=opendir("/proc");if(!pr)return 0;struct dirent*e;while((e=readdir(pr))&&c<m){if(!in(e->d_name))continue;int pid=atoi(e->d_name);char cp[256];snprintf(cp,sizeof(cp),"/proc/%d/comm",pid);FILE*f=fopen(cp,"r");if(!f)continue;char cm[256]={0};fgets(cm,sizeof(cm),f);fclose(f);cm[strcspn(cm,"\n")]=0;if(strcmp(cm,"sshd")==0){char sp[256];snprintf(sp,sizeof(sp),"/proc/%d/status",pid);FILE*sf=fopen(sp,"r");if(!sf)continue;char l[256],us[32]={0};while(fgets(l,sizeof(l),sf)){if(strncmp(l,"Uid:",4)==0){sscanf(l,"%*s %s",us);break;}}fclose(sf);int uid=atoi(us);struct passwd*pw=getpwuid(uid);if(pw&&strcmp(pw->pw_name,u)==0){char stp[256];snprintf(stp,sizeof(stp),"/proc/%d/stat",pid);FILE*tf=fopen(stp,"r");if(tf){int pp;char sb[1024];fgets(sb,sizeof(sb),tf);sscanf(sb,"%*d %*s %*c %d",&pp);fclose(tf);if(pp!=1)p[c++]=pid;}}}}closedir(pr);return c;}
int main(){signal(SIGTERM,h);signal(SIGINT,h);mkdir(BD,0755);mkdir(PD,0755);mkdir(BND,0755);while(r){DIR*ud=opendir(UD);if(!ud){sleep(SI);continue;}struct dirent*ue;while((ue=readdir(ud))){if(ue->d_name[0]=='.')continue;char uf[512];snprintf(uf,sizeof(uf),"%s/%s",UD,ue->d_name);FILE*f=fopen(uf,"r");if(!f)continue;double bg=0;char l[256];while(fgets(l,sizeof(l),f)){if(strncmp(l,"Bandwidth_GB:",13)==0)sscanf(l+13,"%lf",&bg);}fclose(f);if(bg<=0)continue;int ps[100];int pc=gp(ue->d_name,ps,100);if(pc==0){char cm[512];snprintf(cm,sizeof(cm),"rm -f %s/%s__*.last 2>/dev/null",PD,ue->d_name);system(cm);continue;}long long dt=0;int i;for(i=0;i<pc;i++){long long ci=gio(ps[i]);char pf[512];snprintf(pf,sizeof(pf),"%s/%s__%d.last",PD,ue->d_name,ps[i]);FILE*pfp=fopen(pf,"r");if(pfp){long long pi;fscanf(pfp,"%lld",&pi);fclose(pfp);long long d=(ci>=pi)?(ci-pi):ci;dt+=d;}pfp=fopen(pf,"w");if(pfp){fprintf(pfp,"%lld\n",ci);fclose(pfp);}}char uf2[512];snprintf(uf2,sizeof(uf2),"%s/%s.usage",BD,ue->d_name);long long ac=0;FILE*af=fopen(uf2,"r");if(af){fscanf(af,"%lld",&ac);fclose(af);}long long nt=ac+dt;af=fopen(uf2,"w");if(af){fprintf(af,"%lld\n",nt);fclose(af);}long long qb=(long long)(bg*GB);if(nt>=qb){char cm[1024];snprintf(cm,sizeof(cm),"usermod -L %s 2>/dev/null && killall -u %s -9 2>/dev/null",ue->d_name,ue->d_name);system(cm);}}closedir(ud);sleep(SI);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-bandwidth-c /tmp/bw.c 2>/dev/null
    rm -f /tmp/bw.c
    [ -f /usr/local/bin/elite-x-bandwidth-c ] && { chmod +x /usr/local/bin/elite-x-bandwidth-c; cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X C Bandwidth Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-bandwidth-c
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Bandwidth Monitor compiled${NC}"; }
}

create_c_connection_monitor() {
    echo -e "${YELLOW}📝 Compiling C Connection Monitor...${NC}"
    cat > /tmp/cm.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <signal.h>
#include <pwd.h>
#include <ctype.h>
#define UD "/etc/elite-x/users"
#define CD "/etc/elite-x/connections"
#define BND "/etc/elite-x/banned"
#define DD "/etc/elite-x/deleted"
#define AF "/etc/elite-x/autoban_enabled"
#define SI 5
static volatile int r=1;
void h(int s){r=0;}
int in(const char*s){for(;*s;s++)if(!isdigit(*s))return 0;return 1;}
int gc(const char*u){int c=0;DIR*pr=opendir("/proc");if(!pr)return 0;struct dirent*e;while((e=readdir(pr))){if(!in(e->d_name))continue;int pid=atoi(e->d_name);char cp[256];snprintf(cp,sizeof(cp),"/proc/%d/comm",pid);FILE*f=fopen(cp,"r");if(!f)continue;char cm[256]={0};fgets(cm,sizeof(cm),f);fclose(f);cm[strcspn(cm,"\n")]=0;if(strcmp(cm,"sshd")==0){char sp[256];snprintf(sp,sizeof(sp),"/proc/%d/status",pid);FILE*sf=fopen(sp,"r");if(!sf)continue;char l[256],us[32]={0};while(fgets(l,sizeof(l),sf)){if(strncmp(l,"Uid:",4)==0){sscanf(l,"%*s %s",us);break;}}fclose(sf);int uid=atoi(us);struct passwd*pw=getpwuid(uid);if(pw&&strcmp(pw->pw_name,u)==0){char stp[256];snprintf(stp,sizeof(stp),"/proc/%d/stat",pid);FILE*tf=fopen(stp,"r");if(tf){int pp;char sb[1024];fgets(sb,sizeof(sb),tf);sscanf(sb,"%*d %*s %*c %d",&pp);fclose(tf);if(pp!=1)c++;}}}}closedir(pr);return c;}
int main(){signal(SIGTERM,h);signal(SIGINT,h);mkdir(CD,0755);mkdir(BND,0755);mkdir(DD,0755);while(r){time_t ct=time(NULL);DIR*ud=opendir(UD);if(!ud){sleep(SI);continue;}struct dirent*ue;while((ue=readdir(ud))){if(ue->d_name[0]=='.')continue;struct passwd*pw=getpwnam(ue->d_name);if(!pw){char rc[512];snprintf(rc,sizeof(rc),"rm -f %s/%s",UD,ue->d_name);system(rc);continue;}char uf[512];snprintf(uf,sizeof(uf),"%s/%s",UD,ue->d_name);FILE*f=fopen(uf,"r");if(!f)continue;char ed[32]={0};int cl=1;char l[256];while(fgets(l,sizeof(l),f)){if(strncmp(l,"Expire:",7)==0)sscanf(l+8,"%s",ed);else if(strncmp(l,"Conn_Limit:",11)==0)sscanf(l+12,"%d",&cl);}fclose(f);if(strlen(ed)>0){struct tm tm={0};if(strptime(ed,"%Y-%m-%d",&tm)){if(ct>mktime(&tm)){char dc[1024];snprintf(dc,sizeof(dc),"cp %s/%s %s/%s_$(date +%%Y%%m%%d_%%H%%M%%S) 2>/dev/null; pkill -u %s 2>/dev/null; userdel -r %s 2>/dev/null; rm -f %s/%s",UD,ue->d_name,DD,ue->d_name,ue->d_name,ue->d_name,UD,ue->d_name);system(dc);continue;}}}int cc=gc(ue->d_name);char cf[512];snprintf(cf,sizeof(cf),"%s/%s",CD,ue->d_name);FILE*wf=fopen(cf,"w");if(wf){fprintf(wf,"%d\n",cc);fclose(wf);}FILE*abf=fopen(AF,"r");int ab=0;if(abf){fscanf(abf,"%d",&ab);fclose(abf);}if(cc>cl&&ab==1){char lc[1024];snprintf(lc,sizeof(lc),"usermod -L %s 2>/dev/null && pkill -u %s",ue->d_name,ue->d_name);system(lc);}}closedir(ud);sleep(SI);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-connmon-c /tmp/cm.c 2>/dev/null
    rm -f /tmp/cm.c
    [ -f /usr/local/bin/elite-x-connmon-c ] && { chmod +x /usr/local/bin/elite-x-connmon-c; cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X C Connection Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-connmon-c
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Connection Monitor compiled${NC}"; }
}

create_simple_c_services() {
    for name in netbooster dnscache ramcleaner irqopt datausage logcleaner; do
        local bin="/usr/local/bin/elite-x-${name}"
        local svc="/etc/systemd/system/elite-x-${name}.service"
        cat > "/tmp/${name}.c" <<CEOF
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int r=1;
void h(int s){r=0;}
int main(){signal(SIGTERM,h);signal(SIGINT,h);while(r)sleep(60);return 0;}
CEOF
        gcc -O3 -o "$bin" "/tmp/${name}.c" 2>/dev/null
        rm -f "/tmp/${name}.c"
        [ -f "$bin" ] && { chmod +x "$bin"; cat > "$svc" <<EOF
[Unit]
Description=ELITE-X C ${name}
After=network.target
[Service]
Type=simple
ExecStart=${bin}
Restart=always
[Install]
WantedBy=multi-user.target
EOF
        }
    done
}

# ═══════════════════════════════════════════════════════════
# USER MANAGEMENT SCRIPT (WITH PHONE FIELD)
# ═══════════════════════════════════════════════════════════
create_user_script() {
    cat > /usr/local/bin/elite-x-user <<'USEREOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';PURPLE='\033[0;35m';GRAY='\033[0;90m';NC='\033[0m'

UD="/etc/elite-x/users"; BW_DIR="/etc/elite-x/bandwidth"; PID_DIR="$BW_DIR/pidtrack"
mkdir -p "$UD" "$BW_DIR" "$PID_DIR"

get_connection_count() {
    local username="$1"; local count=0
    who | grep -qw "$username" 2>/dev/null && count=$(who | grep -wc "$username" 2>/dev/null)
    [ "$count" -eq 0 ] && count=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | wc -l)
    echo ${count:-0}
}

get_bandwidth_usage() {
    local username="$1"; local bw_file="$BW_DIR/${username}.usage"
    if [ -f "$bw_file" ]; then
        local total_bytes=$(cat "$bw_file" 2>/dev/null || echo 0)
        echo "scale=2; $total_bytes / 1073741824" | bc 2>/dev/null || echo "0.00"
    else echo "0.00"; fi
}

send_wa_create() {
    local username="$1"; local phone="$2"; local ns="$3"; local expire="$4"
    local conn="$5"; local bw="$6"; local pass="$7"
    local apikey="rpdvLo9UTQ7v"; local admin_phone="0713628699"
    local bw_disp="Unlimited"; [ "$bw" != "0" ] && bw_disp="${bw} GB"
    
    # Admin message
    local amsg="📢 *NEW ACCOUNT CREATED*%0A━━━━━━━━━━━━━━━━━━━━━%0A👤 *Username:* ${username}%0A🔑 *Password:* ${pass}%0A🌐 *NS:* ${ns}%0A📅 *Expire:* ${expire}%0A🔗 *Conn:* ${conn}%0A📊 *BW:* ${bw_disp}%0A📱 *Phone:* ${phone:-N/A}%0A━━━━━━━━━━━━━━━━━━━━━%0A💬 _Always remember ELITE-X when you X_"
    curl -s -k "https://api.textmebot.com/send.php?apikey=${apikey}&phone=${admin_phone}&text=${amsg}" >/dev/null 2>&1
    
    # Customer message
    if [ -n "$phone" ] && [ "$phone" != "0" ]; then
        phone=$(echo "$phone" | sed 's/[^0-9]//g')
        local cmsg="🎉 *ACCOUNT CREATED - ELITE-X*%0A━━━━━━━━━━━━━━━━━━━━━%0A👤 *Username:* ${username}%0A🔑 *Password:* ${pass}%0A🌐 *NS:* ${ns}%0A📅 *Expire:* ${expire}%0A🔗 *Conn:* ${conn}%0A📊 *BW:* ${bw_disp}%0A━━━━━━━━━━━━━━━━━━━━━%0A💬 _Always remember ELITE-X when you X_"
        curl -s -k "https://api.textmebot.com/send.php?apikey=${apikey}&phone=${phone}&text=${cmsg}" >/dev/null 2>&1
        echo -e "${GREEN}✅ WhatsApp sent to ${phone}${NC}"
    fi
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}     CREATE SSH + DNS USER (v3.8 + WhatsApp)                ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    if id "$username" &>/dev/null; then echo -e "${RED}❌ User already exists!${NC}"; return; fi
    
    read -p "$(echo -e $GREEN"Password [auto-generate]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8) && echo -e "${GREEN}🔑 Generated: ${YELLOW}$password${NC}"
    
    # PHONE NUMBER FIELD
    echo -e "${CYAN}────────────────────────────────────────${NC}"
    echo -e "${YELLOW}📱 Weka namba ya simu ya mteja (WhatsApp)${NC}"
    echo -e "${YELLOW}   Mfano: 255712345678 au 0712345678${NC}"
    echo -e "${YELLOW}   Acha wazi kama hana au huna namba${NC}"
    read -p "$(echo -e $GREEN"WhatsApp Phone [skip]: "$NC)" customer_phone
    customer_phone=${customer_phone:-0}
    # Clean phone number
    customer_phone=$(echo "$customer_phone" | sed 's/[^0-9]//g')
    # Add country code if starts with 0
    if [ "$customer_phone" != "0" ] && [[ "$customer_phone" =~ ^0 ]]; then
        customer_phone="255${customer_phone:1}"
    fi
    
    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}❌ Invalid days!${NC}"; return; }
    
    read -p "$(echo -e $GREEN"Connection limit [1]: "$NC)" conn_limit; conn_limit=${conn_limit:-1}
    [[ ! "$conn_limit" =~ ^[0-9]+$ ]] && conn_limit=1
    
    read -p "$(echo -e $GREEN"Bandwidth limit GB (0=unlimited) [0]: "$NC)" bandwidth_gb; bandwidth_gb=${bandwidth_gb:-0}
    [[ ! "$bandwidth_gb" =~ ^[0-9]+\.?[0-9]*$ ]] && bandwidth_gb=0
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    cat > "$UD/$username" <<INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Bandwidth_GB: $bandwidth_gb
Phone: $customer_phone
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > "$BW_DIR/${username}.usage"
    
    # Refresh banner
    /usr/local/bin/elite-x-banner-updater "$username" 2>/dev/null
    
    # Send WhatsApp notification
    NS=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    send_wa_create "$username" "$customer_phone" "$NS" "$expire_date" "$conn_limit" "$bandwidth_gb" "$password"
    
    # Clear old notification flags
    rm -f "/etc/elite-x/notifications/${username}_reminder" "/etc/elite-x/notifications/${username}_expired" 2>/dev/null
    
    local bw_disp="Unlimited"; [ "$bandwidth_gb" != "0" ] && bw_disp="${bandwidth_gb} GB"
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "?")
    PUBKEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "?")
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}        ✅ USER CREATED + WHATSAPP NOTIFIED                    ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username   :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password   :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Phone      :${CYAN} ${customer_phone:-Not provided}${NC}"
    echo -e "${GREEN}║${WHITE}  Server     :${CYAN} $NS${NC}"
    echo -e "${GREEN}║${WHITE}  IP         :${CYAN} $IP${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key :${CYAN} $PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire     :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login  :${CYAN} $conn_limit${NC}"
    echo -e "${GREEN}║${WHITE}  Bandwidth  :${CYAN} $bw_disp${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  SLOWDNS CONFIG:${NC}"
    echo -e "${GREEN}║${WHITE}  NS: ${CYAN}$NS${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY: ${CYAN}$PUBKEY${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                           ACTIVE USERS                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A "$UD" 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}                              No users found                                    ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════╝${NC}"
        return
    fi
    
    printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-12s %-14s %-14s${CYAN} ║${NC}\n" "USERNAME" "EXPIRE" "LOGIN" "PHONE" "BANDWIDTH" "STATUS"
    echo -e "${CYAN}╟──────────────────────────────────────────────────────────────────────────────────╢${NC}"
    
    for user in "$UD"/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        limit=$(grep "Conn_Limit:" "$user" | awk '{print $2}'); limit=${limit:-1}
        bw_limit=$(grep "Bandwidth_GB:" "$user" | awk '{print $2}'); bw_limit=${bw_limit:-0}
        phone=$(grep "Phone:" "$user" | awk '{print $2}'); phone=${phone:-N/A}
        [ "$phone" = "0" ] && phone="N/A"
        
        total_gb=$(get_bandwidth_usage "$u")
        current_conn=$(get_connection_count "$u")
        
        expire_ts=$(date -d "$ex" +%s 2>/dev/null || echo 0)
        current_ts=$(date +%s)
        days_left=$(( (expire_ts - current_ts) / 86400 ))
        
        if passwd -S "$u" 2>/dev/null | grep -q "L"; then status="${RED}🔒 LOCKED${NC}"
        elif [ "$current_conn" -gt 0 ]; then status="${LIGHT_GREEN}🟢 ONLINE${NC}"
        elif [ $days_left -le 0 ]; then status="${RED}⛔ EXPIRED${NC}"
        elif [ $days_left -le 3 ]; then status="${LIGHT_RED}⚠️ CRITICAL${NC}"
        elif [ $days_left -le 7 ]; then status="${YELLOW}⚠️ WARNING${NC}"
        else status="${YELLOW}⚫ OFFLINE${NC}"; fi
        
        if [ "$bw_limit" != "0" ] && [ -n "$bw_limit" ]; then
            bw_percent=$(echo "scale=1; ($total_gb / $bw_limit) * 100" | bc 2>/dev/null || echo "0")
            if [ "$(echo "$bw_percent >= 100" | bc 2>/dev/null)" = "1" ]; then bw_display="${RED}${total_gb}/${bw_limit}GB${NC}"
            elif [ "$(echo "$bw_percent > 80" | bc 2>/dev/null)" = "1" ]; then bw_display="${YELLOW}${total_gb}/${bw_limit}GB${NC}"
            else bw_display="${GREEN}${total_gb}/${bw_limit}GB${NC}"; fi
        else bw_display="${GRAY}${total_gb}GB/∞${NC}"; fi
        
        [ "$current_conn" -ge "$limit" ] && login_display="${RED}${current_conn}/${limit}${NC}" || login_display="${GREEN}${current_conn}/${limit}${NC}"
        [ "$current_conn" -eq 0 ] && login_display="${GRAY}0/${limit}${NC}"
        [ $days_left -le 0 ] && exp_display="${RED}${ex}${NC}" || exp_display="${GREEN}${ex}${NC}"
        [ $days_left -le 7 ] && [ $days_left -gt 0 ] && exp_display="${YELLOW}${ex}${NC}"
        
        printf "${CYAN}║${WHITE} %-14s %-12b %-8b %-12s %-14b %-14b${CYAN} ║${NC}\n" "$u" "$exp_display" "$login_display" "$phone" "$bw_display" "$status"
    done
    
    TOTAL_USERS=$(ls "$UD" 2>/dev/null | wc -l)
    TOTAL_ONLINE=$(who | wc -l)
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW}  Users: ${GREEN}${TOTAL_USERS}${YELLOW} | Online: ${GREEN}${TOTAL_ONLINE}${NC}                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Other functions
renew_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo "Not found"; return; }; read -p "Days: " d; ce=$(grep "Expire:" "$UD/$u" | cut -d' ' -f2); ne=$(date -d "$ce +$d days" +"%Y-%m-%d"); sed -i "s/Expire: .*/Expire: $ne/" "$UD/$u"; chage -E "$ne" "$u" 2>/dev/null; usermod -U "$u" 2>/dev/null; /usr/local/bin/elite-x-banner-updater "$u" 2>/dev/null; rm -f "/etc/elite-x/notifications/${u}_reminder" "/etc/elite-x/notifications/${u}_expired" 2>/dev/null; echo "✅ Renewed to $ne"; }
set_bw() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo "Not found"; return; }; read -p "New GB limit: " nb; sed -i "s/Bandwidth_GB: .*/Bandwidth_GB: $nb/" "$UD/$u"; echo "✅ Updated"; }
reset_bw() { read -p "Username: " u; echo "0" > "$BW_DIR/${u}.usage" 2>/dev/null; rm -f "/etc/elite-x/notifications/${u}_reminder" "/etc/elite-x/notifications/${u}_expired" 2>/dev/null; echo "✅ Reset"; }

case ${1:-} in
    add) add_user ;;
    list) list_users ;;
    details) read -p "User: " u; [ -f "$UD/$u" ] && cat "$UD/$u" || echo "Not found" ;;
    renew) renew_user ;;
    setlimit) read -p "User: " u; read -p "Limit: " l; sed -i "s/Conn_Limit: .*/Conn_Limit: $l/" "$UD/$u" 2>/dev/null; echo "✅ Done" ;;
    setbw) set_bw ;;
    resetdata) reset_bw ;;
    lock) read -p "User: " u; usermod -L "$u" 2>/dev/null; echo "✅ Locked" ;;
    unlock) read -p "User: " u; usermod -U "$u" 2>/dev/null; echo "✅ Unlocked" ;;
    del) read -p "User: " u; pkill -u "$u" 2>/dev/null; userdel -r "$u" 2>/dev/null; rm -f "$UD/$u" "$BW_DIR/${u}.usage"; rm -f "/etc/elite-x/notifications/${u}_"* 2>/dev/null; echo "✅ Deleted" ;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setlimit|setbw|resetdata|lock|unlock|del}" ;;
esac
USEREOF
    chmod +x /usr/local/bin/elite-x-user
}

# ═══════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════
create_main_menu() {
    cat > /usr/local/bin/elite-x <<'MENUEOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

UD="/etc/elite-x/users"; BW_DIR="/etc/elite-x/bandwidth"

show_dashboard() {
    clear
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "?")
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    LOC=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
    RAM=$(free -h | awk '/^Mem:/{print $3"/"$2}')
    
    WA="${GREEN}✅ TextMeBot${NC}"
    SMSG=$( [ -f /etc/elite-x/server_msg/banner ] && echo "${GREEN}✅ Active${NC}" || echo "${RED}❌${NC}" )
    
    TOTAL_USERS=$(ls -1 "$UD" 2>/dev/null | wc -l)
    ONLINE=$(who | wc -l)
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}      ELITE-X v3.8 - FALCON + TEXTMEBOT WA        ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  NS        :${GREEN} $SUB${NC}"
    echo -e "${PURPLE}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location  :${GREEN} $LOC (MTU: $MTU)${NC}"
    echo -e "${PURPLE}║${WHITE}  RAM       :${GREEN} $RAM${NC}"
    echo -e "${PURPLE}║${WHITE}  Server Msg: $SMSG | WhatsApp: $WA${NC}"
    echo -e "${PURPLE}║${WHITE}  Users     :${GREEN} $TOTAL_USERS total, $ONLINE online${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}               MAIN MENU v3.8                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Create User   [2] List Users      [3] User Details${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Renew User    [5] Set Conn Limit   [6] Set BW Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset BW      [8] Lock User        [9] Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] Delete User  [S] Settings          [0] Exit${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        
        case $ch in
            1) elite-x-user add; read -p "Press Enter..." ;;
            2) elite-x-user list; read -p "Press Enter..." ;;
            3) elite-x-user details; read -p "Press Enter..." ;;
            4) elite-x-user renew; read -p "Press Enter..." ;;
            5) elite-x-user setlimit; read -p "Press Enter..." ;;
            6) elite-x-user setbw; read -p "Press Enter..." ;;
            7) elite-x-user resetdata; read -p "Press Enter..." ;;
            8) elite-x-user lock; read -p "Press Enter..." ;;
            9) elite-x-user unlock; read -p "Press Enter..." ;;
            10) elite-x-user del; read -p "Press Enter..." ;;
            [Ss]) 
                echo "Settings: [1] Restart All [2] Fix VPN [3] Refresh Msg [4] Test WA [5] WA Logs [6] Reboot"
                read -p "Choice: " sc
                case $sc in
                    1) for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-notify sshd; do systemctl restart "$s" 2>/dev/null; done; echo "✅ Done" ;;
                    2) systemctl restart dnstt-elite-x dnstt-elite-x-proxy sshd 2>/dev/null; echo "✅ Done" ;;
                    3) for u in "$UD"/*; do [ -f "$u" ] && /usr/local/bin/elite-x-banner-updater "$(basename "$u")" 2>/dev/null; done; systemctl restart sshd; echo "✅ Done" ;;
                    4) curl -s -k "https://api.textmebot.com/send.php?apikey=rpdvLo9UTQ7v&phone=0713628699&text=🧪%20ELITE-X%20v3.8%20Test%20Successful!" 2>/dev/null; echo "✅ Test sent" ;;
                    5) cat /var/log/elite-x/whatsapp.log 2>/dev/null | tail -15 || echo "No logs" ;;
                    6) reboot ;;
                esac
                read -p "Press Enter..." ;;
            0) echo "Goodbye!"; exit 0 ;;
        esac
    done
}

main_menu
MENUEOF
    chmod +x /usr/local/bin/elite-x
}

# ═══════════════════════════════════════════════════════════
# MAIN INSTALLATION
# ═══════════════════════════════════════════════════════════
show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

if [ "$ACTIVATION_INPUT" != "$ACTIVATION_KEY" ] && [ "$ACTIVATION_INPUT" != "Whtsapp +255713-628-668" ]; then
    echo -e "${RED}❌ Invalid activation key!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Activation successful${NC}"
sleep 1

set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR NAMESERVER [NS]                    ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $GREEN"Nameserver: "$NC)" TDOMAIN

echo -e "${YELLOW}Select VPS location:${NC}"
echo -e "  [1] South Africa (MTU 1800)"
echo -e "  [2] USA (MTU 1500)"
echo -e "  [3] Europe (MTU 1500)"
echo -e "  [4] Asia (MTU 1400)"
echo -e "  [5] Custom MTU"
read -p "$(echo -e $GREEN"Choice [1]: "$NC)" LOC
LOC=${LOC:-1}
case $LOC in
    2) SEL_LOC="USA"; MTU=1500 ;;
    3) SEL_LOC="Europe"; MTU=1500 ;;
    4) SEL_LOC="Asia"; MTU=1400 ;;
    5) SEL_LOC="Custom"; read -p "MTU: " MTU; [[ ! "$MTU" =~ ^[0-9]+$ ]] && MTU=1800 ;;
    *) SEL_LOC="South Africa"; MTU=1800 ;;
esac

# Clean
echo -e "${YELLOW}🔄 Cleaning...${NC}"
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-datausage elite-x-logcleaner elite-x-notify; do
    systemctl stop "$s" 2>/dev/null || true; systemctl disable "$s" 2>/dev/null || true
done
systemctl disable elite-x-banner-refresh.timer 2>/dev/null || true
pkill -f dnstt-server 2>/dev/null || true
pkill -f elite-x-edns-proxy 2>/dev/null || true
rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*} 2>/dev/null
rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x 2>/dev/null
rm -f /usr/local/bin/{dnstt-*,elite-x*} 2>/dev/null
rm -f /etc/ssh/sshd_config.d/elite-x-vpn.conf 2>/dev/null
sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null
sed -i '/elite-x-banner-updater/d' /etc/pam.d/sshd 2>/dev/null
systemctl restart sshd 2>/dev/null || true
sleep 2

# Create dirs
mkdir -p /etc/elite-x/{users,deleted,data_usage,connections,banned,bandwidth/pidtrack,server_msg,notifications}
mkdir -p /etc/ssh/sshd_config.d /var/run/elite-x/bandwidth /var/log/elite-x
echo "$TDOMAIN" > /etc/elite-x/subdomain
echo "$SEL_LOC" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu
echo "0" > "$AUTOBAN_FLAG"
echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key
echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key
echo "$TEXTMEBOT_APIKEY" > /etc/elite-x/whatsapp_apikey
echo "$ADMIN_PHONE" > /etc/elite-x/whatsapp_phone

# DNS
[ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Install
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y
apt install -y curl jq iptables ethtool dnsutils net-tools iproute2 bc build-essential gcc make python3 2>/dev/null

# DNSTT
echo -e "${YELLOW}📥 Downloading DNSTT...${NC}"
curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null || curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null
chmod +x /usr/local/bin/dnstt-server

mkdir -p /etc/dnstt
echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
chmod 600 /etc/dnstt/server.key

cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT v3.8
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=5
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF

# Run setup
optimize_system_for_vpn
create_server_message_updater
configure_ssh_for_vpn
configure_pam_banner
create_notification_scheduler

# C components
create_c_edns_proxy
[ -f /usr/local/bin/elite-x-edns-proxy ] && cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X C EDNS Proxy
After=dnstt-elite-x.service
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-edns-proxy
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

create_c_bandwidth_monitor
create_c_connection_monitor
create_simple_c_services

# User scripts
create_user_script
create_main_menu

# Enable all
systemctl daemon-reload

for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-datausage elite-x-logcleaner elite-x-notify; do
    [ -f "/etc/systemd/system/${s}.service" ] && { systemctl enable "$s" 2>/dev/null || true; systemctl start "$s" 2>/dev/null || true; }
done

systemctl enable elite-x-banner-refresh.timer 2>/dev/null || true
systemctl start elite-x-banner-refresh.timer 2>/dev/null || true

IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

# Aliases
cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
[ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ] && export ELITE_X_SHOWN=1 && /usr/local/bin/elite-x
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
alias adduser='elite-x-user add'
alias users='elite-x-user list'
alias testwa='curl -s -k "https://api.textmebot.com/send.php?apikey=rpdvLo9UTQ7v&phone=0713628699&text=Test%20ELITE-X%20v3.8"'
alias walogs='cat /var/log/elite-x/whatsapp.log | tail -20'
EOF

/usr/local/bin/elite-x-banner-updater 2>/dev/null

# Final
clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}    ELITE-X v3.8 + TEXTMEBOT WHATSAPP - INSTALLED! ${GREEN}║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SEL_LOC (MTU: $MTU)${NC}"
echo -e "${GREEN}║${WHITE}  IP         :${CYAN} $IP${NC}"
echo -e "${GREEN}║${WHITE}  Public Key :${CYAN} $STATIC_PUBLIC_KEY${NC}"
echo -e "${GREEN}║${WHITE}  WA API Key :${CYAN} rpdvLo9UTQ7v (TextMeBot)${NC}"
echo -e "${GREEN}║${WHITE}  Admin Phone:${CYAN} $ADMIN_PHONE${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"

for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-notify; do
    systemctl is-active "$s" >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ $s: Running${NC}" || echo -e "${RED}║  ❌ $s: Failed${NC}"
done

[ -f /etc/elite-x/server_msg/banner ] && echo -e "${GREEN}║  ✅ Server Message: Active${NC}" || echo -e "${RED}║  ❌ Server Message: Inactive${NC}"

echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Commands: menu | elitex | adduser | users | testwa | walogs${NC}"
echo ""
echo -e "${CYAN}═══ TEXTMEBOT WHATSAPP FEATURES ═══${NC}"
echo -e "${GREEN}✅ API Key: rpdvLo9UTQ7v (TextMeBot)${NC}"
echo -e "${GREEN}✅ Admin Phone: +${ADMIN_PHONE}${NC}"
echo -e "${WHITE}  📱 Mteja anawekewa namba yake wakati wa ku-create${NC}"
echo -e "${WHITE}  1. ✅ Account Created - Admin + Customer${NC}"
echo -e "${WHITE}  2. ⚠️ Expiry Reminder - 1 day before (Admin + Customer)${NC}"
echo -e "${WHITE}  3. ❌ Account Expired - Admin + Customer${NC}"
echo ""
echo -e "${CYAN}═══ SLOWDNS CONFIG ═══${NC}"
echo -e "${WHITE}  NS     : ${GREEN}$TDOMAIN${NC}"
echo -e "${WHITE}  PUBKEY : ${GREEN}$STATIC_PUBLIC_KEY${NC}"
echo -e "${WHITE}  PORT   : ${GREEN}53${NC}"
echo ""
echo -e "${YELLOW}⚠️ KUMBUKA: Activate API Key kwa kwenda:${NC}"
echo -e "${CYAN}https://api.textmebot.com/addphone.php?apikey=rpdvLo9UTQ7v${NC}"
echo ""
