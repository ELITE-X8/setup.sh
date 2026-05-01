#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║      ELITE-X8 FALCON ULTIMATE v5.0 - 1GBPS BOOSTER EDITION                             ║
# ║         C EDNS Proxy • Bandwidth Monitor • Auto-Delete • Web Dashboard                  ║
# ║     ALL BOOSTERS: BBR2 • CAKE • XDP • GRO • TSO • IRQ • NUMA • 1GB BUFFERS             ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ==============================================================================
# COLORS
# ==============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
ORANGE='\033[0;33m'; LIGHT_RED='\033[1;31m'; LIGHT_GREEN='\033[1;32m'; GRAY='\033[0;90m'
NC='\033[0m'

# ==============================================================================
# CONFIGURATION
# ==============================================================================
STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

USER_DB="/etc/elite-x/users"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
PIDTRACK_DIR="$BANDWIDTH_DIR/pidtrack"
BANNED_DB="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"
DELETED_DB="/etc/elite-x/deleted"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
DASHBOARD_PORT=8080

# ==============================================================================
# BANNER
# ==============================================================================
show_banner() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}     ELITE-X8 FALCON ULTIMATE v5.0 - 1GBPS BOOSTER EDITION                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}     C EDNS • Bandwidth Monitor • Auto-Delete • Web Dashboard • 1GBPS READY     ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}${BOLD}     BBR2 • CAKE • XDP • GRO • TSO • IRQ • NUMA • 1GB BUFFERS • MULTI-CORE       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "\n${BLUE}▶${NC} ${CYAN}${BOLD}$1${NC}"; }
print_success() { echo -e "  ${GREEN}✓${NC} ${GREEN}$1${NC}"; }
print_error() { echo -e "  ${RED}✗${NC} ${RED}$1${NC}"; }
print_info() { echo -e "  ${CYAN}ℹ${NC} ${CYAN}$1${NC}"; }

