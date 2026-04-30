#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  ELITE-X DNSTT SCRIPT v3.3.2 - FALCON ULTIMATE
#  + C EDNS Proxy + IPv6 Disabled + BBR + 20MB Buffers
#  + Nice -20 + Bandwidth GB + 3Proxy + Auto-Delete
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
ORANGE='\033[0;33m'; LIGHT_RED='\033[1;31m'; LIGHT_GREEN='\033[1;32m'
GRAY='\033[0;90m'; NC='\033[0m'

STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

USER_DB="/etc/elite-x/users"; USAGE_DB="/etc/elite-x/data_usage"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"; PIDTRACK_DIR="$BANDWIDTH_DIR/pidtrack"
BANNED_DB="/etc/elite-x/banned"; CONN_DB="/etc/elite-x/connections"
DELETED_DB="/etc/elite-x/deleted"; AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
THREEPROXY_DIR="/etc/elite-x/3proxy"; THREEPROXY_BIN="/usr/local/bin/3proxy"
THREEPROXY_SERVICE="/etc/systemd/system/3proxy-elite.service"
EDNS_C_SOURCE="/usr/local/bin/dnstt-edns-proxy.c"
EDNS_C_BIN="/usr/local/bin/dnstt-edns-proxy"

show_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}         ELITE-X SLOWDNS v3.3.2 FALCON ULTIMATE${PURPLE}             ║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}  C Proxy • IPv6 Off • BBR • 20MB Buff • Nice -20 • GB Lim${PURPLE}   ║${NC}"
    echo -e "${PURPLE}║${CYAN}${BOLD}            TURBO BOOST EDITION - FULL OPTIMIZED${PURPLE}            ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_color() { echo -e "${2}${1}${NC}"; }
set_timezone() { timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true; }

# ═══════════════════════════════════════════════════════════════
# KERNEL + IPv6 (FIXED - NO GRUB SED ERRORS)
# ═══════════════════════════════════════════════════════════════
optimize_kernel_and_disable_ipv6() {
    echo -e "${YELLOW}⚙️  Disabling IPv6 & Optimizing Kernel...${NC}"

    cat > /etc/sysctl.d/99-elite-x.conf <<'SYSCTL'
# ELITE-X: Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# ELITE-X: BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# ELITE-X: UDP Buffers 20MB
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.ipv4.udp_rmem_min = 20971520
net.ipv4.udp_wmem_min = 20971520

# ELITE-X: High Backlog
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535

# ELITE-X: TCP Optimizations
net.ipv4.tcp_rmem = 4096 87380 20971520
net.ipv4.tcp_wmem = 4096 65536 20971520
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
SYSCTL

    sysctl -p /etc/sysctl.d/99-elite-x.conf >/dev/null 2>&1 || true
    echo -e "${GREEN}✅ Kernel optimized & IPv6 disabled${NC}"
}

# ═══════════════════════════════════════════════════════════════
# C EDNS PROXY
# ═══════════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}🔧 Creating C EDNS Proxy...${NC}"

    cat > "$EDNS_C_SOURCE" <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <signal.h>

#define LISTEN_PORT 53
#define BACKEND_PORT 5300
#define BACKEND_IP "127.0.0.1"
#define MAX_WORKERS 4
#define BUFFER_SIZE 4096
#define EDNS_OPT 41
#define TARGET_MTU 1800

static volatile int running = 1;

static void signal_handler(int sig) { (void)sig; running = 0; }

static unsigned char *skip_name(unsigned char *ptr, unsigned char *end) {
    while (ptr < end) {
        if (*ptr == 0) return ptr + 1;
        if ((*ptr & 0xC0) == 0xC0) return ptr + 2;
        ptr += *ptr + 1;
    }
    return ptr;
}

static int modify_edns(unsigned char *buf, int len, int max_size) {
    if (len < 12) return len;
    unsigned char *ptr = buf + 12, *end = buf + len;
    int i;
    unsigned short qdcount = (buf[4] << 8) | buf[5];
    unsigned short ancount = (buf[6] << 8) | buf[7];
    unsigned short nscount = (buf[8] << 8) | buf[9];
    unsigned short arcount = (buf[10] << 8) | buf[11];

    for (i = 0; i < qdcount && ptr < end; i++) { ptr = skip_name(ptr, end); if (ptr + 4 > end) return len; ptr += 4; }
    for (i = 0; i < (ancount + nscount) && ptr < end; i++) {
        ptr = skip_name(ptr, end);
        if (ptr + 10 > end) return len;
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }
    for (i = 0; i < arcount && ptr < end; i++) {
        ptr = skip_name(ptr, end);
        if (ptr + 10 > end) return len;
        unsigned short rtype = (ptr[0] << 8) | ptr[1];
        if (rtype == EDNS_OPT) { ptr[2] = (max_size >> 8) & 0xFF; ptr[3] = max_size & 0xFF; return len; }
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }
    return len;
}

typedef struct { int listen_fd; struct sockaddr_in client_addr; socklen_t client_len; unsigned char buffer[BUFFER_SIZE]; int len; } worker_data_t;

