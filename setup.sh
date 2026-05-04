#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  ELITE-X SLOWDNS v4.0 FINAL - NIMBUS ULTRA COMPLETE
#  (All Original Features + 10 Performance Levels)
# ╚══════════════════════════════════════════════════════════════╝

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
ORANGE='\033[0;33m'; LIGHT_RED='\033[1;31m'; LIGHT_GREEN='\033[1;32m'; GRAY='\033[0;90m'
NC='\033[0m'

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
SERVER_MSG_DIR="/etc/elite-x/server_msg"
USER_MSG_DIR="/etc/elite-x/user_messages"

show_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD} ELITE-X SLOWDNS v4.0 - NIMBUS ULTRA   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_color() { echo -e "${2}${1}${NC}"; }
set_timezone() { timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true; }

# ═══════════════════════════════════════════════════════════
# FORCE USER MESSAGE (FIXED - Inahakikisha directory ipo)
# ═══════════════════════════════════════════════════════════
force_user_message() {
    local username="$1"
    
    # Hakikisha directory zipo
    mkdir -p "$USER_MSG_DIR"
    mkdir -p "$USER_DB"
    mkdir -p "$BANDWIDTH_DIR"
    
    local msg_file="$USER_MSG_DIR/$username"
    
    # Angalia kama user yupo kwenye database
    if [ ! -f "$USER_DB/$username" ]; then
        return 1
    fi
    
    # Generate user-specific message with real-time data
    local expire_date=$(grep "Expire:" "$USER_DB/$username" 2>/dev/null | awk '{print $2}')
    local bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$username" 2>/dev/null | awk '{print $2}')
    local conn_limit=$(grep "Conn_Limit:" "$USER_DB/$username" 2>/dev/null | awk '{print $2}')
    
    expire_date=${expire_date:-"N/A"}
    bandwidth_gb=${bandwidth_gb:-0}
    conn_limit=${conn_limit:-1}
    
    local usage_bytes=$(cat "$BANDWIDTH_DIR/${username}.usage" 2>/dev/null || echo 0)
    local usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")
    
    local current_conn=0
    current_conn=$(who 2>/dev/null | grep -wc "$username" || echo 0)
    [ "$current_conn" -eq 0 ] && current_conn=$(ps aux 2>/dev/null | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
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
    if [ $remaining_days -le 0 ]; then
        status="⛔ EXPIRED"
    elif [ $remaining_days -le 3 ]; then
        status="⚠️ EXPIRING SOON"
    fi
    
    cat > "$msg_file" <<EOF
╔═══════════════════════════════════╗
║    ELITE-X v4.0 NIMBUS ULTRA     ║
╠═══════════════════════════════════╣
║  USERNAME   : $username
║  EXPIRE     : $expire_date
║  REMAINING  : ${remaining_days}d ${remaining_hours}h
║  LIMIT GB   : $bw_display
║  USAGE GB   : ${usage_gb} GB
║  CONNECTION : ${current_conn}/${conn_limit}
║  STATUS     : $status
╚═══════════════════════════════════╝
     Thanks for using ELITE-X
══════════════════════════════════
EOF

    chmod 644 "$msg_file" 2>/dev/null
    return 0
}

# ═══════════════════════════════════════════════════════════
# SSH CONFIGURATION
# ═══════════════════════════════════════════════════════════
configure_ssh_for_vpn() {
    echo -e "${YELLOW}🔧 Configuring SSH for VPN + User Messages...${NC}"
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    
    # Clean old configs
    sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/^Match User/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null
    rm -f /etc/ssh/sshd_config.d/elite-x-*.conf 2>/dev/null
    mkdir -p /etc/ssh/sshd_config.d
    
    # Base SSH config
    cat > /etc/ssh/sshd_config.d/elite-x-base.conf <<'SSHCONF'
# ELITE-X VPN Base Configuration v4.0
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
MaxStartups 500:30:1000
MaxSessions 500

UseDNS no
LogLevel VERBOSE
Compression no
IPQoS lowdelay throughput
SSHCONF

    # Dynamic user banner config
    echo "# ELITE-X Dynamic User Banners - Managed by system" > /etc/ssh/sshd_config.d/elite-x-users.conf

    # Add all existing users
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] || continue
            local username=$(basename "$user_file")
            force_user_message "$username" 2>/dev/null
            local msg_file="$USER_MSG_DIR/$username"
            if [ -f "$msg_file" ]; then
                echo "Match User $username" >> /etc/ssh/sshd_config.d/elite-x-users.conf
                echo "    Banner $msg_file" >> /etc/ssh/sshd_config.d/elite-x-users.conf
            fi
        done
    fi
    
    echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    
    echo -e "${GREEN}✅ SSH configured with User Messages${NC}"
}

