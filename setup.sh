#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# ELITE-X SLOWDNS VPN v5.0 - FALCON ULTRA MAX BOOST
# Enhanced: SlowDNS Multi-Protocol, UDP Boost, 3proxy, SOCKS5
# Banner: Colored + Days+Hours+Mins Remaining + Accurate Conn Count
# ═══════════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
ORANGE='\033[0;33m'; LIGHT_RED='\033[1;31m'; LIGHT_GREEN='\033[1;32m'; GRAY='\033[0;90m'
MAGENTA='\033[0;95m'; NC='\033[0m'

STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

USER_DB="/etc/elite-x/users"
USAGE_DB="/etc/elite-x/data_usage"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
PIDTRACK_DIR="$BANDWIDTH_DIR/pidtrack"
BANNED_DB="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"
DELETED_DB="/etc/elite-x/deleted"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
USER_MSG_DIR="/etc/elite-x/user_messages"

SOCKS5_PORT=1080
PROXY3_PORT=3128
PROXY3_AUTH_PORT=1081

show_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}  ELITE-X SLOWDNS VPN v5.0 - FALCON ULTRA MAX BOOST  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}  SlowDNS+UDP+3proxy+SOCKS5 | BBR3 | 20Mbps+ | Zero Ping  ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_color() { echo -e "${2}${1}${NC}"; }
set_timezone() {
    timedatectl set-timezone $TIMEZONE 2>/dev/null || \
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════
# FORCE USER MESSAGE - COLORED BANNER WITH DAYS+HOURS+MINS
# ═══════════════════════════════════════════════════════════
force_user_message() {
    local username="$1"
    local msg_file="$USER_MSG_DIR/$username"
    mkdir -p "$USER_MSG_DIR"

    local expire_date=$(grep "Expire:" "$USER_DB/$username" | awk '{print $2}')
    local bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$username" | awk '{print $2}')
    local conn_limit=$(grep "Conn_Limit:" "$USER_DB/$username" | awk '{print $2}')
    bandwidth_gb=${bandwidth_gb:-0}
    conn_limit=${conn_limit:-1}

    local usage_bytes=$(cat "$BANDWIDTH_DIR/${username}.usage" 2>/dev/null || echo 0)
    local usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")

    # Accurate connection count: read from C monitor file
    local current_conn=0
    if [ -f "$CONN_DB/$username" ]; then
        current_conn=$(cat "$CONN_DB/$username" 2>/dev/null | tr -d '[:space:]' || echo 0)
    fi
    if [ -z "$current_conn" ] || [ "$current_conn" -eq 0 ] 2>/dev/null; then
        current_conn=$(ss -tnp 2>/dev/null | grep "sshd" | grep -c "$username" 2>/dev/null || echo 0)
    fi
    if [ -z "$current_conn" ] || [ "$current_conn" -eq 0 ] 2>/dev/null; then
        current_conn=$(who | grep -wc "$username" 2>/dev/null || echo 0)
    fi
    current_conn=${current_conn:-0}

    local now_ts=$(date +%s)
    local expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
    local remaining_seconds=$((expire_ts - now_ts))
    [ $remaining_seconds -lt 0 ] && remaining_seconds=0
    local remaining_days=$((remaining_seconds / 86400))
    local remaining_hours=$(((remaining_seconds % 86400) / 3600))
    local remaining_mins=$(((remaining_seconds % 3600) / 60))
    [ $remaining_days -lt 0 ] && remaining_days=0
    [ $remaining_hours -lt 0 ] && remaining_hours=0
    [ $remaining_mins -lt 0 ] && remaining_mins=0

    local bw_display="Unlimited"
    [ "$bandwidth_gb" != "0" ] && bw_display="${bandwidth_gb} GB"

    local status_text="ACTIVE"
    local status_icon="🟢"
    if [ $remaining_days -le 0 ] && [ $remaining_hours -le 0 ]; then
        status_text="EXPIRED"; status_icon="⛔"
    elif [ $remaining_days -le 3 ]; then
        status_text="EXPIRING SOON"; status_icon="⚠️ "
    fi

    # Write colored banner using raw ANSI codes (supported by SSH clients)
    printf '\033[1;35m═════════════════════════════════════════\033[0m\n' > "$msg_file"
    printf '\033[1;33m\033[1m  ELITE-X SLOWDNS VPN v5.0              \033[0m\n' >> "$msg_file"
    printf '\033[1;35m═════════════════════════════════════════\033[0m\n' >> "$msg_file"
    printf '\033[0;36m USERNAME  :\033[0m \033[1;32m %s\033[0m\n' "$username" >> "$msg_file"
    printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$msg_file"
    printf '\033[0;36m EXPIRE    :\033[0m \033[1;33m %s\033[0m\n' "$expire_date" >> "$msg_file"
    printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$msg_file"
    printf '\033[0;36m REMAINING :\033[0m \033[1;32m %sd + %sh + %sm\033[0m\n' "$remaining_days" "$remaining_hours" "$remaining_mins" >> "$msg_file"
    printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$msg_file"
    printf '\033[0;36m LIMIT GB  :\033[0m \033[1;33m %s\033[0m\n' "$bw_display" >> "$msg_file"
    printf '\033[0;36m USAGE GB  :\033[0m \033[1;31m %s GB\033[0m\n' "$usage_gb" >> "$msg_file"
    printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$msg_file"
    printf '\033[0;36m CONNECTION:\033[0m \033[1;32m %s\033[0m\033[1;37m/\033[0m\033[1;33m%s\033[0m\n' "$current_conn" "$conn_limit" >> "$msg_file"
    printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$msg_file"
    printf '\033[0;36m STATUS    :\033[0m %s \033[1;32m%s\033[0m\n' "$status_icon" "$status_text" >> "$msg_file"
    printf '\033[1;35m═════════════════════════════════════════\033[0m\n' >> "$msg_file"
    printf '\033[1;33m\033[1m  Thanks for using ELITE-X VPN           \033[0m\n' >> "$msg_file"
    printf '\033[1;35m═════════════════════════════════════════\033[0m\n' >> "$msg_file"

    chmod 644 "$msg_file"
    echo "$msg_file"
}

# ═══════════════════════════════════════════════════════════
# SSH CONFIGURATION WITH USER-SPECIFIC COLORED BANNERS
# ═══════════════════════════════════════════════════════════
configure_ssh_for_vpn() {
    echo -e "${YELLOW}🔧 Configuring SSH for VPN + Colored User Messages...${NC}"
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/^Match User/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null

    cat > /etc/ssh/sshd_config.d/elite-x-base.conf <<'SSHCONF'
# ELITE-X VPN Base Configuration v5.0
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
ClientAliveInterval 30
ClientAliveCountMax 6
MaxStartups 1000:30:2000
MaxSessions 1000
Compression no
UseDNS no
LogLevel VERBOSE
IPQoS lowdelay throughput
SSHCONF

    cat > /etc/ssh/sshd_config.d/elite-x-users.conf <<'SSHCONF2'
# ELITE-X Dynamic User Banners - Managed by system
SSHCONF2

    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] || continue
            local username=$(basename "$user_file")
            local msg_file=$(force_user_message "$username")
            echo "Match User $username" >> /etc/ssh/sshd_config.d/elite-x-users.conf
            echo "    Banner $msg_file" >> /etc/ssh/sshd_config.d/elite-x-users.conf
        done
    fi

    echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    echo -e "${GREEN}✅ SSH configured with Colored Banners (Days+Hours+Mins)${NC}"
}

# ═══════════════════════════════════════════════════════════
# PAM + LOGIN SCRIPT (Colored + Mins + Accurate Conn Count)
# ═══════════════════════════════════════════════════════════
configure_pam_user_message() {
    echo -e "${YELLOW}🔧 Configuring PAM for automatic user message update...${NC}"

    cat > /usr/local/bin/elite-x-update-user-msg <<'SCRIPT'
#!/bin/bash
USERNAME="$PAM_USER"
if [ -n "$USERNAME" ] && [ -f "/etc/elite-x/users/$USERNAME" ]; then
    /usr/local/bin/elite-x-force-user-message "$USERNAME" 2>/dev/null
fi
SCRIPT
    chmod +x /usr/local/bin/elite-x-update-user-msg

    cat > /usr/local/bin/elite-x-force-user-message <<'FORCE'
#!/bin/bash
USERNAME="$1"
USER_DB="/etc/elite-x/users"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
USER_MSG_DIR="/etc/elite-x/user_messages"
CONN_DB="/etc/elite-x/connections"

if [ -z "$USERNAME" ] || [ ! -f "$USER_DB/$USERNAME" ]; then exit 0; fi
mkdir -p "$USER_MSG_DIR"
MSG_FILE="$USER_MSG_DIR/$USERNAME"

expire_date=$(grep "Expire:" "$USER_DB/$USERNAME" | awk '{print $2}')
bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$USERNAME" | awk '{print $2}')
conn_limit=$(grep "Conn_Limit:" "$USER_DB/$USERNAME" | awk '{print $2}')
bandwidth_gb=${bandwidth_gb:-0}
conn_limit=${conn_limit:-1}

usage_bytes=$(cat "$BANDWIDTH_DIR/${USERNAME}.usage" 2>/dev/null || echo 0)
usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")

# Accurate connection count - read C monitor file first
current_conn=0
if [ -f "$CONN_DB/$USERNAME" ]; then
    current_conn=$(cat "$CONN_DB/$USERNAME" 2>/dev/null | tr -d '[:space:]' || echo 0)
fi
if [ -z "$current_conn" ] || ! [ "$current_conn" -gt 0 ] 2>/dev/null; then
    current_conn=$(ss -tnp 2>/dev/null | grep "sshd" | grep -c "$USERNAME" 2>/dev/null || echo 0)
fi
if [ -z "$current_conn" ] || ! [ "$current_conn" -gt 0 ] 2>/dev/null; then
    current_conn=$(who | grep -wc "$USERNAME" 2>/dev/null || echo 0)
fi
current_conn=${current_conn:-0}

now_ts=$(date +%s)
expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
remaining_seconds=$((expire_ts - now_ts))
[ $remaining_seconds -lt 0 ] && remaining_seconds=0
remaining_days=$((remaining_seconds / 86400))
remaining_hours=$(((remaining_seconds % 86400) / 3600))
remaining_mins=$(((remaining_seconds % 3600) / 60))
[ $remaining_days -lt 0 ] && remaining_days=0
[ $remaining_hours -lt 0 ] && remaining_hours=0
[ $remaining_mins -lt 0 ] && remaining_mins=0

bw_display="Unlimited"
[ "$bandwidth_gb" != "0" ] && bw_display="${bandwidth_gb} GB"

status_text="ACTIVE"; status_icon="🟢"
if [ $remaining_days -le 0 ] && [ $remaining_hours -le 0 ]; then
    status_text="EXPIRED"; status_icon="⛔"
elif [ $remaining_days -le 3 ]; then
    status_text="EXPIRING SOON"; status_icon="⚠️ "
fi

printf '\033[1;35m═════════════════════════════════════════\033[0m\n' > "$MSG_FILE"
printf '\033[1;33m\033[1m  ELITE-X SLOWDNS VPN v5.0              \033[0m\n' >> "$MSG_FILE"
printf '\033[1;35m═════════════════════════════════════════\033[0m\n' >> "$MSG_FILE"
printf '\033[0;36m USERNAME  :\033[0m \033[1;32m %s\033[0m\n' "$USERNAME" >> "$MSG_FILE"
printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$MSG_FILE"
printf '\033[0;36m EXPIRE    :\033[0m \033[1;33m %s\033[0m\n' "$expire_date" >> "$MSG_FILE"
printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$MSG_FILE"
printf '\033[0;36m REMAINING :\033[0m \033[1;32m %sd + %sh + %sm\033[0m\n' "$remaining_days" "$remaining_hours" "$remaining_mins" >> "$MSG_FILE"
printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$MSG_FILE"
printf '\033[0;36m LIMIT GB  :\033[0m \033[1;33m %s\033[0m\n' "$bw_display" >> "$MSG_FILE"
printf '\033[0;36m USAGE GB  :\033[0m \033[1;31m %s GB\033[0m\n' "$usage_gb" >> "$MSG_FILE"
printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$MSG_FILE"
printf '\033[0;36m CONNECTION:\033[0m \033[1;32m %s\033[0m\033[1;37m/\033[0m\033[1;33m%s\033[0m\n' "$current_conn" "$conn_limit" >> "$MSG_FILE"
printf '\033[1;34m─────────────────────────────────────────\033[0m\n' >> "$MSG_FILE"
printf '\033[0;36m STATUS    :\033[0m %s \033[1;32m%s\033[0m\n' "$status_icon" "$status_text" >> "$MSG_FILE"
printf '\033[1;35m═════════════════════════════════════════\033[0m\n' >> "$MSG_FILE"
printf '\033[1;33m\033[1m  Thanks for using ELITE-X VPN           \033[0m\n' >> "$MSG_FILE"
printf '\033[1;35m═════════════════════════════════════════\033[0m\n' >> "$MSG_FILE"

chmod 644 "$MSG_FILE"
sed -i "/Match User $USERNAME/,/Banner/d" /etc/ssh/sshd_config.d/elite-x-users.conf 2>/dev/null
echo "Match User $USERNAME" >> /etc/ssh/sshd_config.d/elite-x-users.conf
echo "    Banner $MSG_FILE" >> /etc/ssh/sshd_config.d/elite-x-users.conf
systemctl reload sshd 2>/dev/null || kill -HUP $(cat /var/run/sshd.pid 2>/dev/null) 2>/dev/null || true
echo "$USERNAME: msg updated $(date)" >> /var/log/elite-x-user-msgs.log 2>/dev/null
FORCE
    chmod +x /usr/local/bin/elite-x-force-user-message

    sed -i '/elite-x-update-user-msg/d' /etc/pam.d/sshd 2>/dev/null
    echo "session optional pam_exec.so seteuid /usr/local/bin/elite-x-update-user-msg" >> /etc/pam.d/sshd
    echo -e "${GREEN}✅ PAM configured - colored banner with days+hours+mins on login${NC}"
}