static void *worker_thread(void *arg) {
    worker_data_t *data = (worker_data_t *)arg;
    int backend_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (backend_fd < 0) { free(data); return NULL; }
    struct timeval tv = {5, 0};
    setsockopt(backend_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    struct sockaddr_in backend_addr;
    memset(&backend_addr, 0, sizeof(backend_addr));
    backend_addr.sin_family = AF_INET;
    backend_addr.sin_port = htons(BACKEND_PORT);
    inet_pton(AF_INET, BACKEND_IP, &backend_addr.sin_addr);

    int mlen = modify_edns(data->buffer, data->len, TARGET_MTU);
    sendto(backend_fd, data->buffer, mlen, 0, (struct sockaddr *)&backend_addr, sizeof(backend_addr));

    unsigned char rbuf[BUFFER_SIZE];
    socklen_t blen = sizeof(backend_addr);
    int rlen = recvfrom(backend_fd, rbuf, sizeof(rbuf), 0, (struct sockaddr *)&backend_addr, &blen);
    if (rlen > 0) { rlen = modify_edns(rbuf, rlen, 512); sendto(data->listen_fd, rbuf, rlen, 0, (struct sockaddr *)&data->client_addr, data->client_len); }
    close(backend_fd); free(data);
    return NULL;
}

int main(void) {
    int listen_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (listen_fd < 0) { perror("socket"); return 1; }
    int optval = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEPORT, &optval, sizeof(optval));
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

    struct sockaddr_in listen_addr;
    memset(&listen_addr, 0, sizeof(listen_addr));
    listen_addr.sin_family = AF_INET;
    listen_addr.sin_addr.s_addr = INADDR_ANY;
    listen_addr.sin_port = htons(LISTEN_PORT);

    if (bind(listen_fd, (struct sockaddr *)&listen_addr, sizeof(listen_addr)) < 0) { perror("bind"); close(listen_fd); return 1; }

    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    fprintf(stderr, "C EDNS Proxy on port %d (IPv4, %d workers)\n", LISTEN_PORT, MAX_WORKERS);

    while (running) {
        worker_data_t *data = malloc(sizeof(worker_data_t));
        if (!data) continue;
        data->listen_fd = listen_fd; data->client_len = sizeof(data->client_addr);
        data->len = recvfrom(listen_fd, data->buffer, sizeof(data->buffer), 0, (struct sockaddr *)&data->client_addr, &data->client_len);
        if (data->len <= 0) { free(data); continue; }
        pthread_t tid; pthread_attr_t attr;
        pthread_attr_init(&attr); pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        pthread_create(&tid, &attr, worker_thread, data);
        pthread_attr_destroy(&attr);
    }
    close(listen_fd);
    return 0;
}
CEOF

    echo -e "${YELLOW}🔨 Compiling (gcc -Ofast -march=native -flto)...${NC}"
    gcc -Ofast -march=native -flto -pthread -o "$EDNS_C_BIN" "$EDNS_C_SOURCE" 2>/dev/null || true

    if [ -f "$EDNS_C_BIN" ] && [ -x "$EDNS_C_BIN" ]; then
        echo -e "${GREEN}✅ C EDNS Proxy compiled${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  C compilation failed - using Python${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# 3PROXY
# ═══════════════════════════════════════════════════════════════
install_3proxy() {
    echo -e "${YELLOW}🚀 Installing 3Proxy...${NC}"
    if [ -f "$THREEPROXY_BIN" ] && [ -x "$THREEPROXY_BIN" ]; then
        echo -e "${GREEN}✅ 3Proxy exists${NC}"
        return 0
    fi

    apt-get install -y build-essential git curl 2>/dev/null || true
    cd /tmp && rm -rf 3proxy 2>/dev/null || true

    if git clone https://github.com/3proxy/3proxy.git 2>/dev/null; then
        cd /tmp/3proxy && make -f Makefile.Linux 2>/dev/null || true
        if [ -f "bin/3proxy" ]; then
            cp bin/3proxy "$THREEPROXY_BIN" && chmod +x "$THREEPROXY_BIN"
            echo -e "${GREEN}✅ 3Proxy compiled${NC}"
        fi
    fi

    if [ ! -f "$THREEPROXY_BIN" ]; then
        echo -e "${YELLOW}⚠️  Trying pre-compiled...${NC}"
        curl -fsSL "https://github.com/z3APA3A/3proxy/releases/download/0.9.4/3proxy-0.9.4.x86_64.linux.tar.gz" -o /tmp/3proxy.tar.gz 2>/dev/null || true
        if [ -f /tmp/3proxy.tar.gz ]; then
            cd /tmp && tar -xzf 3proxy.tar.gz 2>/dev/null || true
            [ -f "/tmp/3proxy/3proxy" ] && cp /tmp/3proxy/3proxy "$THREEPROXY_BIN" && chmod +x "$THREEPROXY_BIN"
            rm -f /tmp/3proxy.tar.gz
        fi
    fi

    if [ ! -f "$THREEPROXY_BIN" ]; then
        echo -e "${YELLOW}⚠️  3Proxy failed - skipping${NC}"
        return 1
    fi

    mkdir -p "$THREEPROXY_DIR"
    cat > "$THREEPROXY_DIR/3proxy.cfg" <<'EOF'
nserver 8.8.8.8; nserver 8.8.4.4; nscache 65536
timeouts 1 5 30 60 180 1800 15 60
daemon; pidfile /var/run/3proxy.pid
auth none; socks -p1080; dnspr; auth none; allow *
dnspr -p5353; auth none; allow *
proxy -p8080; log /var/log/3proxy.log D; rotate 7
EOF

    cat > "$THREEPROXY_SERVICE" <<EOF
[Unit]
Description=3Proxy for ELITE-X
After=network.target

[Service]
Type=forking
ExecStart=$THREEPROXY_BIN $THREEPROXY_DIR/3proxy.cfg
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    systemctl enable 3proxy-elite 2>/dev/null || true
    systemctl start 3proxy-elite 2>/dev/null || true
    echo -e "${GREEN}✅ 3Proxy installed${NC}"
    return 0
}