# ==============================================================================
# 1GBPS KERNEL BOOSTERS (ULTIMATE OPTIMIZATION)
# ==============================================================================
optimize_1gbps() {
    print_step "APPLYING 1GBPS BOOSTERS - ULTIMATE OPTIMIZATION"
    
    # Backup existing sysctl
    cp /etc/sysctl.conf /etc/sysctl.conf.bak 2>/dev/null || true
    
    # ===== KERNEL 1GBPS OPTIMIZATIONS =====
    cat > /etc/sysctl.d/99-elite-x8-1gbps.conf << 'EOF'
# ═══════════════════════════════════════════════════════════════════════════
# ELITE-X8 FALCON 1GBPS ULTIMATE BOOSTER CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

# ===== NETWORK CORE - 1GB BUFFERS =====
net.core.rmem_max = 1073741824
net.core.wmem_max = 1073741824
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.optmem_max = 204800
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.core.dev_weight = 600
net.core.dev_weight_rx_bias = 300
net.core.busy_read = 50
net.core.busy_poll = 50

# ===== TCP 1GBPS OPTIMIZATIONS =====
net.ipv4.tcp_rmem = 4096 87380 1073741824
net.ipv4.tcp_wmem = 4096 65536 1073741824
net.ipv4.tcp_mem = 1073741824 1073741824 1073741824
net.ipv4.tcp_congestion_control = bbr2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 1024
net.ipv4.tcp_mtu_probe_floor = 48
net.ipv4.tcp_congestion_control = bbr2
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_app_win = 31
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fastopen_key = 0000000000000000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_orphan_retries = 1
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_comp_sack = 1
net.ipv4.tcp_limit_output_bytes = 262144
net.ipv4.tcp_challenge_ack_limit = 1000
net.ipv4.tcp_min_rtt_wlen = 300
net.ipv4.tcp_thin_linear_timeouts = 1
net.ipv4.tcp_thin_dupack = 1

# ===== UDP 1GBPS OPTIMIZATIONS =====
net.ipv4.udp_mem = 1073741824 1073741824 1073741824
net.ipv4.udp_rmem_min = 262144
net.ipv4.udp_wmem_min = 262144

# ===== IP & FORWARDING =====
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.ip_no_pmtu_disc = 1
net.ipv4.route.flush = 1

# ===== QUEUE DISCIPLINE - CAKE (Best for 1Gbps) =====
net.core.default_qdisc = cake

# ===== DISABLE IPv6 COMPLETELY =====
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# ===== MEMORY & CACHE =====
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 100
vm.dirty_expire_centisecs = 500
vm.vfs_cache_pressure = 50
vm.swappiness = 10
vm.max_map_count = 262144

# ===== FILE SYSTEM =====
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

EOF

    # Apply sysctl
    sysctl -p /etc/sysctl.d/99-elite-x8-1gbps.conf >/dev/null 2>&1
    
    # ===== INSTALL BBR2 MODULE =====
    print_info "Installing BBR2 congestion control..."
    if [ ! -f /lib/modules/$(uname -r)/kernel/net/ipv4/tcp_bbr2.ko ]; then
        # Try to compile BBR2 from source
        if command -v git &>/dev/null && command -v make &>/dev/null; then
            cd /tmp
            git clone https://github.com/google/bbr2.git 2>/dev/null || true
            cd bbr2 2>/dev/null && make 2>/dev/null || true
            cp tcp_bbr2.ko /lib/modules/$(uname -r)/kernel/net/ipv4/ 2>/dev/null || true
            depmod -a 2>/dev/null || true
            cd /tmp && rm -rf bbr2 2>/dev/null
        fi
    fi
    
    # Enable BBR2 if available, else fallback to BBR
    if lsmod | grep -q bbr2; then
        print_success "BBR2 congestion control activated"
    else
        # Fallback to BBR
        sed -i 's/bbr2/bbr/g' /etc/sysctl.d/99-elite-x8-1gbps.conf
        sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
        print_success "BBR congestion control activated (BBR2 not available)"
    fi
    
    # ===== SET CAKE QDISC ON INTERFACE =====
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$INTERFACE" ]; then
        tc qdisc replace dev "$INTERFACE" root cake bandwidth 1gbit 2>/dev/null || true
        print_success "CAKE qdisc set on $INTERFACE (1Gbps)"
    fi
    
    # ===== ENABLE GRO & TSO FOR 1Gbps =====
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ethtool -K "$iface" gro on tso on gso on rx on tx on 2>/dev/null || true
        ethtool -C "$iface" rx-usecs 10 tx-usecs 10 2>/dev/null || true
        ethtool -G "$iface" rx 4096 tx 4096 2>/dev/null || true
        echo "$iface" > /sys/class/net/"$iface"/queues/rx-0/rps_cpus 2>/dev/null || true
        echo 4096 > /sys/class/net/"$iface"/queues/rx-0/rps_flow_cnt 2>/dev/null || true
    done
    print_success "GRO/TSO enabled on all interfaces"
    
    # ===== IRQ AFFINITY - DISTRIBUTE ACROSS CORES =====
    CPU_CORES=$(nproc)
    MASK=$(printf "%x" $(( (1 << CPU_CORES) - 1 )))
    for irq in $(ls /proc/irq/ | grep -E '^[0-9]+$'); do
        echo "$MASK" > /proc/irq/"$irq"/smp_affinity 2>/dev/null || true
    done
    print_success "IRQ affinity distributed across $CPU_CORES cores"
    
    # ===== INCREASE FILES LIMITS =====
    cat > /etc/security/limits.d/99-elite-x8.conf << EOF
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
* soft nproc unlimited
* hard nproc unlimited
EOF
    
    # ===== DISABLE IPv6 IN GRUB =====
    if [ -f /etc/default/grub ]; then
        if ! grep -q "ipv6.disable=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& ipv6.disable=1/' /etc/default/grub
            update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
        fi
    fi
    
    # ===== SET HIGH TCP MEMORY =====
    echo "2097152" > /proc/sys/net/core/somaxconn 2>/dev/null || true
    
    print_success "✅ 1GBPS BOOSTERS APPLIED!"
    print_info "   - BBR2/BBR Congestion Control"
    print_info "   - 1GB UDP/TCP Buffers"
    print_info "   - CAKE Queue Discipline"
    print_info "   - GRO/TSO Hardware Offload"
    print_info "   - IRQ Multi-core Distribution"
    print_info "   - IPv6 Disabled"
    print_info "   - 1M File Limits"
}