# ═══════════════════════════════════════════════════════════
# SUPER SYSTEM OPTIMIZATION - MAXIMUM BOOST v5.0
# ═══════════════════════════════════════════════════════════
optimize_system_for_vpn() {
    echo -e "${YELLOW}🚀 Applying MAXIMUM system optimizations for 20Mbps+...${NC}"
    modprobe tcp_bbr 2>/dev/null || true
    modprobe sch_fq 2>/dev/null || true

    cat > /etc/sysctl.d/99-elite-x-vpn.conf <<'SYSCTL'
# ═══ ELITE-X v5.0 ULTRA BOOST SYSCTL ═══
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=268435456
net.core.wmem_max=268435456
net.core.rmem_default=524288
net.core.wmem_default=524288
net.ipv4.tcp_rmem=4096 262144 268435456
net.ipv4.tcp_wmem=4096 131072 268435456
net.ipv4.tcp_mem=786432 1048576 26777216
net.core.optmem_max=65536
net.ipv4.udp_mem=102400 873800 33554432
net.ipv4.udp_rmem_min=65536
net.ipv4.udp_wmem_min=65536
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_no_pmtu_disc=0
net.ipv4.tcp_max_syn_backlog=65536
net.core.somaxconn=65536
net.core.netdev_max_backlog=50000
net.ipv4.tcp_max_tw_buckets=2000000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=5
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_keepalive_time=30
net.ipv4.tcp_keepalive_intvl=5
net.ipv4.tcp_keepalive_probes=6
net.core.netdev_budget=1000
net.core.netdev_budget_usecs=8000
net.core.busy_read=50
net.core.busy_poll=50
vm.swappiness=5
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=3
vm.min_free_kbytes=65536
fs.file-max=2097152
fs.nr_open=2097152
SYSCTL

    sysctl -p /etc/sysctl.d/99-elite-x-vpn.conf >/dev/null 2>&1 || true

    cat > /etc/security/limits.d/elite-x.conf <<'LIMITS'
* soft nofile 2097152
* hard nofile 2097152
* soft nproc 65536
* hard nproc 65536
root soft nofile 2097152
root hard nofile 2097152
LIMITS

    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/elite-x-limits.conf <<'SDLIMIT'
[Manager]
DefaultLimitNOFILE=2097152
DefaultLimitNPROC=65536
SDLIMIT

    iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true
    iptables -A FORWARD -i lo -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -o lo -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport 1080 -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport 1081 -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport 3128 -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p udp --dport 5302 -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p udp --dport 5353 -j ACCEPT 2>/dev/null || true

    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ethtool -G "$iface" rx 4096 tx 4096 2>/dev/null || true
        ethtool -K "$iface" gso on gro on tso on 2>/dev/null || true
        ip link set "$iface" txqueuelen 10000 2>/dev/null || true
    done
    echo -e "${GREEN}✅ MAXIMUM system optimization applied${NC}"
}

# ═══════════════════════════════════════════════════════════
# INSTALL 3PROXY (SOCKS5 + HTTP PROXY)
# ═══════════════════════════════════════════════════════════
install_3proxy() {
    echo -e "${YELLOW}📦 Installing 3proxy (SOCKS5 + HTTP Proxy)...${NC}"
    apt-get install -y 3proxy 2>/dev/null || true
    PROXY3_BIN=$(which 3proxy 2>/dev/null || echo "")

    if [ -z "$PROXY3_BIN" ] || [ ! -f "$PROXY3_BIN" ]; then
        cd /tmp
        curl -fsSL https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz -o 3proxy.tar.gz 2>/dev/null || true
        if [ -f 3proxy.tar.gz ]; then
            tar xzf 3proxy.tar.gz 2>/dev/null
            local srcdir=$(ls -d /tmp/3proxy-*/ 2>/dev/null | head -1)
            if [ -n "$srcdir" ]; then
                cd "$srcdir"
                make -f Makefile.Linux 2>/dev/null && \
                    cp bin/3proxy /usr/local/bin/3proxy && chmod +x /usr/local/bin/3proxy
            fi
            cd /tmp && rm -rf 3proxy* 2>/dev/null
        fi
        PROXY3_BIN=$(which 3proxy 2>/dev/null || echo "/usr/local/bin/3proxy")
    fi

    if [ ! -f "$PROXY3_BIN" ]; then
        echo -e "${RED}❌ 3proxy not available - C SOCKS5 will handle port 1080${NC}"
        return 1
    fi

    mkdir -p /etc/3proxy /var/log/3proxy
    cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
pidfile /var/run/3proxy.pid
log /var/log/3proxy/3proxy.log D
logformat "- +_G%t.%.  %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 7
maxconn 5000
nserver 1.1.1.1
nserver 8.8.8.8
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
auth none
allow *
socks -p${SOCKS5_PORT} -i0.0.0.0 -e0.0.0.0
proxy -p${PROXY3_PORT} -i0.0.0.0 -e0.0.0.0
auth strong
users elite:CL:elitex2025
allow elite
socks -p${PROXY3_AUTH_PORT} -i0.0.0.0 -e0.0.0.0
EOF

    cat > /etc/systemd/system/3proxy-elite-x.service <<EOF
[Unit]
Description=ELITE-X 3proxy SOCKS5+HTTP Proxy v5.0
After=network-online.target
Wants=network-online.target
[Service]
Type=forking
PIDFile=/var/run/3proxy.pid
User=root
ExecStart=${PROXY3_BIN} /etc/3proxy/3proxy.cfg
Restart=always
RestartSec=3
LimitNOFILE=2097152
Nice=-10
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ 3proxy configured (SOCKS5:${SOCKS5_PORT}, HTTP:${PROXY3_PORT}, Auth:${PROXY3_AUTH_PORT})${NC}"
    return 0
}

# ═══════════════════════════════════════════════════════════
# C: ULTRA EDNS PROXY v5.0 - 64 Workers, 16MB Buffers
# ═══════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}📝 Compiling C ULTRA EDNS Proxy v5.0...${NC}"
    cat > /tmp/edns_proxy.c <<'CEOF'
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
#include <fcntl.h>
#include <sys/resource.h>

#define BUFFER_SIZE       8192
#define DNS_PORT          53
#define BACKEND_PORT      5300
#define MAX_EDNS_SIZE     4096
#define MIN_EDNS_SIZE     512
#define THREAD_POOL_SIZE  64
#define QUEUE_SIZE        65536
#define SOCKET_BUF_SIZE   (16*1024*1024)

static volatile int running = 1;
static int main_sock = -1;

void signal_handler(int sig) { running=0; if(main_sock>=0) close(main_sock); }

static int skip_name(const unsigned char *d, int o, int m) {
    while(o<m){unsigned char l=d[o++];if(l==0)break;if((l&0xC0)==0xC0){o++;break;}o+=l;if(o>=m)break;}
    return o;
}
static void modify_edns(unsigned char *d, int *l, unsigned short ms) {
    if(*l<12)return;
    int o=12;
    unsigned short qd=ntohs(*(unsigned short*)(d+4)),an=ntohs(*(unsigned short*)(d+6));
    unsigned short ns=ntohs(*(unsigned short*)(d+8)),ar=ntohs(*(unsigned short*)(d+10));
    int i;
    for(i=0;i<qd;i++){o=skip_name(d,o,*l);if(o+4>*l)return;o+=4;}
    for(i=0;i<an+ns;i++){o=skip_name(d,o,*l);if(o+10>*l)return;unsigned short r=ntohs(*(unsigned short*)(d+o+8));o+=10+r;}
    for(i=0;i<ar;i++){o=skip_name(d,o,*l);if(o+10>*l)return;unsigned short t=ntohs(*(unsigned short*)(d+o));
        if(t==41){unsigned short sz=htons(ms);memcpy(d+o+2,&sz,2);return;}
        unsigned short r=ntohs(*(unsigned short*)(d+o+8));o+=10+r;}
}

typedef struct { int sock; struct sockaddr_in ca; socklen_t cl; unsigned char *data; int dlen; } work_t;
typedef struct { work_t *items[QUEUE_SIZE]; volatile int head,tail; pthread_mutex_t lk; pthread_cond_t cv; } queue_t;
static queue_t wq;

static void q_init(queue_t *q){memset(q,0,sizeof(*q));pthread_mutex_init(&q->lk,NULL);pthread_cond_init(&q->cv,NULL);}
static int q_push(queue_t *q,work_t *w){pthread_mutex_lock(&q->lk);int n=(q->tail+1)%QUEUE_SIZE;if(n==q->head){pthread_mutex_unlock(&q->lk);return -1;}q->items[q->tail]=w;q->tail=n;pthread_cond_signal(&q->cv);pthread_mutex_unlock(&q->lk);return 0;}
static work_t *q_pop(queue_t *q){pthread_mutex_lock(&q->lk);while(q->head==q->tail&&running)pthread_cond_wait(&q->cv,&q->lk);if(q->head==q->tail){pthread_mutex_unlock(&q->lk);return NULL;}work_t *w=q->items[q->head];q->head=(q->head+1)%QUEUE_SIZE;pthread_mutex_unlock(&q->lk);return w;}

static void *worker(void *a){(void)a;
    while(running){
        work_t *w=q_pop(&wq); if(!w)continue;
        int bs=socket(AF_INET,SOCK_DGRAM,0); if(bs<0){free(w->data);free(w);continue;}
        struct timeval tv={3,0}; setsockopt(bs,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv)); setsockopt(bs,SOL_SOCKET,SO_SNDTIMEO,&tv,sizeof(tv));
        int sb=2*1024*1024; setsockopt(bs,SOL_SOCKET,SO_RCVBUF,&sb,sizeof(sb)); setsockopt(bs,SOL_SOCKET,SO_SNDBUF,&sb,sizeof(sb));
        struct sockaddr_in bk={.sin_family=AF_INET,.sin_addr.s_addr=inet_addr("127.0.0.1"),.sin_port=htons(BACKEND_PORT)};
        int l=w->dlen; modify_edns(w->data,&l,MAX_EDNS_SIZE);
        sendto(bs,w->data,l,0,(struct sockaddr*)&bk,sizeof(bk));
        unsigned char resp[BUFFER_SIZE]; socklen_t bl=sizeof(bk);
        int rn=recvfrom(bs,resp,BUFFER_SIZE,0,(struct sockaddr*)&bk,&bl);
        if(rn>0){modify_edns(resp,&rn,MIN_EDNS_SIZE);sendto(w->sock,resp,rn,0,(struct sockaddr*)&w->ca,w->cl);}
        close(bs); free(w->data); free(w);
    }
    return NULL;
}

int main(void){
    signal(SIGTERM,signal_handler); signal(SIGINT,signal_handler); signal(SIGPIPE,SIG_IGN);
    struct rlimit rl={1048576,1048576}; setrlimit(RLIMIT_NOFILE,&rl);
    q_init(&wq);
    pthread_t pool[THREAD_POOL_SIZE]; int i;
    for(i=0;i<THREAD_POOL_SIZE;i++){pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setdetachstate(&a,PTHREAD_CREATE_DETACHED);pthread_create(&pool[i],&a,worker,NULL);pthread_attr_destroy(&a);}
    main_sock=socket(AF_INET,SOCK_DGRAM,0); if(main_sock<0)return 1;
    int one=1; setsockopt(main_sock,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one)); setsockopt(main_sock,SOL_SOCKET,SO_REUSEPORT,&one,sizeof(one));
    int rb=SOCKET_BUF_SIZE,wb=SOCKET_BUF_SIZE; setsockopt(main_sock,SOL_SOCKET,SO_RCVBUF,&rb,sizeof(rb)); setsockopt(main_sock,SOL_SOCKET,SO_SNDBUF,&wb,sizeof(wb));
    struct sockaddr_in addr={.sin_family=AF_INET,.sin_addr.s_addr=INADDR_ANY,.sin_port=htons(DNS_PORT)};
    system("fuser -k 53/udp >/dev/null 2>&1"); usleep(500000);
    if(bind(main_sock,(struct sockaddr*)&addr,sizeof(addr))<0){system("fuser -k 53/udp >/dev/null 2>&1");usleep(1500000);if(bind(main_sock,(struct sockaddr*)&addr,sizeof(addr))<0){perror("bind");close(main_sock);return 1;}}
    fcntl(main_sock,F_SETFL,fcntl(main_sock,F_GETFL)|O_NONBLOCK);
    fprintf(stderr,"[ELITE-X] C-EDNS Proxy v5.0 running (port 53, %d workers)\n",THREAD_POOL_SIZE);
    while(running){
        struct sockaddr_in ca; socklen_t cl=sizeof(ca);
        unsigned char *buf=malloc(BUFFER_SIZE); if(!buf){usleep(1000);continue;}
        int n=recvfrom(main_sock,buf,BUFFER_SIZE,0,(struct sockaddr*)&ca,&cl);
        if(n<=0){free(buf);if(errno==EAGAIN||errno==EWOULDBLOCK){usleep(100);continue;}if(!running)break;continue;}
        work_t *w=malloc(sizeof(work_t)); if(!w){free(buf);continue;}
        w->sock=main_sock; w->ca=ca; w->cl=cl; w->data=buf; w->dlen=n;
        if(q_push(&wq,w)<0){free(buf);free(w);}
    }
    close(main_sock); return 0;
}
CEOF
    gcc -O3 -march=native -mtune=native -flto -pthread \
        -o /usr/local/bin/elite-x-edns-proxy /tmp/edns_proxy.c 2>/dev/null
    rm -f /tmp/edns_proxy.c
    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        chmod +x /usr/local/bin/elite-x-edns-proxy
        echo -e "${GREEN}✅ C ULTRA EDNS Proxy v5.0 compiled (64 workers, 16MB buffers)${NC}"
    else
        echo -e "${RED}❌ C EDNS Proxy compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: UDP TURBO RELAY (Port 5301) - 32 Workers, SCHED_FIFO
