#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║         ELITE-X8 ULTIMATE EDITION v4.0 - THE PERFECT MERGE                  ║
# ║      C-EDNS Proxy • Bandwidth Monitor • Auto-Delete • Web Dashboard         ║
# ║         IPv6 Disabled • BBR • 20MB Buffers • Multi-Core Optimization        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ==============================================================================
# COLORS & STYLING
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
ORANGE='\033[0;33m'
LIGHT_RED='\033[1;31m'
LIGHT_GREEN='\033[1;32m'
GRAY='\033[0;90m'
NC='\033[0m'

# ==============================================================================
# CONFIGURATION - PREDEFINED (DO NOT CHANGE - FROM REPO)
# ==============================================================================
STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

# ==============================================================================
# DIRECTORIES & PATHS
# ==============================================================================
USER_DB="/etc/elite-x/users"
USAGE_DB="/etc/elite-x/data_usage"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
PIDTRACK_DIR="$BANDWIDTH_DIR/pidtrack"
BANNED_DB="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"
DELETED_DB="/etc/elite-x/deleted"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
SLOWDNS_DIR="/etc/slowdns"
DASHBOARD_PORT=8080
SSHD_PORT=22
SLOWDNS_PORT=5300

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================
print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}     ELITE-X8 ULTIMATE v4.0 - PERFECT MERGE EDITION                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}     C EDNS Proxy • Bandwidth Monitor • Auto-Delete • Web Dashboard     ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}${BOLD}               TURBO BOOST • IPv6 OFF • BBR • 20MB BUFFERS               ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "\n${BLUE}▶${NC} ${CYAN}${BOLD}$1${NC}"; }
print_success() { echo -e "  ${GREEN}✓${NC} ${GREEN}$1${NC}"; }
print_error() { echo -e "  ${RED}✗${NC} ${RED}$1${NC}"; }
print_warning() { echo -e "  ${YELLOW}!${NC} ${YELLOW}$1${NC}"; }
print_info() { echo -e "  ${CYAN}ℹ${NC} ${CYAN}$1${NC}"; }

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/elite-x8-install.log
}

set_timezone() {
    timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true
}

# ==============================================================================
# ACTIVATION
# ==============================================================================
activation_check() {
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
}