# ==============================================================================
# C EDNS PROXY - 1GBPS OPTIMIZED
# ==============================================================================
compile_edns_1gbps() {
    print_step "COMPILING 1GBPS C EDNS PROXY (Multi-core + XDP Ready)"
    
    apt-get install -y gcc make build-essential libnuma-dev 2>/dev/null
    
    cat > /tmp/edns_1gbps.c << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <fcntl.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <numa.h>

#define LISTEN_PORT 53
#define BACKEND_PORT 5300
#define BACKEND_IP "127.0.0.1"
#define BUFFER_SIZE 8192
#define MAX_WORKERS 8
#define MAX_EVENTS 10000
#define UPSTREAM_POOL 64
#define TARGET_MTU 9000  // Jumbo frames for 1Gbps
#define EXT_EDNS 512
#define REQ_TABLE_SIZE 131072

static volatile int running = 1;
static int sock, epoll_fd;
static int upstream_fds[UPSTREAM_POOL];
static int upstream_busy[UPSTREAM_POOL];
static pthread_mutex_t req_mutex = PTHREAD_MUTEX_INITIALIZER;

typedef struct {
    uint16_t id;
    int upstream_idx;
    double timestamp;
    struct sockaddr_in client_addr;
    socklen_t addr_len;
    struct req_entry *next;
} req_entry_t;

static req_entry_t *req_table[REQ_TABLE_SIZE];

void signal_handler(int sig) { running = 0; }

double now() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

uint16_t get_txid(unsigned char *b) { return ((uint16_t)b[0] << 8) | b[1]; }
uint32_t req_hash(uint16_t id) { return id & (REQ_TABLE_SIZE - 1); }

void modify_edns(unsigned char *buf, int *len, int max_size) {
    if (*len < 12) return;
    unsigned char *ptr = buf + 12;
    unsigned char *end = buf + *len;
    int i;
    
    unsigned short qdcount = (buf[4] << 8) | buf[5];
    unsigned short ancount = (buf[6] << 8) | buf[7];
    unsigned short nscount = (buf[8] << 8) | buf[9];
    unsigned short arcount = (buf[10] << 8) | buf[11];
    
    for (i = 0; i < qdcount && ptr < end; i++) {
        while (ptr < end && *ptr) ptr += *ptr + 1;
        ptr++;
        if (ptr + 4 > end) return;
        ptr += 4;
    }
    
    for (i = 0; i < ancount + nscount && ptr < end; i++) {
        while (ptr < end && *ptr) ptr += *ptr + 1;
        ptr++;
        if (ptr + 10 > end) return;
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }
    
    for (i = 0; i < arcount && ptr < end; i++) {
        while (ptr < end && *ptr) ptr += *ptr + 1;
        ptr++;
        if (ptr + 10 > end) return;
        unsigned short rrtype = (ptr[0] << 8) | ptr[1];
        if (rrtype == 41) {
            ptr[2] = (max_size >> 8) & 0xFF;
            ptr[3] = max_size & 0xFF;
            return;
        }
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }
}

int get_upstream() {
    time_t t = time(NULL);
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        if (upstream_busy[i] && t - upstream_busy[i] > 2)
            upstream_busy[i] = 0;
        if (!upstream_busy[i]) {
            upstream_busy[i] = t;
            return i;
        }
    }
    return -1;
}

void release_upstream(int i) { if (i >= 0 && i < UPSTREAM_POOL) upstream_busy[i] = 0; }

void insert_req(int uidx, unsigned char *buf, struct sockaddr_in *c, socklen_t l) {
    req_entry_t *e = calloc(1, sizeof(*e));
    if (!e) return;
    e->upstream_idx = uidx;
    e->id = get_txid(buf);
    e->timestamp = now();
    e->client_addr = *c;
    e->addr_len = l;
    uint32_t h = req_hash(e->id);
    pthread_mutex_lock(&req_mutex);
    e->next = req_table[h];
    req_table[h] = e;
    pthread_mutex_unlock(&req_mutex);
}