# ═══════════════════════════════════════════════════════════
create_c_udp_turbo() {
    echo -e "${YELLOW}📝 Compiling C UDP Turbo Relay v5.0 (port 5301)...${NC}"
    cat > /tmp/udp_turbo.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define RELAY_PORT   5301
#define BACKEND_PORT 5300
#define BUF_SIZE     8192
#define POOL_SIZE    32
#define QUEUE_CAP    32768
#define SOCK_BUF     (16*1024*1024)

static volatile int running=1;
void sh(int s){running=0;}
typedef struct{unsigned char buf[BUF_SIZE];int len;struct sockaddr_in src;}pkt_t;
static pkt_t qb[QUEUE_CAP];
static volatile int qh=0,qt=0;
static pthread_mutex_t qm=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t qc=PTHREAD_COND_INITIALIZER;
static int rsock=-1;

static void qpush(pkt_t *p){pthread_mutex_lock(&qm);int n=(qt+1)%QUEUE_CAP;if(n!=qh){qb[qt]=*p;qt=n;pthread_cond_signal(&qc);}pthread_mutex_unlock(&qm);}
static int qpop(pkt_t *p){pthread_mutex_lock(&qm);while(qh==qt&&running)pthread_cond_wait(&qc,&qm);if(qh==qt){pthread_mutex_unlock(&qm);return 0;}*p=qb[qh];qh=(qh+1)%QUEUE_CAP;pthread_mutex_unlock(&qm);return 1;}

static void *worker(void *a){(void)a;
    struct sched_param sp={.sched_priority=10};pthread_setschedparam(pthread_self(),SCHED_FIFO,&sp);
    while(running){pkt_t pkt;if(!qpop(&pkt))continue;
        int bs=socket(AF_INET,SOCK_DGRAM,0);if(bs<0)continue;
        struct timeval tv={2,0};setsockopt(bs,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));setsockopt(bs,SOL_SOCKET,SO_SNDTIMEO,&tv,sizeof(tv));
        int sb=2*1024*1024;setsockopt(bs,SOL_SOCKET,SO_RCVBUF,&sb,sizeof(sb));setsockopt(bs,SOL_SOCKET,SO_SNDBUF,&sb,sizeof(sb));
        struct sockaddr_in bk={.sin_family=AF_INET,.sin_addr.s_addr=inet_addr("127.0.0.1"),.sin_port=htons(BACKEND_PORT)};
        sendto(bs,pkt.buf,pkt.len,0,(struct sockaddr*)&bk,sizeof(bk));
        unsigned char resp[BUF_SIZE];socklen_t bl=sizeof(bk);
        int rn=recvfrom(bs,resp,BUF_SIZE,0,(struct sockaddr*)&bk,&bl);
        if(rn>0&&rsock>=0)sendto(rsock,resp,rn,0,(struct sockaddr*)&pkt.src,sizeof(pkt.src));
        close(bs);}
    return NULL;}

int main(void){
    signal(SIGTERM,sh);signal(SIGINT,sh);signal(SIGPIPE,SIG_IGN);
    struct rlimit rl={1048576,1048576};setrlimit(RLIMIT_NOFILE,&rl);
    rsock=socket(AF_INET,SOCK_DGRAM,0);if(rsock<0)return 1;
    int one=1;setsockopt(rsock,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));setsockopt(rsock,SOL_SOCKET,SO_REUSEPORT,&one,sizeof(one));
    int rb=SOCK_BUF,wb=SOCK_BUF;setsockopt(rsock,SOL_SOCKET,SO_RCVBUF,&rb,sizeof(rb));setsockopt(rsock,SOL_SOCKET,SO_SNDBUF,&wb,sizeof(wb));
    struct sockaddr_in addr={.sin_family=AF_INET,.sin_addr.s_addr=INADDR_ANY,.sin_port=htons(RELAY_PORT)};
    if(bind(rsock,(struct sockaddr*)&addr,sizeof(addr))<0){perror("bind udp turbo");close(rsock);return 1;}
    fcntl(rsock,F_SETFL,fcntl(rsock,F_GETFL)|O_NONBLOCK);
    pthread_t pool[POOL_SIZE];int i;
    for(i=0;i<POOL_SIZE;i++){pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setdetachstate(&a,PTHREAD_CREATE_DETACHED);pthread_create(&pool[i],&a,worker,NULL);pthread_attr_destroy(&a);}
    fprintf(stderr,"[ELITE-X] UDP Turbo Relay v5.0 port %d\n",RELAY_PORT);
    while(running){pkt_t pkt;socklen_t sl=sizeof(pkt.src);
        int n=recvfrom(rsock,pkt.buf,BUF_SIZE,0,(struct sockaddr*)&pkt.src,&sl);
        if(n<=0){usleep(100);continue;}pkt.len=n;qpush(&pkt);}
    close(rsock);return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto -pthread \
        -o /usr/local/bin/elite-x-udp-turbo /tmp/udp_turbo.c 2>/dev/null
    rm -f /tmp/udp_turbo.c
    if [ -f /usr/local/bin/elite-x-udp-turbo ]; then
        chmod +x /usr/local/bin/elite-x-udp-turbo
        cat > /etc/systemd/system/elite-x-udp-turbo.service <<EOF
[Unit]
Description=ELITE-X C UDP Turbo Relay v5.0 (port 5301)
After=dnstt-elite-x.service
Wants=dnstt-elite-x.service
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-udp-turbo
Restart=always
RestartSec=2
LimitNOFILE=2097152
Nice=-15
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=20
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C UDP Turbo compiled (port 5301, 32 workers)${NC}"
    else
        echo -e "${RED}❌ UDP Turbo compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: UDP BOOST2 (Port 5302) - Dual-Path Fallback, 48 Workers
# ═══════════════════════════════════════════════════════════
create_c_udp_boost2() {
    echo -e "${YELLOW}📝 Compiling C UDP Boost2 Relay v5.0 (port 5302)...${NC}"
    cat > /tmp/udp_boost2.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define RELAY_PORT    5302
#define BACKEND1_PORT 5300
#define BACKEND2_PORT 5301
#define BUF_SIZE      8192
#define POOL_SIZE     48
#define QUEUE_CAP     65536
#define SOCK_BUF      (16*1024*1024)

static volatile int running=1;
void sh(int s){running=0;}
typedef struct{unsigned char buf[BUF_SIZE];int len;struct sockaddr_in src;}pkt_t;
static pkt_t *qbuf;
static volatile int qh=0,qt=0;
static pthread_mutex_t qm=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t qc=PTHREAD_COND_INITIALIZER;
static int rsock=-1;

static void qpush(pkt_t *p){pthread_mutex_lock(&qm);int n=(qt+1)%QUEUE_CAP;if(n!=qh){qbuf[qt]=*p;qt=n;pthread_cond_signal(&qc);}pthread_mutex_unlock(&qm);}
static int qpop(pkt_t *p){pthread_mutex_lock(&qm);while(qh==qt&&running)pthread_cond_wait(&qc,&qm);if(qh==qt){pthread_mutex_unlock(&qm);return 0;}*p=qbuf[qh];qh=(qh+1)%QUEUE_CAP;pthread_mutex_unlock(&qm);return 1;}

static int try_backend(pkt_t *pkt,int port){
    int bs=socket(AF_INET,SOCK_DGRAM,0);if(bs<0)return -1;
    struct timeval tv={2,0};setsockopt(bs,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));setsockopt(bs,SOL_SOCKET,SO_SNDTIMEO,&tv,sizeof(tv));
    int sb=2*1024*1024;setsockopt(bs,SOL_SOCKET,SO_RCVBUF,&sb,sizeof(sb));setsockopt(bs,SOL_SOCKET,SO_SNDBUF,&sb,sizeof(sb));
    struct sockaddr_in bk={.sin_family=AF_INET,.sin_addr.s_addr=inet_addr("127.0.0.1"),.sin_port=htons(port)};
    if(sendto(bs,pkt->buf,pkt->len,0,(struct sockaddr*)&bk,sizeof(bk))<0){close(bs);return -1;}
    unsigned char resp[BUF_SIZE];socklen_t bl=sizeof(bk);
    int rn=recvfrom(bs,resp,BUF_SIZE,0,(struct sockaddr*)&bk,&bl);
    if(rn>0&&rsock>=0){sendto(rsock,resp,rn,0,(struct sockaddr*)&pkt->src,sizeof(pkt->src));close(bs);return rn;}
    close(bs);return -1;}

static void *worker(void *a){(void)a;
    struct sched_param sp={.sched_priority=9};pthread_setschedparam(pthread_self(),SCHED_FIFO,&sp);
    while(running){pkt_t pkt;if(!qpop(&pkt))continue;
        if(try_backend(&pkt,BACKEND1_PORT)<0)try_backend(&pkt,BACKEND2_PORT);}
    return NULL;}

int main(void){
    signal(SIGTERM,sh);signal(SIGINT,sh);signal(SIGPIPE,SIG_IGN);
    struct rlimit rl={1048576,1048576};setrlimit(RLIMIT_NOFILE,&rl);
    qbuf=malloc(sizeof(pkt_t)*QUEUE_CAP);if(!qbuf)return 1;
    rsock=socket(AF_INET,SOCK_DGRAM,0);if(rsock<0){free(qbuf);return 1;}
    int one=1;setsockopt(rsock,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));setsockopt(rsock,SOL_SOCKET,SO_REUSEPORT,&one,sizeof(one));
    int rb=SOCK_BUF,wb=SOCK_BUF;setsockopt(rsock,SOL_SOCKET,SO_RCVBUF,&rb,sizeof(rb));setsockopt(rsock,SOL_SOCKET,SO_SNDBUF,&wb,sizeof(wb));
    struct sockaddr_in addr={.sin_family=AF_INET,.sin_addr.s_addr=INADDR_ANY,.sin_port=htons(RELAY_PORT)};
    if(bind(rsock,(struct sockaddr*)&addr,sizeof(addr))<0){perror("bind udp boost2");close(rsock);free(qbuf);return 1;}
    fcntl(rsock,F_SETFL,fcntl(rsock,F_GETFL)|O_NONBLOCK);
    pthread_t pool[POOL_SIZE];int i;
    for(i=0;i<POOL_SIZE;i++){pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setdetachstate(&a,PTHREAD_CREATE_DETACHED);pthread_create(&pool[i],&a,worker,NULL);pthread_attr_destroy(&a);}
    fprintf(stderr,"[ELITE-X] UDP Boost2 v5.0 port %d (dual-path, %d workers)\n",RELAY_PORT,POOL_SIZE);
    while(running){pkt_t pkt;socklen_t sl=sizeof(pkt.src);
        int n=recvfrom(rsock,pkt.buf,BUF_SIZE,0,(struct sockaddr*)&pkt.src,&sl);
        if(n<=0){if(errno==EAGAIN||errno==EWOULDBLOCK){usleep(50);}continue;}pkt.len=n;qpush(&pkt);}
    close(rsock);free(qbuf);return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto -pthread \
        -o /usr/local/bin/elite-x-udp-boost2 /tmp/udp_boost2.c 2>/dev/null
    rm -f /tmp/udp_boost2.c
    if [ -f /usr/local/bin/elite-x-udp-boost2 ]; then
        chmod +x /usr/local/bin/elite-x-udp-boost2
        cat > /etc/systemd/system/elite-x-udp-boost2.service <<EOF
[Unit]
Description=ELITE-X C UDP Boost2 Relay v5.0 (port 5302 dual-path)
After=dnstt-elite-x.service elite-x-udp-turbo.service
Wants=dnstt-elite-x.service
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-udp-boost2
Restart=always
RestartSec=2
LimitNOFILE=2097152
Nice=-14
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=18
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C UDP Boost2 compiled (port 5302, dual-path, 48 workers)${NC}"
    else
        echo -e "${RED}❌ UDP Boost2 compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: SLOWDNS ALT RELAY (Port 5353) - mDNS bypass
# ═══════════════════════════════════════════════════════════
create_c_slowdns_alt() {
    echo -e "${YELLOW}📝 Compiling C SlowDNS Alt Relay v5.0 (port 5353)...${NC}"
    cat > /tmp/slowdns_alt.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define ALT_PORT     5353
#define BACKEND_PORT 5300
#define BUF_SIZE     8192
#define POOL_SIZE    32
#define QUEUE_CAP    32768
#define SOCK_BUF     (8*1024*1024)

static volatile int running=1;
void sh(int s){running=0;}
typedef struct{unsigned char buf[BUF_SIZE];int len;struct sockaddr_in src;}pkt_t;
static pkt_t qb[QUEUE_CAP];
static volatile int qh=0,qt=0;
static pthread_mutex_t qm=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t qc=PTHREAD_COND_INITIALIZER;
static int asock=-1;

static void qpush(pkt_t *p){pthread_mutex_lock(&qm);int n=(qt+1)%QUEUE_CAP;if(n!=qh){qb[qt]=*p;qt=n;pthread_cond_signal(&qc);}pthread_mutex_unlock(&qm);}
static int qpop(pkt_t *p){pthread_mutex_lock(&qm);while(qh==qt&&running)pthread_cond_wait(&qc,&qm);if(qh==qt){pthread_mutex_unlock(&qm);return 0;}*p=qb[qh];qh=(qh+1)%QUEUE_CAP;pthread_mutex_unlock(&qm);return 1;}

static void *worker(void *a){(void)a;
    while(running){pkt_t pkt;if(!qpop(&pkt))continue;
        int bs=socket(AF_INET,SOCK_DGRAM,0);if(bs<0)continue;
        struct timeval tv={3,0};setsockopt(bs,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));setsockopt(bs,SOL_SOCKET,SO_SNDTIMEO,&tv,sizeof(tv));
        int sb=1024*1024;setsockopt(bs,SOL_SOCKET,SO_RCVBUF,&sb,sizeof(sb));setsockopt(bs,SOL_SOCKET,SO_SNDBUF,&sb,sizeof(sb));
        struct sockaddr_in bk={.sin_family=AF_INET,.sin_addr.s_addr=inet_addr("127.0.0.1"),.sin_port=htons(BACKEND_PORT)};
        sendto(bs,pkt.buf,pkt.len,0,(struct sockaddr*)&bk,sizeof(bk));
        unsigned char resp[BUF_SIZE];socklen_t bl=sizeof(bk);
        int rn=recvfrom(bs,resp,BUF_SIZE,0,(struct sockaddr*)&bk,&bl);
        if(rn>0&&asock>=0)sendto(asock,resp,rn,0,(struct sockaddr*)&pkt.src,sizeof(pkt.src));
        close(bs);}
    return NULL;}