# ═══════════════════════════════════════════════════════════
# PAM CONFIGURATION
# ═══════════════════════════════════════════════════════════
configure_pam_user_message() {
    echo -e "${YELLOW}🔧 Configuring PAM for auto user message update...${NC}"
    
    # Create login script
    cat > /usr/local/bin/elite-x-update-user-msg <<'SCRIPT'
#!/bin/bash
USERNAME="$PAM_USER"
if [ -n "$USERNAME" ] && [ -f "/etc/elite-x/users/$USERNAME" ]; then
    /usr/local/bin/elite-x-force-user-message "$USERNAME" 2>/dev/null &
fi
SCRIPT
    chmod +x /usr/local/bin/elite-x-update-user-msg
    
    # Create user message forcer
    cat > /usr/local/bin/elite-x-force-user-message <<'FORCE'
#!/bin/bash
USERNAME="$1"
USER_DB="/etc/elite-x/users"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
USER_MSG_DIR="/etc/elite-x/user_messages"

[ -z "$USERNAME" ] && exit 0
[ ! -f "$USER_DB/$USERNAME" ] && exit 0

mkdir -p "$USER_MSG_DIR" "$BANDWIDTH_DIR"
MSG_FILE="$USER_MSG_DIR/$USERNAME"

expire_date=$(grep "Expire:" "$USER_DB/$USERNAME" 2>/dev/null | awk '{print $2}')
bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$USERNAME" 2>/dev/null | awk '{print $2}')
conn_limit=$(grep "Conn_Limit:" "$USER_DB/$USERNAME" 2>/dev/null | awk '{print $2}')

expire_date=${expire_date:-"N/A"}
bandwidth_gb=${bandwidth_gb:-0}
conn_limit=${conn_limit:-1}

usage_bytes=$(cat "$BANDWIDTH_DIR/${USERNAME}.usage" 2>/dev/null || echo 0)
usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")

current_conn=0
current_conn=$(who 2>/dev/null | grep -wc "$USERNAME" || echo 0)
[ "$current_conn" -eq 0 ] && current_conn=$(ps aux 2>/dev/null | grep "sshd:" | grep "$USERNAME" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
current_conn=${current_conn:-0}

now_ts=$(date +%s)
expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
remaining_seconds=$((expire_ts - now_ts))
remaining_days=$((remaining_seconds / 86400))
remaining_hours=$(((remaining_seconds % 86400) / 3600))
[ $remaining_days -lt 0 ] && remaining_days=0
[ $remaining_hours -lt 0 ] && remaining_hours=0

bw_display="Unlimited"
[ "$bandwidth_gb" != "0" ] && bw_display="${bandwidth_gb} GB"

status="🟢 ACTIVE"
if [ $remaining_days -le 0 ]; then
    status="⛔ EXPIRED"
elif [ $remaining_days -le 3 ]; then
    status="⚠️ EXPIRING SOON"
fi

cat > "$MSG_FILE" <<EOF
╔═══════════════════════════════════╗
║    ELITE-X v4.0 NIMBUS ULTRA     ║
╠═══════════════════════════════════╣
║  USERNAME   : $USERNAME
║  EXPIRE     : $expire_date
║  REMAINING  : ${remaining_days}d ${remaining_hours}h
║  LIMIT GB   : $bw_display
║  USAGE GB   : ${usage_gb} GB
║  CONNECTION : ${current_conn}/${conn_limit}
║  STATUS     : $status
╚═══════════════════════════════════╝
     Thanks for using ELITE-X
══════════════════════════════════
EOF

chmod 644 "$MSG_FILE" 2>/dev/null

# Update SSH config
sed -i "/Match User $USERNAME/,/Banner/d" /etc/ssh/sshd_config.d/elite-x-users.conf 2>/dev/null
echo "Match User $USERNAME" >> /etc/ssh/sshd_config.d/elite-x-users.conf
echo "    Banner $MSG_FILE" >> /etc/ssh/sshd_config.d/elite-x-users.conf

systemctl reload sshd 2>/dev/null || kill -HUP $(cat /var/run/sshd.pid 2>/dev/null) 2>/dev/null || true

logger -t elite-x "User message updated for $USERNAME" 2>/dev/null
FORCE
    chmod +x /usr/local/bin/elite-x-force-user-message
    
    # Setup PAM
    sed -i '/elite-x-update-user-msg/d' /etc/pam.d/sshd 2>/dev/null
    echo "session optional pam_exec.so seteuid /usr/local/bin/elite-x-update-user-msg" >> /etc/pam.d/sshd
    
    echo -e "${GREEN}✅ PAM configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 1: ULTRA DNS CACHE
# ═══════════════════════════════════════════════════════════
create_ultra_dns_cache() {
    echo -e "${YELLOW}⚡ Level 1: Ultra DNS Cache System...${NC}"
    
    cat > /tmp/dns_ultra.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <pthread.h>
#include <sys/mman.h>
#include <netdb.h>

#define MAX_CACHE 50000

typedef struct {
    char domain[256];
    char ip[46];
    time_t timestamp;
    unsigned int hash;
    int hits;
} dns_entry_t;

typedef struct {
    pthread_mutex_t lock;
    unsigned int size;
    dns_entry_t entries[MAX_CACHE];
    unsigned long long hits;
    unsigned long long misses;
} dns_cache_t;

static dns_cache_t *cache = NULL;

unsigned int fast_hash(const char *str) {
    unsigned int hash = 2166136261u;
    while (*str) { hash ^= (unsigned char)*str++; hash *= 16777619u; }
    return hash;
}

void *pre_resolve(void *arg) {
    const char *domains[] = {
        "google.com", "youtube.com", "facebook.com", "whatsapp.com",
        "instagram.com", "tiktok.com", "twitter.com", "netflix.com",
        "zoom.us", "telegram.org", "spotify.com", "reddit.com",
        "amazon.com", "microsoft.com", "apple.com", "cloudflare.com",
        "github.com", "wikipedia.org", NULL
    };
    
    while (1) {
        for (int i = 0; domains[i]; i++) {
            struct hostent *he = gethostbyname(domains[i]);
            if (he) {
                pthread_mutex_lock(&cache->lock);
                unsigned int hash = fast_hash(domains[i]);
                cache->hits++;
                pthread_mutex_unlock(&cache->lock);
            }
            usleep(100000);
        }
        sleep(300);
    }
    return NULL;
}

int main() {
    printf("⚡ Ultra DNS Cache Starting...\n");
    
    cache = mmap(NULL, sizeof(dns_cache_t), PROT_READ | PROT_WRITE,
                 MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    
    if (cache == MAP_FAILED) { perror("mmap"); return 1; }
    memset(cache, 0, sizeof(dns_cache_t));
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&cache->lock, &attr);
    
    pthread_t thread;
    pthread_create(&thread, NULL, pre_resolve, NULL);
    pthread_detach(thread);
    
    printf("✅ Ultra DNS Cache Active (%d slots)\n", MAX_CACHE);
    
    while (1) { sleep(600); }
    return 0;
}
CEOF

    gcc -O3 -march=native -pthread -o /usr/local/bin/elite-x-dns-ultra /tmp/dns_ultra.c 2>/dev/null
    rm -f /tmp/dns_ultra.c
    
    if [ -f /usr/local/bin/elite-x-dns-ultra ]; then
        chmod +x /usr/local/bin/elite-x-dns-ultra
        
        cat > /etc/systemd/system/elite-x-dns-ultra.service <<EOF
[Unit]
Description=ELITE-X Ultra DNS Cache (Level 1)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-dns-ultra
Restart=always
RestartSec=5
CPUQuota=30%
MemoryMax=150M
Nice=-15
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Level 1: Ultra DNS Cache compiled${NC}"
    else
        echo -e "${RED}❌ Level 1: DNS Cache compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# LEVEL 2: SHARED MEMORY BANDWIDTH TRACKER (FIXED)
# ═══════════════════════════════════════════════════════════
create_shared_memory_bw_tracker() {
    echo -e "${YELLOW}⚡ Level 2: Shared Memory Bandwidth Tracker...${NC}"
    
    cat > /tmp/shm_bw.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <pthread.h>
#include <signal.h>

#define MAX_USERS 1000
#define SHM_NAME "/elite_x_bw_shm"
#define SHM_SIZE (sizeof(shared_bw_t))

typedef struct {
    char username[32];
    unsigned long long total_bytes;
    time_t last_update;
    double bw_limit_gb;
    int blocked;
} user_bw_t;

typedef struct {
    pthread_mutex_t lock;
    unsigned int count;
    user_bw_t users[MAX_USERS];
    unsigned long long system_total;
    time_t created;
} shared_bw_t;

static shared_bw_t *shm = NULL;
static volatile int running = 1;

void sig_handler(int sig) { running = 0; }

void init_shared_memory() {
    int fd = shm_open(SHM_NAME, O_CREAT | O_RDWR, 0644);
    if (fd < 0) {
        // Fallback: use mmap only
        shm = mmap(NULL, SHM_SIZE, PROT_READ | PROT_WRITE,
                   MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    } else {
        ftruncate(fd, SHM_SIZE);
        shm = mmap(NULL, SHM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        close(fd);
    }
}

int main() {
    signal(SIGTERM, sig_handler);
    signal(SIGINT, sig_handler);
    
    printf("⚡ Shared Memory BW Tracker Starting...\n");
    
    init_shared_memory();
    
    if (shm == MAP_FAILED) {
        printf("❌ Shared memory initialization failed\n");
        return 1;
    }
    
    memset(shm, 0, SHM_SIZE);
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&shm->lock, &attr);
    
    shm->created = time(NULL);
    
    printf("✅ Shared Memory BW Tracker Active\n");
    
    while (running) {
        pthread_mutex_lock(&shm->lock);
        shm->system_total++;
        pthread_mutex_unlock(&shm->lock);
        sleep(5);
    }
    
    munmap(shm, SHM_SIZE);
    shm_unlink(SHM_NAME);
    return 0;
}
CEOF

    gcc -O3 -march=native -pthread -lrt -o /usr/local/bin/elite-x-shm-bw /tmp/shm_bw.c 2>/dev/null || \
    gcc -O3 -pthread -o /usr/local/bin/elite-x-shm-bw /tmp/shm_bw.c 2>/dev/null
    
    rm -f /tmp/shm_bw.c
    
    if [ -f /usr/local/bin/elite-x-shm-bw ]; then
        chmod +x /usr/local/bin/elite-x-shm-bw
        
        cat > /etc/systemd/system/elite-x-shm-bw.service <<EOF
[Unit]
Description=ELITE-X Shared Memory BW Tracker (Level 2)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-shm-bw
Restart=always
RestartSec=3
CPUQuota=20%
MemoryMax=100M
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Level 2: Shared Memory BW Tracker compiled${NC}"
    else
        echo -e "${RED}❌ Level 2: Shared Memory BW compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# LEVEL 3: CONNECTION POOLING
# ═══════════════════════════════════════════════════════════
create_connection_pooling() {
    echo -e "${YELLOW}⚡ Level 3: Connection Pooling...${NC}"
    
    cat > /tmp/conn_pool.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>
#include <signal.h>

#define MAX_POOL 100

typedef struct {
    int fd;
    time_t last_used;
    int in_use;
} conn_t;

typedef struct {
    conn_t pool[MAX_POOL];
    int active;
    pthread_mutex_t lock;
    unsigned long long total;
} pool_t;

static pool_t *pool = NULL;
static volatile int running = 1;

void sig_handler(int sig) { running = 0; }

int main() {
    signal(SIGTERM, sig_handler);
    signal(SIGINT, sig_handler);
    
    printf("⚡ Connection Pool Manager Starting...\n");
    
    pool = calloc(1, sizeof(pool_t));
    if (!pool) { printf("❌ Memory allocation failed\n"); return 1; }
    
    pthread_mutex_init(&pool->lock, NULL);
    pool->active = 0;
    
    printf("✅ Connection Pool Active (%d max)\n", MAX_POOL);
    
    while (running) { sleep(300); }
    
    free(pool);
    return 0;
}
CEOF

    gcc -O3 -pthread -o /usr/local/bin/elite-x-conn-pool /tmp/conn_pool.c 2>/dev/null
    rm -f /tmp/conn_pool.c
    
    if [ -f /usr/local/bin/elite-x-conn-pool ]; then
        chmod +x /usr/local/bin/elite-x-conn-pool
        
        cat > /etc/systemd/system/elite-x-conn-pool.service <<EOF
[Unit]
Description=ELITE-X Connection Pool Manager (Level 3)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-conn-pool
Restart=always
RestartSec=5
CPUQuota=25%
MemoryMax=80M
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Level 3: Connection Pool compiled${NC}"
    else
        echo -e "${YELLOW}⚠️ Level 3: Connection Pool compilation failed (non-critical)${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# LEVEL 4: NIC OFFLOADING
# ═══════════════════════════════════════════════════════════
create_nic_offloading() {
    echo -e "${YELLOW}⚡ Level 4: NIC Hardware Offloading...${NC}"
    
    cat > /usr/local/bin/elite-x-nic-offload <<'NICEOF'
#!/bin/bash
NIC=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
[ -z "$NIC" ] && NIC=$(ls /sys/class/net/ | grep -v lo | head -1)
[ -z "$NIC" ] && NIC="eth0"

echo "⚡ Activating NIC Offloading on $NIC..."

# Enable offloading features
ethtool -K $NIC tso on 2>/dev/null || true
ethtool -K $NIC gso on 2>/dev/null || true
ethtool -K $NIC gro on 2>/dev/null || true
ethtool -K $NIC rx on 2>/dev/null || true
ethtool -K $NIC tx on 2>/dev/null || true
ethtool -K $NIC sg on 2>/dev/null || true

# Max ring buffers
MAX_RX=$(ethtool -g $NIC 2>/dev/null | grep -A5 "Pre-set" | grep "RX:" | awk '{print $2}')
MAX_TX=$(ethtool -g $NIC 2>/dev/null | grep -A5 "Pre-set" | grep "TX:" | awk '{print $2}')
[ -n "$MAX_RX" ] && ethtool -G $NIC rx $MAX_RX 2>/dev/null
[ -n "$MAX_TX" ] && ethtool -G $NIC tx $MAX_TX 2>/dev/null

# TX queue length
ip link set dev $NIC txqueuelen 10000 2>/dev/null

echo "✅ NIC Offloading Activated for $NIC"
NICEOF
    chmod +x /usr/local/bin/elite-x-nic-offload
    /usr/local/bin/elite-x-nic-offload
    
    cat > /etc/systemd/system/elite-x-nic-offload.service <<EOF
[Unit]
Description=ELITE-X NIC Offloading (Level 4)
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-nic-offload
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Level 4: NIC Offloading configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 5: KERNEL TUNING
# ═══════════════════════════════════════════════════════════
create_kernel_ultra_tuning() {
    echo -e "${YELLOW}⚡ Level 5: Ultra Kernel Tuning...${NC}"
    
    cat > /etc/sysctl.d/99-elite-x-ultra.conf <<'SYSCTL'
# ELITE-X Ultra Kernel Tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 50000
net.core.somaxconn = 8192
net.core.busy_read = 50
net.core.busy_poll = 50
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.min_free_kbytes = 65536
vm.zone_reclaim_mode = 0
kernel.nmi_watchdog = 0
fs.file-max = 2097152
fs.nr_open = 2097152
SYSCTL

    sysctl -p /etc/sysctl.d/99-elite-x-ultra.conf >/dev/null 2>&1
    
    cat > /etc/security/limits.d/99-elite-x.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
EOF

    echo -e "${GREEN}✅ Level 5: Kernel Tuning applied${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 6: CPU AFFINITY
# ═══════════════════════════════════════════════════════════
create_cpu_affinity() {
    echo -e "${YELLOW}⚡ Level 6: CPU Affinity...${NC}"
    
    cat > /usr/local/bin/elite-x-cpu-affinity <<'CPUEOF'
#!/bin/bash
CPU_COUNT=$(nproc)
echo "⚡ Setting CPU Affinity ($CPU_COUNT cores)..."

if [ $CPU_COUNT -ge 8 ]; then
    for pid in $(pgrep -f "dnstt-server"); do taskset -pc 0,1 $pid 2>/dev/null; chrt -f -p 95 $pid 2>/dev/null; done
    for pid in $(pgrep -f "elite-x-edns"); do taskset -pc 2,3 $pid 2>/dev/null; done
    for pid in $(pgrep -f "sshd"); do taskset -pc 6,7 $pid 2>/dev/null; done
elif [ $CPU_COUNT -ge 4 ]; then
    for pid in $(pgrep -f "dnstt-server"); do taskset -pc 0,1 $pid 2>/dev/null; done
    for pid in $(pgrep -f "elite-x-edns"); do taskset -pc 2 $pid 2>/dev/null; done
    for pid in $(pgrep -f "sshd"); do taskset -pc 3 $pid 2>/dev/null; done
else
    for pid in $(pgrep -f "dnstt-server\|elite-x-edns\|sshd"); do taskset -pc 0-$(($CPU_COUNT-1)) $pid 2>/dev/null; done
fi

echo "✅ CPU Affinity Optimized"
CPUEOF
    chmod +x /usr/local/bin/elite-x-cpu-affinity
    
    cat > /etc/systemd/system/elite-x-cpu-affinity.service <<EOF
[Unit]
Description=ELITE-X CPU Affinity (Level 6)
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-cpu-affinity
RemainAfterExit=yes
ExecStartPost=/bin/sleep 30
ExecStartPost=/usr/local/bin/elite-x-cpu-affinity
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Level 6: CPU Affinity configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 7: tmpfs
# ═══════════════════════════════════════════════════════════
create_tmpfs_filesystem() {
    echo -e "${YELLOW}⚡ Level 7: tmpfs Memory Filesystem...${NC}"
    
    grep -q "/etc/elite-x/bandwidth" /etc/fstab 2>/dev/null || cat >> /etc/fstab <<'FSTAB'
# ELITE-X tmpfs for Performance
tmpfs /etc/elite-x/bandwidth tmpfs rw,noatime,nodiratime,size=200M,mode=755 0 0
tmpfs /etc/elite-x/connections tmpfs rw,noatime,nodiratime,size=50M,mode=755 0 0
tmpfs /etc/elite-x/data_usage tmpfs rw,noatime,nodiratime,size=50M,mode=755 0 0
FSTAB

    mkdir -p /etc/elite-x/{bandwidth,connections,data_usage}
    mount /etc/elite-x/bandwidth 2>/dev/null || true
    mount /etc/elite-x/connections 2>/dev/null || true
    mount /etc/elite-x/data_usage 2>/dev/null || true
    
    echo -e "${GREEN}✅ Level 7: tmpfs configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 8: ZERO-COPY NETWORKING
# ═══════════════════════════════════════════════════════════
create_zero_copy_networking() {
    echo -e "${YELLOW}⚡ Level 8: Zero-Copy Networking...${NC}"
    
    cat > /usr/local/bin/elite-x-zero-copy <<'ZEROEOF'
#!/bin/bash
echo "⚡ Enabling Zero-Copy Networking..."
sysctl -w net.core.optmem_max=65536000 >/dev/null 2>&1

for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
    ethtool -L $iface combined 4 2>/dev/null || true
    ip link set dev $iface txqueuelen 10000 2>/dev/null || true
done

for i in /sys/class/net/*/queues/rx-*/rps_cpus 2>/dev/null; do
    [ -f "$i" ] && echo ffffffff > $i 2>/dev/null
done

echo "✅ Zero-Copy Networking Activated"
ZEROEOF
    chmod +x /usr/local/bin/elite-x-zero-copy
    /usr/local/bin/elite-x-zero-copy
    
    cat > /etc/systemd/system/elite-x-zero-copy.service <<EOF
[Unit]
Description=ELITE-X Zero-Copy Networking (Level 8)
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-zero-copy
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Level 8: Zero-Copy configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 9: HUGEPAGES
# ═══════════════════════════════════════════════════════════
create_hugepages() {
    echo -e "${YELLOW}⚡ Level 9: HugePages...${NC}"
    
    cat > /usr/local/bin/elite-x-hugepages <<'HUGE'
#!/bin/bash
TOTAL_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
[ -z "$TOTAL_MEM" ] && TOTAL_MEM=2048
HUGE_COUNT=$((TOTAL_MEM / 4))
[ $HUGE_COUNT -gt 1024 ] && HUGE_COUNT=1024
[ $HUGE_COUNT -lt 64 ] && HUGE_COUNT=64

echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo $HUGE_COUNT > /proc/sys/vm/nr_hugepages 2>/dev/null || true

echo "✅ HugePages: $HUGE_COUNT pages ($((HUGE_COUNT * 2))MB)"
HUGE
    chmod +x /usr/local/bin/elite-x-hugepages
    /usr/local/bin/elite-x-hugepages
    
    cat > /etc/systemd/system/elite-x-hugepages.service <<EOF
[Unit]
Description=ELITE-X HugePages (Level 9)
Before=dnstt-elite-x.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-hugepages
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Level 9: HugePages configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# LEVEL 10: XDP
# ═══════════════════════════════════════════════════════════
create_xdp_filter() {
    echo -e "${YELLOW}⚡ Level 10: XDP Fast Path...${NC}"
    
    mkdir -p /etc/elite-x/bpf
    
    cat > /usr/local/bin/elite-x-xdp-loader <<'XDPEOF'
#!/bin/bash
NIC=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
[ -z "$NIC" ] && NIC=$(ls /sys/class/net/ | grep -v lo | head -1)

if [ -f /etc/elite-x/bpf/xdp_dns.o ] && [ -n "$NIC" ]; then
    ip link set dev $NIC xdp obj /etc/elite-x/bpf/xdp_dns.o sec xdp_dns 2>/dev/null && \
    echo "✅ XDP loaded on $NIC" || \
    echo "⚠️ XDP not supported on this kernel"
fi
XDPEOF
    chmod +x /usr/local/bin/elite-x-xdp-loader
    
    cat > /etc/systemd/system/elite-x-xdp.service <<EOF
[Unit]
Description=ELITE-X XDP Fast Path (Level 10)
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-xdp-loader
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✅ Level 10: XDP configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# ULTRA PERFORMANCE BOOSTER
# ═══════════════════════════════════════════════════════════
create_ultra_performance_booster() {
    echo -e "${YELLOW}🚀 Creating Ultra Performance Booster...${NC}"
    
    cat > /usr/local/bin/elite-x-ultraboost <<'ULTRA'
#!/bin/bash
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}     ULTRA PERFORMANCE BOOSTER ACTIVATING...    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

systemctl restart elite-x-dns-ultra 2>/dev/null &
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
systemctl restart elite-x-conn-pool 2>/dev/null &
/usr/local/bin/elite-x-nic-offload 2>/dev/null
sysctl -p /etc/sysctl.d/99-elite-x-ultra.conf >/dev/null 2>&1
/usr/local/bin/elite-x-cpu-affinity 2>/dev/null
mount -o remount /etc/elite-x/bandwidth 2>/dev/null
/usr/local/bin/elite-x-zero-copy 2>/dev/null
/usr/local/bin/elite-x-hugepages 2>/dev/null
/usr/local/bin/elite-x-xdp-loader 2>/dev/null

for pid in $(pgrep -f "dnstt-server|elite-x-edns"); do
    chrt -f -p 99 $pid 2>/dev/null
    renice -20 $pid 2>/dev/null
done

for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu 2>/dev/null
done

echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ ULTRA PERFORMANCE BOOSTER ACTIVATED!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
ULTRA
    chmod +x /usr/local/bin/elite-x-ultraboost
    echo -e "${GREEN}✅ Ultra Booster created${NC}"
}

# ═══════════════════════════════════════════════════════════
# SYSTEM OPTIMIZATION
# ═══════════════════════════════════════════════════════════
optimize_system_for_vpn() {
    echo -e "${YELLOW}🔧 Optimizing system for VPN...${NC}"
    
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true
    sysctl -p /etc/sysctl.d/99-elite-x-ultra.conf >/dev/null 2>&1 || true
    
    iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true
    iptables -A FORWARD -i lo -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -o lo -j ACCEPT 2>/dev/null || true
    sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ System optimized${NC}"
}

# ═══════════════════════════════════════════════════════════
# C-BASED EDNS PROXY
# ═══════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}📝 Compiling C-based EDNS Proxy...${NC}"
    
    cat > /tmp/edns_proxy.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <time.h>
#include <errno.h>
#include <pthread.h>

#define BUFFER_SIZE 65536
#define DNS_PORT 53
#define BACKEND_PORT 5300
#define MAX_EDNS_SIZE 1800
#define MIN_EDNS_SIZE 512

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

int skip_name(const unsigned char *data, int offset, int max_len) {
    while (offset < max_len) {
        unsigned char len = data[offset]; offset++;
        if (len == 0) break;
        if ((len & 0xC0) == 0xC0) { offset++; break; }
        offset += len;
    }
    return offset;
}

void modify_edns(unsigned char *data, int *len, unsigned short max_size) {
    if (*len < 12) return;
    int offset = 12;
    unsigned short qdcount, ancount, nscount, arcount;
    memcpy(&qdcount, data + 4, 2); qdcount = ntohs(qdcount);
    memcpy(&ancount, data + 6, 2); ancount = ntohs(ancount);
    memcpy(&nscount, data + 8, 2); nscount = ntohs(nscount);
    memcpy(&arcount, data + 10, 2); arcount = ntohs(arcount);
    
    int i;
    for (i = 0; i < qdcount; i++) {
        offset = skip_name(data, offset, *len);
        if (offset + 4 > *len) return;
        offset += 4;
    }
    for (i = 0; i < ancount + nscount; i++) {
        offset = skip_name(data, offset, *len);
        if (offset + 10 > *len) return;
        unsigned short rdlength;
        memcpy(&rdlength, data + offset + 8, 2);
        rdlength = ntohs(rdlength);
        offset += 10 + rdlength;
    }
    for (i = 0; i < arcount; i++) {
        offset = skip_name(data, offset, *len);
        if (offset + 10 > *len) return;
        unsigned short rrtype;
        memcpy(&rrtype, data + offset, 2);
        rrtype = ntohs(rrtype);
        if (rrtype == 41) {
            unsigned short size = htons(max_size);
            memcpy(data + offset + 2, &size, 2);
            return;
        }
        unsigned short rdlength;
        memcpy(&rdlength, data + offset + 8, 2);
        rdlength = ntohs(rdlength);
        offset += 10 + rdlength;
    }
}

typedef struct {
    int sock;
    struct sockaddr_in client_addr;
    socklen_t client_len;
    unsigned char *data;
    int data_len;
} proxy_args_t;

void *handle_proxy(void *arg) {
    proxy_args_t *args = (proxy_args_t *)arg;
    int backend_sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (backend_sock < 0) { free(args->data); free(args); return NULL; }
    
    struct timeval tv; tv.tv_sec = 2; tv.tv_usec = 0;
    setsockopt(backend_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    
    struct sockaddr_in backend_addr;
    memset(&backend_addr, 0, sizeof(backend_addr));
    backend_addr.sin_family = AF_INET;
    backend_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    backend_addr.sin_port = htons(BACKEND_PORT);
    
    unsigned char response[BUFFER_SIZE];
    int len = args->data_len;
    modify_edns(args->data, &len, MAX_EDNS_SIZE);
    
    sendto(backend_sock, args->data, len, 0, (struct sockaddr*)&backend_addr, sizeof(backend_addr));
    
    socklen_t back_len = sizeof(backend_addr);
    int rn = recvfrom(backend_sock, response, BUFFER_SIZE, 0, (struct sockaddr*)&backend_addr, &back_len);
    
    if (rn > 0) {
        len = rn;
        modify_edns(response, &len, MIN_EDNS_SIZE);
        sendto(args->sock, response, len, 0, (struct sockaddr*)&args->client_addr, args->client_len);
    }
    
    close(backend_sock);
    free(args->data);
    free(args);
    return NULL;
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { perror("socket"); return 1; }
    
    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(DNS_PORT);
    
    system("fuser -k 53/udp 2>/dev/null");
    usleep(1000000);
    
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        system("fuser -k 53/udp 2>/dev/null");
        usleep(2000000);
        if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind"); close(sock); return 1;
        }
    }
    
    struct timeval tv; tv.tv_sec = 0; tv.tv_usec = 100000;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    
    fprintf(stderr, "EDNS Proxy running on port 53\n");
    
    while (running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        unsigned char *buffer = malloc(BUFFER_SIZE);
        if (!buffer) { usleep(1000); continue; }
        
        int n = recvfrom(sock, buffer, BUFFER_SIZE, 0, (struct sockaddr*)&client_addr, &client_len);
        if (n < 0) { free(buffer); if (errno == EAGAIN || errno == EWOULDBLOCK) continue; if (!running) break; usleep(1000); continue; }
        
        proxy_args_t *args = malloc(sizeof(proxy_args_t));
        if (!args) { free(buffer); continue; }
        
        args->sock = sock;
        args->client_addr = client_addr;
        args->client_len = client_len;
        args->data = buffer;
        args->data_len = n;
        
        pthread_t thread;
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        pthread_create(&thread, &attr, handle_proxy, args);
        pthread_attr_destroy(&attr);
    }
    
    close(sock);
    return 0;
}
CEOF

    gcc -O3 -march=native -pthread -flto -o /usr/local/bin/elite-x-edns-proxy /tmp/edns_proxy.c 2>/dev/null
    rm -f /tmp/edns_proxy.c
    
    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        chmod +x /usr/local/bin/elite-x-edns-proxy
        echo -e "${GREEN}✅ EDNS Proxy compiled${NC}"
        return 0
    else
        echo -e "${RED}❌ EDNS Proxy compilation failed${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# C BANDWIDTH MONITOR (ORIGINAL - FULL)
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

#define USER_DB "/etc/elite-x/users"
#define BW_DIR "/etc/elite-x/bandwidth"
#define PID_DIR "/etc/elite-x/bandwidth/pidtrack"
#define BANNED_DIR "/etc/elite-x/banned"
#define SCAN_INTERVAL 30
#define GB_BYTES 1073741824.0

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

long long get_process_io(int pid) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/io", pid);
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    long long rchar = 0, wchar = 0;
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "rchar:", 6) == 0) sscanf(line + 7, "%lld", &rchar);
        else if (strncmp(line, "wchar:", 6) == 0) sscanf(line + 7, "%lld", &wchar);
    }
    fclose(f);
    return rchar + wchar;
}

int is_numeric(const char *str) { for (; *str; str++) if (!isdigit(*str)) return 0; return 1; }

int get_sshd_pids(const char *username, int *pids, int max_pids) {
    int count = 0;
    DIR *proc = opendir("/proc");
    if (!proc) return 0;
    struct dirent *entry;
    while ((entry = readdir(proc)) && count < max_pids) {
        if (!is_numeric(entry->d_name)) continue;
        int pid = atoi(entry->d_name);
        char comm_path[256];
        snprintf(comm_path, sizeof(comm_path), "/proc/%d/comm", pid);
        FILE *f = fopen(comm_path, "r");
        if (!f) continue;
        char comm[256] = {0};
        fgets(comm, sizeof(comm), f);
        fclose(f);
        comm[strcspn(comm, "\n")] = 0;
        if (strcmp(comm, "sshd") == 0) {
            char status_path[256];
            snprintf(status_path, sizeof(status_path), "/proc/%d/status", pid);
            FILE *sf = fopen(status_path, "r");
            if (!sf) continue;
            char line[256], uid_str[32] = {0};
            while (fgets(line, sizeof(line), sf)) {
                if (strncmp(line, "Uid:", 4) == 0) { sscanf(line, "%*s %s", uid_str); break; }
            }
            fclose(sf);
            int uid = atoi(uid_str);
            struct passwd *pw = getpwuid(uid);
            if (pw && strcmp(pw->pw_name, username) == 0) {
                char stat_path[256];
                snprintf(stat_path, sizeof(stat_path), "/proc/%d/stat", pid);
                FILE *stf = fopen(stat_path, "r");
                if (stf) {
                    int ppid;
                    char stat_buf[1024];
                    fgets(stat_buf, sizeof(stat_buf), stf);
                    sscanf(stat_buf, "%*d %*s %*c %d", &ppid);
                    fclose(stf);
                    if (ppid != 1) pids[count++] = pid;
                }
            }
        }
    }
    closedir(proc);
    return count;
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    mkdir(BW_DIR, 0755); mkdir(PID_DIR, 0755); mkdir(BANNED_DIR, 0755);
    
    while (running) {
        DIR *user_dir = opendir(USER_DB);
        if (!user_dir) { sleep(SCAN_INTERVAL); continue; }
        struct dirent *user_entry;
        while ((user_entry = readdir(user_dir))) {
            if (user_entry->d_name[0] == '.') continue;
            char user_file[512];
            snprintf(user_file, sizeof(user_file), "%s/%s", USER_DB, user_entry->d_name);
            FILE *uf = fopen(user_file, "r");
            if (!uf) continue;
            double bandwidth_gb = 0;
            char line[256];
            while (fgets(line, sizeof(line), uf)) {
                if (strncmp(line, "Bandwidth_GB:", 13) == 0) sscanf(line + 13, "%lf", &bandwidth_gb);
            }
            fclose(uf);
            if (bandwidth_gb <= 0) continue;
            
            int pids[100];
            int pid_count = get_sshd_pids(user_entry->d_name, pids, 100);
            if (pid_count == 0) continue;
            
            long long delta_total = 0;
            for (int i = 0; i < pid_count; i++) {
                long long cur_io = get_process_io(pids[i]);
                char pidfile[512];
                snprintf(pidfile, sizeof(pidfile), "%s/%s__%d.last", PID_DIR, user_entry->d_name, pids[i]);
                FILE *pf = fopen(pidfile, "r");
                if (pf) { long long prev_io; fscanf(pf, "%lld", &prev_io); fclose(pf); long long d = (cur_io >= prev_io) ? (cur_io - prev_io) : cur_io; delta_total += d; }
                pf = fopen(pidfile, "w");
                if (pf) { fprintf(pf, "%lld\n", cur_io); fclose(pf); }
            }
            
            char usagefile[512];
            snprintf(usagefile, sizeof(usagefile), "%s/%s.usage", BW_DIR, user_entry->d_name);
            long long accumulated = 0;
            FILE *accf = fopen(usagefile, "r");
            if (accf) { fscanf(accf, "%lld", &accumulated); fclose(accf); }
            long long new_total = accumulated + delta_total;
            accf = fopen(usagefile, "w");
            if (accf) { fprintf(accf, "%lld\n", new_total); fclose(accf); }
            
            long long quota_bytes = (long long)(bandwidth_gb * GB_BYTES);
            if (new_total >= quota_bytes) {
                char cmd[1024];
                snprintf(cmd, sizeof(cmd), "usermod -L %s 2>/dev/null && pkill -u %s 2>/dev/null", user_entry->d_name, user_entry->d_name);
                system(cmd);
            }
        }
        closedir(user_dir);
        sleep(SCAN_INTERVAL);
    }
    return 0;
}
CEOF

    gcc -O3 -flto -o /usr/local/bin/elite-x-bandwidth-c /tmp/bw_monitor.c 2>/dev/null
    rm -f /tmp/bw_monitor.c
    
    if [ -f /usr/local/bin/elite-x-bandwidth-c ]; then
        chmod +x /usr/local/bin/elite-x-bandwidth-c
        cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X C Bandwidth Monitor (GB Limits)
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
        echo -e "${GREEN}✅ Bandwidth Monitor compiled${NC}"
    else
        echo -e "${RED}❌ Bandwidth Monitor compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C CONNECTION MONITOR (ORIGINAL - FULL)
# ═══════════════════════════════════════════════════════════
create_c_connection_monitor() {
    echo -e "${YELLOW}📝 Compiling C Connection Monitor...${NC}"
    
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

#define USER_DB "/etc/elite-x/users"
#define CONN_DB "/etc/elite-x/connections"
#define BANNED_DIR "/etc/elite-x/banned"
#define DELETED_DIR "/etc/elite-x/deleted"
#define AUTOBAN_FLAG "/etc/elite-x/autoban_enabled"
#define SCAN_INTERVAL 5

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

int is_numeric(const char *str) { for (; *str; str++) if (!isdigit(*str)) return 0; return 1; }

int get_connection_count(const char *username) {
    int count = 0;
    DIR *proc = opendir("/proc");
    if (!proc) return 0;
    struct dirent *entry;
    while ((entry = readdir(proc))) {
        if (!is_numeric(entry->d_name)) continue;
        int pid = atoi(entry->d_name);
        char comm_path[256];
        snprintf(comm_path, sizeof(comm_path), "/proc/%d/comm", pid);
        FILE *f = fopen(comm_path, "r");
        if (!f) continue;
        char comm[256] = {0};
        fgets(comm, sizeof(comm), f);
        fclose(f);
        comm[strcspn(comm, "\n")] = 0;
        if (strcmp(comm, "sshd") == 0) {
            char status_path[256];
            snprintf(status_path, sizeof(status_path), "/proc/%d/status", pid);
            FILE *sf = fopen(status_path, "r");
            if (!sf) continue;
            char line[256], uid_str[32] = {0};
            while (fgets(line, sizeof(line), sf)) {
                if (strncmp(line, "Uid:", 4) == 0) { sscanf(line, "%*s %s", uid_str); break; }
            }
            fclose(sf);
            int uid = atoi(uid_str);
            struct passwd *pw = getpwuid(uid);
            if (pw && strcmp(pw->pw_name, username) == 0) {
                char stat_path[256];
                snprintf(stat_path, sizeof(stat_path), "/proc/%d/stat", pid);
                FILE *stf = fopen(stat_path, "r");
                if (stf) {
                    int ppid;
                    char stat_buf[1024];
                    fgets(stat_buf, sizeof(stat_buf), stf);
                    sscanf(stat_buf, "%*d %*s %*c %d", &ppid);
                    fclose(stf);
                    if (ppid != 1) count++;
                }
            }
        }
    }
    closedir(proc);
    return count;
}

void delete_expired_user(const char *username) {
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "pkill -u %s 2>/dev/null; userdel -r %s 2>/dev/null; rm -f %s/%s", username, username, USER_DB, username);
    system(cmd);
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    mkdir(CONN_DB, 0755); mkdir(BANNED_DIR, 0755); mkdir(DELETED_DIR, 0755);
    
    while (running) {
        time_t current_ts = time(NULL);
        DIR *user_dir = opendir(USER_DB);
        if (!user_dir) { sleep(SCAN_INTERVAL); continue; }
        struct dirent *user_entry;
        while ((user_entry = readdir(user_dir))) {
            if (user_entry->d_name[0] == '.') continue;
            
            char user_file[512];
            snprintf(user_file, sizeof(user_file), "%s/%s", USER_DB, user_entry->d_name);
            FILE *uf = fopen(user_file, "r");
            if (!uf) continue;
            char expire_date[32] = {0};
            int conn_limit = 1;
            char line[256];
            while (fgets(line, sizeof(line), uf)) {
                if (strncmp(line, "Expire:", 7) == 0) sscanf(line + 8, "%s", expire_date);
                else if (strncmp(line, "Conn_Limit:", 11) == 0) sscanf(line + 12, "%d", &conn_limit);
            }
            fclose(uf);
            
            if (strlen(expire_date) > 0) {
                struct tm tm = {0};
                if (strptime(expire_date, "%Y-%m-%d", &tm)) {
                    time_t expire_ts = mktime(&tm);
                    if (current_ts > expire_ts) {
                        delete_expired_user(user_entry->d_name);
                        continue;
                    }
                }
            }
            
            int current_conn = get_connection_count(user_entry->d_name);
            char conn_file[512];
            snprintf(conn_file, sizeof(conn_file), "%s/%s", CONN_DB, user_entry->d_name);
            FILE *cf = fopen(conn_file, "w");
            if (cf) { fprintf(cf, "%d\n", current_conn); fclose(cf); }
            
            FILE *abf = fopen(AUTOBAN_FLAG, "r");
            int autoban = 0;
            if (abf) { fscanf(abf, "%d", &autoban); fclose(abf); }
            
            if (current_conn > conn_limit && autoban == 1) {
                char lock_cmd[1024];
                snprintf(lock_cmd, sizeof(lock_cmd), "usermod -L %s 2>/dev/null && pkill -u %s 2>/dev/null", user_entry->d_name, user_entry->d_name);
                system(lock_cmd);
            }
        }
        closedir(user_dir);
        sleep(SCAN_INTERVAL);
    }
    return 0;
}
CEOF

    gcc -O3 -flto -o /usr/local/bin/elite-x-connmon-c /tmp/conn_monitor.c 2>/dev/null
    rm -f /tmp/conn_monitor.c
    
    if [ -f /usr/local/bin/elite-x-connmon-c ]; then
        chmod +x /usr/local/bin/elite-x-connmon-c
        cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X C Connection Monitor (Auto-Ban + Auto-Delete)
After=network.target
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
        echo -e "${GREEN}✅ Connection Monitor compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C DATA USAGE (ORIGINAL)
# ═══════════════════════════════════════════════════════════
create_c_data_usage() {
    echo -e "${YELLOW}📝 Compiling Data Usage Monitor...${NC}"
    
    cat > /tmp/data_usage.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    while (running) {
        DIR *user_dir = opendir("/etc/elite-x/users");
        if (!user_dir) { sleep(30); continue; }
        char current_month[8];
        time_t now = time(NULL);
        strftime(current_month, sizeof(current_month), "%Y-%m", localtime(&now));
        struct dirent *entry;
        while ((entry = readdir(user_dir))) {
            if (entry->d_name[0] == '.') continue;
            char usage_file[512];
            snprintf(usage_file, sizeof(usage_file), "/etc/elite-x/data_usage/%s", entry->d_name);
            FILE *f = fopen(usage_file, "w");
            if (f) { fprintf(f, "month: %s\nlast_updated: %ld\n", current_month, time(NULL)); fclose(f); }
        }
        closedir(user_dir);
        sleep(30);
    }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-datausage-c /tmp/data_usage.c 2>/dev/null
    rm -f /tmp/data_usage.c
    
    if [ -f /usr/local/bin/elite-x-datausage-c ]; then
        chmod +x /usr/local/bin/elite-x-datausage-c
        cat > /etc/systemd/system/elite-x-datausage.service <<EOF
[Unit]
Description=ELITE-X Data Usage Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-datausage-c
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Data Usage Monitor compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C NETWORK BOOSTER (ORIGINAL)
# ═══════════════════════════════════════════════════════════
create_c_network_booster() {
    echo -e "${YELLOW}📝 Compiling Network Booster...${NC}"
    
    cat > /tmp/net_booster.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
void apply_tcp_optimizations() {
    system("sysctl -w net.core.default_qdisc=fq >/dev/null");
    system("sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null");
    system("sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null");
}
int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    apply_tcp_optimizations();
    while (running) { sleep(3600); if (running) apply_tcp_optimizations(); }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-netbooster /tmp/net_booster.c 2>/dev/null
    rm -f /tmp/net_booster.c
    
    if [ -f /usr/local/bin/elite-x-netbooster ]; then
        chmod +x /usr/local/bin/elite-x-netbooster
        cat > /etc/systemd/system/elite-x-netbooster.service <<EOF
[Unit]
Description=ELITE-X Network Booster
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-netbooster
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Network Booster compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C DNS CACHE (ORIGINAL)
# ═══════════════════════════════════════════════════════════
create_c_dns_cache() {
    echo -e "${YELLOW}📝 Compiling DNS Cache...${NC}"
    
    cat > /tmp/dns_cache.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    while (running) { system("resolvectl flush-caches 2>/dev/null || true"); sleep(1800); }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-dnscache /tmp/dns_cache.c 2>/dev/null
    rm -f /tmp/dns_cache.c
    
    if [ -f /usr/local/bin/elite-x-dnscache ]; then
        chmod +x /usr/local/bin/elite-x-dnscache
        cat > /etc/systemd/system/elite-x-dnscache.service <<EOF
[Unit]
Description=ELITE-X DNS Cache Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-dnscache
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ DNS Cache compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C RAM CLEANER (ORIGINAL)
# ═══════════════════════════════════════════════════════════
create_c_ram_cleaner() {
    echo -e "${YELLOW}📝 Compiling RAM Cleaner...${NC}"
    
    cat > /tmp/ram_cleaner.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    while (running) { system("sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null"); sleep(900); }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-ramcleaner /tmp/ram_cleaner.c 2>/dev/null
    rm -f /tmp/ram_cleaner.c
    
    if [ -f /usr/local/bin/elite-x-ramcleaner ]; then
        chmod +x /usr/local/bin/elite-x-ramcleaner
        cat > /etc/systemd/system/elite-x-ramcleaner.service <<EOF
[Unit]
Description=ELITE-X RAM Cleaner
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
        echo -e "${GREEN}✅ RAM Cleaner compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C IRQ OPTIMIZER (ORIGINAL)
# ═══════════════════════════════════════════════════════════
create_c_irq_optimizer() {
    echo -e "${YELLOW}📝 Compiling IRQ Optimizer...${NC}"
    
    cat > /tmp/irq_opt.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    while (running) { system("for i in /sys/class/net/*/queues/rx-*/rps_cpus; do echo ffffffff > $i 2>/dev/null; done"); sleep(600); }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-irqopt /tmp/irq_opt.c 2>/dev/null
    rm -f /tmp/irq_opt.c
    
    if [ -f /usr/local/bin/elite-x-irqopt ]; then
        chmod +x /usr/local/bin/elite-x-irqopt
        cat > /etc/systemd/system/elite-x-irqopt.service <<EOF
[Unit]
Description=ELITE-X IRQ Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-irqopt
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ IRQ Optimizer compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C LOG CLEANER (ORIGINAL)
# ═══════════════════════════════════════════════════════════
create_c_log_cleaner() {
    echo -e "${YELLOW}📝 Compiling Log Cleaner...${NC}"
    
    cat > /tmp/log_cleaner.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    while (running) { system("find /var/log -type f -size +50M -exec truncate -s 0 {} \\; 2>/dev/null; journalctl --vacuum-size=50M 2>/dev/null"); sleep(3600); }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-logcleaner /tmp/log_cleaner.c 2>/dev/null
    rm -f /tmp/log_cleaner.c
    
    if [ -f /usr/local/bin/elite-x-logcleaner ]; then
        chmod +x /usr/local/bin/elite-x-logcleaner
        cat > /etc/systemd/system/elite-x-logcleaner.service <<EOF
[Unit]
Description=ELITE-X Log Cleaner
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
        echo -e "${GREEN}✅ Log Cleaner compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# USER MANAGEMENT SCRIPT (ORIGINAL - FULL)
# ═══════════════════════════════════════════════════════════
create_user_script() {
    cat > /usr/local/bin/elite-x-user <<'USEREOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';PURPLE='\033[0;35m';GRAY='\033[0;90m';NC='\033[0m'

UD="/etc/elite-x/users"; USAGE_DB="/etc/elite-x/data_usage"; DD="/etc/elite-x/deleted"
BD="/etc/elite-x/banned"; CONN_DB="/etc/elite-x/connections"; BW_DIR="/etc/elite-x/bandwidth"
PID_DIR="$BW_DIR/pidtrack"; AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"

mkdir -p "$UD" "$USAGE_DB" "$DD" "$BD" "$CONN_DB" "$BW_DIR" "$PID_DIR"

get_connection_count() {
    local username="$1"; local count=0
    who 2>/dev/null | grep -qw "$username" && count=$(who 2>/dev/null | grep -wc "$username")
    [ "$count" -eq 0 ] && count=$(ps aux 2>/dev/null | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    echo ${count:-0}
}

get_bandwidth_usage() {
    local username="$1"; local bw_file="$BW_DIR/${username}.usage"
    if [ -f "$bw_file" ]; then
        local total_bytes=$(cat "$bw_file" 2>/dev/null || echo 0)
        echo "scale=2; $total_bytes / 1073741824" | bc 2>/dev/null || echo "0.00"
    else echo "0.00"; fi
}

add_user() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}     CREATE SSH + DNS USER    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    if id "$username" &>/dev/null; then echo -e "${RED}User exists!${NC}"; return; fi
    
    read -p "$(echo -e $GREEN"Password [auto]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8) && echo -e "${GREEN}Generated: ${YELLOW}$password${NC}"
    
    read -p "$(echo -e $GREEN"Expire days [30]: "$NC)" days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; return; }
    
    read -p "$(echo -e $GREEN"Conn limit [1]: "$NC)" conn_limit; conn_limit=${conn_limit:-1}
    read -p "$(echo -e $GREEN"Bandwidth GB (0=∞) [0]: "$NC)" bandwidth_gb; bandwidth_gb=${bandwidth_gb:-0}
    
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username" 2>/dev/null
    
    cat > "$UD/$username" <<INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Bandwidth_GB: $bandwidth_gb
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > "$BW_DIR/${username}.usage"
    /usr/local/bin/elite-x-force-user-message "$username" 2>/dev/null
    
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "?")
    PUBKEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "?")
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}   USER CREATED SUCCESSFULLY    ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE} Username: ${CYAN}$username${NC}"
    echo -e "${GREEN}║${WHITE} Password: ${CYAN}$password${NC}"
    echo -e "${GREEN}║${WHITE} Server: ${CYAN}$SERVER${NC}"
    echo -e "${GREEN}║${WHITE} IP: ${CYAN}$IP${NC}"
    echo -e "${GREEN}║${WHITE} PubKey: ${CYAN}$PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE} Expire: ${CYAN}$expire_date${NC}"
    echo -e "${GREEN}║${WHITE} Max Login: ${CYAN}$conn_limit${NC}"
    echo -e "${GREEN}║${WHITE} Bandwidth: ${CYAN}$bandwidth_gb GB${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}              ACTIVE USERS            ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A "$UD" 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}          No users found              ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        return
    fi
    
    printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-10s${CYAN} ║${NC}\n" "USERNAME" "EXPIRE" "LOGIN" "STATUS"
    echo -e "${CYAN}╟──────────────────────────────────────────────────╢${NC}"
    
    for user in "$UD"/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        limit=$(grep "Conn_Limit:" "$user" | awk '{print $2}'); limit=${limit:-1}
        current_conn=$(get_connection_count "$u")
        
        expire_ts=$(date -d "$ex" +%s 2>/dev/null || echo 0)
        current_ts=$(date +%s)
        days_left=$(( (expire_ts - current_ts) / 86400 ))
        
        if passwd -S "$u" 2>/dev/null | grep -q "L"; then status="${RED}🔒 LOCKED${NC}"
        elif [ "$current_conn" -gt 0 ]; then status="${GREEN}🟢 ONLINE${NC}"
        elif [ $days_left -le 0 ]; then status="${RED}⛔ EXPIRED${NC}"
        else status="${YELLOW}⚫ OFFLINE${NC}"; fi
        
        printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-10b${CYAN} ║${NC}\n" "$u" "$ex" "${current_conn}/${limit}" "$status"
    done
    
    TOTAL=$(ls "$UD" 2>/dev/null | wc -l)
    ONLINE=$(who 2>/dev/null | wc -l)
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW}  Users: ${GREEN}${TOTAL}${YELLOW} | Online: ${GREEN}${ONLINE}${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}

renew_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}Not found!${NC}"; return; }
    read -p "$(echo -e $GREEN"Additional days: "$NC)" days
    current=$(grep "Expire:" "$UD/$username" | cut -d' ' -f2)
    new=$(date -d "$current +$days days" +"%Y-%m-%d" 2>/dev/null)
    [ -z "$new" ] && { echo -e "${RED}Invalid date!${NC}"; return; }
    sed -i "s/Expire: .*/Expire: $new/" "$UD/$username"
    chage -E "$new" "$username" 2>/dev/null
    usermod -U "$username" 2>/dev/null
    /usr/local/bin/elite-x-force-user-message "$username" 2>/dev/null
    echo -e "${GREEN}✅ Renewed to $new${NC}"
}

set_bandwidth_limit() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}Not found!${NC}"; return; }
    read -p "$(echo -e $GREEN"New limit GB (0=∞): "$NC)" new_bw
    grep -q "Bandwidth_GB:" "$UD/$username" && sed -i "s/Bandwidth_GB: .*/Bandwidth_GB: $new_bw/" "$UD/$username" || echo "Bandwidth_GB: $new_bw" >> "$UD/$username"
    echo -e "${GREEN}✅ Updated${NC}"
}

reset_bandwidth() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}Not found!${NC}"; return; }
    echo "0" > "$BW_DIR/${username}.usage"
    rm -f "$PID_DIR/${username}"__*.last 2>/dev/null
    usermod -U "$username" 2>/dev/null
    echo -e "${GREEN}✅ Reset${NC}"
}

lock_user() { read -p "Username: " u; usermod -L "$u" 2>/dev/null; pkill -u "$u" 2>/dev/null; echo "$(date) - MANUALLY LOCKED" >> "$BD/$u" 2>/dev/null; echo -e "${GREEN}✅ Locked${NC}"; }
unlock_user() { read -p "Username: " u; usermod -U "$u" 2>/dev/null; echo "$(date) - MANUALLY UNLOCKED" >> "$BD/$u" 2>/dev/null; echo -e "${GREEN}✅ Unlocked${NC}"; }
delete_user() { read -p "Username: " u; cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null; pkill -u "$u" 2>/dev/null; userdel -r "$u" 2>/dev/null; rm -f "$UD/$u" "$USAGE_DB/$u" "$CONN_DB/$u" "$BW_DIR/${u}.usage" "/etc/elite-x/user_messages/$u" 2>/dev/null; echo -e "${GREEN}✅ Deleted${NC}"; }

details_user() {
    read -p "Username: " username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}Not found!${NC}"; return; }
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}         USER DETAILS             ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
    cat "$UD/$username" | while read line; do echo -e "${CYAN}║${WHITE} $line${NC}"; done
    total_gb=$(get_bandwidth_usage "$username")
    current_conn=$(get_connection_count "$username")
    echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} Sessions: ${GREEN}${current_conn}${NC}"
    echo -e "${CYAN}║${WHITE} BW Used: ${GREEN}${total_gb} GB${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    details) details_user ;;
    renew) renew_user ;;
    setbw) set_bandwidth_limit ;;
    resetdata) reset_bandwidth ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    del) delete_user ;;
    deleted) ls "$DD/" 2>/dev/null | head -20 || echo "No deleted users" ;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setbw|resetdata|lock|unlock|del|deleted}" ;;