# ==============================================================================
# SYSTEM OPTIMIZATION (From C-version.sh + wewew.sh)
# ==============================================================================
optimize_system() {
    print_step "Optimizing System (BBR, UDP Buffers, IPv6 Disabled)"
    
    # Maximize UDP buffers to 20MB
    cat > /etc/sysctl.d/99-elite-x8.conf << EOF
# ELITE-X8 ULTIMATE OPTIMIZATION
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.core.rmem_default = 20971520
net.core.wmem_default = 20971520
net.ipv4.udp_mem = 20971520 20971520 20971520
net.ipv4.udp_rmem_min = 20971520
net.ipv4.udp_wmem_min = 20971520
net.ipv4.tcp_rmem = 4096 87380 20971520
net.ipv4.tcp_wmem = 4096 65536 20971520
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0

# Disable IPv6 completely
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    sysctl -p /etc/sysctl.d/99-elite-x8.conf >/dev/null 2>&1
    
    # Disable IPv6 in GRUB
    if [ -f /etc/default/grub ] && ! grep -q "ipv6.disable=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
        update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
    fi
    
    # Disable systemd-resolved
    systemctl disable --now systemd-resolved 2>/dev/null
    systemctl stop systemd-resolved 2>/dev/null
    
    # Configure resolv.conf
    [ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    
    print_success "System optimized (BBR, 20MB UDP buffers, IPv6 disabled)"
}

# ==============================================================================
# SSH CONFIGURATION (From C-version.sh)
# ==============================================================================
configure_ssh() {
    print_step "Configuring SSH for VPN/Tunneling"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
    
    cat > /etc/ssh/sshd_config.d/elite-x8.conf << 'SSHCONF'
# ELITE-X8 ULTIMATE SSH CONFIGURATION
AddressFamily inet
Port 22
Protocol 2
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
SSHCONF

    if ! grep -q "Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
        echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    fi
    
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    print_success "SSH configured on port 22 (IPv4 only)"
}

# ==============================================================================
# C EDNS PROXY - ULTIMATE VERSION (Merged from both)
# ==============================================================================
compile_edns_proxy() {
    print_step "Compiling High-Performance C EDNS Proxy"
    
    apt-get install -y gcc make build-essential 2>/dev/null
    
    cat > /tmp/edns_proxy_ultimate.c << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <netinet/in.h>
#include <pthread.h>

#define LISTEN_PORT 53
#define BACKEND_PORT 5300
#define BACKEND_IP "127.0.0.1"
#define BUFFER_SIZE 4096
#define MAX_WORKERS 4
#define MAX_EVENTS 4096
#define UPSTREAM_POOL 32
#define TARGET_MTU 1800
#define EXT_EDNS 512

static volatile int running = 1;
static int sock, epoll_fd;
static int upstream_fds[UPSTREAM_POOL];
static int upstream_busy[UPSTREAM_POOL];

typedef struct {
    uint16_t id;
    int upstream_idx;
    double timestamp;
    struct sockaddr_in client_addr;
    socklen_t addr_len;
    struct req_entry *next;
} req_entry_t;

static req_entry_t *req_table[65536];
static pthread_mutex_t req_mutex = PTHREAD_MUTEX_INITIALIZER;

void signal_handler(int sig) { running = 0; }

double now() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

uint16_t get_txid(unsigned char *b) { return ((uint16_t)b[0] << 8) | b[1]; }

uint32_t req_hash(uint16_t id) { return id & 65535; }

int skip_name(unsigned char *ptr, unsigned char *end) {
    while (ptr < end) {
        if (*ptr == 0) return 1;
        if ((*ptr & 0xC0) == 0xC0) return 2;
        ptr += *ptr + 1;
    }
    return 0;
}

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
        int skip = skip_name(ptr, end);
        if (!skip) return;
        ptr += skip;
        if (ptr + 4 > end) return;
        ptr += 4;
    }
    
    for (i = 0; i < ancount + nscount && ptr < end; i++) {
        int skip = skip_name(ptr, end);
        if (!skip) return;
        ptr += skip;
        if (ptr + 10 > end) return;
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }
    
    for (i = 0; i < arcount && ptr < end; i++) {
        int skip = skip_name(ptr, end);
        if (!skip) return;
        ptr += skip;
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

void release_upstream(int i) {
    if (i >= 0 && i < UPSTREAM_POOL) upstream_busy[i] = 0;
}

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
        if (*pp == e) {
            *pp = e->next;
            free(e);
            break;
        }
        pp = &(*pp)->next;
    }
    pthread_mutex_unlock(&req_mutex);
}

void cleanup_expired() {
    double t = now();
    pthread_mutex_lock(&req_mutex);
    for (int i = 0; i < 65536; i++) {
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
    
    // Create main socket with SO_REUSEPORT
    sock = socket(AF_INET, SOCK_DGRAM, 0);
    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, sizeof(reuse));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(LISTEN_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    // Kill any process using port 53
    system("fuser -k 53/udp 2>/dev/null");
    usleep(1000000);
    
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        return 1;
    }
    
    // Setup upstream sockets
    struct sockaddr_in backend_addr = {0};
    backend_addr.sin_family = AF_INET;
    backend_addr.sin_port = htons(BACKEND_PORT);
    inet_pton(AF_INET, BACKEND_IP, &backend_addr.sin_addr);
    
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        upstream_fds[i] = socket(AF_INET, SOCK_DGRAM, 0);
        fcntl(upstream_fds[i], F_SETFL, O_NONBLOCK);
        upstream_busy[i] = 0;
    }
    
    // Setup epoll
    epoll_fd = epoll_create1(0);
    struct epoll_event ev = {.events = EPOLLIN, .data.fd = sock};
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, sock, &ev);
    
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        ev.events = EPOLLIN;
        ev.data.fd = upstream_fds[i];
        epoll_ctl(epoll_fd, EPOLL_CTL_ADD, upstream_fds[i], &ev);
    }
    
    fprintf(stderr, "🚀 ELITE-X8 C EDNS Proxy running on port 53 (IPv4 only, multi-core)\n");
    
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

    gcc -O3 -march=native -mtune=native -pipe -pthread -flto -o /usr/local/bin/elite-x8-edns /tmp/edns_proxy_ultimate.c 2>/dev/null
    
    if [ -f /usr/local/bin/elite-x8-edns ]; then
        chmod +x /usr/local/bin/elite-x8-edns
        print_success "C EDNS Proxy compiled successfully (multi-core, SO_REUSEPORT)"
    else
        print_error "Compilation failed"
        return 1
    fi
    
    rm -f /tmp/edns_proxy_ultimate.c
}