int main(void){
    signal(SIGTERM,sh);signal(SIGINT,sh);signal(SIGPIPE,SIG_IGN);
    struct rlimit rl={524288,524288};setrlimit(RLIMIT_NOFILE,&rl);
    asock=socket(AF_INET,SOCK_DGRAM,0);if(asock<0)return 1;
    int one=1;setsockopt(asock,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));setsockopt(asock,SOL_SOCKET,SO_REUSEPORT,&one,sizeof(one));
    int rb=SOCK_BUF,wb=SOCK_BUF;setsockopt(asock,SOL_SOCKET,SO_RCVBUF,&rb,sizeof(rb));setsockopt(asock,SOL_SOCKET,SO_SNDBUF,&wb,sizeof(wb));
    struct sockaddr_in addr={.sin_family=AF_INET,.sin_addr.s_addr=INADDR_ANY,.sin_port=htons(ALT_PORT)};
    if(bind(asock,(struct sockaddr*)&addr,sizeof(addr))<0){perror("bind slowdns-alt");close(asock);return 1;}
    fcntl(asock,F_SETFL,fcntl(asock,F_GETFL)|O_NONBLOCK);
    pthread_t pool[POOL_SIZE];int i;
    for(i=0;i<POOL_SIZE;i++){pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setdetachstate(&a,PTHREAD_CREATE_DETACHED);pthread_create(&pool[i],&a,worker,NULL);pthread_attr_destroy(&a);}
    fprintf(stderr,"[ELITE-X] SlowDNS Alt v5.0 port %d (mDNS bypass)\n",ALT_PORT);
    while(running){pkt_t pkt;socklen_t sl=sizeof(pkt.src);
        int n=recvfrom(asock,pkt.buf,BUF_SIZE,0,(struct sockaddr*)&pkt.src,&sl);
        if(n<=0){usleep(100);continue;}pkt.len=n;qpush(&pkt);}
    close(asock);return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto -pthread \
        -o /usr/local/bin/elite-x-slowdns-alt /tmp/slowdns_alt.c 2>/dev/null
    rm -f /tmp/slowdns_alt.c
    if [ -f /usr/local/bin/elite-x-slowdns-alt ]; then
        chmod +x /usr/local/bin/elite-x-slowdns-alt
        cat > /etc/systemd/system/elite-x-slowdns-alt.service <<EOF
[Unit]
Description=ELITE-X SlowDNS Alt Relay v5.0 (port 5353 mDNS)
After=dnstt-elite-x.service
Wants=dnstt-elite-x.service
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-slowdns-alt
Restart=always
RestartSec=3
LimitNOFILE=524288
Nice=-12
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C SlowDNS Alt compiled (port 5353, 32 workers)${NC}"
    else
        echo -e "${RED}❌ SlowDNS Alt compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: SOCKS5 SERVER (RFC 1928, Thread-per-conn)