# ═══════════════════════════════════════════════════════════════
# BANDWIDTH MONITOR
# ═══════════════════════════════════════════════════════════════
create_bandwidth_monitor() {
    cat > /usr/local/bin/elite-x-bandwidth <<'BWEOF'
#!/bin/bash
USER_DB="/etc/elite-x/users"; BW_DIR="/etc/elite-x/bandwidth"; PID_DIR="$BW_DIR/pidtrack"
SCAN_INTERVAL=30; mkdir -p "$BW_DIR" "$PID_DIR"

while true; do
    declare -A uid_to_user=() session_pids=() loginuid_pids=()

    while IFS=: read -r u _ uid _; do [[ -n "$u" && "$uid" =~ ^[0-9]+$ ]] && uid_to_user["$uid"]="$u"; done < /etc/passwd

    while read -r pid usr; do [[ "$pid" =~ ^[0-9]+$ && -n "$usr" && "$usr" != "root" && "$usr" != "sshd" ]] && session_pids["$usr"]+="$pid "; done < <(ps -C sshd -o pid=,user= 2>/dev/null)

    for p in /proc/[0-9]*/loginuid; do
        [ -f "$p" ] || continue; read -r luid < "$p" || continue
        [[ "$luid" =~ ^[0-9]+$ && "$luid" != "4294967295" ]] || continue
        susr="${uid_to_user[$luid]:-}"; [ -n "$susr" ] || continue
        pd=$(dirname "$p"); pn=$(basename "$pd")
        read -r comm < "$pd/comm" 2>/dev/null || continue; [[ "$comm" == "sshd" ]] || continue
        ppid=""; while read -r k v; do [[ "$k" == "PPid:" ]] && { ppid="$v"; break; }; done < "$pd/status"
        [[ "$ppid" != "1" ]] && loginuid_pids["$susr"]+="$pn "
    done

    for uf in "$USER_DB"/*; do
        [ -f "$uf" ] || continue; un=$(basename "$uf")
        bw_gb=$(grep "Bandwidth_GB:" "$uf" 2>/dev/null | awk '{print $2}')
        [[ -z "$bw_gb" || "$bw_gb" == "0" ]] && continue

        declare -A upids=()
        for pid in ${session_pids[$un]:-} ${loginuid_pids[$un]:-}; do [[ "$pid" =~ ^[0-9]+$ ]] && upids["$pid"]=1; done
        ((${#upids[@]} == 0)) && { rm -f "$PID_DIR/${un}__"*.last 2>/dev/null; continue; }

        uf_usage="$BW_DIR/${un}.usage"; acc=0
        [ -f "$uf_usage" ] && { read -r acc < "$uf_usage"; [[ "$acc" =~ ^[0-9]+$ ]] || acc=0; }

        dtotal=0
        for pid in "${!upids[@]}"; do
            io="/proc/$pid/io"; cur=0
            if [ -r "$io" ]; then
                r=0; w=0
                while read -r k v; do case "$k" in rchar:) r=${v:-0};; wchar:) w=${v:-0};; esac; done < "$io"
                cur=$((r + w))
            fi
            pf="$PID_DIR/${un}__${pid}.last"
            if [ -f "$pf" ]; then read -r pv < "$pf"; [[ "$pv" =~ ^[0-9]+$ ]] || pv=0; d=$((cur >= pv ? cur - pv : cur)); dtotal=$((dtotal + d)); fi
            echo "$cur" > "$pf"
        done
        for f in "$PID_DIR/${un}__"*.last; do [ -f "$f" ] || continue; fpid=${f##*__}; fpid=${fpid%.last}; [ -d "/proc/$fpid" ] || rm -f "$f"; done

        new_total=$((acc + dtotal)); echo "$new_total" > "$uf_usage"
        quota=$(awk "BEGIN {printf \"%.0f\", $bw_gb * 1073741824}")
        if [[ "$quota" =~ ^[0-9]+$ ]] && ((new_total >= quota)); then
            passwd -S "$un" 2>/dev/null | grep -q "L" || { usermod -L "$un" 2>/dev/null; killall -u "$un" -9 2>/dev/null; echo "$(date) - BLOCKED: BW exceeded (${bw_gb}GB)" >> "/etc/elite-x/banned/$un"; }
        fi
    done
    sleep "$SCAN_INTERVAL"
done
BWEOF
    chmod +x /usr/local/bin/elite-x-bandwidth

    cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X Bandwidth Monitor
After=network.target
[Service]
Type=simple; ExecStart=/usr/local/bin/elite-x-bandwidth
Restart=always; RestartSec=10; Nice=10
[Install]
WantedBy=multi-user.target
EOF
}

# ═══════════════════════════════════════════════════════════════
# CONNECTION MONITOR
# ═══════════════════════════════════════════════════════════════
create_connection_monitor() {
    cat > /usr/local/bin/elite-x-connmon <<'CONNEOF'
#!/bin/bash
UD="/etc/elite-x/users"; BD="/etc/elite-x/banned"; DD="/etc/elite-x/deleted"
BW_DIR="/etc/elite-x/bandwidth"; PID_DIR="$BW_DIR/pidtrack"
AF="/etc/elite-x/autoban_enabled"; CD="/etc/elite-x/connections"
mkdir -p "$CD" "$BD" "$DD"

get_conn() { local u=$1 c=0; who|grep -qw "$u" 2>/dev/null && c=$(who|grep -wc "$u"); [ "$c" -eq 0 ] && c=$(ps aux|grep "sshd:"|grep "$u"|grep -v grep|grep -v "@notty"|wc -l); echo ${c:-0}; }

del_expired() {
    local u=$1 r=$2
    cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    pkill -u "$u" 2>/dev/null; killall -u "$u" -9 2>/dev/null; userdel -r "$u" 2>/dev/null
    rm -f "$UD/$u" "/etc/elite-x/data_usage/$u" "$CD/$u" "$BD/$u" "$BW_DIR/${u}.usage" "$PID_DIR/${u}__"*.last 2>/dev/null
    logger -t "elite-x" "Auto-deleted: $u ($r)"
}

while true; do
    cts=$(date +%s)
    for uf in "$UD"/*; do
        [ -f "$uf" ] || continue; un=$(basename "$uf")
        id "$un" &>/dev/null || { rm -f "$UD/$un"; continue; }

        ex=$(grep "Expire:" "$uf" 2>/dev/null | awk '{print $2}')
        [ -n "$ex" ] && { ets=$(date -d "$ex" +%s 2>/dev/null || echo 0); [ "$ets" -gt 0 ] && [ "$cts" -gt "$ets" ] && { del_expired "$un" "Expired $ex"; continue; }; }

        cl=$(grep "Conn_Limit:" "$uf" 2>/dev/null | awk '{print $2}'); cl=${cl:-1}
        cc=$(get_conn "$un"); echo "$cc" > "$CD/$un"

        ab=$(cat "$AF" 2>/dev/null || echo "0")
        il=$(passwd -S "$un" 2>/dev/null | grep -q "L" && echo "yes" || echo "no")
        [ "$cc" -gt "$cl" ] && [ "$il" = "no" ] && [ "$ab" = "1" ] && { usermod -L "$un" 2>/dev/null; pkill -u "$un" 2>/dev/null; echo "$(date) - BLOCKED: Conn limit ($cc/$cl)" >> "$BD/$un"; }
    done
    sleep 5
done
CONNEOF
    chmod +x /usr/local/bin/elite-x-connmon

    cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X Connection Monitor
After=network.target ssh.service
[Service]
Type=simple; ExecStart=/usr/local/bin/elite-x-connmon
Restart=always; RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
}

# ═══════════════════════════════════════════════════════════════
# DATA USAGE MONITOR
# ═══════════════════════════════════════════════════════════════
create_data_usage_monitor() {
    cat > /usr/local/bin/elite-x-datausage <<'DATAEOF'
#!/bin/bash
UD="/etc/elite-x/users"; USAGE_DB="/etc/elite-x/data_usage"; BW_DIR="/etc/elite-x/bandwidth"
mkdir -p "$USAGE_DB" "$BW_DIR"
while true; do
    cm=$(date +%Y-%m)
    for uf in "$UD"/*; do
        [ -f "$uf" ] || continue; un=$(basename "$uf")
        uf_usage="$BW_DIR/${un}.usage"; tg="0.00"
        [ -f "$uf_usage" ] && { tb=$(cat "$uf_usage" 2>/dev/null || echo 0); tg=$(echo "scale=2; $tb / 1073741824" | bc 2>/dev/null || echo "0.00"); }
        cat > "$USAGE_DB/$un" <<INFO
month: $cm
total_gb: $tg
last_updated: $(date)
INFO
    done
    sleep 30
done
DATAEOF
    chmod +x /usr/local/bin/elite-x-datausage

    cat > /etc/systemd/system/elite-x-datausage.service <<EOF
[Unit]
Description=ELITE-X Data Usage Monitor
After=network.target
[Service]
Type=simple; ExecStart=/usr/local/bin/elite-x-datausage; Restart=always; RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
}

# ═══════════════════════════════════════════════════════════════
# USER MANAGEMENT
# ═══════════════════════════════════════════════════════════════
create_user_script() {
    cat > /usr/local/bin/elite-x-user <<'USEREOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';LIGHT_RED='\033[1;31m';LIGHT_GREEN='\033[1;32m'
GRAY='\033[0;90m';NC='\033[0m'

UD="/etc/elite-x/users"; USG="/etc/elite-x/data_usage"; DD="/etc/elite-x/deleted"
BD="/etc/elite-x/banned"; CD="/etc/elite-x/connections"; BW="/etc/elite-x/bandwidth"
PD="$BW/pidtrack"; mkdir -p "$UD" "$USG" "$DD" "$BD" "$CD" "$BW" "$PD"

gconn() { local u=$1 c=0; who|grep -qw "$u" 2>/dev/null && c=$(who|grep -wc "$u"); [ "$c" -eq 0 ] && c=$(ps aux|grep "sshd:"|grep "$u"|grep -v grep|grep -v "@notty"|wc -l); echo ${c:-0}; }
gbw() { local u=$1 f="$BW/${u}.usage"; [ -f "$f" ] && { local tb=$(cat "$f" 2>/dev/null || echo 0); echo "scale=2; $tb / 1073741824" | bc 2>/dev/null || echo "0.00"; } || echo "0.00"; }

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE SSH + DNS USER${CYAN}                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $GREEN"Username: "$NC)" un
    id "$un" &>/dev/null && { echo -e "${RED}User exists!${NC}"; return; }
    read -p "$(echo -e $GREEN"Password [auto]: "$NC)" pw
    [ -z "$pw" ] && pw=$(head /dev/urandom|tr -dc 'A-Za-z0-9'|head -c 8) && echo -e "${GREEN}🔑 Generated: ${YELLOW}$pw${NC}"
    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" d; d=${d:-30}
    [[ ! "$d" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; return; }
    read -p "$(echo -e $GREEN"Conn limit [1]: "$NC)" cl; cl=${cl:-1}
    read -p "$(echo -e $GREEN"BW limit GB (0=∞) [0]: "$NC)" bw; bw=${bw:-0}
    useradd -m -s /bin/false "$un"; echo "$un:$pw" | chpasswd
    ed=$(date -d "+$d days" +"%Y-%m-%d"); chage -E "$ed" "$un"
    cat > "$UD/$un" <<INFO
Username: $un
Password: $pw
Expire: $ed
Conn_Limit: $cl
Bandwidth_GB: $bw
Created: $(date)
INFO
    echo "0" > "$BW/${un}.usage"
    local bwd="Unlimited"; [ "$bw" != "0" ] && bwd="${bw} GB"
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER CREATED SUCCESSFULLY${GREEN}                    ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  User:${CYAN} $un${NC}"; echo -e "${GREEN}║${WHITE}  Pass:${CYAN} $pw${NC}"
    echo -e "${GREEN}║${WHITE}  Server:${CYAN} $SERVER${NC}"; echo -e "${GREEN}║${WHITE}  Expire:${CYAN} $ed${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login:${CYAN} $cl${NC}"; echo -e "${GREEN}║${WHITE}  BW:${CYAN} $bwd${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                    ACTIVE USERS + BANDWIDTH + STATUS${CYAN}                                     ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    if [ -z "$(ls -A "$UD" 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}                                    No users found${CYAN}                                          ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        return
    fi
    printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-14s %-18s${CYAN} ║${NC}\n" "USERNAME" "EXPIRE" "LOGIN" "BANDWIDTH" "STATUS"
    echo -e "${CYAN}╟──────────────────────────────────────────────────────────────────────────────────────────────────╢${NC}"
    for uf in "$UD"/*; do
        [ ! -f "$uf" ] && continue; u=$(basename "$uf")
        ex=$(grep "Expire:" "$uf" | cut -d' ' -f2); limit=$(grep "Conn_Limit:" "$uf" | awk '{print $2}'); limit=${limit:-1}
        bw_limit=$(grep "Bandwidth_GB:" "$uf" | awk '{print $2}'); bw_limit=${bw_limit:-0}
        tg=$(gbw "$u"); cc=$(gconn "$u")
        ets=$(date -d "$ex" +%s 2>/dev/null || echo 0); cts=$(date +%s); dl=$(((ets - cts) / 86400))

        if passwd -S "$u" 2>/dev/null | grep -q "L"; then st="${RED}🔒 LOCKED${NC}"
        elif [ "$cc" -gt 0 ]; then st="${LIGHT_GREEN}🟢 ONLINE${NC}"
        elif [ $dl -le 0 ]; then st="${RED}⛔ EXPIRED${NC}"
        elif [ $dl -le 3 ]; then st="${LIGHT_RED}⚠️ CRITICAL${NC}"
        elif [ $dl -le 7 ]; then st="${YELLOW}⚠️ WARNING${NC}"
        else st="${YELLOW}⚫ OFFLINE${NC}"; fi

        if [ "$bw_limit" != "0" ] && [ -n "$bw_limit" ]; then
            bp=$(echo "scale=1; ($tg / $bw_limit) * 100" | bc 2>/dev/null || echo "0")
            [ "$(echo "$bp >= 100" | bc 2>/dev/null)" = "1" ] && bwd="${RED}${tg}/${bw_limit}GB${NC}" || { [ "$(echo "$bp > 80" | bc 2>/dev/null)" = "1" ] && bwd="${YELLOW}${tg}/${bw_limit}GB${NC}" || bwd="${GREEN}${tg}/${bw_limit}GB${NC}"; }
        else bwd="${GRAY}${tg}GB/∞${NC}"; fi

        [ "$cc" -ge "$limit" ] && ld="${RED}${cc}/${limit}${NC}" || ld="${GREEN}${cc}/${limit}${NC}"
        [ "$cc" -eq 0 ] && ld="${GRAY}0/${limit}${NC}"
        [ $dl -le 0 ] && ed="${RED}${ex}${NC}" || ed="${GREEN}${ex}${NC}"
        [ $dl -le 7 ] && [ $dl -gt 0 ] && ed="${YELLOW}${ex}${NC}"

        printf "${CYAN}║${WHITE} %-14s %-12b %-8b %-14b %-18b${CYAN} ║${NC}\n" "$u" "$ed" "$ld" "$bwd" "$st"
    done
    TU=$(ls "$UD" 2>/dev/null | wc -l); TO=$(who | wc -l)
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW}  📊 Users: ${GREEN}${TU}${YELLOW} | Online: ${GREEN}${TO}${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

renew_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; read -p "Additional days: " d; ce=$(grep "Expire:" "$UD/$u" | cut -d' ' -f2); ne=$(date -d "$ce +$d days" +"%Y-%m-%d"); sed -i "s/Expire: .*/Expire: $ne/" "$UD/$u"; chage -E "$ne" "$u" 2>/dev/null; usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Renewed to $ne${NC}"; }
set_bw() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; cbw=$(grep "Bandwidth_GB:" "$UD/$u" 2>/dev/null | awk '{print $2}'); echo -e "Current: ${YELLOW}${cbw:-Not set} GB${NC}"; read -p "New limit (0=∞): " nbw; grep -q "Bandwidth_GB:" "$UD/$u" && sed -i "s/Bandwidth_GB: .*/Bandwidth_GB: $nbw/" "$UD/$u" || echo "Bandwidth_GB: $nbw" >> "$UD/$u"; [ "$nbw" = "0" ] && usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Updated${NC}"; }
reset_bw() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; echo "0" > "$BW/${u}.usage"; rm -rf "$PD/${u}" 2>/dev/null; rm -f "$PD/${u}__"*.last 2>/dev/null; usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Reset${NC}"; }
lock_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; usermod -L "$u" 2>/dev/null; pkill -u "$u" 2>/dev/null; echo "$(date) - MANUALLY LOCKED" >> "$BD/$u"; echo -e "${GREEN}✅ Locked${NC}"; }
unlock_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; usermod -U "$u" 2>/dev/null; echo "$(date) - MANUALLY UNLOCKED" >> "$BD/$u"; echo -e "${GREEN}✅ Unlocked${NC}"; }
delete_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null; pkill -u "$u" 2>/dev/null; killall -u "$u" -9 2>/dev/null; userdel -r "$u" 2>/dev/null; rm -f "$UD/$u" "$USG/$u" "$CD/$u" "$BD/$u" "$BW/${u}.usage"; rm -rf "$PD/${u}" 2>/dev/null; echo -e "${GREEN}✅ Deleted${NC}"; }
details_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; clear; echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"; echo -e "${CYAN}║${YELLOW}              USER DETAILS${CYAN}                                     ║${NC}"; echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"; cat "$UD/$u" | while read l; do echo -e "${CYAN}║${WHITE}  $l${NC}"; done; tg=$(gbw "$u"); bw_limit=$(grep "Bandwidth_GB:" "$UD/$u" 2>/dev/null | awk '{print $2}'); bw_limit=${bw_limit:-0}; cc=$(gconn "$u"); echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"; echo -e "${CYAN}║${WHITE}  Sessions: ${GREEN}${cc}${NC}"; echo -e "${CYAN}║${WHITE}  BW Used: ${GREEN}${tg} GB${NC} / ${YELLOW}${bw_limit:-Unlimited} GB${NC}"; echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"; }