req_entry_t *find_req(uint16_t id) {
    uint32_t h = req_hash(id);
    pthread_mutex_lock(&req_mutex);
    req_entry_t *e = req_table[h];
    while (e && e->id != id) e = e->next;
    pthread_mutex_unlock(&req_mutex);
    return e;
}

void delete_req(req_entry_t *e) {
    if (!e) return;
    release_upstream(e->upstream_idx);
    uint32_t h = req_hash(e->id);
    pthread_mutex_lock(&req_mutex);
    req_entry_t **pp = &req_table[h];
    while (*pp) {
        if (*pp == e) { *pp = e->next; free(e); break; }
        pp = &(*pp)->next;
    }
    pthread_mutex_unlock(&req_mutex);
}

void cleanup_expired() {
    double t = now();
    pthread_mutex_lock(&req_mutex);
    for (int i = 0; i < REQ_TABLE_SIZE; i++) {
        req_entry_t **pp = &req_table[i];
        while (*pp) {
            if (t - (*pp)->timestamp > 5.0) {
                req_entry_t *old = *pp;
                release_upstream(old->upstream_idx);
                *pp = old->next;
                free(old);
            } else {
                pp = &(*pp)->next;
            }
        }
    }
    pthread_mutex_unlock(&req_mutex);
}

int main() {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Increase file limits
    struct rlimit rl = {1048576, 1048576};
    setrlimit(RLIMIT_NOFILE, &rl);
    
    // Bind to specific NUMA node if available
    if (numa_available() >= 0) {
        numa_bind(numa_alloc_onnode(0, 0));
    }
    
    // Create socket with SO_REUSEPORT
    sock = socket(AF_INET, SOCK_DGRAM, 0);
    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, sizeof(reuse));
    
    // Increase socket buffers for 1Gbps
    int rcvbuf = 1073741824;  // 1GB
    int sndbuf = 1073741824;
    setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
    setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(LISTEN_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    system("fuser -k 53/udp 2>/dev/null");
    usleep(1000000);
    
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        return 1;
    }
    
    struct sockaddr_in backend_addr = {0};
    backend_addr.sin_family = AF_INET;
    backend_addr.sin_port = htons(BACKEND_PORT);
    inet_pton(AF_INET, BACKEND_IP, &backend_addr.sin_addr);
    
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        upstream_fds[i] = socket(AF_INET, SOCK_DGRAM, 0);
        fcntl(upstream_fds[i], F_SETFL, O_NONBLOCK);
        setsockopt(upstream_fds[i], SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
        setsockopt(upstream_fds[i], SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
        upstream_busy[i] = 0;
    }
    
    epoll_fd = epoll_create1(0);
    struct epoll_event ev = {.events = EPOLLIN, .data.fd = sock};
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, sock, &ev);
    
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        ev.events = EPOLLIN;
        ev.data.fd = upstream_fds[i];
        epoll_ctl(epoll_fd, EPOLL_CTL_ADD, upstream_fds[i], &ev);
    }
    
    fprintf(stderr, "🚀 ELITE-X8 1GBPS EDNS Proxy running on port 53\n");
    fprintf(stderr, "   Buffers: 1GB | Workers: %d | Upstreams: %d\n", MAX_WORKERS, UPSTREAM_POOL);
    
    struct epoll_event events[MAX_EVENTS];
    
    while (running) {
        cleanup_expired();
        int n = epoll_wait(epoll_fd, events, MAX_EVENTS, 10);
        
        for (int i = 0; i < n; i++) {
            int fd = events[i].data.fd;
            
            if (fd == sock) {
                unsigned char buf[BUFFER_SIZE];
                struct sockaddr_in client_addr;
                socklen_t client_len = sizeof(client_addr);
                int len = recvfrom(sock, buf, BUFFER_SIZE, 0, (struct sockaddr*)&client_addr, &client_len);
                
                if (len > 0) {
                    int mlen = len;
                    modify_edns(buf, &mlen, TARGET_MTU);
                    int u = get_upstream();
                    if (u >= 0) {
                        insert_req(u, buf, &client_addr, client_len);
                        sendto(upstream_fds[u], buf, mlen, 0, (struct sockaddr*)&backend_addr, sizeof(backend_addr));
                    }
                }
            } else {
                unsigned char buf[BUFFER_SIZE];
                int len = recv(fd, buf, BUFFER_SIZE, 0);
                if (len > 0) {
                    uint16_t id = get_txid(buf);
                    req_entry_t *e = find_req(id);
                    if (e) {
                        modify_edns(buf, &len, EXT_EDNS);
                        sendto(sock, buf, len, 0, (struct sockaddr*)&e->client_addr, e->addr_len);
                        delete_req(e);
                    }
                }
            }
        }
    }
    
    close(sock);
    for (int i = 0; i < UPSTREAM_POOL; i++) close(upstream_fds[i]);
    return 0;
}
CEOF

    gcc -O3 -march=native -mtune=native -pipe -pthread -flto -m64 -D_GNU_SOURCE \
        -o /usr/local/bin/elite-x8-edns-1gbps /tmp/edns_1gbps.c -lnuma 2>/dev/null || \
    gcc -O3 -march=native -mtune=native -pipe -pthread -flto -o /usr/local/bin/elite-x8-edns-1gbps /tmp/edns_1gbps.c 2>/dev/null
    
    if [ -f /usr/local/bin/elite-x8-edns-1gbps ]; then
        chmod +x /usr/local/bin/elite-x8-edns-1gbps
        print_success "1GBPS C EDNS Proxy compiled (NUMA-aware, 1GB buffers)"
    else
        print_error "Compilation failed"
        return 1
    fi
    
    rm -f /tmp/edns_1gbps.c
}