# ==============================================================================
# C BANDWIDTH MONITOR (From C-version.sh - Enhanced)
# ==============================================================================
compile_bandwidth_monitor() {
    print_step "Compiling C Bandwidth Monitor"
    
    cat > /tmp/bw_monitor.c << 'BWEOF'
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
            
            int pids[100];
            int pid_count = get_sshd_pids(user_entry->d_name, pids, 100);
            
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

    gcc -O3 -o /usr/local/bin/elite-x8-bandwidth /tmp/bw_monitor.c 2>/dev/null
    rm -f /tmp/bw_monitor.c
    
    if [ -f /usr/local/bin/elite-x8-bandwidth ]; then
        chmod +x /usr/local/bin/elite-x8-bandwidth
        print_success "C Bandwidth Monitor compiled"
    else
        print_error "Bandwidth monitor compilation failed"
    fi
}

# ==============================================================================
# C CONNECTION MONITOR (From C-version.sh)
# ==============================================================================
compile_connection_monitor() {
    print_step "Compiling C Connection Monitor"
    
    cat > /tmp/conn_monitor.c << 'CONNEOF'
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
#define BW_DIR "/etc/elite-x/bandwidth"
#define PID_DIR "/etc/elite-x/bandwidth/pidtrack"
#define AUTOBAN_FLAG "/etc/elite-x/autoban_enabled"
#define SCAN_INTERVAL 5

static volatile int running = 1;

void signal_handler(int sig) { running = 0; }

int is_numeric(const char *str) {
    for (; *str; str++) if (!isdigit(*str)) return 0;
    return 1;
}

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
                    if (ppid != 1) count++;
                }
            }
        }
    }
    closedir(proc);
    return count;
}

void delete_expired_user(const char *username, const char *reason) {
    char cmd[2048];
    snprintf(cmd, sizeof(cmd),
            "userdel -r %s 2>/dev/null; "
            "rm -f %s/%s %s/%s %s/%s %s/%s %s/%s.usage; "
            "rm -f %s/%s__*.last 2>/dev/null",
            username, USER_DB, username, "/etc/elite-x/data_usage", username,
            CONN_DB, username, BANNED_DIR, username, BW_DIR, username,
            PID_DIR, username);
    system(cmd);
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    
    mkdir(CONN_DB, 0755);
    mkdir(BANNED_DIR, 0755);
    mkdir(DELETED_DIR, 0755);
    
    while (running) {
        DIR *user_dir = opendir(USER_DB);
        if (!user_dir) { sleep(SCAN_INTERVAL); continue; }
        
        time_t current_ts = time(NULL);
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
                        delete_expired_user(user_entry->d_name, "Expired");
                        continue;
                    }
                }
            }
            
            int current_conn = get_connection_count(user_entry->d_name);
            if (current_conn > conn_limit) {
                char lock_cmd[1024];
                snprintf(lock_cmd, sizeof(lock_cmd), "usermod -L %s 2>/dev/null && pkill -u %s 2>/dev/null",
                        user_entry->d_name, user_entry->d_name);
                system(lock_cmd);
            }
        }
        closedir(user_dir);
        sleep(SCAN_INTERVAL);
    }
    return 0;
}
CONNEOF

    gcc -O3 -o /usr/local/bin/elite-x8-connmon /tmp/conn_monitor.c 2>/dev/null
    rm -f /tmp/conn_monitor.c
    
    if [ -f /usr/local/bin/elite-x8-connmon ]; then
        chmod +x /usr/local/bin/elite-x8-connmon
        print_success "C Connection Monitor compiled"
    fi
}