case $1 in
    add) add_user;; list) list_users;; details) details_user;; renew) renew_user;;
    setlimit) read -p "User: " u; read -p "Limit: " l; [ -f "$UD/$u" ] && { sed -i "s/Conn_Limit: .*/Conn_Limit: $l/" "$UD/$u"; echo -e "${GREEN}✅ Updated${NC}"; } || echo -e "${RED}Not found${NC}";;
    setbw) set_bw;; resetdata) reset_bw;; deleted) ls "$DD/" 2>/dev/null | head -20 || echo "None";;
    lock) lock_user;; unlock) unlock_user;; del) delete_user;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setlimit|setbw|resetdata|deleted|lock|unlock|del}";;
esac
USEREOF
    chmod +x /usr/local/bin/elite-x-user
}

# ═══════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════
create_main_menu() {
    cat > /usr/local/bin/elite-x <<'MENUEOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'
UD="/etc/elite-x/users"; BW_DIR="/etc/elite-x/bandwidth"; AF="/etc/elite-x/autoban_enabled"

show_dashboard() {
    clear
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "Unknown")
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?"); LOC=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800"); RAM=$(free -h | awk '/^Mem:/{print $3"/"$2}')
    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    BW=$(systemctl is-active elite-x-bandwidth 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    P3X=$(systemctl is-active 3proxy-elite 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    TU=$(ls -1 "$UD" 2>/dev/null | wc -l); ON=$(who | wc -l)
    TB=0
    for f in "$BW_DIR"/*.usage; do [ -f "$f" ] && { b=$(cat "$f" 2>/dev/null || echo 0); gb=$(echo "scale=2; $b / 1073741824" | bc 2>/dev/null || echo "0"); TB=$(echo "$TB + $gb" | bc 2>/dev/null || echo "$TB"); }; done
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}        ELITE-X v3.3.2 - FALCON ULTIMATE${PURPLE}             ║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  NS:${GREEN} $SUB${NC}"; echo -e "${PURPLE}║${WHITE}  IP:${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location:${GREEN} $LOC (MTU: $MTU)${NC}"; echo -e "${PURPLE}║${WHITE}  RAM:${GREEN} $RAM${NC}"
    echo -e "${PURPLE}║${WHITE}  Services: DNS:$DNS PRX:$PRX BW:$BW 3PX:$P3X${NC}"
    echo -e "${PURPLE}║${WHITE}  Users:${GREEN} $TU total, $ON online${NC}"
    echo -e "${PURPLE}║${WHITE}  Total BW:${YELLOW} ${TB} GB${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

settings_menu() {
    while true; do
        clear; ab=$(cat "$AF" 2>/dev/null || echo "0")
        [ "$ab" = "1" ] && AS="${RED}ENABLED${NC}" || AS="${GREEN}DISABLED${NC}"
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}                 SETTINGS MENU${PURPLE}                     ║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Change MTU  [2] Speed Optimize  [3] Clean Cache${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Edit Banner [5] Reset Banner     [6] Traffic Stats${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset All BW [8] Toggle Auto-Ban ($AS)${WHITE}${NC}"
        echo -e "${PURPLE}║${WHITE}  [9] Restart All  [10] Reboot VPS      [11] Uninstall${NC}"
        echo -e "${PURPLE}║${WHITE}  [12] Reinstall 3Proxy${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Back${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        case $ch in
            1) read -p "New MTU (1000-5000): " m; [[ "$m" =~ ^[0-9]+$ ]] && [ $m -ge 1000 ] && [ $m -le 5000 ] && { echo "$m" > /etc/elite-x/mtu; sed -i "s/-mtu [0-9]*/-mtu $m/" /etc/systemd/system/dnstt-elite-x.service; systemctl daemon-reload; systemctl restart dnstt-elite-x dnstt-elite-x-proxy; echo -e "${GREEN}✅ MTU updated${NC}"; } || echo -e "${RED}Invalid${NC}"; read -p "Enter..." ;;
            2) sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1; sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1; echo -e "${GREEN}✅ Optimized${NC}"; read -p "Enter..." ;;
            3) apt clean 2>/dev/null; sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null; echo -e "${GREEN}✅ Cleaned${NC}"; read -p "Enter..." ;;
            4) nano /etc/elite-x/banner/ssh-banner; systemctl restart sshd; echo -e "${GREEN}✅ Banner updated${NC}"; read -p "Enter..." ;;
            5) cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner; systemctl restart sshd; echo -e "${GREEN}✅ Reset${NC}"; read -p "Enter..." ;;
            6) iface=$(ip route | grep default | awk '{print $5}' | head -1); rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0); tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0); echo -e "RX: $(echo "scale=2; $rx/1073741824" | bc) GB"; echo -e "TX: $(echo "scale=2; $tx/1073741824" | bc) GB"; read -p "Enter..." ;;
            7) for f in "$BW_DIR"/*.usage; do [ -f "$f" ] && echo "0" > "$f"; done; for u in "$UD"/*; do [ -f "$u" ] && usermod -U "$(basename "$u")" 2>/dev/null; done; echo -e "${GREEN}✅ All BW reset${NC}"; read -p "Enter..." ;;
            8) [ "$ab" = "1" ] && echo "0" > "$AF" || echo "1" > "$AF"; systemctl restart elite-x-connmon 2>/dev/null; echo -e "${GREEN}✅ Toggled${NC}"; read -p "Enter..." ;;
            9) systemctl restart dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon 3proxy-elite sshd 2>/dev/null; echo -e "${GREEN}✅ Restarted${NC}"; read -p "Enter..." ;;
            10) read -p "Reboot? (y/n): " c; [ "$c" = "y" ] && reboot ;;
            11) read -p "Type 'YES' to uninstall: " c; [ "$c" = "YES" ] && { for u in "$UD"/*; do [ -f "$u" ] && { un=$(basename "$u"); pkill -u "$un" 2>/dev/null; userdel -r "$un" 2>/dev/null; }; done; for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon 3proxy-elite; do systemctl stop "$s" 2>/dev/null; systemctl disable "$s" 2>/dev/null; done; rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*,3proxy-elite*}; rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x /tmp/3proxy*; rm -f /usr/local/bin/{dnstt-*,elite-x*,3proxy}; sed -i '/^Banner/d' /etc/ssh/sshd_config; systemctl restart sshd 2>/dev/null; rm -f /etc/profile.d/elite-x-dashboard.sh; sed -i '/elite-x/d' ~/.bashrc 2>/dev/null; systemctl daemon-reload; echo -e "${GREEN}✅ Uninstalled!${NC}"; exit 0; }; read -p "Enter..." ;;
            12) systemctl stop 3proxy-elite 2>/dev/null; rm -f /usr/local/bin/3proxy; install_3proxy; read -p "Enter..." ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}               MAIN MENU v3.3.2${PURPLE}                     ║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Create User   [2] List Users      [3] User Details${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Renew User    [5] Set Conn Limit   [6] Set BW Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset BW      [8] Lock User        [9] Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] Delete User  [11] Deleted List     [S] Settings${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Exit${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        case $ch in
            1) elite-x-user add; read -p "Enter..." ;; 2) elite-x-user list; read -p "Enter..." ;;
            3) elite-x-user details; read -p "Enter..." ;; 4) elite-x-user renew; read -p "Enter..." ;;
            5) elite-x-user setlimit; read -p "Enter..." ;; 6) elite-x-user setbw; read -p "Enter..." ;;
            7) elite-x-user resetdata; read -p "Enter..." ;; 8) elite-x-user lock; read -p "Enter..." ;;
            9) elite-x-user unlock; read -p "Enter..." ;; 10) elite-x-user del; read -p "Enter..." ;;
            11) elite-x-user deleted; read -p "Enter..." ;; [Ss]) settings_menu ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid${NC}"; read -p "Enter..." ;;
        esac
    done
}
main_menu
MENUEOF
    chmod +x /usr/local/bin/elite-x
}

# ═══════════════════════════════════════════════════════════════
# MAIN INSTALLATION
# ═══════════════════════════════════════════════════════════════
show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED${YELLOW}                          ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $CYAN"Activation Key: "$NC)" AK
if [ "$AK" != "$ACTIVATION_KEY" ] && [ "$AK" != "Whtsapp +255713-628-668" ]; then
    echo -e "${RED}❌ Invalid key!${NC}"; exit 1
fi
echo -e "${GREEN}✅ Activated${NC}"; sleep 1
set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR NAMESERVER [NS]${CYAN}                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $GREEN"Nameserver: "$NC)" TDOMAIN

echo -e "${YELLOW}Select VPS location:${NC}"
echo -e "  [1] South Africa (MTU 1800)  [2] USA (MTU 1500)  [3] Europe (MTU 1500)  [4] Asia (MTU 1400)  [5] Custom MTU"
read -p "$(echo -e $GREEN"Choice [1]: "$NC)" LOC; LOC=${LOC:-1}
case $LOC in
    2) SEL_LOC="USA"; MTU=1500 ;; 3) SEL_LOC="Europe"; MTU=1500 ;; 4) SEL_LOC="Asia"; MTU=1400 ;;
    5) SEL_LOC="Custom"; read -p "MTU: " MTU; [[ ! "$MTU" =~ ^[0-9]+$ ]] && MTU=1800 ;;
    *) SEL_LOC="South Africa"; MTU=1800 ;;
esac

echo -e "${YELLOW}🔄 Cleaning previous installation...${NC}"
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon 3proxy-elite; do
    systemctl stop "$s" 2>/dev/null || true; systemctl disable "$s" 2>/dev/null || true
done
pkill -f dnstt-server 2>/dev/null || true
rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*,3proxy-elite*} 2>/dev/null || true
rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x 2>/dev/null || true
rm -f /usr/local/bin/{dnstt-*,elite-x*,3proxy} 2>/dev/null || true
sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null || true
systemctl restart sshd 2>/dev/null || true
sleep 2

echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p /etc/elite-x/{banner,users,traffic,deleted,data_usage,connections,banned,traffic_stats,bandwidth/pidtrack,3proxy}
mkdir -p /var/run/elite-x/bandwidth
echo "$TDOMAIN" > /etc/elite-x/subdomain; echo "$SEL_LOC" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu; echo "0" > "$AUTOBAN_FLAG"
echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key; echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key

cat > /etc/elite-x/banner/default <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║        ELITE-X v3.3.2 FALCON ULTIMATE                        ║
║     C Proxy • IPv6 Off • BBR • 20MB Buff • Nice -20          ║
╚═══════════════════════════════════════════════════════════════╝
EOF
cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner
echo "Banner /etc/elite-x/banner/ssh-banner" >> /etc/ssh/sshd_config
systemctl restart sshd 2>/dev/null || true

echo -e "${YELLOW}🔧 Configuring DNS...${NC}"
[ -f /etc/systemd/resolved.conf ] && { sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf; systemctl restart systemd-resolved 2>/dev/null || true; }
[ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf; echo "nameserver 8.8.4.4" >> /etc/resolv.conf

echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y 2>/dev/null || true
apt install -y curl python3 jq bc build-essential git gcc 2>/dev/null || true

optimize_kernel_and_disable_ipv6

echo -e "${YELLOW}📥 Downloading DNSTT server...${NC}"
if ! curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null; then
    curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null || true
fi
if [ -f /usr/local/bin/dnstt-server ]; then
    chmod +x /usr/local/bin/dnstt-server
    echo -e "${GREEN}✅ DNSTT downloaded${NC}"
else
    echo -e "${RED}❌ DNSTT download failed${NC}"; exit 1
fi

mkdir -p /etc/dnstt
echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key; echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
chmod 600 /etc/dnstt/server.key

echo -e "${YELLOW}🔧 Creating DNSTT service...${NC}"
cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server v3.3.2
After=network-online.target
[Service]
Type=simple; User=root; Nice=-20
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always; RestartSec=5; LimitNOFILE=1000000; CPUQuota=200%
[Install]
WantedBy=multi-user.target
EOF

install_3proxy
create_c_edns_proxy

if [ -f "$EDNS_C_BIN" ] && [ -x "$EDNS_C_BIN" ]; then
    PROXY_EXEC="$EDNS_C_BIN"; PROXY_TYPE="C (compiled, multi-core)"
else
    PROXY_EXEC="/usr/bin/python3 /usr/local/bin/dnstt-edns-proxy.py"; PROXY_TYPE="Python (fallback)"
fi

echo -e "${YELLOW}🔧 Creating EDNS Proxy service (${PROXY_TYPE})...${NC}"
cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X EDNS Proxy (${PROXY_TYPE})
After=dnstt-elite-x.service
[Service]
Type=simple; User=root; Nice=-20; LimitNOFILE=1000000
ExecStart=${PROXY_EXEC}
Restart=always; RestartSec=3; CPUQuota=200%
[Install]
WantedBy=multi-user.target
EOF

# Python fallback
cat > /usr/local/bin/dnstt-edns-proxy.py <<'EOF'
#!/usr/bin/env python3
import socket, threading, struct, os, signal, logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
L=5300; running=True
def modify_edns(d, max_size):
    if len(d)<12: return d
    o=12
    def skip_name(b,o):
        while o<len(b):
            l=b[o];o+=1
            if l==0:break
            if l&0xC0==0xC0:o+=1;break
            o+=l
        return o
    try: q,a,n,r=struct.unpack("!HHHH",d[4:12])
    except: return d
    for _ in range(q): o=skip_name(d,o); o+=4
    for _ in range(a+n):
        o=skip_name(d,o)
        if o+10>len(d): return d
        try: _,_,_,l=struct.unpack("!HHIH",d[o:o+10])
        except: return d
        o+=10+l
    modified=bytearray(d)
    for _ in range(r):
        o=skip_name(d,o)
        if o+10>len(d): return d
        t=struct.unpack("!H",d[o:o+2])[0]
        if t==41: modified[o+2:o+4]=struct.pack("!H",max_size); return bytes(modified)
        _,_,l=struct.unpack("!HIH",d[o+2:o+10]); o+=10+l
    return d
def handle(sock,data,addr):
    c=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);c.settimeout(5)
    try:
        md=modify_edns(data,1800);c.sendto(md,('127.0.0.1',L))
        r,_=c.recvfrom(4096);mr=modify_edns(r,512);sock.sendto(mr,addr)
    except:pass
    finally:c.close()
def main():
    global running
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    os.system("fuser -k 53/udp 2>/dev/null; sleep 1")
    try: s.bind(('0.0.0.0',53))
    except:
        os.system("fuser -k 53/udp 2>/dev/null; sleep 2")
        try: s.bind(('0.0.0.0',53))
        except: logging.error("Cannot bind port 53"); sys.exit(1)
    logging.info("EDNS Proxy on port 53 (Python fallback)")
    while running:
        try: data,addr=s.recvfrom(4096);threading.Thread(target=handle,args=(s,data,addr),daemon=True).start()
        except:pass
main()
EOF
chmod +x /usr/local/bin/dnstt-edns-proxy.py

echo -e "${YELLOW}📝 Creating monitoring scripts...${NC}"
create_bandwidth_monitor; create_connection_monitor; create_data_usage_monitor
create_user_script; create_main_menu

echo -e "${YELLOW}🚀 Starting services...${NC}"
systemctl daemon-reload 2>/dev/null || true
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon 3proxy-elite; do
    [ -f "/etc/systemd/system/${s}.service" ] && { systemctl enable "$s" 2>/dev/null || true; systemctl start "$s" 2>/dev/null || true; }
done

IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
[ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ] && { export ELITE_X_SHOWN=1; /usr/local/bin/elite-x; }
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'; alias elitex='elite-x'; alias adduser='elite-x-user add'
alias users='elite-x-user list'; alias setbw='elite-x-user setbw'
EOF

clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}     ELITE-X v3.3.2 FALCON ULTIMATE - INSTALLED!${GREEN}              ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Domain:${CYAN} $TDOMAIN${NC}"; echo -e "${GREEN}║${WHITE}  Location:${CYAN} $SEL_LOC (MTU: $MTU)${NC}"
echo -e "${GREEN}║${WHITE}  IP:${CYAN} $IP${NC}"; echo -e "${GREEN}║${WHITE}  Proxy:${CYAN} ${PROXY_TYPE}${NC}"
echo -e "${GREEN}║${WHITE}  IPv6:${RED} DISABLED${NC}"; echo -e "${GREEN}║${WHITE}  Kernel:${GREEN} BBR + 20MB Buff${NC}"
echo -e "${GREEN}║${WHITE}  Nice:${GREEN} -20 (Max Priority)${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
systemctl is-active dnstt-elite-x >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ DNSTT Server: Running${NC}" || echo -e "${RED}║  ❌ DNSTT Server: Failed${NC}"
systemctl is-active dnstt-elite-x-proxy >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ EDNS Proxy: Running${NC}" || echo -e "${RED}║  ❌ EDNS Proxy: Failed${NC}"
systemctl is-active elite-x-bandwidth >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ Bandwidth Monitor: Running${NC}" || echo -e "${RED}║  ❌ Bandwidth: Failed${NC}"
systemctl is-active 3proxy-elite >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ 3Proxy: Running${NC}" || echo -e "${YELLOW}║  ⚠️  3Proxy: Not running${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Commands: menu | elite-x | users | adduser | setbw${NC}"
echo -e "${YELLOW}Type 'exec bash' to access dashboard${NC}"