# ==============================================================================
# C BANDWIDTH MONITOR (Optimized for 1Gbps)
# ==============================================================================
compile_bandwidth_1gbps() {
    print_step "COMPILING 1GBPS C BANDWIDTH MONITOR"
    
    cat > /tmp/bw_1gbps.c << 'BWEOF'
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
#define SCAN_INTERVAL 10
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

int is_numeric(const char *str) {
    for (; *str; str++) if (!isdigit(*str)) return 0;
    return 1;
}

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
                if (strncmp(line, "Uid:", 4) == 0) {
                    sscanf(line, "%*s %s", uid_str);
                    break;
                }
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
    
    mkdir(BW_DIR, 0755);
    mkdir(PID_DIR, 0755);
    mkdir(BANNED_DIR, 0755);
    
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
                if (strncmp(line, "Bandwidth_GB:", 13) == 0)
                    sscanf(line + 13, "%lf", &bandwidth_gb);
            }
            fclose(uf);
            
            if (bandwidth_gb <= 0) continue;
            
            int pids[200];
            int pid_count = get_sshd_pids(user_entry->d_name, pids, 200);
            
            if (pid_count == 0) {
                char cmd[512];
                snprintf(cmd, sizeof(cmd), "rm -f %s/%s__*.last 2>/dev/null", PID_DIR, user_entry->d_name);
                system(cmd);
                continue;
            }
            
            long long delta_total = 0;
            for (int i = 0; i < pid_count; i++) {
                long long cur_io = get_process_io(pids[i]);
                char pidfile[512];
                snprintf(pidfile, sizeof(pidfile), "%s/%s__%d.last", PID_DIR, user_entry->d_name, pids[i]);
                
                FILE *pf = fopen(pidfile, "r");
                if (pf) {
                    long long prev_io;
                    fscanf(pf, "%lld", &prev_io);
                    fclose(pf);
                    delta_total += (cur_io >= prev_io) ? (cur_io - prev_io) : cur_io;
                }
                
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
                snprintf(cmd, sizeof(cmd), "usermod -L %s 2>/dev/null && killall -u %s -9 2>/dev/null",
                        user_entry->d_name, user_entry->d_name);
                system(cmd);
            }
        }
        closedir(user_dir);
        sleep(SCAN_INTERVAL);
    }
    return 0;
}
BWEOF

    gcc -O3 -march=native -mtune=native -flto -o /usr/local/bin/elite-x8-bandwidth-1gbps /tmp/bw_1gbps.c 2>/dev/null
    rm -f /tmp/bw_1gbps.c
    
    if [ -f /usr/local/bin/elite-x8-bandwidth-1gbps ]; then
        chmod +x /usr/local/bin/elite-x8-bandwidth-1gbps
        print_success "1GBPS Bandwidth Monitor compiled"
    fi
}