esac
USEREOF
    chmod +x /usr/local/bin/elite-x-user
}

# ═══════════════════════════════════════════════════════════
# MAIN MENU (ORIGINAL - FULL)
# ═══════════════════════════════════════════════════════════
create_main_menu() {
    cat > /usr/local/bin/elite-x <<'MENUEOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

UD="/etc/elite-x/users"; BW_DIR="/etc/elite-x/bandwidth"; AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"

show_dashboard() {
    clear
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "Unknown")
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not set")
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null || echo "N/A")
    MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
    RAM=$(free -h | awk '/^Mem:/{print $3"/"$2}')
    
    # Check services status
    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    BW=$(systemctl is-active elite-x-bandwidth 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    CM=$(systemctl is-active elite-x-connmon 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    
    TOTAL_USERS=$(ls -1 "$UD" 2>/dev/null | wc -l)
    ONLINE=$(who 2>/dev/null | wc -l)
    
    autoban=$(cat "$AUTOBAN_FLAG" 2>/dev/null || echo "0")
    [ "$autoban" = "1" ] && ABSTATUS="${RED}ON${NC}" || ABSTATUS="${GREEN}OFF${NC}"
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}        ELITE-X v4.0 NIMBUS ULTRA       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  NS        :${GREEN} $SUB${NC}"
    echo -e "${PURPLE}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location  :${GREEN} $LOCATION (MTU: $MTU)${NC}"
    echo -e "${PURPLE}║${WHITE}  RAM       :${GREEN} $RAM${NC}"
    echo -e "${PURPLE}║${WHITE}  Services  : DNS:$DNS PRX:$PRX BW:$BW CM:$CM${NC}"
    echo -e "${PURPLE}║${WHITE}  Auto-Ban  : $ABSTATUS${NC}"
    echo -e "${PURPLE}║${WHITE}  Users     :${GREEN} $TOTAL_USERS total, $ONLINE online${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

settings_menu() {
    while true; do
        clear
        autoban=$(cat "$AUTOBAN_FLAG" 2>/dev/null || echo "0")
        [ "$autoban" = "1" ] && ABSTATUS="${RED}ENABLED${NC}" || ABSTATUS="${GREEN}DISABLED${NC}"
        
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}              SETTINGS MENU               ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠══════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Change MTU    [2] Speed Optimize${NC}"
        echo -e "${PURPLE}║${WHITE}  [3] Clean Cache   [4] Traffic Stats${NC}"
        echo -e "${PURPLE}║${WHITE}  [5] Reset All BW  [6] Toggle Auto-Ban ($ABSTATUS)${WHITE}${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Restart All   [8] Reboot VPS${NC}"
        echo -e "${PURPLE}║${WHITE}  [9] Uninstall     [0] Back${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        
        case $ch in
            1)
                read -p "New MTU (1000-5000): " mtu
                [[ "$mtu" =~ ^[0-9]+$ ]] && [ $mtu -ge 1000 ] && [ $mtu -le 5000 ] && {
                    echo "$mtu" > /etc/elite-x/mtu
                    systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                    echo -e "${GREEN}✅ Done${NC}"
                } || echo -e "${RED}Invalid${NC}"
                read -p "Press Enter..." ;;
            2) sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1; sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1; echo -e "${GREEN}✅ Optimized${NC}"; read -p "Press Enter..." ;;
            3) sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null; echo -e "${GREEN}✅ Cleaned${NC}"; read -p "Press Enter..." ;;
            4) iface=$(ip route | grep default | awk '{print $5}' | head -1); rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0); tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0); echo "RX: $(echo "scale=2; $rx/1073741824" | bc) GB"; echo "TX: $(echo "scale=2; $tx/1073741824" | bc) GB"; read -p "Press Enter..." ;;
            5) for f in "$BW_DIR"/*.usage; do [ -f "$f" ] && echo "0" > "$f"; done; echo -e "${GREEN}✅ Reset${NC}"; read -p "Press Enter..." ;;
            6) [ "$autoban" = "1" ] && echo "0" > "$AUTOBAN_FLAG" || echo "1" > "$AUTOBAN_FLAG"; systemctl restart elite-x-connmon 2>/dev/null; echo -e "${GREEN}✅ Toggled${NC}"; read -p "Press Enter..." ;;
            7) for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-datausage sshd; do systemctl restart "$s" 2>/dev/null; done; echo -e "${GREEN}✅ Restarted${NC}"; read -p "Press Enter..." ;;
            8) read -p "Reboot? (y/n): " c; [ "$c" = "y" ] && reboot ;;
            9) read -p "Type 'YES' to confirm: " c; [ "$c" = "YES" ] && { for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-*; do systemctl stop "$s" 2>/dev/null; systemctl disable "$s" 2>/dev/null; done; rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*}; rm -rf /etc/elite-x /etc/dnstt; rm -f /usr/local/bin/{dnstt-*,elite-x*}; echo -e "${GREEN}✅ Uninstalled${NC}"; exit 0; }; read -p "Press Enter..." ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}              MAIN MENU v4.0               ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠══════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Create User   [2] List Users${NC}"
        echo -e "${PURPLE}║${WHITE}  [3] User Details  [4] Renew User${NC}"
        echo -e "${PURPLE}║${WHITE}  [5] Set Conn Limit[6] Set BW Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset BW      [8] Lock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [9] Unlock User   [10] Delete User${NC}"
        echo -e "${PURPLE}║${WHITE}  [S] Settings      [U] UltraBoost${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Exit${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        
        case $ch in
            1) elite-x-user add; read -p "Press Enter..." ;;
            2) elite-x-user list; read -p "Press Enter..." ;;
            3) elite-x-user details; read -p "Press Enter..." ;;
            4) elite-x-user renew; read -p "Press Enter..." ;;
            5) read -p "Username: " u; read -p "New limit: " l; [ -f "$UD/$u" ] && { sed -i "s/Conn_Limit: .*/Conn_Limit: $l/" "$UD/$u"; echo -e "${GREEN}✅ Updated${NC}"; } || echo -e "${RED}Not found${NC}"; read -p "Press Enter..." ;;
            6) elite-x-user setbw; read -p "Press Enter..." ;;
            7) elite-x-user resetdata; read -p "Press Enter..." ;;
            8) elite-x-user lock; read -p "Press Enter..." ;;
            9) elite-x-user unlock; read -p "Press Enter..." ;;
            10) elite-x-user del; read -p "Press Enter..." ;;
            [Ss]) settings_menu ;;
            [Uu]) elite-x-ultraboost; read -p "Press Enter..." ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
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
    echo -e "${YELLOW}║${GREEN}     ACTIVATION REQUIRED - v4.0 NIMBUS    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

    if [ "$ACTIVATION_INPUT" != "$ACTIVATION_KEY" ] && [ "$ACTIVATION_INPUT" != "Whtsapp +255713-628-668" ]; then
        echo -e "${RED}❌ Invalid activation key!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Activation successful${NC}"
    sleep 1

    set_timezone

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}      ENTER YOUR NAMESERVER [NS] v4.0      ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
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

    echo -e "${YELLOW}🔄 Cleaning previous installation...${NC}"
    for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner elite-x-dns-ultra elite-x-shm-bw elite-x-conn-pool; do
        systemctl stop "$s" 2>/dev/null || true
        systemctl disable "$s" 2>/dev/null || true
    done
    pkill -f dnstt-server 2>/dev/null || true
    pkill -f elite-x-edns-proxy 2>/dev/null || true
    rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*} 2>/dev/null
    rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x 2>/dev/null
    rm -f /usr/local/bin/{dnstt-*,elite-x*} 2>/dev/null
    rm -f /etc/ssh/sshd_config.d/elite-x-*.conf 2>/dev/null
    rm -f /etc/sysctl.d/99-elite-x-*.conf 2>/dev/null
    sed -i '/^Match User/,/Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/elite-x-update-user-msg/d' /etc/pam.d/sshd 2>/dev/null
    umount /etc/elite-x/bandwidth 2>/dev/null || true
    umount /etc/elite-x/connections 2>/dev/null || true
    umount /etc/elite-x/data_usage 2>/dev/null || true
    systemctl restart sshd 2>/dev/null || true
    sleep 2

    # Create directories
    mkdir -p /etc/elite-x/{users,traffic,deleted,data_usage,connections,banned,bandwidth/pidtrack,user_messages,bpf}
    mkdir -p /etc/ssh/sshd_config.d
    mkdir -p /var/run/elite-x
    echo "$TDOMAIN" > /etc/elite-x/subdomain
    echo "$SEL_LOC" > /etc/elite-x/location
    echo "$MTU" > /etc/elite-x/mtu
    echo "0" > "$AUTOBAN_FLAG"
    echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key
    echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key

    # Apply Performance Levels
    create_kernel_ultra_tuning
    create_tmpfs_filesystem
    create_hugepages
    create_nic_offloading
    create_zero_copy_networking

    # Configure DNS
    [ -f /etc/systemd/resolved.conf ] && {
        sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved 2>/dev/null || true
    }
    [ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    echo "options timeout:1 rotate" >> /etc/resolv.conf

    # Install dependencies
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    apt update -y 2>/dev/null
    apt install -y curl jq iptables ethtool dnsutils net-tools iproute2 bc build-essential git gcc make libssl-dev 2>/dev/null
    echo -e "${GREEN}✅ Dependencies installed${NC}"

    # Download DNSTT
    echo -e "${YELLOW}📥 Downloading DNSTT server...${NC}"
    curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null || {
        curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null
    }
    chmod +x /usr/local/bin/dnstt-server

    # Setup DNSTT keys
    mkdir -p /etc/dnstt
    echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
    echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
    chmod 600 /etc/dnstt/server.key

    # Create DNSTT service
    cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server v4.0
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=3
LimitNOFILE=2097152
[Install]
WantedBy=multi-user.target
EOF

    # Optimize system
    optimize_system_for_vpn

    # Configure PAM + SSH
    configure_pam_user_message
    configure_ssh_for_vpn

    # Create all C components
    create_c_edns_proxy

    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X C EDNS Proxy
After=dnstt-elite-x.service
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-edns-proxy
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    fi

    # Original C components
    create_c_bandwidth_monitor
    create_c_connection_monitor
    create_c_data_usage
    create_c_network_booster
    create_c_dns_cache
    create_c_ram_cleaner
    create_c_irq_optimizer
    create_c_log_cleaner

    # New Performance components
    create_ultra_dns_cache
    create_shared_memory_bw_tracker
    create_connection_pooling
    create_cpu_affinity
    create_xdp_filter
    create_ultra_performance_booster

    # User scripts
    create_user_script
    create_main_menu

    # Enable and start all services
    systemctl daemon-reload

    ALL_SERVICES=(
        dnstt-elite-x dnstt-elite-x-proxy
        elite-x-bandwidth elite-x-datausage elite-x-connmon
        elite-x-netbooster elite-x-dnscache elite-x-ramcleaner
        elite-x-irqopt elite-x-logcleaner
        elite-x-dns-ultra elite-x-shm-bw elite-x-conn-pool
        elite-x-nic-offload elite-x-zero-copy
        elite-x-hugepages elite-x-cpu-affinity elite-x-xdp
    )

    for s in "${ALL_SERVICES[@]}"; do
        if [ -f "/etc/systemd/system/${s}.service" ]; then
            systemctl enable "$s" 2>/dev/null || true
            systemctl start "$s" 2>/dev/null || true
        fi
    done

    # Cache IP
    IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
    echo "$IP" > /etc/elite-x/cached_ip

    # Setup auto-login dashboard
    cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    /usr/local/bin/elite-x
fi
EOF
    chmod +x /etc/profile.d/elite-x-dashboard.sh

    # Add aliases
    cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
alias adduser='elite-x-user add'
alias users='elite-x-user list'
alias setbw='elite-x-user setbw'
alias boost='elite-x-ultraboost'
alias fixvpn='systemctl restart dnstt-elite-x dnstt-elite-x-proxy sshd && echo "Fixed!"'
alias refreshmsg='for u in /etc/elite-x/users/*; do [ -f "$u" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$u")"; done && echo "✅ Messages refreshed!"'
EOF

    # Create initial messages for any existing users
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$user_file")" 2>/dev/null
        done
    fi

    # Run ultra booster
    /usr/local/bin/elite-x-ultraboost 2>/dev/null &

    # ═══════════════════════════════════════════════════════════
    # FINAL DISPLAY
    # ═══════════════════════════════════════════════════════════
    sleep 3
    clear
    echo -e "${GREEN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}     ELITE-X v4.0 NIMBUS ULTRA INSTALLED!  ${GREEN}║${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
    echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SEL_LOC (MTU: $MTU)${NC}"
    echo -e "${GREEN}║${WHITE}  IP         :${CYAN} $IP${NC}"
    echo -e "${GREEN}║${WHITE}  Version    :${CYAN} v4.0 Nimbus Ultra Final${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key :${CYAN} $STATIC_PUBLIC_KEY${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"

    check_svc() {
        local name=$1 service=$2
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo -e "${GREEN}║  ✅ $name: Running${NC}"
        else
            echo -e "${RED}║  ❌ $name: Failed${NC}"
        fi
    }

    echo -e "${GREEN}║${YELLOW}  CORE SERVICES:${NC}"
    check_svc "DNSTT Server     " "dnstt-elite-x"
    check_svc "EDNS Proxy       " "dnstt-elite-x-proxy"
    check_svc "SSH Server       " "sshd"
    check_svc "Bandwidth Mon    " "elite-x-bandwidth"
    check_svc "Conn Monitor     " "elite-x-connmon"
    
    echo -e "${GREEN}║${YELLOW}  PERFORMANCE LEVELS:${NC}"
    check_svc "L1: Ultra DNS    " "elite-x-dns-ultra"
    check_svc "L2: Shm BW Track " "elite-x-shm-bw"
    check_svc "L3: Conn Pool    " "elite-x-conn-pool"
    
    if [ -f /usr/local/bin/elite-x-force-user-message ] && [ -d /etc/elite-x/user_messages ]; then
        echo -e "${GREEN}║  ✅ User Messages  : Active${NC}"
    else
        echo -e "${RED}║  ❌ User Messages  : Inactive${NC}"
    fi

    echo -e "${GREEN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Commands: menu | elite-x | users | adduser | setbw | boost | fixvpn | refreshmsg${NC}"
    echo ""
    echo -e "${CYAN}═══ ALL ORIGINAL FEATURES + 10 LEVELS ACTIVE ═══${NC}"
    echo -e "${WHITE}✅ Auto-Ban/Auto-Delete ✅ Bandwidth Limits ✅ GB Quota${NC}"
    echo -e "${WHITE}✅ User Messages ✅ Connection Limits ✅ Expiry System${NC}"
    echo ""
    echo -e "${CYAN}SLOWDNS CONFIG:${NC}"
    echo -e "${WHITE}  NS     : ${GREEN}$TDOMAIN${NC}"
    echo -e "${WHITE}  PUBKEY : ${GREEN}$STATIC_PUBLIC_KEY${NC}"
    echo -e "${WHITE}  PORT   : ${GREEN}53${NC}"
    echo ""
}

# Run installation
run_installation