# ═══════════════════════════════════════════════════════════
create_c_socks5() {
    echo -e "${YELLOW}📝 Compiling C SOCKS5 Server v5.0 (port 1080)...${NC}"
    cat > /tmp/socks5_server.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>

#define SOCKS5_PORT 1080
#define BACKLOG     4096
#define BUF_SIZE    16384
#define SOCK_BUF    (4*1024*1024)

static volatile int running=1;
static int lsock=-1;
void sh(int s){running=0;if(lsock>=0)close(lsock);}

static void set_opts(int fd){
    int one=1,sb=SOCK_BUF;
    setsockopt(fd,SOL_SOCKET,SO_RCVBUF,&sb,sizeof(sb));
    setsockopt(fd,SOL_SOCKET,SO_SNDBUF,&sb,sizeof(sb));
    setsockopt(fd,IPPROTO_TCP,TCP_NODELAY,&one,sizeof(one));
}
static ssize_t recv_all(int fd,void *b,size_t n){
    size_t r=0;while(r<n){ssize_t x=recv(fd,(char*)b+r,n-r,0);if(x<=0)return x;r+=x;}return r;
}
static void relay(int c,int r){
    fd_set fds;char buf[BUF_SIZE];struct timeval tv;
    while(1){FD_ZERO(&fds);FD_SET(c,&fds);FD_SET(r,&fds);int mx=(c>r?c:r)+1;tv.tv_sec=300;tv.tv_usec=0;
        if(select(mx,&fds,NULL,NULL,&tv)<=0)break;
        if(FD_ISSET(c,&fds)){int n=recv(c,buf,BUF_SIZE,0);if(n<=0)break;if(send(r,buf,n,MSG_NOSIGNAL)<=0)break;}
        if(FD_ISSET(r,&fds)){int n=recv(r,buf,BUF_SIZE,0);if(n<=0)break;if(send(c,buf,n,MSG_NOSIGNAL)<=0)break;}}
}
static void *handle(void *arg){
    int cfd=*(int*)arg;free(arg);set_opts(cfd);
    unsigned char buf[512];
    if(recv_all(cfd,buf,2)!=2)goto done;
    if(buf[0]!=0x05)goto done;
    int nm=buf[1];if(recv_all(cfd,buf,nm)!=nm)goto done;
    unsigned char rep[2]={0x05,0x00};send(cfd,rep,2,MSG_NOSIGNAL);
    if(recv_all(cfd,buf,4)!=4)goto done;
    if(buf[0]!=0x05||buf[1]!=0x01)goto done;
    int atyp=buf[3];char host[256];int port;
    if(atyp==0x01){unsigned char ip[4];if(recv_all(cfd,ip,4)!=4)goto done;snprintf(host,sizeof(host),"%d.%d.%d.%d",ip[0],ip[1],ip[2],ip[3]);}
    else if(atyp==0x03){unsigned char dl;if(recv_all(cfd,&dl,1)!=1)goto done;if(recv_all(cfd,host,dl)!=dl)goto done;host[dl]=0;}
    else if(atyp==0x04){unsigned char ip6[16];if(recv_all(cfd,ip6,16)!=16)goto done;snprintf(host,sizeof(host),"%x:%x:%x:%x:%x:%x:%x:%x",(ip6[0]<<8)|ip6[1],(ip6[2]<<8)|ip6[3],(ip6[4]<<8)|ip6[5],(ip6[6]<<8)|ip6[7],(ip6[8]<<8)|ip6[9],(ip6[10]<<8)|ip6[11],(ip6[12]<<8)|ip6[13],(ip6[14]<<8)|ip6[15]);}
    else goto done;
    unsigned char pb[2];if(recv_all(cfd,pb,2)!=2)goto done;port=(pb[0]<<8)|pb[1];
    struct addrinfo hints,*res;memset(&hints,0,sizeof(hints));hints.ai_family=AF_UNSPEC;hints.ai_socktype=SOCK_STREAM;
    char ps[8];snprintf(ps,sizeof(ps),"%d",port);int rfd=-1;
    if(getaddrinfo(host,ps,&hints,&res)==0){struct addrinfo *p;for(p=res;p;p=p->ai_next){rfd=socket(p->ai_family,p->ai_socktype,p->ai_protocol);if(rfd<0)continue;set_opts(rfd);struct timeval ctv={10,0};setsockopt(rfd,SOL_SOCKET,SO_SNDTIMEO,&ctv,sizeof(ctv));if(connect(rfd,p->ai_addr,p->ai_addrlen)==0)break;close(rfd);rfd=-1;}freeaddrinfo(res);}
    if(rfd<0){unsigned char f[10]={0x05,0x05,0x00,0x01,0,0,0,0,0,0};send(cfd,f,10,MSG_NOSIGNAL);goto done;}
    unsigned char ok[10]={0x05,0x00,0x00,0x01,127,0,0,1,(SOCKS5_PORT>>8)&0xFF,SOCKS5_PORT&0xFF};
    send(cfd,ok,10,MSG_NOSIGNAL);relay(cfd,rfd);close(rfd);
done:close(cfd);return NULL;
}

int main(void){
    signal(SIGTERM,sh);signal(SIGINT,sh);signal(SIGPIPE,SIG_IGN);
    struct rlimit rl={1048576,1048576};setrlimit(RLIMIT_NOFILE,&rl);
    lsock=socket(AF_INET,SOCK_STREAM,0);if(lsock<0)return 1;
    int one=1;setsockopt(lsock,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));setsockopt(lsock,SOL_SOCKET,SO_REUSEPORT,&one,sizeof(one));
    set_opts(lsock);
    struct sockaddr_in addr={.sin_family=AF_INET,.sin_addr.s_addr=INADDR_ANY,.sin_port=htons(SOCKS5_PORT)};
    if(bind(lsock,(struct sockaddr*)&addr,sizeof(addr))<0){perror("bind socks5");close(lsock);return 1;}
    if(listen(lsock,BACKLOG)<0){perror("listen");close(lsock);return 1;}
    fprintf(stderr,"[ELITE-X] SOCKS5 Server v5.0 port %d\n",SOCKS5_PORT);
    while(running){
        struct sockaddr_in ca;socklen_t cl=sizeof(ca);
        int cfd=accept(lsock,(struct sockaddr*)&ca,&cl);
        if(cfd<0){if(errno==EINTR||!running)break;continue;}
        int *p=malloc(sizeof(int));if(!p){close(cfd);continue;}*p=cfd;
        pthread_t t;pthread_attr_t a;pthread_attr_init(&a);pthread_attr_setdetachstate(&a,PTHREAD_CREATE_DETACHED);pthread_attr_setstacksize(&a,128*1024);
        if(pthread_create(&t,&a,handle,p)!=0){free(p);close(cfd);}pthread_attr_destroy(&a);}
    close(lsock);return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto -pthread \
        -o /usr/local/bin/elite-x-socks5 /tmp/socks5_server.c 2>/dev/null
    rm -f /tmp/socks5_server.c
    if [ -f /usr/local/bin/elite-x-socks5 ]; then
        chmod +x /usr/local/bin/elite-x-socks5
        cat > /etc/systemd/system/elite-x-socks5.service <<EOF
[Unit]
Description=ELITE-X C SOCKS5 Server v5.0 (port 1080)
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-socks5
Restart=always
RestartSec=3
LimitNOFILE=1048576
Nice=-12
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C SOCKS5 Server compiled (port 1080, RFC 1928)${NC}"
    else
        echo -e "${RED}❌ SOCKS5 Server compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: SPEED BOOSTER
# ═══════════════════════════════════════════════════════════
create_c_speed_booster() {
    echo -e "${YELLOW}📝 Compiling C Speed Booster v5.0...${NC}"
    cat > /tmp/speed_booster.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <dirent.h>
static volatile int running=1;
void sig(int s){running=0;}
static void wf(const char *p,const char *v){FILE *f=fopen(p,"w");if(f){fputs(v,f);fclose(f);}}
static void sc(const char *k,const char *v){char path[512];snprintf(path,sizeof(path),"/proc/sys/%s",k);char *p=path+10;while(*p){if(*p=='.')(*p)='/';p++;}wf(path,v);}
static void boost_net(void){
    sc("net.core.default_qdisc","fq\n");sc("net.ipv4.tcp_congestion_control","bbr\n");
    sc("net.core.rmem_max","268435456\n");sc("net.core.wmem_max","268435456\n");
    sc("net.core.rmem_default","524288\n");sc("net.core.wmem_default","524288\n");
    sc("net.ipv4.tcp_rmem","4096 262144 268435456\n");sc("net.ipv4.tcp_wmem","4096 131072 268435456\n");
    sc("net.ipv4.udp_rmem_min","65536\n");sc("net.ipv4.udp_wmem_min","65536\n");
    sc("net.ipv4.udp_mem","102400 873800 33554432\n");
    sc("net.ipv4.tcp_fastopen","3\n");sc("net.ipv4.tcp_slow_start_after_idle","0\n");
    sc("net.ipv4.tcp_sack","1\n");sc("net.ipv4.tcp_window_scaling","1\n");
    sc("net.ipv4.tcp_mtu_probing","1\n");sc("net.ipv4.tcp_notsent_lowat","16384\n");
    sc("net.ipv4.tcp_max_syn_backlog","65536\n");sc("net.core.somaxconn","65536\n");
    sc("net.core.netdev_max_backlog","50000\n");sc("net.ipv4.tcp_tw_reuse","1\n");
    sc("net.ipv4.tcp_fin_timeout","5\n");sc("net.ipv4.tcp_keepalive_time","30\n");
    sc("net.core.netdev_budget","1000\n");sc("net.core.busy_read","50\n");sc("net.core.busy_poll","50\n");
    sc("vm.swappiness","5\n");sc("vm.vfs_cache_pressure","50\n");sc("vm.dirty_ratio","10\n");sc("vm.dirty_background_ratio","3\n");
    DIR *d=opendir("/sys/class/net");if(d){struct dirent *e;while((e=readdir(d))){if(e->d_name[0]=='.'||strcmp(e->d_name,"lo")==0)continue;char p[512];snprintf(p,sizeof(p),"/sys/class/net/%s/queues/rx-0/rps_cpus",e->d_name);wf(p,"ffffffff\n");snprintf(p,sizeof(p),"/sys/class/net/%s/queues/tx-0/xps_cpus",e->d_name);wf(p,"ffffffff\n");}closedir(d);}
}
static void boost_cpu(void){system("for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor;do echo performance>\"$f\" 2>/dev/null;done");}
int main(void){signal(SIGTERM,sig);signal(SIGINT,sig);boost_net();boost_cpu();
    while(running){int i;for(i=0;i<600&&running;i++)sleep(1);if(running){boost_net();boost_cpu();}}return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto \
        -o /usr/local/bin/elite-x-speedbooster /tmp/speed_booster.c 2>/dev/null
    rm -f /tmp/speed_booster.c
    if [ -f /usr/local/bin/elite-x-speedbooster ]; then
        chmod +x /usr/local/bin/elite-x-speedbooster
        cat > /etc/systemd/system/elite-x-speedbooster.service <<EOF
[Unit]
Description=ELITE-X C Speed Booster v5.0 (20Mbps+)
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-speedbooster
Restart=always
RestartSec=5
Nice=-15
IOSchedulingClass=realtime
IOSchedulingPriority=0
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Speed Booster v5.0 compiled${NC}"
    else
        echo -e "${RED}❌ Speed Booster compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: BANDWIDTH MONITOR
# ═══════════════════════════════════════════════════════════
create_c_bandwidth_monitor() {
    echo -e "${YELLOW}📝 Compiling C Bandwidth Monitor...${NC}"
    cat > /tmp/bw_monitor.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <signal.h>
#include <pwd.h>
#include <ctype.h>
#define USER_DB    "/etc/elite-x/users"
#define BW_DIR     "/etc/elite-x/bandwidth"
#define PID_DIR    "/etc/elite-x/bandwidth/pidtrack"
#define BANNED_DIR "/etc/elite-x/banned"
#define SCAN_INT   20
#define GB_BYTES   1073741824.0
static volatile int running=1;
void signal_handler(int s){running=0;}
static long long get_io(int pid){char p[256];snprintf(p,sizeof(p),"/proc/%d/io",pid);FILE *f=fopen(p,"r");if(!f)return 0;long long r=0,w=0;char l[256];while(fgets(l,sizeof(l),f)){if(strncmp(l,"rchar:",6)==0)sscanf(l+7,"%lld",&r);else if(strncmp(l,"wchar:",6)==0)sscanf(l+7,"%lld",&w);}fclose(f);return r+w;}
static int is_num(const char *s){for(;*s;s++)if(!isdigit(*s))return 0;return 1;}
static int get_pids(const char *u,int *pids,int mx){int c=0;DIR *d=opendir("/proc");if(!d)return 0;struct dirent *e;while((e=readdir(d))&&c<mx){if(!is_num(e->d_name))continue;int pid=atoi(e->d_name);char cp[256];snprintf(cp,sizeof(cp),"/proc/%d/comm",pid);FILE *f=fopen(cp,"r");if(!f)continue;char cm[64]={0};fgets(cm,sizeof(cm),f);fclose(f);cm[strcspn(cm,"\n")]=0;if(strcmp(cm,"sshd")!=0)continue;char sp[256];snprintf(sp,sizeof(sp),"/proc/%d/status",pid);FILE *sf=fopen(sp,"r");if(!sf)continue;char ln[256],uid[32]={0};while(fgets(ln,sizeof(ln),sf))if(strncmp(ln,"Uid:",4)==0){sscanf(ln,"%*s %s",uid);break;}fclose(sf);struct passwd *pw=getpwuid(atoi(uid));if(!pw||strcmp(pw->pw_name,u)!=0)continue;char st[256];snprintf(st,sizeof(st),"/proc/%d/stat",pid);FILE *stf=fopen(st,"r");if(!stf)continue;int pp;char sb[1024];fgets(sb,sizeof(sb),stf);sscanf(sb,"%*d %*s %*c %d",&pp);fclose(stf);if(pp!=1)pids[c++]=pid;}closedir(d);return c;}
int main(void){signal(SIGTERM,signal_handler);signal(SIGINT,signal_handler);
    mkdir(BW_DIR,0755);mkdir(PID_DIR,0755);mkdir(BANNED_DIR,0755);
    while(running){DIR *ud=opendir(USER_DB);if(!ud){sleep(SCAN_INT);continue;}struct dirent *ue;
        while((ue=readdir(ud))){if(ue->d_name[0]=='.')continue;
            char uf[512];snprintf(uf,sizeof(uf),"%s/%s",USER_DB,ue->d_name);FILE *f=fopen(uf,"r");if(!f)continue;
            double bg=0;char l[256];while(fgets(l,sizeof(l),f))if(strncmp(l,"Bandwidth_GB:",13)==0)sscanf(l+13,"%lf",&bg);fclose(f);
            if(bg<=0)continue;
            int pids[100];int pc=get_pids(ue->d_name,pids,100);
            if(pc==0){char cmd[512];snprintf(cmd,sizeof(cmd),"rm -f %s/%s__*.last 2>/dev/null",PID_DIR,ue->d_name);system(cmd);continue;}
            long long delta=0;int i;
            for(i=0;i<pc;i++){long long cur=get_io(pids[i]);char pf[512];snprintf(pf,sizeof(pf),"%s/%s__%d.last",PID_DIR,ue->d_name,pids[i]);
                FILE *pf2=fopen(pf,"r");if(pf2){long long prev;fscanf(pf2,"%lld",&prev);fclose(pf2);delta+=(cur>=prev)?(cur-prev):cur;}
                pf2=fopen(pf,"w");if(pf2){fprintf(pf2,"%lld\n",cur);fclose(pf2);}}
            char uf2[512];snprintf(uf2,sizeof(uf2),"%s/%s.usage",BW_DIR,ue->d_name);
            long long acc=0;FILE *af=fopen(uf2,"r");if(af){fscanf(af,"%lld",&acc);fclose(af);}
            long long nt=acc+delta;af=fopen(uf2,"w");if(af){fprintf(af,"%lld\n",nt);fclose(af);}
            if(nt>=(long long)(bg*GB_BYTES)){char cmd[1024];snprintf(cmd,sizeof(cmd),"passwd -S %s 2>/dev/null|grep -q 'L'||(usermod -L %s 2>/dev/null&&killall -u %s -9 2>/dev/null&&echo '%s BLOCKED:BW'>%s/%s)",ue->d_name,ue->d_name,ue->d_name,ue->d_name,BANNED_DIR,ue->d_name);system(cmd);}}
        closedir(ud);sleep(SCAN_INT);}return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto \
        -o /usr/local/bin/elite-x-bandwidth-c /tmp/bw_monitor.c 2>/dev/null
    rm -f /tmp/bw_monitor.c
    if [ -f /usr/local/bin/elite-x-bandwidth-c ]; then
        chmod +x /usr/local/bin/elite-x-bandwidth-c
        cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X C Bandwidth Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-bandwidth-c
Restart=always
RestartSec=10
Nice=10
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Bandwidth Monitor compiled${NC}"
    else
        echo -e "${RED}❌ C Bandwidth Monitor compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: CONNECTION MONITOR (Accurate /proc count → CONN_DB)
# ═══════════════════════════════════════════════════════════
create_c_connection_monitor() {
    echo -e "${YELLOW}📝 Compiling C Connection Monitor v5.0 (accurate)...${NC}"
    cat > /tmp/conn_monitor.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <signal.h>
#include <pwd.h>
#include <ctype.h>
#include <sys/stat.h>
#define USER_DB      "/etc/elite-x/users"
#define CONN_DB      "/etc/elite-x/connections"
#define BANNED_DIR   "/etc/elite-x/banned"
#define DELETED_DIR  "/etc/elite-x/deleted"
#define BW_DIR       "/etc/elite-x/bandwidth"
#define PID_DIR      "/etc/elite-x/bandwidth/pidtrack"
#define AUTOBAN_FLAG "/etc/elite-x/autoban_enabled"
#define SCAN_INT     5
static volatile int running=1;
void signal_handler(int s){running=0;}
static int is_num(const char *s){for(;*s;s++)if(!isdigit(*s))return 0;return 1;}
static int get_conn(const char *u){
    int cnt=0;DIR *d=opendir("/proc");if(!d)return 0;struct dirent *e;
    while((e=readdir(d))){if(!is_num(e->d_name))continue;int pid=atoi(e->d_name);
        char cp[256];snprintf(cp,sizeof(cp),"/proc/%d/comm",pid);FILE *f=fopen(cp,"r");if(!f)continue;
        char cm[64]={0};fgets(cm,sizeof(cm),f);fclose(f);cm[strcspn(cm,"\n")]=0;
        if(strcmp(cm,"sshd")!=0)continue;
        char sp[256];snprintf(sp,sizeof(sp),"/proc/%d/status",pid);FILE *sf=fopen(sp,"r");if(!sf)continue;
        char ln[256],uid[32]={0};while(fgets(ln,sizeof(ln),sf))if(strncmp(ln,"Uid:",4)==0){sscanf(ln,"%*s %s",uid);break;}fclose(sf);
        if(!strlen(uid))continue;struct passwd *pw=getpwuid(atoi(uid));if(!pw||strcmp(pw->pw_name,u)!=0)continue;
        char st[256];snprintf(st,sizeof(st),"/proc/%d/stat",pid);FILE *stf=fopen(st,"r");if(!stf)continue;
        int pp=0;char sb[1024];fgets(sb,sizeof(sb),stf);sscanf(sb,"%*d %*s %*c %d",&pp);fclose(stf);
        if(pp!=1)cnt++;}
    closedir(d);return cnt;}
static void del_expired(const char *u,const char *r){
    char cmd[2048];snprintf(cmd,sizeof(cmd),
        "cp %s/%s %s/%s_$(date +%%Y%%m%%d_%%H%%M%%S) 2>/dev/null;"
        "pkill -u %s 2>/dev/null;killall -u %s -9 2>/dev/null;userdel -r %s 2>/dev/null;"
        "rm -f %s/%s %s/%s %s/%s %s/%s %s/%s.usage;rm -f %s/%s__*.last 2>/dev/null;"
        "logger -t elite-x 'Auto-deleted: %s (%s)'",
        USER_DB,u,DELETED_DIR,u,u,u,u,USER_DB,u,"/etc/elite-x/data_usage",u,
        CONN_DB,u,BANNED_DIR,u,BW_DIR,u,PID_DIR,u,u,r);
    system(cmd);}
int main(void){signal(SIGTERM,signal_handler);signal(SIGINT,signal_handler);
    mkdir(CONN_DB,0755);mkdir(BANNED_DIR,0755);mkdir(DELETED_DIR,0755);mkdir(BW_DIR,0755);mkdir(PID_DIR,0755);
    while(running){time_t now=time(NULL);DIR *ud=opendir(USER_DB);if(!ud){sleep(SCAN_INT);continue;}struct dirent *ue;
        while((ue=readdir(ud))){if(ue->d_name[0]=='.')continue;
            struct passwd *pw=getpwnam(ue->d_name);if(!pw){char rc[512];snprintf(rc,sizeof(rc),"rm -f %s/%s",USER_DB,ue->d_name);system(rc);continue;}
            char uf[512];snprintf(uf,sizeof(uf),"%s/%s",USER_DB,ue->d_name);FILE *f=fopen(uf,"r");if(!f)continue;
            char exp[32]={0};int cl=1;char l[256];
            while(fgets(l,sizeof(l),f)){if(strncmp(l,"Expire:",7)==0)sscanf(l+8,"%s",exp);else if(strncmp(l,"Conn_Limit:",11)==0)sscanf(l+12,"%d",&cl);}fclose(f);
            if(strlen(exp)>0){struct tm tm={0};if(strptime(exp,"%Y-%m-%d",&tm)){time_t et=mktime(&tm);if(now>et+86400){char r[256];snprintf(r,sizeof(r),"Expired on %s",exp);del_expired(ue->d_name,r);continue;}}}
            int cc=get_conn(ue->d_name);
            char cf[512];snprintf(cf,sizeof(cf),"%s/%s",CONN_DB,ue->d_name);FILE *cfile=fopen(cf,"w");if(cfile){fprintf(cfile,"%d\n",cc);fclose(cfile);}
            int ab=0;FILE *abf=fopen(AUTOBAN_FLAG,"r");if(abf){fscanf(abf,"%d",&ab);fclose(abf);}
            if(cc>cl&&ab==1){char cmd[1024];snprintf(cmd,sizeof(cmd),"passwd -S %s 2>/dev/null|grep -q 'L'||(usermod -L %s 2>/dev/null&&pkill -u %s 2>/dev/null&&echo 'BLOCKED:%d/%d'>%s/%s)",ue->d_name,ue->d_name,ue->d_name,cc,cl,BANNED_DIR,ue->d_name);system(cmd);}}
        closedir(ud);sleep(SCAN_INT);}return 0;}
CEOF
    gcc -O3 -march=native -mtune=native -flto \
        -o /usr/local/bin/elite-x-connmon-c /tmp/conn_monitor.c 2>/dev/null
    rm -f /tmp/conn_monitor.c
    if [ -f /usr/local/bin/elite-x-connmon-c ]; then
        chmod +x /usr/local/bin/elite-x-connmon-c
        cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X C Connection Monitor v5.0 (accurate count)
After=network.target ssh.service
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-connmon-c
Restart=always
RestartSec=5
CPUQuota=20%
MemoryMax=50M
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Connection Monitor compiled (accurate /proc count)${NC}"
    else
        echo -e "${RED}❌ C Connection Monitor compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: NETWORK BOOSTER
# ═══════════════════════════════════════════════════════════
create_c_network_booster() {
    echo -e "${YELLOW}📝 Compiling C Network Booster...${NC}"
    cat > /tmp/net_booster.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running=1;
void sh(int s){running=0;}
static void apply(void){
    system("sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1");
    system("sysctl -w net.core.rmem_max=268435456 >/dev/null 2>&1");
    system("sysctl -w net.core.wmem_max=268435456 >/dev/null 2>&1");
    system("sysctl -w 'net.ipv4.tcp_rmem=4096 262144 268435456' >/dev/null 2>&1");
    system("sysctl -w 'net.ipv4.tcp_wmem=4096 131072 268435456' >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_tw_reuse=1 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_fin_timeout=5 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1");
    system("sysctl -w net.core.somaxconn=65536 >/dev/null 2>&1");
    system("sysctl -w net.core.netdev_max_backlog=50000 >/dev/null 2>&1");}
int main(void){signal(SIGTERM,sh);signal(SIGINT,sh);apply();
    while(running){int i;for(i=0;i<3600&&running;i++)sleep(1);if(running)apply();}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-netbooster /tmp/net_booster.c 2>/dev/null
    rm -f /tmp/net_booster.c
    if [ -f /usr/local/bin/elite-x-netbooster ]; then
        chmod +x /usr/local/bin/elite-x-netbooster
        cat > /etc/systemd/system/elite-x-netbooster.service <<EOF
[Unit]
Description=ELITE-X C Network Booster
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-netbooster
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Network Booster compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: DNS CACHE OPTIMIZER
# ═══════════════════════════════════════════════════════════
create_c_dns_cache() {
    echo -e "${YELLOW}📝 Compiling C DNS Cache Optimizer...${NC}"
    cat > /tmp/dns_cache.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running=1;
void sh(int s){running=0;}
static void flush(void){system("systemctl restart systemd-resolved 2>/dev/null||true");system("resolvectl flush-caches 2>/dev/null||true");system("killall -HUP dnsmasq 2>/dev/null||true");}
static void opt_resolv(void){FILE *f=fopen("/etc/resolv.conf","w");if(f){fprintf(f,"nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 9.9.9.9\noptions timeout:1 attempts:3 rotate\noptions ndots:0\n");fclose(f);}}
int main(void){signal(SIGTERM,sh);signal(SIGINT,sh);opt_resolv();while(running){flush();int i;for(i=0;i<1800&&running;i++)sleep(1);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-dnscache /tmp/dns_cache.c 2>/dev/null
    rm -f /tmp/dns_cache.c
    if [ -f /usr/local/bin/elite-x-dnscache ]; then
        chmod +x /usr/local/bin/elite-x-dnscache
        cat > /etc/systemd/system/elite-x-dnscache.service <<EOF
[Unit]
Description=ELITE-X C DNS Cache Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-dnscache
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C DNS Cache Optimizer compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: RAM CLEANER
# ═══════════════════════════════════════════════════════════
create_c_ram_cleaner() {
    echo -e "${YELLOW}📝 Compiling C RAM Cache Cleaner...${NC}"
    cat > /tmp/ram_cleaner.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running=1;
void sh(int s){running=0;}
static void clean(void){
    system("sync&&echo 3>/proc/sys/vm/drop_caches 2>/dev/null");
    system("echo 1>/proc/sys/vm/compact_memory 2>/dev/null");
    system("sysctl -w vm.swappiness=5 >/dev/null 2>&1");
    system("sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1");
    system("sysctl -w vm.dirty_ratio=10 >/dev/null 2>&1");
    system("sysctl -w vm.dirty_background_ratio=3 >/dev/null 2>&1");
    system("sysctl -w vm.min_free_kbytes=65536 >/dev/null 2>&1");}
int main(void){signal(SIGTERM,sh);signal(SIGINT,sh);while(running){clean();int i;for(i=0;i<900&&running;i++)sleep(1);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-ramcleaner /tmp/ram_cleaner.c 2>/dev/null
    rm -f /tmp/ram_cleaner.c
    if [ -f /usr/local/bin/elite-x-ramcleaner ]; then
        chmod +x /usr/local/bin/elite-x-ramcleaner
        cat > /etc/systemd/system/elite-x-ramcleaner.service <<EOF
[Unit]
Description=ELITE-X C RAM Cache Cleaner
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-ramcleaner
Restart=always
RestartSec=30
CPUQuota=10%
MemoryMax=30M
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C RAM Cleaner compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: IRQ AFFINITY OPTIMIZER
# ═══════════════════════════════════════════════════════════
create_c_irq_optimizer() {
    echo -e "${YELLOW}📝 Compiling C IRQ Affinity Optimizer...${NC}"
    cat > /tmp/irq_optimizer.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <signal.h>
static volatile int running=1;
void sh(int s){running=0;}
static void wf(const char *p,const char *v){FILE *f=fopen(p,"w");if(f){fputs(v,f);fclose(f);}}
static void opt(void){
    DIR *d=opendir("/proc/irq");if(!d)return;struct dirent *e;
    while((e=readdir(d))){if(e->d_name[0]=='.')continue;char p[512];snprintf(p,sizeof(p),"/proc/irq/%s/smp_affinity",e->d_name);wf(p,"ffffffff\n");}closedir(d);
    DIR *nd=opendir("/sys/class/net");if(!nd)return;
    while((e=readdir(nd))){if(e->d_name[0]=='.'||strcmp(e->d_name,"lo")==0)continue;char p[512];
        snprintf(p,sizeof(p),"/sys/class/net/%s/queues/rx-0/rps_cpus",e->d_name);wf(p,"ffffffff\n");
        snprintf(p,sizeof(p),"/sys/class/net/%s/queues/tx-0/xps_cpus",e->d_name);wf(p,"ffffffff\n");
        snprintf(p,sizeof(p),"/sys/class/net/%s/queues/rx-0/rps_flow_cnt",e->d_name);wf(p,"32768\n");}closedir(nd);
    wf("/proc/sys/net/core/rps_sock_flow_entries","32768\n");}
int main(void){signal(SIGTERM,sh);signal(SIGINT,sh);while(running){opt();int i;for(i=0;i<600&&running;i++)sleep(1);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-irqopt /tmp/irq_optimizer.c 2>/dev/null
    rm -f /tmp/irq_optimizer.c
    if [ -f /usr/local/bin/elite-x-irqopt ]; then
        chmod +x /usr/local/bin/elite-x-irqopt
        cat > /etc/systemd/system/elite-x-irqopt.service <<EOF
[Unit]
Description=ELITE-X C IRQ Affinity Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-irqopt
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C IRQ Optimizer compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: DATA USAGE MONITOR
# ═══════════════════════════════════════════════════════════
create_c_data_usage() {
    echo -e "${YELLOW}📝 Compiling C Data Usage Monitor...${NC}"
    cat > /tmp/data_usage.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <signal.h>
static volatile int running=1;
void sh(int s){running=0;}
int main(void){signal(SIGTERM,sh);signal(SIGINT,sh);
    while(running){DIR *ud=opendir("/etc/elite-x/users");if(!ud){sleep(30);continue;}
        char mo[8];time_t now=time(NULL);strftime(mo,sizeof(mo),"%Y-%m",localtime(&now));
        struct dirent *e;while((e=readdir(ud))){if(e->d_name[0]=='.')continue;
            char bf[512];snprintf(bf,sizeof(bf),"/etc/elite-x/bandwidth/%s.usage",e->d_name);
            long long b=0;FILE *f=fopen(bf,"r");if(f){fscanf(f,"%lld",&b);fclose(f);}
            double gb=b/1073741824.0;char uf[512];snprintf(uf,sizeof(uf),"/etc/elite-x/data_usage/%s",e->d_name);
            f=fopen(uf,"w");if(f){time_t t=time(NULL);char *ts=ctime(&t);ts[strcspn(ts,"\n")]=0;fprintf(f,"month: %s\ntotal_gb: %.2f\nlast_updated: %s\n",mo,gb,ts);fclose(f);}}
        closedir(ud);sleep(30);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-datausage-c /tmp/data_usage.c 2>/dev/null
    rm -f /tmp/data_usage.c
    if [ -f /usr/local/bin/elite-x-datausage-c ]; then
        chmod +x /usr/local/bin/elite-x-datausage-c
        cat > /etc/systemd/system/elite-x-datausage.service <<EOF
[Unit]
Description=ELITE-X C Data Usage Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-datausage-c
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Data Usage Monitor compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: LOG CLEANER
# ═══════════════════════════════════════════════════════════
create_c_log_cleaner() {
    echo -e "${YELLOW}📝 Compiling C Log Cleaner...${NC}"
    cat > /tmp/log_cleaner.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running=1;
void sh(int s){running=0;}
static void clean(void){
    system("find /var/log -type f -name '*.log' -size +50M -exec truncate -s 0 {} \\; 2>/dev/null");
    system("journalctl --vacuum-size=50M 2>/dev/null");
    system("truncate -s 0 /var/log/syslog 2>/dev/null");
    system("truncate -s 0 /var/log/auth.log 2>/dev/null");
    system("find /var/log -name '*.gz' -mtime +3 -delete 2>/dev/null");
    system("find /var/log -name '*.1' -delete 2>/dev/null");}
int main(void){signal(SIGTERM,sh);signal(SIGINT,sh);while(running){clean();int i;for(i=0;i<3600&&running;i++)sleep(1);}return 0;}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-logcleaner /tmp/log_cleaner.c 2>/dev/null
    rm -f /tmp/log_cleaner.c
    if [ -f /usr/local/bin/elite-x-logcleaner ]; then
        chmod +x /usr/local/bin/elite-x-logcleaner
        cat > /etc/systemd/system/elite-x-logcleaner.service <<EOF
[Unit]
Description=ELITE-X C Log Cleaner
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-logcleaner
Restart=always
RestartSec=30
CPUQuota=10%
MemoryMax=20M
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Log Cleaner compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# USER MANAGEMENT SCRIPT v5.0
# ═══════════════════════════════════════════════════════════
create_user_script() {
    cat > /usr/local/bin/elite-x-user <<'USEREOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';ORANGE='\033[0;33m';MAGENTA='\033[0;95m'
PURPLE='\033[0;35m';GRAY='\033[0;90m';NC='\033[0m'
UD="/etc/elite-x/users"; DD="/etc/elite-x/deleted"; BD="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"; BW_DIR="/etc/elite-x/bandwidth"; PID_DIR="$BW_DIR/pidtrack"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
mkdir -p "$UD" "$DD" "$BD" "$CONN_DB" "$BW_DIR" "$PID_DIR"

get_conn() {
    local u="$1"
    if [ -f "$CONN_DB/$u" ]; then
        local c=$(cat "$CONN_DB/$u" 2>/dev/null | tr -d '[:space:]')
        [ -n "$c" ] && echo "$c" && return
    fi
    echo 0
}
get_bw() { local u="$1"; [ -f "$BW_DIR/${u}.usage" ] && echo "scale=2; $(cat "$BW_DIR/${u}.usage") / 1073741824" | bc 2>/dev/null || echo "0.00"; }

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}        CREATE SSH + SLOWDNS USER v5.0         ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    if id "$username" &>/dev/null; then echo -e "${RED}User already exists!${NC}"; return; fi
    read -p "$(echo -e $GREEN"Password [auto]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10) && echo -e "${GREEN}🔑 Generated: ${YELLOW}$password${NC}"
    read -p "$(echo -e $GREEN"Expire days [30]: "$NC)" days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; return; }
    read -p "$(echo -e $GREEN"Conn limit [1]: "$NC)" cl; cl=${cl:-1}
    [[ ! "$cl" =~ ^[0-9]+$ ]] && cl=1
    read -p "$(echo -e $GREEN"Bandwidth GB (0=unlimited) [0]: "$NC)" bw; bw=${bw:-0}
    [[ ! "$bw" =~ ^[0-9]+\.?[0-9]*$ ]] && bw=0
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    local exp=$(date -d "+${days} days" +%Y-%m-%d)
    cat > "$UD/$username" <<EOF
Username: $username
Password: $password
Expire: $exp
Conn_Limit: $cl
Bandwidth_GB: $bw
Created: $(date +%Y-%m-%d)
EOF
    echo 0 > "$CONN_DB/$username"
    /usr/local/bin/elite-x-force-user-message "$username" 2>/dev/null
    local IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "SERVER_IP")
    local NS=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "ns.domain.com")
    local PK=$(cat /etc/elite-x/public_key 2>/dev/null || echo "PUBKEY")
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}        ✅ USER CREATED - ELITE-X v5.0          ${GREEN}║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  User    : ${CYAN}$username${NC}"
    echo -e "${GREEN}║${WHITE}  Pass    : ${CYAN}$password${NC}"
    echo -e "${GREEN}║${WHITE}  Expire  : ${YELLOW}$exp${NC}"
    echo -e "${GREEN}║${WHITE}  Conn    : ${CYAN}$cl${NC}"
    echo -e "${GREEN}║${WHITE}  BW      : ${CYAN}$([ "$bw" = "0" ] && echo "Unlimited" || echo "${bw} GB")${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  📡 SLOWDNS:${NC}"
    echo -e "${GREEN}║${WHITE}  NS    : ${CYAN}$NS${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY: ${CYAN}${PK:0:32}...${NC}"
    echo -e "${GREEN}║${WHITE}  PORTS : ${CYAN}53 | 5301 | 5302 | 5353${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  🧦 SOCKS5: ${CYAN}$IP:1080${WHITE} (no auth)${NC}"
    echo -e "${GREEN}║${YELLOW}  🔄 HTTP  : ${CYAN}$IP:3128${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${PURPLE}╔═════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}              USER LIST - ELITE-X v5.0                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════╦═════════════╦═══════════╦════════╦═══════╦═══════╣${NC}"
    echo -e "${PURPLE}║${WHITE} USER         ${PURPLE}║${WHITE} EXPIRE      ${PURPLE}║${WHITE} REMAIN    ${PURPLE}║${WHITE} CONN   ${PURPLE}║${WHITE} BW    ${PURPLE}║${WHITE} USAGE ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════╬═════════════╬═══════════╬════════╬═══════╬═══════╣${NC}"
    for f in "$UD"/*; do
        [ -f "$f" ] || continue
        local u=$(basename "$f")
        local exp=$(grep "Expire:" "$f"|awk '{print $2}')
        local cl=$(grep "Conn_Limit:" "$f"|awk '{print $2}')
        local bwg=$(grep "Bandwidth_GB:" "$f"|awk '{print $2}')
        local now_ts=$(date +%s); local exp_ts=$(date -d "$exp" +%s 2>/dev/null||echo 0)
        local rem_s=$((exp_ts-now_ts)); [ $rem_s -lt 0 ] && rem_s=0
        local rd=$((rem_s/86400)); local rh=$(((rem_s%86400)/3600)); local rm=$(((rem_s%3600)/60))
        local cc=$(get_conn "$u"); local usage=$(get_bw "$u")
        local bd="UNL"; [ "$bwg" != "0" ] && bd="${bwg}G"
        local st="${GREEN}ACT${NC}"; [ $rem_s -le 0 ] && st="${RED}EXP${NC}"; [ $rd -le 3 ] && [ $rem_s -gt 0 ] && st="${YELLOW}EXP!${NC}"
        printf "${PURPLE}║${CYAN}%-14s${PURPLE}║${WHITE}%-13s${PURPLE}║${GREEN}%-11s${PURPLE}║${YELLOW}%-8s${PURPLE}║${WHITE}%-7s${PURPLE}║${RED}%-7s${PURPLE}║${NC}\n" \
            " $u" " $exp" " ${rd}d${rh}h${rm}m" " $cc/$cl" " $bd" " ${usage}G"
    done
    echo -e "${PURPLE}╚══════════════╩═════════════╩═══════════╩════════╩═══════╩═══════╝${NC}"
    echo -e "${PURPLE}  Total: ${YELLOW}$(ls "$UD" 2>/dev/null|wc -l)${PURPLE} users${NC}"
}

renew_user() {
    read -p "$(echo -e $GREEN"Username to renew: "$NC)" u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }
    read -p "$(echo -e $GREEN"New expire days [30]: "$NC)" d; d=${d:-30}
    local ne=$(date -d "+${d} days" +%Y-%m-%d)
    sed -i "s/^Expire:.*/Expire: $ne/" "$UD/$u"
    usermod -U "$u" 2>/dev/null
    /usr/local/bin/elite-x-force-user-message "$u" 2>/dev/null
    echo -e "${GREEN}✅ $u renewed until $ne${NC}"
}

set_limit() { read -p "$(echo -e $GREEN"Username: "$NC)" u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }; read -p "$(echo -e $GREEN"New conn limit: "$NC)" cl; sed -i "s/^Conn_Limit:.*/Conn_Limit: $cl/" "$UD/$u"; /usr/local/bin/elite-x-force-user-message "$u" 2>/dev/null; echo -e "${GREEN}✅ Done${NC}"; }
set_bandwidth() { read -p "$(echo -e $GREEN"Username: "$NC)" u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }; read -p "$(echo -e $GREEN"BW GB (0=unlimited): "$NC)" bw; sed -i "s/^Bandwidth_GB:.*/Bandwidth_GB: $bw/" "$UD/$u"; /usr/local/bin/elite-x-force-user-message "$u" 2>/dev/null; echo -e "${GREEN}✅ Done${NC}"; }
reset_data() { read -p "$(echo -e $GREEN"Username: "$NC)" u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }; echo 0>"$BW_DIR/${u}.usage"; rm -f "$BW_DIR/pidtrack/${u}__*.last" 2>/dev/null; /usr/local/bin/elite-x-force-user-message "$u" 2>/dev/null; echo -e "${GREEN}✅ Data reset${NC}"; }
lock_user() { read -p "$(echo -e $GREEN"Username: "$NC)" u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }; usermod -L "$u" 2>/dev/null; pkill -u "$u" 2>/dev/null; echo -e "${YELLOW}🔒 $u locked${NC}"; }
unlock_user() { read -p "$(echo -e $GREEN"Username: "$NC)" u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }; usermod -U "$u" 2>/dev/null; echo -e "${GREEN}🔓 $u unlocked${NC}"; }

delete_user() {
    read -p "$(echo -e $RED"Username to delete: "$NC)" u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }
    read -p "$(echo -e $RED"Confirm delete $u? (y/N): "$NC)" yn
    [ "$yn" != "y" ] && { echo "Cancelled"; return; }
    cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    pkill -u "$u" 2>/dev/null; killall -u "$u" -9 2>/dev/null
    userdel -r "$u" 2>/dev/null
    rm -f "$UD/$u" "$BW_DIR/${u}.usage" "$CONN_DB/$u" "$BD/$u"
    rm -f "$BW_DIR/pidtrack/${u}__*.last" "/etc/elite-x/user_messages/$u" 2>/dev/null
    sed -i "/Match User $u/,/Banner/d" /etc/ssh/sshd_config.d/elite-x-users.conf 2>/dev/null
    systemctl reload sshd 2>/dev/null
    echo -e "${GREEN}✅ $u deleted${NC}"
}

show_details() {
    read -p "$(echo -e $GREEN"Username: "$NC)" u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }
    local exp=$(grep "Expire:" "$UD/$u"|awk '{print $2}'); local cl=$(grep "Conn_Limit:" "$UD/$u"|awk '{print $2}')
    local bwg=$(grep "Bandwidth_GB:" "$UD/$u"|awk '{print $2}'); local pass=$(grep "Password:" "$UD/$u"|awk '{print $2}')
    local now_ts=$(date +%s); local exp_ts=$(date -d "$exp" +%s 2>/dev/null||echo 0)
    local rem_s=$((exp_ts-now_ts)); [ $rem_s -lt 0 ] && rem_s=0
    local rd=$((rem_s/86400)); local rh=$(((rem_s%86400)/3600)); local rm=$(((rem_s%3600)/60))
    local cc=$(get_conn "$u"); local usage=$(get_bw "$u")
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}   USER DETAILS: $u${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  Password  : ${GREEN}$pass${NC}"
    echo -e "${CYAN}║${WHITE}  Expire    : ${YELLOW}$exp${NC}"
    echo -e "${CYAN}║${WHITE}  Remaining : ${GREEN}${rd}d ${rh}h ${rm}m${NC}"
    echo -e "${CYAN}║${WHITE}  Conn      : ${YELLOW}$cc / $cl${NC}"
    echo -e "${CYAN}║${WHITE}  BW Limit  : ${WHITE}$([ "$bwg" = "0" ] && echo "Unlimited" || echo "${bwg} GB")${NC}"
    echo -e "${CYAN}║${WHITE}  Usage     : ${RED}${usage} GB${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
}

case "$1" in
    add) add_user ;; list) list_users ;; details) show_details ;; renew) renew_user ;;
    setlimit) set_limit ;; setbw) set_bandwidth ;; resetdata) reset_data ;;
    lock) lock_user ;; unlock) unlock_user ;; del) delete_user ;;
    deleted) echo -e "${YELLOW}=== Deleted ===${NC}"; ls -la "$DD" 2>/dev/null||echo "None" ;;
    *) echo -e "${RED}Usage: elite-x-user {add|list|details|renew|setlimit|setbw|resetdata|lock|unlock|del|deleted}${NC}" ;;