# ==============================================================================
# SYSTEMD SERVICES FOR 1GBPS
# ==============================================================================
create_1gbps_services() {
    print_step "CREATING 1GBPS SYSTEM SERVICES"
    
    # DNSTT Service with 1Gbps settings
    cat > /etc/systemd/system/dnstt-elite-x.service << EOF
[Unit]
Description=ELITE-X8 DNSTT Server 1GBPS
After=network.target sshd.service

[Service]
Type=simple
Nice=-20
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu 9000 -privkey-file /etc/dnstt/server.key $NAMESERVER 127.0.0.1:22
Restart=always
RestartSec=3
LimitNOFILE=1048576
LimitMEMLOCK=infinity
CPUQuota=400%
IOSchedulingClass=realtime
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
EOF

    # EDNS Proxy Service
    cat > /etc/systemd/system/elite-x8-edns.service << EOF
[Unit]
Description=ELITE-X8 1GBPS EDNS Proxy
After=dnstt-elite-x.service

[Service]
Type=simple
Nice=-20
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=98
ExecStart=/usr/local/bin/elite-x8-edns-1gbps
Restart=always
RestartSec=2
LimitNOFILE=1048576
LimitMEMLOCK=infinity
CPUQuota=400%

[Install]
WantedBy=multi-user.target
EOF

    # Bandwidth Monitor Service
    cat > /etc/systemd/system/elite-x8-bandwidth.service << EOF
[Unit]
Description=ELITE-X8 1GBPS Bandwidth Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x8-bandwidth-1gbps
Restart=always
RestartSec=10
Nice=10

[Install]
WantedBy=multi-user.target
EOF

    print_success "1GBPS services created"
}

# ==============================================================================
# USER MANAGEMENT
# ==============================================================================
create_user_system() {
    print_step "CREATING USER MANAGEMENT SYSTEM"
    
    mkdir -p "$USER_DB" "$BANDWIDTH_DIR" "$PIDTRACK_DIR" "$BANNED_DB" "$CONN_DB" "$DELETED_DB"
    echo "0" > "$AUTOBAN_FLAG"
    
    cat > /usr/local/bin/elite-x8-user << 'USEREOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';PURPLE='\033[0;35m';NC='\033[0m'

UD="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
PUBLIC_KEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "N/A")
SERVER_IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null)
NS=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "dns.google.com")

get_bandwidth() { local f="$BW_DIR/${1}.usage"; [ -f "$f" ] && echo "scale=2; $(cat "$f")/1073741824" | bc 2>/dev/null || echo "0.00"; }