# ==============================================================================
# USER MANAGEMENT SCRIPT (Enhanced from both versions)
# ==============================================================================
create_user_management() {
    print_step "Creating User Management System"
    
    mkdir -p "$USER_DB" "$USAGE_DB" "$DELETED_DB" "$BANNED_DB" "$CONN_DB" "$BANDWIDTH_DIR" "$PIDTRACK_DIR"
    echo "0" > "$AUTOBAN_FLAG"
    
    cat > /usr/local/bin/elite-x8-user << 'USEREOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';PURPLE='\033[0;35m';NC='\033[0m'

UD="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
PID_DIR="$BW_DIR/pidtrack"
PUBLIC_KEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "N/A")
SERVER_IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null)
NS=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "dns.google.com")

get_bandwidth_usage() {
    local bw_file="$BW_DIR/${1}.usage"
    [ -f "$bw_file" ] && echo "scale=2; $(cat "$bw_file") / 1073741824" | bc 2>/dev/null || echo "0.00"
}

add_user() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE ELITE-X8 USER                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists!${NC}"
        return
    fi
    
    read -p "$(echo -e $GREEN"Password [auto-generate]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8)
    
    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" days; days=${days:-30}
    read -p "$(echo -e $GREEN"Connection limit [2]: "$NC)" conn_limit; conn_limit=${conn_limit:-2}
    read -p "$(echo -e $GREEN"Bandwidth limit GB (0=unlimited) [0]: "$NC)" bandwidth_gb; bandwidth_gb=${bandwidth_gb:-0}
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    cat > "$UD/$username" << INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Bandwidth_GB: $bandwidth_gb
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    
    echo "0" > "$BW_DIR/${username}.usage"
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER CREATED SUCCESSFULLY                  ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username    :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password    :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Server      :${CYAN} $NS${NC}"
    echo -e "${GREEN}║${WHITE}  IP          :${CYAN} $SERVER_IP${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key  :${CYAN} $PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire      :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login   :${CYAN} $conn_limit${NC}"
    echo -e "${GREEN}║${WHITE}  Bandwidth   :${CYAN} $([ "$bandwidth_gb" != "0" ] && echo "${bandwidth_gb} GB" || echo "Unlimited")${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  SLOWDNS CONFIG:${NC}"
    echo -e "${GREEN}║${WHITE}  NS     : ${CYAN}$NS${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY : ${CYAN}$PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE}  PORT   : ${CYAN}53${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                    ACTIVE USERS                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    
    [ -z "$(ls -A "$UD" 2>/dev/null)" ] && {
        echo -e "${CYAN}║${RED}                         No users found                             ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
        return
    }
    
    printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-14s %-18s${CYAN} ║${NC}\n" "USERNAME" "EXPIRE" "LOGIN" "BANDWIDTH" "STATUS"
    echo -e "${CYAN}╟──────────────────────────────────────────────────────────────────────╢${NC}"
    
    for user in "$UD"/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        limit=$(grep "Conn_Limit:" "$user" | awk '{print $2}'); limit=${limit:-1}
        bw_limit=$(grep "Bandwidth_GB:" "$user" | awk '{print $2}'); bw_limit=${bw_limit:-0}
        total_gb=$(get_bandwidth_usage "$u")
        
        if passwd -S "$u" 2>/dev/null | grep -q "L"; then
            status="${RED}🔒 LOCKED${NC}"
        elif who | grep -q "$u"; then
            status="${GREEN}🟢 ONLINE${NC}"
        else
            status="${YELLOW}⚫ OFFLINE${NC}"
        fi
        
        [ "$bw_limit" != "0" ] && bw_disp="${total_gb}/${bw_limit}GB" || bw_disp="${total_gb}GB/∞"
        printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-14s %-18b${CYAN} ║${NC}\n" "$u" "$ex" "0/$limit" "$bw_disp" "$status"
    done
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
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
# TERMINAL PANEL (From wewew.sh)
# ==============================================================================
create_terminal_panel() {
    print_step "Creating Terminal Management Panel"
    
    cat > /usr/local/bin/elite-x8-panel << 'PANELSCRIPT'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

PUBLIC_KEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "N/A")
SERVER_IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "Unknown")
NS=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not set")