esac
USEREOF
    chmod +x /usr/local/bin/elite-x-user
}

# ═══════════════════════════════════════════════════════════
# MAIN MENU v5.0
# ═══════════════════════════════════════════════════════════
create_main_menu() {
    cat > /usr/local/bin/elite-x <<'MENUEOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';MAGENTA='\033[0;95m'
PURPLE='\033[0;35m';GRAY='\033[0;90m';NC='\033[0m'
UD="/etc/elite-x/users"; CONN_DB="/etc/elite-x/connections"; AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"

show_dashboard() {
    clear
    local IP=$(cat /etc/elite-x/cached_ip 2>/dev/null||curl -4 -s ifconfig.me 2>/dev/null||echo "Unknown")
    local NS=$(cat /etc/elite-x/subdomain 2>/dev/null||echo "N/A")
    local LOC=$(cat /etc/elite-x/location 2>/dev/null||echo "N/A")
    local MTU=$(cat /etc/elite-x/mtu 2>/dev/null||echo "1800")
    local PK=$(cat /etc/elite-x/public_key 2>/dev/null||echo "N/A")
    local TOTAL=$(ls "$UD" 2>/dev/null|wc -l)
    local ONLINE=$(who|wc -l)
    local UPT=$(uptime -p 2>/dev/null|sed 's/up //'||echo "N/A")
    local MEM=$(free -m|awk '/^Mem:/{printf "%.0f%%",$3/$2*100}')
    local CPU=$(top -bn1|grep "Cpu(s)"|awk '{print $2+$4}'|awk '{printf "%.0f%%",$1}')

    echo -e "${PURPLE}╔═════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}   ELITE-X SLOWDNS VPN v5.0 - FALCON ULTRA MAX BOOST         ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠═════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE} 🌐 IP    :${CYAN} $IP  ${WHITE}📍 LOC:${CYAN} $LOC  ${WHITE}MTU:${CYAN} $MTU${NC}"
    echo -e "${PURPLE}║${WHITE} 📡 NS    :${GREEN} $NS${NC}"
    echo -e "${PURPLE}║${WHITE} 🔑 PUBKEY:${GRAY} ${PK:0:48}...${NC}"
    echo -e "${PURPLE}╠═════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE} 👥 Users:${YELLOW} $TOTAL ${WHITE} 🟢 Online:${GREEN} $ONLINE ${WHITE} ⏱:${CYAN} $UPT${NC}"
    echo -e "${PURPLE}║${WHITE} 🖥  CPU :${YELLOW} $CPU   ${WHITE}💾 RAM:${MAGENTA} $MEM${NC}"
    echo -e "${PURPLE}╠═════════════════════════════════════════════════════════════════════╣${NC}"

    chk() { systemctl is-active "$2" >/dev/null 2>&1 && printf "${GREEN}║  ✅ %-40s${NC}\n" "$1: Running" || printf "${RED}║  ❌ %-40s${NC}\n" "$1: Stopped"; }
    chk "DNSTT Server          " "dnstt-elite-x"
    chk "C EDNS Proxy (dns:53) " "dnstt-elite-x-proxy"
    chk "C UDP Turbo  (udp5301)" "elite-x-udp-turbo"
    chk "C UDP Boost2 (udp5302)" "elite-x-udp-boost2"
    chk "C SlowDNS Alt(udp5353)" "elite-x-slowdns-alt"
    chk "C SOCKS5     (tcp1080)" "elite-x-socks5"
    chk "3proxy HTTP  (tcp3128)" "3proxy-elite-x"
    chk "C Speed Booster       " "elite-x-speedbooster"
    chk "C Bandwidth Monitor   " "elite-x-bandwidth"
    chk "C Conn Monitor        " "elite-x-connmon"

    echo -e "${PURPLE}╠═════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${YELLOW} 📡 SLOWDNS: ${WHITE}53 | 5301 | 5302 | 5353   🧦 SOCKS5: ${CYAN}$IP:1080${NC}"
    echo -e "${PURPLE}║${YELLOW} 🔄 HTTP  : ${CYAN}$IP:3128  ${YELLOW}Auth-SOCKS5: ${CYAN}$IP:1081 (elite/elitex2025)${NC}"
    echo -e "${PURPLE}╚═════════════════════════════════════════════════════════════════════╝${NC}"
}

settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${YELLOW}               SETTINGS v5.0               ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════╣${NC}"
        local AB=$(cat "$AUTOBAN_FLAG" 2>/dev/null||echo 0)
        [ "$AB" = "1" ] && ABs="${GREEN}ON${NC}" || ABs="${RED}OFF${NC}"
        echo -e "${CYAN}║${WHITE}  [1]  Auto-Ban: $ABs${NC}"
        echo -e "${CYAN}║${WHITE}  [2]  Restart All Services${NC}"
        echo -e "${CYAN}║${WHITE}  [3]  Restart DNSTT + All UDP Relays${NC}"
        echo -e "${CYAN}║${WHITE}  [4]  Fix VPN/SSH${NC}"
        echo -e "${CYAN}║${WHITE}  [5]  Refresh All User Messages${NC}"
        echo -e "${CYAN}║${WHITE}  [6]  Test User Message${NC}"
        echo -e "${CYAN}║${WHITE}  [7]  Apply Speed Boost Now${NC}"
        echo -e "${CYAN}║${WHITE}  [8]  Restart SOCKS5 + 3proxy${NC}"
        echo -e "${CYAN}║${WHITE}  [9]  Show Active Connections${NC}"
        echo -e "${CYAN}║${WHITE}  [10] Connection Count (all users)${NC}"
        echo -e "${CYAN}║${WHITE}  [0]  Back${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        case $ch in
            1) [ "$AB" = "1" ] && echo 0>"$AUTOBAN_FLAG"||echo 1>"$AUTOBAN_FLAG" ;;
            2) for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-udp-turbo elite-x-udp-boost2 \
                        elite-x-slowdns-alt elite-x-socks5 3proxy-elite-x elite-x-speedbooster \
                        elite-x-bandwidth elite-x-connmon elite-x-netbooster elite-x-dnscache \
                        elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner elite-x-datausage; do
                   systemctl restart "$s" 2>/dev/null||true; done
               echo -e "${GREEN}✅ All restarted${NC}"; read -p "Enter..." ;;
            3) systemctl restart dnstt-elite-x dnstt-elite-x-proxy elite-x-udp-turbo \
                   elite-x-udp-boost2 elite-x-slowdns-alt 2>/dev/null
               echo -e "${GREEN}✅ DNSTT + UDP relays restarted${NC}"; read -p "Enter..." ;;
            4) systemctl restart dnstt-elite-x dnstt-elite-x-proxy sshd 2>/dev/null; echo -e "${GREEN}✅ Fixed${NC}"; read -p "Enter..." ;;
            5) for u in "$UD"/*; do [ -f "$u" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$u")" 2>/dev/null; done
               systemctl reload sshd 2>/dev/null; echo -e "${GREEN}✅ Messages refreshed${NC}"; read -p "Enter..." ;;
            6) read -p "Username: " un; [ -f "/etc/elite-x/user_messages/$un" ] && cat "/etc/elite-x/user_messages/$un"||echo "No message"; read -p "Enter..." ;;
            7) systemctl restart elite-x-speedbooster elite-x-netbooster elite-x-irqopt 2>/dev/null; echo -e "${GREEN}✅ Speed boost applied${NC}"; read -p "Enter..." ;;
            8) systemctl restart elite-x-socks5 3proxy-elite-x 2>/dev/null; echo -e "${GREEN}✅ SOCKS5 + 3proxy restarted${NC}"; read -p "Enter..." ;;
            9) echo -e "${YELLOW}=== SSH Sessions ===${NC}"; who; echo -e "${YELLOW}=== SOCKS5:1080 ===${NC}"; ss -tnp|grep ":1080"||echo "None"; echo -e "${YELLOW}=== 3proxy:3128 ===${NC}"; ss -tnp|grep ":3128"||echo "None"; read -p "Enter..." ;;
            10) echo -e "${YELLOW}=== Connection Count Per User ===${NC}"; for u in "$UD"/*; do [ -f "$u" ]&&printf "${CYAN}%-20s${NC}: ${GREEN}%s${NC}\n" "$(basename $u)" "$(cat $CONN_DB/$(basename $u) 2>/dev/null||echo 0)"; done; read -p "Enter..." ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}                    MAIN MENU v5.0                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Create User   [2] List Users    [3] User Details${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Renew User    [5] Conn Limit    [6] BW Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset BW      [8] Lock User     [9] Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] Delete User  [11] Deleted List  [S] Settings${NC}"
        echo -e "${PURPLE}║${WHITE}  [M] Test Msg      [0] Exit${NC}"
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
            11) elite-x-user deleted; read -p "Press Enter..." ;;
            [Ss]) settings_menu ;;
            [Mm]) read -p "Username: " un
                if [ -f "/etc/elite-x/user_messages/$un" ]; then
                    clear
                    echo -e "${CYAN}══ MESSAGE PREVIEW: $un ══${NC}"
                    cat "/etc/elite-x/user_messages/$un"
                else echo -e "${RED}No message for $un!${NC}"; fi
                read -p "Press Enter..." ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
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
run_installation() {
    show_banner
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${GREEN}         ELITE-X v5.0 ACTIVATION REQUIRED       ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT
    if [ "$ACTIVATION_INPUT" != "$ACTIVATION_KEY" ] && [ "$ACTIVATION_INPUT" != "Whtsapp +255713-628-668" ]; then
        echo -e "${RED}❌ Invalid activation key!${NC}"; exit 1
    fi
    echo -e "${GREEN}✅ Activation successful${NC}"; sleep 1
    set_timezone

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}           ENTER YOUR NAMESERVER [NS]      ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $GREEN"Nameserver: "$NC)" TDOMAIN

    echo -e "${YELLOW}Select VPS location:${NC}"
    echo -e "  [1] South Africa (MTU 1800)"
    echo -e "  [2] USA (MTU 1500)"
    echo -e "  [3] Europe (MTU 1500)"
    echo -e "  [4] Asia (MTU 1400)"
    echo -e "  [5] Custom MTU"
    read -p "$(echo -e $GREEN"Choice [1]: "$NC)" LOC; LOC=${LOC:-1}
    case $LOC in
        2) SEL_LOC="USA"; MTU=1500 ;; 3) SEL_LOC="Europe"; MTU=1500 ;;
        4) SEL_LOC="Asia"; MTU=1400 ;; 5) SEL_LOC="Custom"; read -p "MTU: " MTU; [[ ! "$MTU" =~ ^[0-9]+$ ]] && MTU=1800 ;;
        *) SEL_LOC="South Africa"; MTU=1800 ;;
    esac

    echo -e "${YELLOW}🔄 Cleaning previous installation...${NC}"
    for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage \
              elite-x-connmon elite-x-cleaner elite-x-traffic elite-x-netbooster \
              elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner \
              elite-x-udp-turbo elite-x-udp-boost2 elite-x-slowdns-alt elite-x-socks5 \
              elite-x-speedbooster 3proxy-elite-x 3proxy-elite; do
        systemctl stop "$s" 2>/dev/null||true; systemctl disable "$s" 2>/dev/null||true
    done
    pkill -f dnstt-server 2>/dev/null; pkill -f elite-x-edns-proxy 2>/dev/null
    pkill -f elite-x-udp-turbo 2>/dev/null; pkill -f elite-x-udp-boost2 2>/dev/null
    pkill -f elite-x-slowdns-alt 2>/dev/null; pkill -f elite-x-socks5 2>/dev/null
    pkill -f elite-x-speedbooster 2>/dev/null; pkill -f 3proxy 2>/dev/null
    rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*,3proxy-elite*} 2>/dev/null
    rm -rf /etc/dnstt /etc/elite-x /etc/3proxy /var/run/elite-x 2>/dev/null
    rm -f /usr/local/bin/{dnstt-*,elite-x*,3proxy} 2>/dev/null
    rm -f /etc/ssh/sshd_config.d/elite-x-*.conf 2>/dev/null
    rm -f /etc/sysctl.d/99-elite-x-vpn.conf 2>/dev/null
    sed -i '/^Match User/,/Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/elite-x-update-user-msg/d' /etc/pam.d/sshd 2>/dev/null
    systemctl restart sshd 2>/dev/null||true; sleep 2

    mkdir -p /etc/elite-x/{users,traffic,deleted,data_usage,connections,banned,traffic_stats,bandwidth/pidtrack,user_messages}
    mkdir -p /etc/ssh/sshd_config.d /var/run/elite-x/bandwidth /etc/3proxy /var/log/3proxy
    echo "$TDOMAIN" > /etc/elite-x/subdomain
    echo "$SEL_LOC" > /etc/elite-x/location
    echo "$MTU" > /etc/elite-x/mtu
    echo "0" > "$AUTOBAN_FLAG"
    echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key
    echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key

    [ -f /etc/systemd/resolved.conf ] && {
        sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved 2>/dev/null||true
    }
    [ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
    printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 9.9.9.9\noptions timeout:1 attempts:3 rotate\noptions ndots:0\n" > /etc/resolv.conf

    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    apt update -y
    apt install -y curl jq iptables ethtool dnsutils net-tools iproute2 bc \
        build-essential git gcc make linux-tools-common 2>/dev/null

    echo -e "${YELLOW}📥 Downloading DNSTT server...${NC}"
    curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null || \
        curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null
    chmod +x /usr/local/bin/dnstt-server

    mkdir -p /etc/dnstt
    echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
    echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
    chmod 600 /etc/dnstt/server.key

    cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server v5.0 ULTRA
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=3
LimitNOFILE=2097152
LimitNPROC=65536
Nice=-10
[Install]
WantedBy=multi-user.target
EOF

    optimize_system_for_vpn
    configure_pam_user_message
    configure_ssh_for_vpn
    create_c_edns_proxy

    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X C ULTRA EDNS Proxy v5.0
After=dnstt-elite-x.service
Wants=dnstt-elite-x.service
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-edns-proxy
Restart=always
RestartSec=2
LimitNOFILE=2097152
Nice=-15
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=30
[Install]
WantedBy=multi-user.target
EOF
    fi

    create_c_udp_turbo
    create_c_udp_boost2
    create_c_slowdns_alt
    create_c_socks5
    create_c_speed_booster
    create_c_bandwidth_monitor
    create_c_connection_monitor
    create_c_data_usage
    create_c_network_booster
    create_c_dns_cache
    create_c_ram_cleaner
    create_c_irq_optimizer
    create_c_log_cleaner
    install_3proxy
    create_user_script
    create_main_menu

    cp "$0" /usr/local/bin/setup_elite_x_v5.sh 2>/dev/null && chmod +x /usr/local/bin/setup_elite_x_v5.sh

    systemctl daemon-reload

    ALL_SERVICES=(
        dnstt-elite-x dnstt-elite-x-proxy
        elite-x-udp-turbo elite-x-udp-boost2 elite-x-slowdns-alt
        elite-x-socks5 3proxy-elite-x
        elite-x-speedbooster elite-x-bandwidth elite-x-datausage
        elite-x-connmon elite-x-netbooster elite-x-dnscache
        elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner
    )
    for s in "${ALL_SERVICES[@]}"; do
        if [ -f "/etc/systemd/system/${s}.service" ]; then
            systemctl enable "$s" 2>/dev/null||true
            systemctl start "$s" 2>/dev/null||true
        fi
    done

    IP=$(curl -4 -s ifconfig.me 2>/dev/null||echo "Unknown")
    echo "$IP" > /etc/elite-x/cached_ip

    cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    /usr/local/bin/elite-x
fi
EOF
    chmod +x /etc/profile.d/elite-x-dashboard.sh

    cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
alias adduser='elite-x-user add'
alias users='elite-x-user list'
alias setbw='elite-x-user setbw'
alias boost='systemctl restart elite-x-speedbooster elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-udp-turbo elite-x-udp-boost2'
alias fixvpn='systemctl restart dnstt-elite-x dnstt-elite-x-proxy sshd && echo "VPN Fixed!"'
alias fixsocks='systemctl restart elite-x-socks5 3proxy-elite-x && echo "SOCKS5+3proxy Fixed!"'
alias fixudp='systemctl restart elite-x-udp-turbo elite-x-udp-boost2 elite-x-slowdns-alt && echo "UDP relays restarted!"'
alias refreshmsg='for u in /etc/elite-x/users/*; do [ -f "$u" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$u")"; done && systemctl reload sshd && echo "Messages refreshed!"'
alias testmsg='read -p "Username: " u; cat /etc/elite-x/user_messages/$u 2>/dev/null || echo "No message"'
alias speedtest='systemctl restart elite-x-speedbooster && echo "Speed boost applied!"'
alias connstatus='for u in /etc/elite-x/connections/*; do [ -f "$u" ] && printf "%-20s: %s\n" "$(basename $u)" "$(cat $u)"; done'
EOF

    for user_file in /etc/elite-x/users/*; do
        [ -f "$user_file" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$user_file")" 2>/dev/null
    done

    # ═══════════════════════════════════════════════════════════
    # FINAL DISPLAY
    # ═══════════════════════════════════════════════════════════
    clear
    echo -e "${GREEN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}    ELITE-X v5.0 FALCON ULTRA MAX BOOST INSTALLED!   ${GREEN}║${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
    echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SEL_LOC (MTU: $MTU)${NC}"
    echo -e "${GREEN}║${WHITE}  IP         :${CYAN} $IP${NC}"
    echo -e "${GREEN}║${WHITE}  Version    :${CYAN} v5.0 Falcon Ultra Max Boost${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key :${CYAN} $STATIC_PUBLIC_KEY${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"

    chk_svc() {
        local name=$1 svc=$2
        systemctl is-active "$svc" >/dev/null 2>&1 \
            && echo -e "${GREEN}║  ✅ $name: Running${NC}" \
            || echo -e "${RED}║  ❌ $name: Failed${NC}"
    }
    chk_svc "DNSTT Server          " "dnstt-elite-x"
    chk_svc "C EDNS Proxy  (dns:53)" "dnstt-elite-x-proxy"
    chk_svc "C UDP Turbo  (udp5301)" "elite-x-udp-turbo"
    chk_svc "C UDP Boost2 (udp5302)" "elite-x-udp-boost2"
    chk_svc "C SlowDNS Alt(udp5353)" "elite-x-slowdns-alt"
    chk_svc "C SOCKS5     (tcp1080)" "elite-x-socks5"
    chk_svc "3proxy HTTP  (tcp3128)" "3proxy-elite-x"
    chk_svc "C Speed Booster       " "elite-x-speedbooster"
    chk_svc "SSH Server            " "sshd"
    chk_svc "C Bandwidth Monitor   " "elite-x-bandwidth"
    chk_svc "C Conn Monitor        " "elite-x-connmon"
    chk_svc "C Net Booster         " "elite-x-netbooster"
    chk_svc "C DNS Cache           " "elite-x-dnscache"
    chk_svc "C RAM Cleaner         " "elite-x-ramcleaner"
    chk_svc "C IRQ Optimizer       " "elite-x-irqopt"
    chk_svc "C Log Cleaner         " "elite-x-logcleaner"

    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  ✨ NEW IN v5.0:${NC}"
    echo -e "${GREEN}║${WHITE}  🚀 UDP Turbo (5301) + UDP Boost2 (5302) dual-path${NC}"
    echo -e "${GREEN}║${WHITE}  🌐 SlowDNS Alt port 5353 (mDNS - bypasses ISP filter)${NC}"
    echo -e "${GREEN}║${WHITE}  🧦 C SOCKS5 Server (port 1080) RFC 1928 compliant${NC}"
    echo -e "${GREEN}║${WHITE}  🔄 3proxy: SOCKS5(1080) + HTTP(3128) + Auth(1081)${NC}"
    echo -e "${GREEN}║${WHITE}  🎨 Colored SSH banner: days + hours + MINS remaining${NC}"
    echo -e "${GREEN}║${WHITE}  📊 Accurate conn count via /proc (C monitor → file)${NC}"
    echo -e "${GREEN}║${WHITE}  ⚡ 48-worker UDP Boost2 with dual-path 5300→5301 fallback${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${CYAN}  📡 SLOWDNS PORTS  : ${WHITE}53 | 5301 | 5302 | 5353${NC}"
    echo -e "${GREEN}║${CYAN}  🧦 SOCKS5 (no auth): ${WHITE}$IP:1080${NC}"
    echo -e "${GREEN}║${CYAN}  🔄 HTTP Proxy      : ${WHITE}$IP:3128${NC}"
    echo -e "${GREEN}║${CYAN}  🔐 SOCKS5 (auth)   : ${WHITE}$IP:1081 (elite / elitex2025)${NC}"
    echo -e "${GREEN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Commands: menu | adduser | users | boost | fixvpn | fixsocks | fixudp | connstatus${NC}"
    echo -e "${YELLOW}Re-login or 'exec bash' to access dashboard${NC}"
    echo ""
}

# Run installation
run_installation