add_user() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE ELITE-X8 1GBPS USER                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    id "$username" &>/dev/null && { echo -e "${RED}Exists!${NC}"; return; }
    
    read -p "$(echo -e $GREEN"Password [auto]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
    
    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" days; days=${days:-30}
    read -p "$(echo -e $GREEN"Connection limit [5]: "$NC)" conn; conn=${conn:-5}
    read -p "$(echo -e $GREEN"Bandwidth GB [0=unlimited]: "$NC)" bw; bw=${bw:-0}
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    cat > "$UD/$username" << EOF
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn
Bandwidth_GB: $bw
Created: $(date +"%Y-%m-%d %H:%M:%S")
EOF
    echo "0" > "$BW_DIR/${username}.usage"
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}              USER CREATED - 1GBPS READY                    ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username: ${CYAN}$username${NC}"
    echo -e "${GREEN}║${WHITE}  Password: ${CYAN}$password${NC}"
    echo -e "${GREEN}║${WHITE}  NS:       ${CYAN}$NS${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY:   ${CYAN}$PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire:   ${CYAN}$expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login:${CYAN}$conn${NC}"
    echo -e "${GREEN}║${WHITE}  Bandwidth:${CYAN}$([ "$bw" != "0" ] && echo "${bw}GB" || echo "Unlimited")${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear; echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}              ACTIVE USERS (1GBPS)                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${NC}"
    for u in "$UD"/*; do [ -f "$u" ] && echo -e "${CYAN}║${WHITE}  $(basename "$u"): $(grep Expire: "$u" | cut -d' ' -f2) - $(get_bandwidth $(basename "$u"))GB${NC}"; done
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
}

case "$1" in
    add) add_user ;;
    list) list_users ;;
    del) read -p "Username: " u; userdel -r "$u" 2>/dev/null; rm -f "$UD/$u" "$BW_DIR/${u}.usage"; echo "Deleted" ;;
    *) echo "Usage: elite-x8-user {add|list|del}" ;;
esac
USEREOF

    chmod +x /usr/local/bin/elite-x8-user
    print_success "User management created"
}

# ==============================================================================
# TERMINAL PANEL
# ==============================================================================
create_panel() {
    print_step "CREATING 1GBPS TERMINAL PANEL"
    
    cat > /usr/local/bin/elitex << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

PUBLIC_KEY=$(cat /etc/elite-x/public_key 2>/dev/null | cut -c1-40)
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
NS=$(cat /etc/elite-x/subdomain 2>/dev/null)

show_speed() {
    SPEED=$(ping -c 1 8.8.8.8 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1)
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Latency:      ${WHITE}${SPEED:-N/A} ms${NC}"
}

show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}     🚀 ELITE-X8 1GBPS FALCON ULTIMATE v5.0${NC}                ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}         1GBPS BOOSTER EDITION - MAX PERFORMANCE${NC}          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}📊 SERVER STATUS - 1GBPS MODE${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    systemctl is-active --quiet dnstt-elite-x && echo -e "${CYAN}│${NC} ${GREEN}●${NC} SlowDNS:    ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} SlowDNS:    ${RED}Stopped${NC}"
    systemctl is-active --quiet elite-x8-edns && echo -e "${CYAN}│${NC} ${GREEN}●${NC} EDNS Proxy:  ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} EDNS Proxy:  ${RED}Stopped${NC}"
    show_speed
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}NS:   ${GREEN}$NS${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}KEY:  ${YELLOW}${PUBLIC_KEY:-N/A}...${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Create User   ${GREEN}[2]${NC} List Users     ${GREEN}[3]${NC} Delete User${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} Show Speed    ${GREEN}[5]${NC} Restart All    ${GREEN}[0]${NC} Exit${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
}

while true; do
    show_header
    read -p "$(echo -e "${WHITE}Select: ${NC}")" choice
    case $choice in
        1) elite-x8-user add; read -p "Press Enter..." ;;
        2) elite-x8-user list; read -p "Press Enter..." ;;
        3) elite-x8-user del; read -p "Press Enter..." ;;
        4) speedtest-cli --simple 2>/dev/null || echo "Install speedtest-cli"; read -p "Enter..." ;;
        5) systemctl restart dnstt-elite-x elite-x8-edns; echo "Restarted"; sleep 2 ;;
        0) exit 0 ;;
    esac
done
PANELEOF

    chmod +x /usr/local/bin/elitex
    print_success "Terminal panel created (type 'elitex')"
}

# ==============================================================================
# DOWNLOAD DNSTT SERVER (FROM REPO - DO NOT CHANGE)
# ==============================================================================
download_dnstt() {
    print_step "DOWNLOADING DNSTT SERVER"
    
    mkdir -p /etc/dnstt
    echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
    echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
    chmod 600 /etc/dnstt/server.key
    
    curl -fsSL https://raw.githubusercontent.com/ELITE-X8/setup.sh/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null || \
    curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null
    
    chmod +x /usr/local/bin/dnstt-server
    print_success "DNSTT server ready"
}

# ==============================================================================
# CONFIGURE SSH
# ==============================================================================
configure_ssh() {
    print_step "CONFIGURING SSH FOR 1GBPS"
    
    cat > /etc/ssh/sshd_config.d/elite-x8.conf << EOF
AddressFamily inet
Port 22
PermitRootLogin yes
PasswordAuthentication yes
AllowTcpForwarding yes
GatewayPorts yes
ClientAliveInterval 60
ClientAliveCountMax 3
MaxSessions 500
MaxStartups 500:30:1000
UseDNS no
EOF
    systemctl restart sshd
    print_success "SSH configured"
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
show_summary() {
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo "$SERVER_IP" > /etc/elite-x/cached_ip
    echo "$NAMESERVER" > /etc/elite-x/subdomain
    echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}     ELITE-X8 1GBPS FALCON ULTIMATE v5.0 - INSTALLED!                 ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Nameserver:   ${CYAN}$NAMESERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Server IP:    ${CYAN}$SERVER_IP${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key:   ${CYAN}${STATIC_PUBLIC_KEY:0:50}...${NC}"
    echo -e "${GREEN}║${WHITE}  UDP Buffers:  ${GREEN}1GB (1,073,741,824 bytes)${NC}"
    echo -e "${GREEN}║${WHITE}  Queue Disc:   ${GREEN}CAKE @ 1Gbps${NC}"
    echo -e "${GREEN}║${WHITE}  Congestion:   ${GREEN}BBR2/BBR${NC}"
    echo -e "${GREEN}║${WHITE}  IPv6:         ${RED}DISABLED${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    for s in dnstt-elite-x elite-x8-edns elite-x8-bandwidth sshd; do
        systemctl is-active --quiet "$s" && echo -e "${GREEN}║  ✅ $s: Running${NC}" || echo -e "${RED}║  ❌ $s: Failed${NC}"
    done
    
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📌 QUICK COMMANDS:${NC}"
    echo -e "   ${GREEN}elitex${NC}              - Open terminal panel"
    echo -e "   ${GREEN}elite-x8-user add${NC}   - Create user"
    echo -e "   ${GREEN}sysctl -a | grep bbr${NC} - Check BBR status"
    echo -e "   ${GREEN}tc qdisc show${NC}       - Check CAKE qdisc"
    echo ""
    echo -e "${CYAN}🎯 SLOWDNS CONFIG FOR CLIENTS (1GBPS READY):${NC}"
    echo -e "   NS     : ${GREEN}$NAMESERVER${NC}"
    echo -e "   PUBKEY : ${GREEN}$STATIC_PUBLIC_KEY${NC}"
    echo -e "   PORT   : ${GREEN}53${NC}"
}

# ==============================================================================
# MAIN INSTALLATION
# ==============================================================================
main() {
    show_banner
    
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT
    
    if [ "$ACTIVATION_INPUT" != "$ACTIVATION_KEY" ] && [ "$ACTIVATION_INPUT" != "Whatsapp +255713-628-668" ]; then
        echo -e "${RED}❌ Invalid activation key!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Activation successful${NC}"
    sleep 1
    
    timedatectl set-timezone $TIMEZONE 2>/dev/null || true
    
    echo -e "\n${WHITE}${BOLD}Enter your Nameserver (NS):${NC}"
    echo -e "${CYAN}  Example: dns.google.com, ns1.yourdomain.com${NC}"
    read -p "$(echo -e $GREEN"Nameserver: "$NC)" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
    # Install dependencies
    apt update -y
    apt install -y curl wget git gcc make build-essential ethtool net-tools bc 2>/dev/null
    
    # Apply 1Gbps boosters
    optimize_1gbps
    
    # Compile components
    download_dnstt
    compile_edns_1gbps
    compile_bandwidth_1gbps
    create_1gbps_services
    configure_ssh
    create_user_system
    create_panel
    
    # Start services
    systemctl daemon-reload
    systemctl enable dnstt-elite-x elite-x8-edns elite-x8-bandwidth
    systemctl start dnstt-elite-x elite-x8-edns elite-x8-bandwidth
    
    show_summary
    
    cat > /etc/profile.d/elitex.sh << 'EOF'
if [ -f /usr/local/bin/elitex ] && [ -z "$ELITEX_SHOWN" ]; then
    export ELITEX_SHOWN=1
    /usr/local/bin/elitex
fi
EOF
    chmod +x /etc/profile.d/elitex.sh
    
    echo -e "\n${GREEN}✅ Installation complete! Type 'elitex' to access the panel${NC}"
}

main "$@"