show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}          🚀 ELITE-X8 ULTIMATE VPS PANEL${NC}                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}              Management Console v4.0${NC}                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_status() {
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}📊 SERVER STATUS${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    
    systemctl is-active --quiet dnstt-elite-x && echo -e "${CYAN}│${NC} ${GREEN}●${NC} SlowDNS:   ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} SlowDNS:   ${RED}Stopped${NC}"
    systemctl is-active --quiet elite-x8-edns && echo -e "${CYAN}│${NC} ${GREEN}●${NC} EDNS Proxy: ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} EDNS Proxy: ${RED}Stopped${NC}"
    systemctl is-active --quiet sshd && echo -e "${CYAN}│${NC} ${GREEN}●${NC} SSH:        ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} SSH:        ${RED}Stopped${NC}"
    
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} NS:         ${WHITE}$NS${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IP:         ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Public Key: ${WHITE}${PUBLIC_KEY:0:40}...${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

main_menu() {
    while true; do
        show_header
        show_status
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}        ${WHITE}${BOLD}🎮 MAIN MENU${NC}                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} ${WHITE}Create User${NC}                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} ${WHITE}List Users${NC}                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} ${WHITE}Delete User${NC}                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} ${WHITE}Restart Services${NC}                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[5]${NC} ${WHITE}Show Public Key${NC}                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[6]${NC} ${WHITE}Web Dashboard URL${NC}                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC} ${WHITE}Exit${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        read -p "$(echo -e "${WHITE}Select: ${NC}")" choice
        
        case $choice in
            1) elite-x8-user add; read -p "Press Enter..." ;;
            2) elite-x8-user list; read -p "Press Enter..." ;;
            3) elite-x8-user del; read -p "Press Enter..." ;;
            4) systemctl restart dnstt-elite-x elite-x8-edns sshd; echo -e "${GREEN}Restarted${NC}"; sleep 2 ;;
            5) echo -e "\n${YELLOW}$PUBLIC_KEY${NC}\n"; read -p "Press Enter..." ;;
            6) echo -e "\n${GREEN}http://$SERVER_IP:8080${NC}\n"; read -p "Press Enter..." ;;
            0) exit 0 ;;
        esac
    done
}

main_menu
PANELSCRIPT

    chmod +x /usr/local/bin/elite-x8-panel
    ln -sf /usr/local/bin/elite-x8-panel /usr/bin/elitex 2>/dev/null
    print_success "Terminal panel created (run 'elitex')"
}

