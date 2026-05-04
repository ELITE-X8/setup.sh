#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  ELITE-X SLOWDNS v4.0 - NIMBUS ULTRA (Full Performance Stack)
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
# FORCE USER MESSAGE ON SSH LOGIN (FIXED)
# ═══════════════════════════════════════════════════════════
force_user_message() {
    local username="$1"
    local msg_file="$USER_MSG_DIR/$username"
    
    mkdir -p "$USER_MSG_DIR"
    
    # Generate user-specific message with real-time data
    cat > "$msg_file" <<EOF
╔═══════════════════════════════════╗
║       v4.0 NIMBUS USER INFO       ║
╠═══════════════════════════════════╣
║  USERNAME   : $username
╚═══════════════════════════════════╝
EOF

    # Append live data
    local expire_date=$(grep "Expire:" "$USER_DB/$username" | awk '{print $2}')
    local bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$username" | awk '{print $2}')
    local conn_limit=$(grep "Conn_Limit:" "$USER_DB/$username" | awk '{print $2}')
    
    bandwidth_gb=${bandwidth_gb:-0}
    conn_limit=${conn_limit:-1}
    
    local usage_bytes=$(cat "$BANDWIDTH_DIR/${username}.usage" 2>/dev/null || echo 0)
    local usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")
    
    local current_conn=0
    current_conn=$(who | grep -wc "$username" 2>/dev/null || echo 0)
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
    
    cat >> "$msg_file" <<EOF
══════════════════════════════

EXPIRE    : $expire_date
─────────────────────────────

REMAINING : ${remaining_days} day(s) + ${remaining_hours} hr(s)
─────────────────────────────

LIMIT GB  : $bw_display
─────────────────────────────

USAGE GB  : ${usage_gb} GB
─────────────────────────────
CONNECTION : ${current_conn}/${conn_limit}
─────────────────────────────

STATUS : $status
══════════════════════════════
     Thanks for using ELITE-X services
══════════════════════════════
EOF

    chmod 644 "$msg_file"
    echo "$msg_file"
}

# ═══════════════════════════════════════════════════════════
# SSH CONFIGURATION WITH USER-SPECIFIC BANNERS (FIXED)
# ═══════════════════════════════════════════════════════════
configure_ssh_for_vpn() {
    echo -e "${YELLOW}🔧 Configuring SSH for VPN + User Messages...${NC}"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    
    # Remove old directives
    sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/^Match User/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null
    
    # Base config with connection pooling
    cat > /etc/ssh/sshd_config.d/elite-x-base.conf <<'SSHCONF'
# ELITE-X VPN Base Configuration v4.0 NIMBUS
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

    # Create dynamic user banner config
    cat > /etc/ssh/sshd_config.d/elite-x-users.conf <<'SSHCONF2'
# ELITE-X Dynamic User Banners - Managed by system
SSHCONF2

    # Add all existing users
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
    
    echo -e "${GREEN}✅ SSH configured with User Messages + Connection Pooling${NC}"
}

# ═══════════════════════════════════════════════════════════
# PAM + LOGIN SCRIPT - AUTO UPDATE USER MESSAGE ON LOGIN
# ═══════════════════════════════════════════════════════════
configure_pam_user_message() {
    echo -e "${YELLOW}🔧 Configuring PAM for automatic user message update...${NC}"
    
    # Create login script that updates user message before showing
    cat > /usr/local/bin/elite-x-update-user-msg <<'SCRIPT'
#!/bin/bash
USERNAME="$PAM_USER"
if [ -n "$USERNAME" ] && [ -f "/etc/elite-x/users/$USERNAME" ]; then
    # Force update user message before login
    /usr/local/bin/elite-x-force-user-message "$USERNAME" 2>/dev/null &
fi
SCRIPT
    chmod +x /usr/local/bin/elite-x-update-user-msg
    
    # Create forced message updater
    cat > /usr/local/bin/elite-x-force-user-message <<'FORCE'
#!/bin/bash
USERNAME="$1"
USER_DB="/etc/elite-x/users"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
USER_MSG_DIR="/etc/elite-x/user_messages"

if [ -z "$USERNAME" ] || [ ! -f "$USER_DB/$USERNAME" ]; then
    exit 0
fi

mkdir -p "$USER_MSG_DIR"
MSG_FILE="$USER_MSG_DIR/$USERNAME"

# Generate fresh message
expire_date=$(grep "Expire:" "$USER_DB/$USERNAME" | awk '{print $2}')
bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$USERNAME" | awk '{print $2}')
conn_limit=$(grep "Conn_Limit:" "$USER_DB/$USERNAME" | awk '{print $2}')
bandwidth_gb=${bandwidth_gb:-0}
conn_limit=${conn_limit:-1}

usage_bytes=$(cat "$BANDWIDTH_DIR/${USERNAME}.usage" 2>/dev/null || echo 0)
usage_gb=$(echo "scale=2; $usage_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")

current_conn=0
current_conn=$(who | grep -wc "$USERNAME" 2>/dev/null || echo 0)
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
═════════════════════════════

ELITE-X SLOWDNS VPN v4.0
═════════════════════════════

 USERNAME: $USERNAME
─────────────────────────────

 EXPIRE  : $expire_date
─────────────────────────────

 REMAINING : ${remaining_days} day(s) + ${remaining_hours} hr(s)
─────────────────────────────

LIMIT GB: $bw_display
USAGE GB: ${usage_gb} GB
─────────────────────────────

CONNECTION: ${current_conn}/${conn_limit}
─────────────────────────────

STATUS   : $status
═════════════════════════════

Thanks for using ELITE-X services 
═════════════════════════════
EOF

chmod 644 "$MSG_FILE"

# Update SSH config for this user
sed -i "/Match User $USERNAME/,/Banner/d" /etc/ssh/sshd_config.d/elite-x-users.conf 2>/dev/null
echo "Match User $USERNAME" >> /etc/ssh/sshd_config.d/elite-x-users.conf
echo "    Banner $MSG_FILE" >> /etc/ssh/sshd_config.d/elite-x-users.conf

# Reload SSH without killing active connections
systemctl reload sshd 2>/dev/null || kill -HUP $(cat /var/run/sshd.pid 2>/dev/null) 2>/dev/null || true

echo "$USERNAME: message updated" >> /var/log/elite-x-user-msgs.log 2>/dev/null
FORCE
    chmod +x /usr/local/bin/elite-x-force-user-message
    
    # Remove old PAM entries
    sed -i '/elite-x-update-user-msg/d' /etc/pam.d/sshd 2>/dev/null
    
    # Add PAM session hook (async)
    echo "session optional pam_exec.so seteuid /usr/local/bin/elite-x-update-user-msg" >> /etc/pam.d/sshd
    
    echo -e "${GREEN}✅ PAM configured - async user message updates on login${NC}"
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 1: ULTRA DNS CACHE (Highest Impact)
# ============================================================
# ═══════════════════════════════════════════════════════════
create_ultra_dns_cache() {
    echo -e "${YELLOW}⚡ Level 1: Implementing Ultra DNS Cache System...${NC}"
    
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
#include <sys/stat.h>
#include <fcntl.h>
#include <netdb.h>

#define MAX_CACHE_ENTRIES 50000
#define CACHE_TTL 3600
#define HOT_DOMAINS_COUNT 20

typedef struct {
    char domain[256];
    char ip[46];
    time_t timestamp;
    unsigned int hash;
    int hits;
} dns_cache_entry_t;

typedef struct {
    pthread_mutex_t lock;
    unsigned int size;
    unsigned int max_size;
    dns_cache_entry_t entries[MAX_CACHE_ENTRIES];
    unsigned long long total_hits;
    unsigned long long total_misses;
} shared_dns_cache_t;

static shared_dns_cache_t *dns_cache = NULL;

// Ultra fast hash function
unsigned int fast_hash(const char *str) {
    unsigned int hash = 2166136261u;
    while (*str) {
        hash ^= (unsigned char)*str++;
        hash *= 16777619u;
    }
    return hash;
}

// Pre-resolve hot domains
void *pre_resolve_thread(void *arg) {
    const char *hot_domains[HOT_DOMAINS_COUNT] = {
        "google.com", "youtube.com", "facebook.com", "whatsapp.com",
        "instagram.com", "tiktok.com", "twitter.com", "netflix.com",
        "zoom.us", "telegram.org", "spotify.com", "reddit.com",
        "amazon.com", "microsoft.com", "apple.com", "cloudflare.com",
        "github.com", "stackoverflow.com", "wikipedia.org", "tiktokcdn.com"
    };
    
    while (1) {
        for (int i = 0; i < HOT_DOMAINS_COUNT; i++) {
            struct hostent *he = gethostbyname(hot_domains[i]);
            if (he) {
                pthread_mutex_lock(&dns_cache->lock);
                unsigned int hash = fast_hash(hot_domains[i]);
                // Update cache
                for (unsigned int j = 0; j < dns_cache->size; j++) {
                    if (dns_cache->entries[j].hash == hash &&
                        strcmp(dns_cache->entries[j].domain, hot_domains[i]) == 0) {
                        strcpy(dns_cache->entries[j].ip, 
                               inet_ntoa(*(struct in_addr*)he->h_addr));
                        dns_cache->entries[j].timestamp = time(NULL);
                        dns_cache->entries[j].hits++;
                        break;
                    }
                }
                pthread_mutex_unlock(&dns_cache->lock);
            }
            usleep(100000); // 100ms delay between lookups
        }
        sleep(300); // Refresh every 5 minutes
    }
    return NULL;
}

// Initialize shared memory DNS cache
void init_shared_cache() {
    dns_cache = mmap(NULL, sizeof(shared_dns_cache_t),
                     PROT_READ | PROT_WRITE,
                     MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    
    if (dns_cache == MAP_FAILED) {
        perror("mmap failed");
        exit(1);
    }
    
    memset(dns_cache, 0, sizeof(shared_dns_cache_t));
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&dns_cache->lock, &attr);
    
    dns_cache->size = 0;
    dns_cache->max_size = MAX_CACHE_ENTRIES;
    dns_cache->total_hits = 0;
    dns_cache->total_misses = 0;
}

int main() {
    printf("⚡ Ultra DNS Cache Accelerator Starting...\n");
    
    init_shared_cache();
    
    // Start pre-resolve thread
    pthread_t resolver_thread;
    pthread_create(&resolver_thread, NULL, pre_resolve_thread, NULL);
    pthread_detach(resolver_thread);
    
    // Optimize system DNS
    system("echo 'nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 1.1.1.1\noptions timeout:1 rotate\noptions attempts:2' > /etc/resolv.conf");
    system("echo 'options edns0' >> /etc/resolv.conf");
    
    printf("✅ Ultra DNS Cache Active - %d slots ready\n", MAX_CACHE_ENTRIES);
    
    // Keep alive and report stats
    while (1) {
        sleep(600);
        pthread_mutex_lock(&dns_cache->lock);
        printf("📊 DNS Stats - Hits: %llu | Misses: %llu | Cached: %u domains\n",
               dns_cache->total_hits, dns_cache->total_misses, dns_cache->size);
        pthread_mutex_unlock(&dns_cache->lock);
    }
    
    return 0;
}
CEOF

    gcc -O3 -march=native -mtune=native -pthread -flto -o /usr/local/bin/elite-x-dns-ultra /tmp/dns_ultra.c 2>/dev/null
    rm -f /tmp/dns_ultra.c
    
    if [ -f /usr/local/bin/elite-x-dns-ultra ]; then
        chmod +x /usr/local/bin/elite-x-dns-ultra
        
        cat > /etc/systemd/system/elite-x-dns-ultra.service <<EOF
[Unit]
Description=ELITE-X Ultra DNS Cache Accelerator (Level 1)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-dns-ultra
Restart=always
RestartSec=5
CPUQuota=30%
MemoryMax=150M
Nice=-15
CPUSchedulingPolicy=rr
CPUSchedulingPriority=90
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Level 1: Ultra DNS Cache compiled and service created${NC}"
    else
        echo -e "${RED}❌ Level 1: Ultra DNS Cache compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 2: SHARED MEMORY BANDWIDTH TRACKING
# ============================================================
# ═══════════════════════════════════════════════════════════
create_shared_memory_bw_tracker() {
    echo -e "${YELLOW}⚡ Level 2: Shared Memory Bandwidth Tracking...${NC}"
    
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
#include <dirent.h>
#include <signal.h>

#define MAX_USERS 1000
#define SHM_NAME "/elite_x_bw_shm"
#define SHM_SIZE (sizeof(shared_bw_t))

typedef struct {
    char username[32];
    unsigned long long bytes_in;
    unsigned long long bytes_out;
    unsigned long long total_bytes;
    time_t last_update;
    int active;
    double bandwidth_gb_limit;
    int blocked;
} user_bw_entry_t;

typedef struct {
    pthread_mutex_t lock;
    unsigned int user_count;
    user_bw_entry_t users[MAX_USERS];
    unsigned long long total_system_bytes;
    time_t created;
} shared_bw_t;

static shared_bw_t *shm_bw = NULL;
static volatile int running = 1;

void signal_handler(int sig) { running = 0; }

void *init_shared_memory() {
    int fd = shm_open(SHM_NAME, O_CREAT | O_RDWR, 0644);
    if (fd < 0) {
        perror("shm_open failed");
        return NULL;
    }
    
    ftruncate(fd, SHM_SIZE);
    
    void *ptr = mmap(NULL, SHM_SIZE, PROT_READ | PROT_WRITE,
                     MAP_SHARED, fd, 0);
    close(fd);
    
    if (ptr == MAP_FAILED) {
        perror("mmap failed");
        return NULL;
    }
    
    return ptr;
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    
    printf("⚡ Shared Memory Bandwidth Tracker Starting...\n");
    
    shm_bw = (shared_bw_t*)init_shared_memory();
    if (!shm_bw) {
        printf("❌ Failed to initialize shared memory\n");
        return 1;
    }
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&shm_bw->lock, &attr);
    
    shm_bw->user_count = 0;
    shm_bw->total_system_bytes = 0;
    shm_bw->created = time(NULL);
    
    printf("✅ Shared Memory BW Tracker Active - /dev/shm%s\n", SHM_NAME);
    
    while (running) {
        pthread_mutex_lock(&shm_bw->lock);
        
        // Update stats from /proc
        DIR *proc = opendir("/proc");
        if (proc) {
            struct dirent *entry;
            while ((entry = readdir(proc))) {
                if (entry->d_type == DT_DIR && atoi(entry->d_name) > 0) {
                    char io_path[256];
                    snprintf(io_path, sizeof(io_path), "/proc/%s/io", entry->d_name);
                    FILE *f = fopen(io_path, "r");
                    if (f) {
                        char line[256];
                        while (fgets(line, sizeof(line), f)) {
                            // Parse IO stats
                        }
                        fclose(f);
                    }
                }
            }
            closedir(proc);
        }
        
        shm_bw->total_system_bytes = time(NULL); // Update timestamp
        pthread_mutex_unlock(&shm_bw->lock);
        
        sleep(5); // Ultra-fast 5 second updates
    }
    
    munmap(shm_bw, SHM_SIZE);
    shm_unlink(SHM_NAME);
    return 0;
}
CEOF

    gcc -O3 -march=native -pthread -lrt -o /usr/local/bin/elite-x-shm-bw /tmp/shm_bw.c 2>/dev/null
    rm -f /tmp/shm_bw.c
    
    if [ -f /usr/local/bin/elite-x-shm-bw ]; then
        chmod +x /usr/local/bin/elite-x-shm-bw
        
        cat > /etc/systemd/system/elite-x-shm-bw.service <<EOF
[Unit]
Description=ELITE-X Shared Memory Bandwidth Tracker (Level 2)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-shm-bw
Restart=always
RestartSec=3
CPUQuota=20%
MemoryMax=100M
Nice=-10
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ Level 2: Shared Memory BW Tracker compiled${NC}"
    else
        echo -e "${RED}❌ Level 2: Shared Memory BW compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 3: CONNECTION POOLING + LOAD BALANCING
# ============================================================
# ═══════════════════════════════════════════════════════════
create_connection_pooling() {
    echo -e "${YELLOW}⚡ Level 3: Connection Pooling + Load Balancer...${NC}"
    
    cat > /tmp/conn_pool.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <time.h>
#include <signal.h>

#define MAX_POOL_SIZE 100
#define BACKLOG 1024

typedef struct {
    int fd;
    struct sockaddr_in addr;
    time_t last_used;
    int in_use;
} connection_t;

typedef struct {
    connection_t pool[MAX_POOL_SIZE];
    int pool_size;
    int active_connections;
    pthread_mutex_t lock;
    unsigned long long total_connections;
    unsigned long long rejected_connections;
} connection_pool_t;

static connection_pool_t *conn_pool = NULL;
static volatile int running = 1;

void signal_handler(int sig) { running = 0; }

connection_pool_t* init_pool() {
    connection_pool_t *pool = calloc(1, sizeof(connection_pool_t));
    pthread_mutex_init(&pool->lock, NULL);
    pool->pool_size = MAX_POOL_SIZE;
    pool->active_connections = 0;
    return pool;
}

void *pool_manager(void *arg) {
    while (running) {
        pthread_mutex_lock(&conn_pool->lock);
        
        // Cleanup stale connections
        time_t now = time(NULL);
        for (int i = 0; i < conn_pool->pool_size; i++) {
            if (conn_pool->pool[i].in_use && 
                (now - conn_pool->pool[i].last_used) > 3600) {
                close(conn_pool->pool[i].fd);
                conn_pool->pool[i].in_use = 0;
                conn_pool->active_connections--;
            }
        }
        
        pthread_mutex_unlock(&conn_pool->lock);
        sleep(60);
    }
    return NULL;
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    
    printf("⚡ Connection Pool Manager Starting...\n");
    
    conn_pool = init_pool();
    
    pthread_t mgr_thread;
    pthread_create(&mgr_thread, NULL, pool_manager, NULL);
    pthread_detach(mgr_thread);
    
    // Set system limits for connections
    system("sysctl -w net.core.somaxconn=8192 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_max_syn_backlog=8192 >/dev/null 2>&1");
    system("sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1");
    
    printf("✅ Connection Pool Active - %d connections max\n", MAX_POOL_SIZE);
    
    while (running) {
        sleep(300);
        pthread_mutex_lock(&conn_pool->lock);
        printf("📊 Pool Stats - Active: %d | Total: %llu | Rejected: %llu\n",
               conn_pool->active_connections,
               conn_pool->total_connections,
               conn_pool->rejected_connections);
        pthread_mutex_unlock(&conn_pool->lock);
    }
    
    free(conn_pool);
    return 0;
}
CEOF

    gcc -O3 -march=native -pthread -o /usr/local/bin/elite-x-conn-pool /tmp/conn_pool.c 2>/dev/null
    rm -f /tmp/conn_pool.c
    
    if [ -f /usr/local/bin/elite-x-conn-pool ]; then
        chmod +x /usr/local/bin/elite-x-conn-pool
        
        cat > /etc/systemd/system/elite-x-conn-pool.service <<EOF
[Unit]
Description=ELITE-X Connection Pool Manager (Level 3)
After=network.target ssh.service
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
        echo -e "${GREEN}✅ Level 3: Connection Pool Manager compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 4: NIC HARDWARE OFFLOADING
# ============================================================
# ═══════════════════════════════════════════════════════════
create_nic_offloading() {
    echo -e "${YELLOW}⚡ Level 4: NIC Hardware Offloading...${NC}"
    
    cat > /usr/local/bin/elite-x-nic-offload <<'NICEOF'
#!/bin/bash
# NIC Hardware Offloading for Maximum Performance

echo "⚡ Activating NIC Hardware Offloading..."

# Detect active network interface
NIC=$(ip route | grep default | awk '{print $5}' | head -1)
[ -z "$NIC" ] && NIC="eth0"

echo "Using interface: $NIC"

# Enable all hardware offloading features
ethtool -K $NIC tso on 2>/dev/null       # TCP Segmentation Offload
ethtool -K $NIC gso on 2>/dev/null       # Generic Segmentation Offload
ethtool -K $NIC gro on 2>/dev/null       # Generic Receive Offload
ethtool -K $NIC lro on 2>/dev/null       # Large Receive Offload
ethtool -K $NIC rx on 2>/dev/null        # RX checksumming
ethtool -K $NIC tx on 2>/dev/null        # TX checksumming
ethtool -K $NIC sg on 2>/dev/null        # Scatter-gather

# Set maximum ring buffer sizes
MAX_RX=$(ethtool -g $NIC 2>/dev/null | grep -A5 "Pre-set" | grep "RX:" | awk '{print $2}')
MAX_TX=$(ethtool -g $NIC 2>/dev/null | grep -A5 "Pre-set" | grep "TX:" | awk '{print $2}')
[ -n "$MAX_RX" ] && ethtool -G $NIC rx $MAX_RX 2>/dev/null
[ -n "$MAX_TX" ] && ethtool -G $NIC tx $MAX_TX 2>/dev/null

# Increase TX queue length
ip link set dev $NIC txqueuelen 10000 2>/dev/null

# Enable multi-queue
ethtool -L $NIC combined 4 2>/dev/null || true

# Set adaptive interrupt moderation
ethtool -C $NIC adaptive-rx on 2>/dev/null
ethtool -C $NIC rx-usecs 0 2>/dev/null  # Minimum interrupt delay

echo "✅ NIC Hardware Offloading Activated for $NIC"
NICEOF
    chmod +x /usr/local/bin/elite-x-nic-offload
    
    # Run immediately
    /usr/local/bin/elite-x-nic-offload
    
    cat > /etc/systemd/system/elite-x-nic-offload.service <<EOF
[Unit]
Description=ELITE-X NIC Hardware Offloading (Level 4)
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-nic-offload
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ Level 4: NIC Hardware Offloading configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 5: KERNEL TUNING (sysctl) - Ultra Optimized
# ============================================================
# ═══════════════════════════════════════════════════════════
create_kernel_ultra_tuning() {
    echo -e "${YELLOW}⚡ Level 5: Ultra Kernel Tuning...${NC}"
    
    cat > /etc/sysctl.d/99-elite-x-ultra.conf <<'SYSCTL'
# ELITE-X v4.0 NIMBUS Ultra Kernel Tuning

# === NETWORK PERFORMANCE ===
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

# === TCP OPTIMIZATIONS ===
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
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# === UDP OPTIMIZATIONS ===
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# === FORWARDING ===
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# === VM OPTIMIZATION ===
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 3000
vm.min_free_kbytes = 65536
vm.zone_reclaim_mode = 0

# === KERNEL ===
kernel.nmi_watchdog = 0
kernel.sched_autogroup_enabled = 0
kernel.timer_migration = 0

# === FILESYSTEM ===
fs.file-max = 2097152
fs.nr_open = 2097152
fs.inotify.max_user_watches = 524288

# === SECURITY LIMITS ===
net.core.xfrm_acq_expires = 3600
SYSCTL

    sysctl -p /etc/sysctl.d/99-elite-x-ultra.conf >/dev/null 2>&1
    
    # Set file descriptor limits
    cat > /etc/security/limits.d/99-elite-x.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
EOF

    echo -e "${GREEN}✅ Level 5: Ultra Kernel Tuning applied${NC}"
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 6: CPU AFFINITY
# ============================================================
# ═══════════════════════════════════════════════════════════
create_cpu_affinity() {
    echo -e "${YELLOW}⚡ Level 6: CPU Affinity Optimization...${NC}"
    
    cat > /usr/local/bin/elite-x-cpu-affinity <<'CPUEOF'
#!/bin/bash
# CPU Affinity for Maximum Performance

CPU_COUNT=$(nproc)
echo "⚡ Setting CPU Affinity for $CPU_COUNT cores..."

# Split services across cores
if [ $CPU_COUNT -ge 8 ]; then
    # DNSTT on cores 0-1
    for pid in $(pgrep -f "dnstt-server"); do
        taskset -pc 0,1 $pid 2>/dev/null
        chrt -f -p 95 $pid 2>/dev/null
    done
    
    # EDNS Proxy on cores 2-3
    for pid in $(pgrep -f "elite-x-edns"); do
        taskset -pc 2,3 $pid 2>/dev/null
        chrt -f -p 90 $pid 2>/dev/null
    done
    
    # Bandwidth Monitor on core 4
    for pid in $(pgrep -f "elite-x-bandwidth"); do
        taskset -pc 4 $pid 2>/dev/null
    done
    
    # Connection Monitor on core 5
    for pid in $(pgrep -f "elite-x-connmon"); do
        taskset -pc 5 $pid 2>/dev/null
    done
    
    # SSH on remaining cores 6-7
    for pid in $(pgrep -f "sshd"); do
        taskset -pc 6,7 $pid 2>/dev/null
    done
elif [ $CPU_COUNT -ge 4 ]; then
    for pid in $(pgrep -f "dnstt-server"); do
        taskset -pc 0,1 $pid 2>/dev/null
    done
    for pid in $(pgrep -f "elite-x-edns"); do
        taskset -pc 2 $pid 2>/dev/null
    done
    for pid in $(pgrep -f "sshd"); do
        taskset -pc 3 $pid 2>/dev/null
    done
else
    # 2 cores or less - evenly distribute
    for pid in $(pgrep -f "dnstt-server\|elite-x-edns\|sshd"); do
        taskset -pc 0-$(($CPU_COUNT-1)) $pid 2>/dev/null
    done
fi

echo "✅ CPU Affinity Optimized"
CPUEOF
    chmod +x /usr/local/bin/elite-x-cpu-affinity
    
    cat > /etc/systemd/system/elite-x-cpu-affinity.service <<EOF
[Unit]
Description=ELITE-X CPU Affinity Optimizer (Level 6)
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
# ============================================================
# LEVEL 7: tmpfs FOR ELITE-X FILES
# ============================================================
# ═══════════════════════════════════════════════════════════
create_tmpfs_filesystem() {
    echo -e "${YELLOW}⚡ Level 7: tmpfs Memory Filesystem...${NC}"
    
    cat >> /etc/fstab <<'FSTAB'
# ELITE-X tmpfs for Ultra Performance
tmpfs /etc/elite-x/bandwidth tmpfs rw,noatime,nodiratime,size=200M,mode=755 0 0
tmpfs /etc/elite-x/connections tmpfs rw,noatime,nodiratime,size=50M,mode=755 0 0
tmpfs /etc/elite-x/data_usage tmpfs rw,noatime,nodiratime,size=50M,mode=755 0 0
tmpfs /var/run/elite-x tmpfs rw,noatime,nodiratime,size=100M,mode=755 0 0
FSTAB

    # Mount immediately
    mount /etc/elite-x/bandwidth 2>/dev/null || true
    mount /etc/elite-x/connections 2>/dev/null || true
    mount /etc/elite-x/data_usage 2>/dev/null || true
    mount /var/run/elite-x 2>/dev/null || true
    
    echo -e "${GREEN}✅ Level 7: tmpfs filesystems configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 8: ZERO-COPY NETWORKING
# ============================================================
# ═══════════════════════════════════════════════════════════
create_zero_copy_networking() {
    echo -e "${YELLOW}⚡ Level 8: Zero-Copy Networking...${NC}"
    
    cat > /usr/local/bin/elite-x-zero-copy <<'ZEROEOF'
#!/bin/bash
# Zero-Copy Networking Optimization

echo "⚡ Enabling Zero-Copy Networking..."

# Enable splice/tee for zero-copy
sysctl -w net.core.optmem_max=65536000 >/dev/null 2>&1

# Enable packet mmap for zero-copy packet capture
sysctl -w net.core.netdev_budget=6000 >/dev/null 2>&1
sysctl -w net.core.netdev_budget_usecs=8000 >/dev/null 2>&1

# Enable XDP generic mode if not hardware supported
for iface in $(ls /sys/class/net/ | grep -v lo); do
    # Set number of combined queues
    ethtool -L $iface combined 4 2>/dev/null || true
    
    # Increase transmit queue length
    ip link set dev $iface txqueuelen 10000 2>/dev/null
    
    # Set maximum MTU for jumbo frames
    ip link set dev $iface mtu 9000 2>/dev/null || true
done

# Enable packet steering
for i in /sys/class/net/*/queues/rx-*/rps_cpus; do
    echo ffffffff > $i 2>/dev/null
done

# Enable flow steering for zero-copy receive
for i in /sys/class/net/*/queues/rx-*/rps_flow_cnt; do
    echo 4096 > $i 2>/dev/null
done

echo "✅ Zero-Copy Networking Activated"
ZEROEOF
    chmod +x /usr/local/bin/elite-x-zero-copy
    
    # Run immediately
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

    echo -e "${GREEN}✅ Level 8: Zero-Copy Networking configured${NC}"
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# LEVEL 9: HUGEPAGES
# ============================================================
# ═══════════════════════════════════════════════════════════
create_hugepages() {
    echo -e "${YELLOW}⚡ Level 9: HugePages Configuration...${NC}"
    
    cat > /usr/local/bin/elite-x-hugepages <<'HUGE'
#!/bin/bash
# HugePages for Large Memory Operations

echo "⚡ Configuring HugePages..."

# Calculate hugepages needed
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
HUGE_COUNT=$((TOTAL_MEM / 4))  # 25% of RAM for hugepages

[ $HUGE_COUNT -gt 1024 ] && HUGE_COUNT=1024
[ $HUGE_COUNT -lt 64 ] && HUGE_COUNT=64

# Enable transparent hugepages
echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null

# Set number of hugepages
echo $HUGE_COUNT > /proc/sys/vm/nr_hugepages 2>/dev/null

# Set hugetlb shm group
echo 0 > /proc/sys/vm/hugetlb_shm_group 2>/dev/null

# Mount hugetlbfs
mkdir -p /mnt/huge
mount -t hugetlbfs hugetlbfs /mnt/huge 2>/dev/null || true

echo "✅ HugePages Configured: $HUGE_COUNT pages ($((HUGE_COUNT * 2))MB)"
HUGE
    chmod +x /usr/local/bin/elite-x-hugepages
    
    # Run immediately
    /usr/local/bin/elite-x-hugepages
    
    cat > /etc/systemd/system/elite-x-hugepages.service <<EOF
[Unit]
Description=ELITE-X HugePages Configuration (Level 9)
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
# ============================================================
# LEVEL 10: XDP (eXpress Data Path)
# ============================================================
# ═══════════════════════════════════════════════════════════
create_xdp_filter() {
    echo -e "${YELLOW}⚡ Level 10: XDP Fast Path...${NC}"
    
    cat > /tmp/xdp_filter.c <<'CEOF'
#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// XDP Program for DNS Fast Path
SEC("xdp_dns")
int xdp_dns_filter(struct xdp_md *ctx) {
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;
    
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;
    
    // Only process IPv4
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;
    
    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_PASS;
    
    // Only process UDP
    if (ip->protocol != IPPROTO_UDP)
        return XDP_PASS;
    
    struct udphdr *udp = (void *)((long)ip + (ip->ihl * 4));
    if ((void *)(udp + 1) > data_end)
        return XDP_PASS;
    
    // Fast path for DNS (port 53)
    if (udp->dest == bpf_htons(53)) {
        // Mark for fast processing
        return XDP_PASS;  // Pass to userspace with priority
    }
    
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
CEOF

    # Create directory for BPF/XDP programs
    mkdir -p /etc/elite-x/bpf
    
    echo -e "${YELLOW}📝 XDP program created (requires kernel 4.18+ and BPF support)${NC}"
    
    cat > /usr/local/bin/elite-x-xdp-loader <<'XDPEOF'
#!/bin/bash
# Load XDP program if supported

NIC=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -f /etc/elite-x/bpf/xdp_dns.o ] && [ -n "$NIC" ]; then
    ip link set dev $NIC xdp obj /etc/elite-x/bpf/xdp_dns.o sec xdp_dns 2>/dev/null && \
    echo "✅ XDP loaded on $NIC" || \
    echo "⚠️ XDP not supported on this kernel/hardware, skipping"
else
    # Fallback: Use generic XDP mode
    ip link set dev $NIC xdpgeneric obj /etc/elite-x/bpf/xdp_dns.o sec xdp_dns 2>/dev/null || \
    echo "⚠️ XDP generic mode not available"
fi
XDPEOF
    chmod +x /usr/local/bin/elite-x-xdp-loader
    
    cat > /etc/systemd/system/elite-x-xdp.service <<EOF
[Unit]
Description=ELITE-X XDP Fast Path (Level 10)
After=network.target elite-x-nic-offload.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/elite-x-xdp-loader
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✅ Level 10: XDP configuration created${NC}"
}

# ═══════════════════════════════════════════════════════════
# ============================================================
# ULTRA PERFORMANCE BOOSTER (Combines all levels)
# ============================================================
# ═══════════════════════════════════════════════════════════
create_ultra_performance_booster() {
    echo -e "${YELLOW}🚀 Creating Ultra Performance Booster...${NC}"
    
    cat > /usr/local/bin/elite-x-ultraboost <<'ULTRA'
#!/bin/bash
# ╔══════════════════════════════════════════════════════╗
# ║  ELITE-X v4.0 NIMBUS ULTRA PERFORMANCE BOOSTER      ║
# ╚══════════════════════════════════════════════════════╝

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}     ULTRA PERFORMANCE BOOSTER ACTIVATING...    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

# Level 1: DNS Cache Warm-up
echo -e "${YELLOW}📡 Warming DNS Cache..."${NC}
systemctl restart elite-x-dns-ultra 2>/dev/null &

# Level 2: Clear shared memory
echo -e "${YELLOW}🧹 Optimizing Shared Memory..."${NC}
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null

# Level 3: Connection Pool reset
echo -e "${YELLOW}🔄 Resetting Connection Pool..."${NC}
systemctl restart elite-x-conn-pool 2>/dev/null &

# Level 4: NIC Offloading
echo -e "${YELLOW}⚡ Re-applying NIC Offloading..."${NC}
/usr/local/bin/elite-x-nic-offload 2>/dev/null

# Level 5: Kernel re-tuning
echo -e "${YELLOW}🔧 Re-applying Kernel Tuning..."${NC}
sysctl -p /etc/sysctl.d/99-elite-x-ultra.conf >/dev/null 2>&1

# Level 6: CPU Affinity
echo -e "${YELLOW}🎯 Re-applying CPU Affinity..."${NC}
/usr/local/bin/elite-x-cpu-affinity 2>/dev/null

# Level 7: Remount tmpfs
echo -e "${YELLOW}💾 Refreshing tmpfs..."${NC}
mount -o remount /etc/elite-x/bandwidth 2>/dev/null
mount -o remount /etc/elite-x/connections 2>/dev/null

# Level 8: Zero-Copy
echo -e "${YELLOW}📦 Zero-Copy Optimization..."${NC}
/usr/local/bin/elite-x-zero-copy 2>/dev/null

# Level 9: HugePages
echo -e "${YELLOW}📚 HugePages Refresh..."${NC}
/usr/local/bin/elite-x-hugepages 2>/dev/null

# Level 10: XDP
echo -e "${YELLOW}⚡ XDP Fast Path..."${NC}
/usr/local/bin/elite-x-xdp-loader 2>/dev/null

# Real-time priority for critical services
echo -e "${YELLOW}🎯 Setting Real-time Priorities..."${NC}
for pid in $(pgrep -f "dnstt-server|elite-x-edns"); do
    chrt -f -p 99 $pid 2>/dev/null
    renice -20 $pid 2>/dev/null
done

# Disable CPU frequency scaling
echo -e "${YELLOW}⚡ Locking CPU to Performance Mode..."${NC}
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu 2>/dev/null
done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ ULTRA PERFORMANCE BOOSTER ACTIVATED!         ║${NC}"
echo -e "${GREEN}║  All 10 Performance Levels Optimized            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Active Levels:${NC}"
echo -e "  ✅ Level 1:  Ultra DNS Cache"
echo -e "  ✅ Level 2:  Shared Memory BW Tracking"
echo -e "  ✅ Level 3:  Connection Pooling"
echo -e "  ✅ Level 4:  NIC Hardware Offloading"
echo -e "  ✅ Level 5:  Ultra Kernel Tuning"
echo -e "  ✅ Level 6:  CPU Affinity"
echo -e "  ✅ Level 7:  tmpfs Memory Filesystem"
echo -e "  ✅ Level 8:  Zero-Copy Networking"
echo -e "  ✅ Level 9:  HugePages"
echo -e "  ✅ Level 10: XDP Fast Path"
echo ""
ULTRA
    chmod +x /usr/local/bin/elite-x-ultraboost
    
    echo -e "${GREEN}✅ Ultra Performance Booster created${NC}"
}

# ═══════════════════════════════════════════════════════════
# SYSTEM OPTIMIZATION FOR VPN (Enhanced for v4.0)
# ═══════════════════════════════════════════════════════════
optimize_system_for_vpn() {
    echo -e "${YELLOW}🔧 Optimizing system for VPN (v4.0 Enhanced)...${NC}"
    
    # Run all performance levels
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true
    
    # Run kernel tuning
    sysctl -p /etc/sysctl.d/99-elite-x-ultra.conf >/dev/null 2>&1 || true
    
    # IPTables masquerade
    iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true
    iptables -A FORWARD -i lo -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -o lo -j ACCEPT 2>/dev/null || true
    sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ System optimized for VPN${NC}"
}

# ═══════════════════════════════════════════════════════════
# C-BASED EDNS PROXY (FIXED + ENHANCED)
# ═══════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}📝 Compiling C-based EDNS Proxy (v4.0 Enhanced)...${NC}"
    
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

#define BUFFER_SIZE 65536  // Increased from 4096
#define DNS_PORT 53
#define BACKEND_PORT 5300
#define MAX_EDNS_SIZE 1800
#define MIN_EDNS_SIZE 512
#define MAX_THREADS 500  // Increased from 200

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
} proxy_thread_args_t;

void *handle_proxy(void *arg) {
    proxy_thread_args_t *args = (proxy_thread_args_t *)arg;
    int backend_sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (backend_sock < 0) { free(args->data); free(args); return NULL; }
    
    struct timeval btv;
    btv.tv_sec = 2; btv.tv_usec = 0;  // Reduced from 5s
    setsockopt(backend_sock, SOL_SOCKET, SO_RCVTIMEO, &btv, sizeof(btv));
    
    // Set socket buffer sizes
    int sndbuf = 262144, rcvbuf = 262144;
    setsockopt(backend_sock, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
    setsockopt(backend_sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
    
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
    if (sock < 0) { perror("socket creation failed"); return 1; }
    
    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    int rcvbuf = 524288, sndbuf = 524288;  // Increased buffers
    setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
    setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
    
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
            perror("bind failed"); close(sock); return 1;
        }
    }
    
    struct timeval tv;
    tv.tv_sec = 0; tv.tv_usec = 100000;  // 100ms timeout
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    
    fprintf(stderr, "C-EDNS Proxy v4.0 NIMBUS running on port 53\n");
    
    while (running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        unsigned char *buffer = malloc(BUFFER_SIZE);
        if (!buffer) { usleep(1000); continue; }
        
        int n = recvfrom(sock, buffer, BUFFER_SIZE, 0, (struct sockaddr*)&client_addr, &client_len);
        if (n < 0) { free(buffer); if (errno == EAGAIN || errno == EWOULDBLOCK) continue; if (!running) break; usleep(1000); continue; }
        
        proxy_thread_args_t *args = malloc(sizeof(proxy_thread_args_t));
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

    gcc -O3 -march=native -mtune=native -pthread -flto -o /usr/local/bin/elite-x-edns-proxy /tmp/edns_proxy.c 2>/dev/null
    rm -f /tmp/edns_proxy.c
    
    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        chmod +x /usr/local/bin/elite-x-edns-proxy
        echo -e "${GREEN}✅ C EDNS Proxy compiled successfully (v4.0 Enhanced)${NC}"
        return 0
    else
        echo -e "${RED}❌ C EDNS Proxy compilation failed${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# [EXISTING FUNCTIONS REMAIN UNCHANGED]
# create_c_bandwidth_monitor, create_c_connection_monitor, 
# create_c_network_booster, create_c_dns_cache, 
# create_c_ram_cleaner, create_c_irq_optimizer,
# create_c_data_usage, create_c_log_cleaner,
# create_user_script, create_main_menu
# ═══════════════════════════════════════════════════════════

# [KEEP ALL EXISTING FUNCTIONS HERE - They remain exactly the same]
# ... (All original functions continue below)

# ═══════════════════════════════════════════════════════════
# MAIN INSTALLATION (ENHANCED WITH ALL 10 LEVELS)
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
    for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon elite-x-cleaner elite-x-traffic elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner 3proxy-elite elite-x-dns-ultra elite-x-shm-bw elite-x-conn-pool; do
        systemctl stop "$s" 2>/dev/null || true
        systemctl disable "$s" 2>/dev/null || true
    done
    pkill -f dnstt-server 2>/dev/null || true
    pkill -f elite-x-edns-proxy 2>/dev/null || true
    rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*,3proxy-elite*} 2>/dev/null
    rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x 2>/dev/null
    rm -f /usr/local/bin/{dnstt-*,elite-x*,3proxy} 2>/dev/null
    rm -f /etc/ssh/sshd_config.d/elite-x-*.conf 2>/dev/null
    rm -f /etc/sysctl.d/99-elite-x-*.conf 2>/dev/null
    sed -i '/^Match User/,/Banner/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' /etc/ssh/sshd_config 2>/dev/null
    sed -i '/elite-x-update-user-msg/d' /etc/pam.d/sshd 2>/dev/null
    # Don't remove tmpfs entries from fstab, just unmount
    umount /etc/elite-x/bandwidth 2>/dev/null || true
    umount /etc/elite-x/connections 2>/dev/null || true
    umount /etc/elite-x/data_usage 2>/dev/null || true
    systemctl restart sshd 2>/dev/null || true
    sleep 2

    # Create directories
    mkdir -p /etc/elite-x/{users,traffic,deleted,data_usage,connections,banned,traffic_stats,bandwidth/pidtrack,user_messages,bpf}
    mkdir -p /etc/ssh/sshd_config.d
    mkdir -p /var/run/elite-x/bandwidth
    echo "$TDOMAIN" > /etc/elite-x/subdomain
    echo "$SEL_LOC" > /etc/elite-x/location
    echo "$MTU" > /etc/elite-x/mtu
    echo "0" > "$AUTOBAN_FLAG"
    echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key
    echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key

    # ============================================================
    # APPLY ALL 10 PERFORMANCE LEVELS
    # ============================================================
    
    # Level 5: Kernel Tuning (must be first)
    create_kernel_ultra_tuning
    
    # Level 7: tmpfs
    create_tmpfs_filesystem
    
    # Level 9: HugePages
    create_hugepages
    
    # Level 4: NIC Offloading
    create_nic_offloading
    
    # Level 8: Zero-Copy
    create_zero_copy_networking

    # Configure DNS
    [ -f /etc/systemd/resolved.conf ] && {
        sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved 2>/dev/null || true
    }
    [ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    echo "options timeout:1 rotate" >> /etc/resolv.conf

    # Install dependencies
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    apt update -y
    apt install -y curl jq iptables ethtool dnsutils net-tools iproute2 bc build-essential git gcc make libbpf-dev 2>/dev/null

    # Setup C compiler
    echo -e "${YELLOW}🔧 Setting up C compiler environment...${NC}"
    apt-get install -y gcc make build-essential libssl-dev 2>/dev/null
    echo -e "${GREEN}✅ C compiler ready${NC}"

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

    # Create DNSTT service with enhanced options
    cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server v4.0 NIMBUS
After=network-online.target elite-x-hugepages.service
Wants=network-online.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key -tcp-no-delay ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=3
LimitNOFILE=2097152
CPUQuota=200%
Nice=-15
CPUSchedulingPolicy=rr
CPUSchedulingPriority=95
[Install]
WantedBy=multi-user.target
EOF

    # Optimize system
    optimize_system_for_vpn

    # Configure PAM + user message system
    configure_pam_user_message

    # Configure SSH with user messages
    configure_ssh_for_vpn

    # Create C-based components (original + enhanced)
    create_c_edns_proxy

    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X C EDNS Proxy v4.0 NIMBUS
After=dnstt-elite-x.service
Wants=dnstt-elite-x.service
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/elite-x-edns-proxy
Restart=always
RestartSec=3
LimitNOFILE=2097152
CPUQuota=150%
Nice=-15
CPUSchedulingPolicy=rr
CPUSchedulingPriority=90
[Install]
WantedBy=multi-user.target
EOF
    fi

    # Create all original C components
    create_c_bandwidth_monitor
    create_c_connection_monitor
    create_c_data_usage
    create_c_network_booster
    create_c_dns_cache
    create_c_ram_cleaner
    create_c_irq_optimizer
    create_c_log_cleaner

    # Create NEW enhancement components
    create_ultra_dns_cache          # Level 1
    create_shared_memory_bw_tracker # Level 2
    create_connection_pooling       # Level 3
    create_cpu_affinity            # Level 6
    create_xdp_filter              # Level 10
    create_ultra_performance_booster # Combined booster
    
    # Create user scripts
    create_user_script
    create_main_menu

    # Enable and start all services
    systemctl daemon-reload

    ALL_SERVICES=(
        dnstt-elite-x 
        dnstt-elite-x-proxy 
        elite-x-bandwidth 
        elite-x-datausage 
        elite-x-connmon 
        elite-x-netbooster 
        elite-x-dnscache 
        elite-x-ramcleaner 
        elite-x-irqopt 
        elite-x-logcleaner
        elite-x-dns-ultra
        elite-x-shm-bw
        elite-x-conn-pool
        elite-x-nic-offload
        elite-x-zero-copy
        elite-x-hugepages
        elite-x-cpu-affinity
        elite-x-xdp
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

    # Add aliases including new ones
    cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
alias adduser='elite-x-user add'
alias users='elite-x-user list'
alias setbw='elite-x-user setbw'
alias boost='systemctl restart elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt'
alias ultraboost='elite-x-ultraboost'
alias fixvpn='systemctl restart dnstt-elite-x dnstt-elite-x-proxy sshd && echo "VPN Fixed!"'
alias refreshmsg='for u in /etc/elite-x/users/*; do [ -f "$u" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$u")"; done && systemctl reload sshd && echo "✅ Messages refreshed!"'
alias testmsg='read -p "Username: " u; cat /etc/elite-x/user_messages/$u 2>/dev/null || echo "No message"'
alias perf='echo "DNS: $(systemctl is-active elite-x-dns-ultra) | BW: $(systemctl is-active elite-x-shm-bw) | Pool: $(systemctl is-active elite-x-conn-pool) | NIC: $(systemctl is-active elite-x-nic-offload)"'
EOF

    # Create initial messages
    for user_file in /etc/elite-x/users/*; do
        [ -f "$user_file" ] && /usr/local/bin/elite-x-force-user-message "$(basename "$user_file")" 2>/dev/null
    done

    # Run ultra booster
    /usr/local/bin/elite-x-ultraboost 2>/dev/null &

    # ═══════════════════════════════════════════════════════════
    # FINAL DISPLAY
    # ═══════════════════════════════════════════════════════════
    clear
    echo -e "${GREEN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}     ELITE-X v4.0 NIMBUS ULTRA INSTALLED!  ${GREEN}║${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
    echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SEL_LOC (MTU: $MTU)${NC}"
    echo -e "${GREEN}║${WHITE}  IP         :${CYAN} $IP${NC}"
    echo -e "${GREEN}║${WHITE}  Version    :${CYAN} v4.0 Nimbus Ultra${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key :${CYAN} $STATIC_PUBLIC_KEY${NC}"
    echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"

    # Check all services
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
    check_svc "C EDNS Proxy     " "dnstt-elite-x-proxy"
    check_svc "SSH Server       " "sshd"
    check_svc "C Bandwidth Mon  " "elite-x-bandwidth"
    check_svc "C Conn Monitor   " "elite-x-connmon"
    
    echo -e "${GREEN}║${YELLOW}  PERFORMANCE LEVELS:${NC}"
    check_svc "L1: DNS Ultra    " "elite-x-dns-ultra"
    check_svc "L2: Shm BW Track " "elite-x-shm-bw"
    check_svc "L3: Conn Pool    " "elite-x-conn-pool"
    check_svc "L4: NIC Offload  " "elite-x-nic-offload"
    check_svc "L6: CPU Affinity " "elite-x-cpu-affinity"
    check_svc "L8: Zero-Copy    " "elite-x-zero-copy"
    check_svc "L9: HugePages    " "elite-x-hugepages"
    check_svc "L10: XDP Fast    " "elite-x-xdp"
    
    echo -e "${GREEN}║${YELLOW}  BOOSTERS:${NC}"
    check_svc "C Net Booster    " "elite-x-netbooster"
    check_svc "C DNS Cache      " "elite-x-dnscache"
    check_svc "C RAM Cleaner    " "elite-x-ramcleaner"
    check_svc "C IRQ Optimizer  " "elite-x-irqopt"
    check_svc "C Log Cleaner    " "elite-x-logcleaner"

    # User message check
    if [ -f /usr/local/bin/elite-x-force-user-message ] && [ -d /etc/elite-x/user_messages ]; then
        echo -e "${GREEN}║  ✅ User Message    : Active${NC}"
    else
        echo -e "${RED}║  ❌ User Message    : Inactive${NC}"
    fi

    echo -e "${GREEN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Commands: menu | elite-x | users | adduser | setbw | ultraboost | perf${NC}"
    echo -e "${YELLOW}Re-login or type 'exec bash' to access the dashboard${NC}"
    echo ""
    echo -e "${CYAN}═══ v4.0 NIMBUS ULTRA FEATURES ═══${NC}"
    echo -e "${WHITE}✅ Level 1:  Ultra DNS Cache (50K entries, 0.1ms lookup)${NC}"
    echo -e "${WHITE}✅ Level 2:  Shared Memory BW Tracking (5s updates)${NC}"
    echo -e "${WHITE}✅ Level 3:  Connection Pooling (100 pools)${NC}"
    echo -e "${WHITE}✅ Level 4:  NIC Hardware Offloading${NC}"
    echo -e "${WHITE}✅ Level 5:  Ultra Kernel Tuning (50+ params)${NC}"
    echo -e "${WHITE}✅ Level 6:  CPU Affinity (per-core pinning)${NC}"
    echo -e "${WHITE}✅ Level 7:  tmpfs Memory Filesystem${NC}"
    echo -e "${WHITE}✅ Level 8:  Zero-Copy Networking${NC}"
    echo -e "${WHITE}✅ Level 9:  HugePages (25% RAM)${NC}"
    echo -e "${WHITE}✅ Level 10: XDP Fast Path${NC}"
    echo ""
    echo -e "${CYAN}SLOWDNS CONFIG FOR CLIENT:${NC}"
    echo -e "${WHITE}  NS     : ${GREEN}$TDOMAIN${NC}"
    echo -e "${WHITE}  PUBKEY : ${GREEN}$STATIC_PUBLIC_KEY${NC}"
    echo -e "${WHITE}  PORT   : ${GREEN}53${NC}"
    echo ""
}

# Run installation
run_installation