# ==============================================================================
# WEB DASHBOARD (From wewew.sh)
# ==============================================================================
create_web_dashboard() {
    print_step "Creating Web Dashboard"
    
    mkdir -p /etc/elite-x/dashboard
    
    cat > /etc/elite-x/dashboard/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X8 Ultimate Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            text-align: center;
        }
        .header h1 { color: white; font-size: 2em; margin-bottom: 10px; }
        .header p { color: rgba(255,255,255,0.8); }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            text-align: center;
            color: white;
        }
        .stat-card .value { font-size: 2em; font-weight: bold; color: #ffd700; }
        .stat-card .label { font-size: 0.9em; opacity: 0.8; margin-top: 5px; }
        .info-card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            color: white;
        }
        .public-key {
            background: #1a1a2e;
            border-radius: 10px;
            padding: 15px;
            font-family: monospace;
            word-break: break-all;
            color: #ffd700;
        }
        button {
            background: #667eea;
            border: none;
            color: white;
            padding: 10px 20px;
            border-radius: 10px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover { background: #764ba2; }
        pre { background: #1a1a2e; padding: 15px; border-radius: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 ELITE-X8 ULTIMATE DASHBOARD</h1>
            <p>C EDNS Proxy • Bandwidth Monitor • Auto-Delete • Multi-Core</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card"><div class="value" id="users">-</div><div class="label">Total Users</div></div>
            <div class="stat-card"><div class="value" id="online">-</div><div class="label">Online Users</div></div>
            <div class="stat-card"><div class="value" id="bandwidth">-</div><div class="label">Total Bandwidth (GB)</div></div>
            <div class="stat-card"><div class="value" id="uptime">-</div><div class="label">System Uptime</div></div>
        </div>
        
        <div class="info-card">
            <h3>🔑 Public Key</h3>
            <div class="public-key" id="publicKey">Loading...</div>
        </div>
        
        <div class="info-card">
            <h3>📋 Service Status</h3>
            <pre id="status"></pre>
        </div>
        
        <div class="info-card">
            <h3>⚡ Quick Actions</h3>
            <button onclick="restartServices()">🔄 Restart All</button>
            <button onclick="refreshData()">📊 Refresh</button>
        </div>
    </div>
    
    <script>
        async function fetchData() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();
                document.getElementById('users').textContent = data.users || 0;
                document.getElementById('online').textContent = data.online || 0;
                document.getElementById('bandwidth').textContent = data.bandwidth || '0';
                document.getElementById('uptime').textContent = data.uptime || 'N/A';
                document.getElementById('publicKey').textContent = data.publicKey || 'N/A';
                document.getElementById('status').textContent = data.services || 'No data';
            } catch(e) { console.error(e); }
        }
        
        async function restartServices() {
            await fetch('/api/restart', { method: 'POST' });
            alert('Services restarted');
            setTimeout(fetchData, 2000);
        }
        
        function refreshData() { fetchData(); }
        fetchData();
        setInterval(fetchData, 10000);
    </script>
</body>
</html>
HTMLEOF

    cat > /usr/local/bin/elite-x8-api << 'APIEOF'
#!/usr/bin/env python3
import http.server
import json
import subprocess
import os
import glob

class EliteX8API(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args): pass
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('/etc/elite-x/dashboard/index.html', 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/api/status':
            users = len(glob.glob('/etc/elite-x/users/*'))
            online = len(subprocess.run(['who'], capture_output=True, text=True).stdout.strip().split('\n'))
            uptime = subprocess.run(['uptime', '-p'], capture_output=True, text=True).stdout.strip()
            public_key = ''
            with open('/etc/elite-x/public_key', 'r') as f: public_key = f.read().strip()
            
            services = []
            for s in ['dnstt-elite-x', 'elite-x8-edns', 'elite-x8-bandwidth', 'elite-x8-connmon', 'sshd']:
                status = subprocess.run(['systemctl', 'is-active', s], capture_output=True, text=True).stdout.strip()
                services.append(f"{s}: {status}")
            
            self.send_json({
                'users': users, 'online': online, 'bandwidth': 'N/A',
                'uptime': uptime, 'publicKey': public_key, 'services': '\n'.join(services)
            })
    
    def do_POST(self):
        if self.path == '/api/restart':
            subprocess.run(['systemctl', 'restart', 'dnstt-elite-x', 'elite-x8-edns'])
            self.send_json({'status': 'ok'})

if __name__ == '__main__':
    http.server.HTTPServer(('0.0.0.0', 8080), EliteX8API).serve_forever()
APIEOF

    chmod +x /usr/local/bin/elite-x8-api
    print_success "Web dashboard created on port 8080"
}

# ==============================================================================
# CREATE SERVICES (Using dnstt-server from repo - DO NOT CHANGE)
# ==============================================================================
create_services() {
    print_step "Creating System Services"
    
    # Download dnstt-server from repo
    mkdir -p /etc/dnstt
    echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
    echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
    chmod 600 /etc/dnstt/server.key
    
    # Download dnstt-server binary
    if [ ! -f /usr/local/bin/dnstt-server ]; then
        curl -fsSL https://raw.githubusercontent.com/ELITE-X8/setup.sh/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null || \
        curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null
        chmod +x /usr/local/bin/dnstt-server
    fi
    
    # DNSTT Service
    cat > /etc/systemd/system/dnstt-elite-x.service << EOF
[Unit]
Description=ELITE-X8 DNSTT Server
After=network.target sshd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu 1200 -privkey-file /etc/dnstt/server.key $NAMESERVER 127.0.0.1:22
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # EDNS Proxy Service
    cat > /etc/systemd/system/elite-x8-edns.service << EOF
[Unit]
Description=ELITE-X8 C EDNS Proxy
After=dnstt-elite-x.service

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x8-edns
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # Bandwidth Monitor Service
    cat > /etc/systemd/system/elite-x8-bandwidth.service << EOF
[Unit]
Description=ELITE-X8 Bandwidth Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x8-bandwidth
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Connection Monitor Service
    cat > /etc/systemd/system/elite-x8-connmon.service << EOF
[Unit]
Description=ELITE-X8 Connection Monitor
After=network.target sshd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x8-connmon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Dashboard API Service
    cat > /etc/systemd/system/elite-x8-dashboard.service << EOF
[Unit]
Description=ELITE-X8 Web Dashboard
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/elite-x8-api
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    print_success "All services created"
}

# ==============================================================================
# START SERVICES
# ==============================================================================
start_services() {
    print_step "Starting All Services"
    
    systemctl daemon-reload
    
    for s in dnstt-elite-x elite-x8-edns elite-x8-bandwidth elite-x8-connmon elite-x8-dashboard; do
        systemctl enable "$s" 2>/dev/null
        systemctl start "$s" 2>/dev/null
        sleep 1
    done
    
    print_success "Services started"
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
show_summary() {
    SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo "$SERVER_IP" > /etc/elite-x/cached_ip
    echo "$NAMESERVER" > /etc/elite-x/subdomain
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}        ELITE-X8 ULTIMATE v4.0 - INSTALLATION COMPLETE!                ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Nameserver   :${CYAN} $NAMESERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Server IP    :${CYAN} $SERVER_IP${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key   :${CYAN} $STATIC_PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE}  Web Dashboard:${CYAN} http://$SERVER_IP:8080${NC}"
    echo -e "${GREEN}║${WHITE}  Terminal     :${CYAN} elitex${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    for s in dnstt-elite-x elite-x8-edns elite-x8-bandwidth elite-x8-connmon sshd; do
        if systemctl is-active --quiet "$s"; then
            echo -e "${GREEN}║  ✅ $s: Running${NC}"
        else
            echo -e "${RED}║  ❌ $s: Failed${NC}"
        fi
    done
    
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📌 Quick Commands:${NC}"
    echo -e "   ${GREEN}elitex${NC}           - Open terminal panel"
    echo -e "   ${GREEN}elite-x8-user add${NC} - Create new user"
    echo -e "   ${GREEN}elite-x8-user list${NC} - List all users"
    echo -e "   ${GREEN}systemctl restart dnstt-elite-x${NC} - Restart SlowDNS"
    echo ""
    echo -e "${CYAN}🎯 SLOWDNS CONFIG FOR CLIENTS:${NC}"
    echo -e "   NS     : ${GREEN}$NAMESERVER${NC}"
    echo -e "   PUBKEY : ${GREEN}$STATIC_PUBLIC_KEY${NC}"
    echo -e "   PORT   : ${GREEN}53${NC}"
}

# ==============================================================================
# MAIN INSTALLATION
# ==============================================================================
main() {
    print_banner
    activation_check
    set_timezone
    
    # Get nameserver
    echo -e "${WHITE}${BOLD}Enter your Nameserver (NS):${NC}"
    echo -e "${CYAN}  Example: dns.google.com, ns1.yourdomain.com${NC}"
    read -p "$(echo -e $GREEN"Nameserver: "$NC)" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
    # Clean previous installation
    print_step "Cleaning previous installation"
    for s in dnstt-elite-x elite-x8-edns elite-x8-bandwidth elite-x8-connmon elite-x8-dashboard; do
        systemctl stop "$s" 2>/dev/null || true
        systemctl disable "$s" 2>/dev/null || true
    done
    rm -rf /etc/elite-x /etc/dnstt /etc/slowdns 2>/dev/null
    rm -f /usr/local/bin/elite-x8-* /usr/local/bin/dnstt-server 2>/dev/null
    
    # Create directories
    mkdir -p /etc/elite-x /etc/dnstt
    
    # Run installation steps
    optimize_system
    configure_ssh
    compile_edns_proxy
    compile_bandwidth_monitor
    compile_connection_monitor
    create_user_management
    create_terminal_panel
    create_web_dashboard
    create_services
    start_services
    show_summary
    
    # Setup auto-login
    cat > /etc/profile.d/elite-x8.sh << 'EOF'
if [ -f /usr/local/bin/elite-x8-panel ] && [ -z "$ELITE_X8_SHOWN" ]; then
    export ELITE_X8_SHOWN=1
    /usr/local/bin/elite-x8-panel
fi
EOF
    chmod +x /etc/profile.d/elite-x8.sh
    
    echo -e "\n${GREEN}✅ Installation complete! Type 'elitex' to access the panel${NC}"
}

# Run main
main "$@"
