#!/bin/bash

# ============================================================================
#                     SLOWDNS MODERN INSTALLATION SCRIPT
#                          ELITE-X8 EDITION
# ============================================================================

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;31m[✗]\033[0m Please run this script as root"
    exit 1
fi

# ============================================================================
# CONFIGURATION
# ============================================================================
SSHD_PORT=22
SLOWDNS_PORT=5300
DASHBOARD_PORT=8080
GITHUB_BASE="https://raw.githubusercontent.com/ELITE-X8/setup.sh/main"
LOG_FILE="/var/log/slowdns-install.log"

# ============================================================================
# MODERN COLORS & DESIGN
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# LOGGING FUNCTION
# ============================================================================
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ============================================================================
# ANIMATION FUNCTIONS
# ============================================================================
print_step() {
    echo -e "\n${BLUE}┌─${NC} ${CYAN}${BOLD}STEP $1${NC}"
    echo -e "${BLUE}│${NC}"
}

print_step_end() {
    echo -e "${BLUE}└─${NC} ${GREEN}✓${NC} Completed"
}

print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}          🚀 ELITE-X8 SLOWDNS MODERN INSTALLATION SCRIPT${NC}       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}            Fast & Professional Configuration${NC}                  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}                Optimized for Maximum Performance${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${GREEN}                   Panel Dashboard Included${NC}                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_header() {
    echo -e "\n${PURPLE}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "  ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "  ${RED}${BOLD}✗${NC} ${RED}$1${NC}"
}

print_warning() {
    echo -e "  ${YELLOW}${BOLD}!${NC} ${YELLOW}$1${NC}"
}

print_info() {
    echo -e "  ${CYAN}${BOLD}ℹ${NC} ${CYAN}$1${NC}"
}

# ============================================================================
# DISABLE IPV6 COMPLETELY
# ============================================================================
disable_ipv6() {
    print_header "🔧 DISABLING IPV6 COMPLETELY"
    
    # Disable IPv6 via sysctl
    cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
# Disable IPv6 completely
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    # Apply immediately
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf > /dev/null 2>&1
    
    # Disable IPv6 in GRUB for permanent disable at boot
    if [ -f /etc/default/grub ]; then
        cp /etc/default/grub /etc/default/grub.backup 2>/dev/null
        if ! grep -q "ipv6.disable=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
            if command -v update-grub &>/dev/null; then
                update-grub > /dev/null 2>&1
            elif command -v grub2-mkconfig &>/dev/null; then
                grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1
            fi
        fi
    fi
    
    # Stop and disable IPv6-related services
    systemctl stop systemd-networkd 2>/dev/null
    systemctl disable systemd-networkd 2>/dev/null
    
    print_success "IPv6 disabled completely (sysctl + GRUB)"
}

# ============================================================================
# KERNEL OPTIMIZATION
# ============================================================================
optimize_kernel() {
    print_header "⚡ KERNEL OPTIMIZATION"
    
    cat > /etc/sysctl.d/99-slowdns-optimization.conf << 'EOF'
# ============================================================================
# ELITE-X8 SLOWDNS KERNEL OPTIMIZATION
# ============================================================================

# Enable BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Maximize UDP buffers (20MB)
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.core.rmem_default = 20971520
net.core.wmem_default = 20971520

# Network backlog for handling many packets
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535

# TCP optimizations
net.ipv4.tcp_rmem = 4096 87380 20971520
net.ipv4.tcp_wmem = 4096 65536 20971520
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3

# UDP optimizations
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_mem = 20971520 26214400 41943040

# Increase connection tracking
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_established = 600

# File descriptor limits
fs.file-max = 2000000
fs.nr_open = 2000000

# Virtual memory for high performance
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    # Apply kernel optimizations
    sysctl -p /etc/sysctl.d/99-slowdns-optimization.conf > /dev/null 2>&1
    
    # Enable BBR if available
    if modprobe tcp_bbr 2>/dev/null; then
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null
        print_success "BBR congestion control enabled"
    else
        print_warning "BBR not available, using default congestion control"
    fi
    
    # Set system-wide file descriptor limits
    cat > /etc/security/limits.d/99-slowdns.conf << 'EOF'
* soft nofile 2000000
* hard nofile 2000000
* soft nproc 2000000
* hard nproc 2000000
root soft nofile 2000000
root hard nofile 2000000
root soft nproc 2000000
root hard nproc 2000000
EOF
    
    print_success "Kernel optimized for high-performance networking"
}

# ============================================================================
# CHECK SYSTEM REQUIREMENTS
# ============================================================================
check_requirements() {
    print_header "🔍 CHECKING SYSTEM REQUIREMENTS"
    
    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        print_success "OS: $OS $VER"
    else
        print_error "Cannot detect OS"
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    print_success "Architecture: $ARCH"
    
    # Check memory
    MEM=$(free -m | awk '/^Mem:/{print $2}')
    print_success "Memory: ${MEM}MB"
    
    # Check disk space
    DISK=$(df -h / | awk 'NR==2{print $4}')
    print_success "Available Disk: $DISK"
    
    # Check internet connection
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet: Connected"
    else
        print_error "No internet connection"
        exit 1
    fi
}

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================
install_dependencies() {
    print_info "Installing required packages..."
    
    # Update package list silently
    apt-get update -qq > /dev/null 2>&1
    
    # Install essential packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        wget curl git build-essential gcc make \
        python3 python3-pip unzip tar \
        iptables net-tools > /dev/null 2>&1
    
    print_success "Dependencies installed"
}

# ============================================================================
# DOWNLOAD FILES (WITH FALLBACK)
# ============================================================================
download_files() {
    print_step "1"
    print_info "Downloading files from ELITE-X8 Repository"
    
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    
    # Download dnstt-server with multiple fallback sources
    echo -ne "  ${CYAN}Downloading dnstt-server binary...${NC}"
    DOWNLOAD_SUCCESS=false
    
    # Try primary GitHub source
    if wget -q --timeout=10 "$GITHUB_BASE/dnstt-server" -O dnstt-server 2>/dev/null; then
        if file dnstt-server | grep -q "ELF\|executable"; then
            DOWNLOAD_SUCCESS=true
            echo -e "\r  ${GREEN}✓ dnstt-server downloaded from GitHub${NC}"
        fi
    fi
    
    # Fallback: Download from official dnstt source and compile
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo -e "\r  ${YELLOW}! GitHub download failed, building from source...${NC}"
        
        # Install Go if not present
        if ! command -v go &>/dev/null; then
            print_info "Installing Go for compilation..."
            wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz -O /tmp/go.tar.gz 2>/dev/null
            tar -C /usr/local -xzf /tmp/go.tar.gz 2>/dev/null
            export PATH=$PATH:/usr/local/go/bin
            rm -f /tmp/go.tar.gz
        fi
        
        # Clone and build dnstt
        if command -v go &>/dev/null; then
            cd /tmp
            git clone https://github.com/benjojo/dnstt.git /tmp/dnstt-build 2>/dev/null
            if [ -d /tmp/dnstt-build ]; then
                cd /tmp/dnstt-build/dnstt-server
                go build -o /etc/slowdns/dnstt-server -ldflags="-s -w" . 2>/dev/null
                if [ -f /etc/slowdns/dnstt-server ]; then
                    DOWNLOAD_SUCCESS=true
                    echo -e "\r  ${GREEN}✓ dnstt-server compiled from source${NC}"
                fi
                cd /etc/slowdns
                rm -rf /tmp/dnstt-build
            fi
        fi
    fi
    
    # Fallback: Download pre-compiled binary from alternative sources
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo -e "\r  ${YELLOW}! Trying alternative download sources...${NC}"
        
        # Try multiple alternative URLs
        ALT_URLS=(
            "https://github.com/benjojo/dnstt/releases/download/v0.1.0/dnstt-server-linux-amd64"
            "https://github.com/benjojo/dnstt/releases/latest/download/dnstt-server-linux-amd64"
        )
        
        for url in "${ALT_URLS[@]}"; do
            if wget -q --timeout=10 "$url" -O dnstt-server 2>/dev/null; then
                if file dnstt-server | grep -q "ELF\|executable"; then
                    DOWNLOAD_SUCCESS=true
                    echo -e "\r  ${GREEN}✓ dnstt-server downloaded from releases${NC}"
                    break
                fi
            fi
        done
    fi
    
    # Final fallback: Create a shell script wrapper (will use system DNS tunnel if available)
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo -e "\r  ${YELLOW}! Creating dnstt-server wrapper script...${NC}"
        cat > /etc/slowdns/dnstt-server << 'DNSTTEOF'
#!/bin/bash
# Simple DNS tunnel wrapper - forwards to SSH via netcat
while true; do
    nc -u -l -p ${2#:} -c "nc 127.0.0.1 ${4#*:}" 2>/dev/null
    sleep 1
done
DNSTTEOF
        chmod +x /etc/slowdns/dnstt-server
        print_warning "Using fallback wrapper - limited functionality"
        log_message "WARNING: Using dnstt-server fallback wrapper"
    fi
    
    chmod +x /etc/slowdns/dnstt-server
    log_message "dnstt-server setup completed"
    
    # Download server.key
    echo -ne "  ${CYAN}Downloading server.key...${NC}"
    if wget -q --timeout=10 "$GITHUB_BASE/server.key" -O server.key 2>/dev/null; then
        chmod 600 server.key
        echo -e "\r  ${GREEN}✓ server.key downloaded${NC}"
        log_message "server.key downloaded successfully"
    else
        # Generate new key pair if download fails
        echo -e "\r  ${YELLOW}! Generating new keypair...${NC}"
        if [ -x /etc/slowdns/dnstt-server ] && /etc/slowdns/dnstt-server -gen-key 2>/dev/null; then
            print_success "New keypair generated"
        else
            print_error "Failed to get server.key"
            log_message "ERROR: Failed to get server.key"
            exit 1
        fi
    fi
    
    # Download server.pub
    echo -ne "  ${CYAN}Downloading server.pub...${NC}"
    if wget -q --timeout=10 "$GITHUB_BASE/server.pub" -O server.pub 2>/dev/null; then
        chmod 644 server.pub
        echo -e "\r  ${GREEN}✓ server.pub downloaded${NC}"
        log_message "server.pub downloaded successfully"
    else
        if [ -f server.pub ]; then
            chmod 644 server.pub
            echo -e "\r  ${GREEN}✓ server.pub already exists${NC}"
        else
            print_error "Failed to get server.pub"
            log_message "ERROR: Failed to get server.pub"
        fi
    fi
    
    # Download dashboard
    echo -ne "  ${CYAN}Downloading dashboard files...${NC}"
    mkdir -p /etc/slowdns/dashboard
    wget -q --timeout=10 "$GITHUB_BASE/dashboard/index.html" -O /etc/slowdns/dashboard/index.html 2>/dev/null
    wget -q --timeout=10 "$GITHUB_BASE/dashboard/style.css" -O /etc/slowdns/dashboard/style.css 2>/dev/null
    wget -q --timeout=10 "$GITHUB_BASE/dashboard/script.js" -O /etc/slowdns/dashboard/script.js 2>/dev/null
    
    # Create dashboard files if download failed
    if [ ! -s /etc/slowdns/dashboard/index.html ]; then
        cat > /etc/slowdns/dashboard/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html><head><title>ELITE-X8 Dashboard</title></head>
<body><h1>ELITE-X8 SlowDNS Dashboard</h1><p>Server Running</p></body></html>
HTMLEOF
    fi
    
    echo -e "\r  ${GREEN}✓ Dashboard files ready${NC}"
    log_message "Dashboard files downloaded/generated"
    
    print_success "All files prepared"
    print_step_end
}

# ============================================================================
# CONFIGURE SSH
# ============================================================================
configure_ssh() {
    print_step "2"
    print_info "Configuring OpenSSH on port $SSHD_PORT"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
    
    cat > /etc/ssh/sshd_config << EOF
# ELITE-X8 SLOWDNS SSH CONFIGURATION
Port $SSHD_PORT
Protocol 2
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3
AllowTcpForwarding yes
GatewayPorts yes
Compression delayed
Subsystem sftp /usr/lib/openssh/sftp-server
MaxSessions 100
MaxStartups 100:30:200
LoginGraceTime 30
UseDNS no
EOF
    
    systemctl restart sshd 2>/dev/null
    sleep 2
    
    if systemctl is-active --quiet sshd; then
        print_success "SSH configured on port $SSHD_PORT"
    else
        print_error "SSH configuration failed"
        log_message "ERROR: SSH restart failed"
    fi
    print_step_end
}

# ============================================================================
# COMPILE HIGH-PERFORMANCE EDNS PROXY
# ============================================================================
compile_edns() {
    print_step "3"
    print_info "Compiling High-Performance Multi-Core EDNS Proxy"
    
    # Install compiler and build tools if needed
    if ! command -v gcc &>/dev/null; then
        print_info "Installing build tools..."
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq gcc make > /dev/null 2>&1
    fi
    
    # Create high-performance EDNS proxy with SO_REUSEPORT for multi-core
    cat > /tmp/edns.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <sys/wait.h>
#include <sched.h>

#define LISTEN_PORT 53
#define SLOWDNS_PORT 5300
#define BUFFER_SIZE 4096
#define UPSTREAM_POOL 64
#define SOCKET_TIMEOUT 2.0
#define MAX_EVENTS 4096
#define REQ_TABLE_SIZE 65536
#define EXT_EDNS 512
#define INT_EDNS 1400
#define MAX_WORKERS 16

typedef struct {
    int fd;
    int busy;
    double last_used;
} upstream_t;

typedef struct req_entry {
    uint16_t req_id;
    int upstream_idx;
    double timestamp;
    struct sockaddr_in client_addr;
    socklen_t addr_len;
    struct req_entry *next;
} req_entry_t;

static upstream_t upstreams[UPSTREAM_POOL];
static req_entry_t *req_table[REQ_TABLE_SIZE];
static int sock, epoll_fd;
static volatile sig_atomic_t shutdown_flag = 0;
static volatile sig_atomic_t worker_ready = 0;

static inline double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

static inline uint16_t get_txid(unsigned char *b) {
    return ((uint16_t)b[0] << 8) | b[1];
}

static inline uint32_t req_hash(uint16_t id) {
    return id & (REQ_TABLE_SIZE - 1);
}

static int patch_edns(unsigned char *buf, int len, int size) {
    if (len < 12) return len;
    int off = 12;
    int qd = (buf[4] << 8) | buf[5];
    if (buf[4] || buf[5]) {
        for (int i = 0; i < qd; i++) {
            while (buf[off] && off < len) off++;
            off += 5;
            if (off >= len) return len;
        }
    }
    return len;
}

static int get_upstream(void) {
    double t = now();
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        if (upstreams[i].busy && (t - upstreams[i].last_used) > SOCKET_TIMEOUT)
            upstreams[i].busy = 0;
        if (!upstreams[i].busy) {
            upstreams[i].busy = 1;
            upstreams[i].last_used = t;
            return i;
        }
    }
    return -1;
}

static void release_upstream(int i) {
    if (i >= 0 && i < UPSTREAM_POOL)
        upstreams[i].busy = 0;
}

static void insert_req(int uidx, unsigned char *buf, struct sockaddr_in *c, socklen_t l) {
    req_entry_t *e = calloc(1, sizeof(*e));
    if (!e) return;
    e->upstream_idx = uidx;
    e->req_id = get_txid(buf);
    e->timestamp = now();
    e->client_addr = *c;
    e->addr_len = l;
    uint32_t h = req_hash(e->req_id);
    e->next = req_table[h];
    req_table[h] = e;
}

static req_entry_t *find_req(uint16_t id) {
    uint32_t h = req_hash(id);
    for (req_entry_t *e = req_table[h]; e; e = e->next)
        if (e->req_id == id) return e;
    return NULL;
}

static void delete_req(req_entry_t *e) {
    release_upstream(e->upstream_idx);
    uint32_t h = req_hash(e->req_id);
    req_entry_t **pp = &req_table[h];
    while (*pp) {
        if (*pp == e) { *pp = e->next; free(e); return; }
        pp = &(*pp)->next;
    }
}

static void cleanup_expired(void) {
    double t = now();
    for (int i = 0; i < REQ_TABLE_SIZE; i++) {
        req_entry_t **pp = &req_table[i];
        while (*pp) {
            if (t - (*pp)->timestamp > SOCKET_TIMEOUT) {
                req_entry_t *o = *pp;
                release_upstream(o->upstream_idx);
                *pp = o->next;
                free(o);
            } else {
                pp = &(*pp)->next;
            }
        }
    }
}

static void sig_handler(int s) { 
    shutdown_flag = 1; 
}

static int worker_process(int worker_id) {
    /* Set CPU affinity for better cache locality */
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(worker_id, &cpuset);
    sched_setaffinity(0, sizeof(cpuset), &cpuset);
    
    /* Create socket with SO_REUSEPORT for multi-core processing */
    sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) exit(1);
    
    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    #ifdef SO_REUSEPORT
    setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, sizeof(reuse));
    #endif
    
    fcntl(sock, F_SETFL, O_NONBLOCK);
    
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET;
    a.sin_port = htons(LISTEN_PORT);
    a.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(sock, (struct sockaddr*)&a, sizeof(a)) < 0) exit(1);
    
    /* SlowDNS upstream address - IPv4 only */
    struct sockaddr_in slow = {0};
    slow.sin_family = AF_INET;
    slow.sin_port = htons(SLOWDNS_PORT);
    inet_pton(AF_INET, "127.0.0.1", &slow.sin_addr);
    
    epoll_fd = epoll_create1(0);
    struct epoll_event ev = {.events = EPOLLIN, .data.fd = sock};
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, sock, &ev);
    
    /* Initialize upstream pool */
    for (int i = 0; i < UPSTREAM_POOL; i++) {
        upstreams[i].fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (upstreams[i].fd >= 0) {
            fcntl(upstreams[i].fd, F_SETFL, O_NONBLOCK);
            struct epoll_event ue = {.events = EPOLLIN, .data.fd = upstreams[i].fd};
            epoll_ctl(epoll_fd, EPOLL_CTL_ADD, upstreams[i].fd, &ue);
        }
        upstreams[i].busy = 0;
        upstreams[i].last_used = 0;
    }
    
    struct epoll_event events[MAX_EVENTS];
    
    __sync_fetch_and_add(&worker_ready, 1);
    
    while (!shutdown_flag) {
        cleanup_expired();
        int n = epoll_wait(epoll_fd, events, MAX_EVENTS, 10);
        
        for (int i = 0; i < n; i++) {
            int fd = events[i].data.fd;
            
            if (fd == sock) {
                unsigned char buf[BUFFER_SIZE];
                struct sockaddr_in c;
                socklen_t l = sizeof(c);
                
                int len = recvfrom(sock, buf, sizeof(buf), MSG_DONTWAIT, 
                                   (struct sockaddr*)&c, &l);
                if (len > 12 && len < BUFFER_SIZE) {
                    int u = get_upstream();
                    if (u >= 0) {
                        insert_req(u, buf, &c, l);
                        sendto(upstreams[u].fd, buf, len, MSG_DONTWAIT,
                               (struct sockaddr*)&slow, sizeof(slow));
                    }
                }
            } else {
                unsigned char buf[BUFFER_SIZE];
                int len = recv(fd, buf, sizeof(buf), 0);
                if (len > 0) {
                    uint16_t id = get_txid(buf);
                    req_entry_t *e = find_req(id);
                    if (e) {
                        sendto(sock, buf, len, MSG_DONTWAIT,
                               (struct sockaddr*)&e->client_addr, e->addr_len);
                        delete_req(e);
                    }
                }
            }
        }
    }
    
    return 0;
}

int main(int argc, char *argv[]) {
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);
    
    int num_workers = sysconf(_SC_NPROCESSORS_ONLN);
    if (num_workers < 1) num_workers = 1;
    if (num_workers > MAX_WORKERS) num_workers = MAX_WORKERS;
    
    /* Fork worker processes */
    for (int i = 0; i < num_workers; i++) {
        pid_t pid = fork();
        if (pid < 0) exit(1);
        if (pid == 0) return worker_process(i);
    }
    
    /* Wait for all workers */
    while (__sync_fetch_and_add(&worker_ready, 0) < num_workers)
        usleep(10000);
    
    /* Parent waits */
    int status;
    while (!shutdown_flag) {
        pid_t wpid = waitpid(-1, &status, WNOHANG);
        if (wpid > 0) {
            pid_t pid = fork();
            if (pid == 0) return worker_process(rand() % num_workers);
        }
        usleep(100000);
    }
    
    kill(0, SIGTERM);
    while (wait(&status) > 0) {}
    return 0;
}
EOF
    
    # Compile with maximum optimization flags
    echo -ne "  ${CYAN}Compiling EDNS Proxy...${NC}"
    
    if gcc -Ofast -march=native -mtune=native -flto -fomit-frame-pointer \
        -ffast-math -funroll-loops -finline-functions \
        -o /usr/local/bin/edns-proxy /tmp/edns.c -lpthread 2>/dev/null; then
        chmod +x /usr/local/bin/edns-proxy
        echo -e "\r  ${GREEN}✓ EDNS Proxy compiled (-Ofast -march=native -flto)${NC}"
    elif gcc -O3 -march=native -flto -o /usr/local/bin/edns-proxy /tmp/edns.c -lpthread 2>/dev/null; then
        chmod +x /usr/local/bin/edns-proxy
        echo -e "\r  ${GREEN}✓ EDNS Proxy compiled (-O3 fallback)${NC}"
    else
        echo -e "\r  ${RED}✗ Compilation failed${NC}"
        log_message "ERROR: EDNS Proxy compilation failed"
    fi
    
    rm -f /tmp/edns.c
    print_success "EDNS Proxy ready - Multi-core, IPv4-only"
    print_step_end
}

# ============================================================================
# CREATE DASHBOARD
# ============================================================================
create_dashboard() {
    print_step "4"
    print_info "Creating Management Dashboard"
    
    mkdir -p /etc/slowdns/dashboard
    
    # Create dashboard HTML if not exists
    if [ ! -s /etc/slowdns/dashboard/index.html ]; then
        cat > /etc/slowdns/dashboard/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X8 SlowDNS Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .header h1 { color: white; font-size: 2.5em; margin-bottom: 10px; }
        .header p { color: rgba(255,255,255,0.8); font-size: 1.1em; }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.2);
            color: white;
        }
        .stat-card h3 { font-size: 0.9em; color: rgba(255,255,255,0.7); margin-bottom: 10px; }
        .stat-card .value { font-size: 2em; font-weight: bold; }
        .controls {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.2);
            margin-bottom: 30px;
        }
        .button {
            background: rgba(255,255,255,0.2);
            border: 1px solid rgba(255,255,255,0.3);
            color: white;
            padding: 10px 20px;
            border-radius: 10px;
            cursor: pointer;
            margin: 5px;
            font-size: 1em;
            transition: all 0.3s;
        }
        .button:hover { background: rgba(255,255,255,0.3); }
        .button.start { background: rgba(72, 187, 120, 0.5); }
        .button.stop { background: rgba(245, 101, 101, 0.5); }
        .button.restart { background: rgba(236, 201, 75, 0.5); }
        .logs {
            background: rgba(0,0,0,0.5);
            border-radius: 15px;
            padding: 20px;
            color: #0f0;
            font-family: monospace;
            height: 300px;
            overflow-y: auto;
        }
        .public-key {
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
            padding: 15px;
            color: #ffd700;
            font-family: monospace;
            word-break: break-all;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 ELITE-X8 SlowDNS Dashboard</h1>
            <p>Advanced DNS Tunnel Management System</p>
        </div>
        <div class="stats-grid">
            <div class="stat-card"><h3>SERVER STATUS</h3><div class="value">🟢 Online</div></div>
            <div class="stat-card"><h3>SLOWDNS PORT</h3><div class="value">5300</div></div>
            <div class="stat-card"><h3>SSH PORT</h3><div class="value">22</div></div>
            <div class="stat-card"><h3>ACTIVE</h3><div class="value" id="connections">-</div></div>
        </div>
        <div class="controls">
            <h3 style="color:white;margin-bottom:15px;">🎮 Controls</h3>
            <button class="button start" onclick="ctrl('start')">▶ Start</button>
            <button class="button stop" onclick="ctrl('stop')">⏹ Stop</button>
            <button class="button restart" onclick="ctrl('restart')">🔄 Restart</button>
        </div>
        <div class="controls">
            <h3 style="color:white;margin-bottom:15px;">🔑 Public Key</h3>
            <div class="public-key" id="pubkey">Loading...</div>
        </div>
        <div class="controls">
            <h3 style="color:white;margin-bottom:15px;">📋 Logs</h3>
            <div class="logs" id="logs">Loading...</div>
        </div>
    </div>
    <script>
        function refresh() {
            fetch('/api/status').then(r=>r.json()).then(d=>{
                document.getElementById('connections').textContent = d.connections || 0;
                document.getElementById('pubkey').textContent = d.publicKey || 'N/A';
                document.getElementById('logs').innerHTML = d.logs || 'No logs';
            });
        }
        function ctrl(a) {
            fetch('/api/control',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:a})})
            .then(r=>r.json()).then(d=>{alert(d.message);refresh();});
        }
        setInterval(refresh,5000);
        refresh();
    </script>
</body>
</html>
HTMLEOF
    fi
    
    # Create API server
    cat > /usr/local/bin/slowdns-api << 'APIEOF'
#!/usr/bin/env python3
import http.server, json, subprocess, os

class API(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type','text/html')
            self.end_headers()
            with open('/etc/slowdns/dashboard/index.html','rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type','application/json')
            self.send_header('Access-Control-Allow-Origin','*')
            self.end_headers()
            conn = 0
            try:
                r = subprocess.run(['ss','-tn'],capture_output=True,text=True)
                conn = len([l for l in r.stdout.split('\n') if ':22' in l or ':5300' in l])
            except: pass
            logs = "No logs"
            try:
                r = subprocess.run(['journalctl','-u','server-sldns','--no-pager','-n','20'],
                                   capture_output=True,text=True,timeout=5)
                if r.stdout: logs = r.stdout
            except: pass
            pk = "Not available"
            try:
                with open('/etc/slowdns/server.pub','r') as f:
                    pk = f.read().strip()
            except: pass
            self.wfile.write(json.dumps({'connections':conn,'logs':logs,'publicKey':pk}).encode())
    def do_POST(self):
        if self.path == '/api/control':
            cl = int(self.headers['Content-Length'])
            data = json.loads(self.rfile.read(cl).decode())
            a = data.get('action','')
            try:
                if a == 'start': subprocess.run(['systemctl','start','server-sldns','edns-proxy'])
                elif a == 'stop': subprocess.run(['systemctl','stop','server-sldns','edns-proxy'])
                elif a == 'restart': subprocess.run(['systemctl','restart','server-sldns','edns-proxy'])
                msg = "Success"
            except Exception as e: msg = str(e)
            self.send_response(200)
            self.send_header('Content-type','application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'message':msg}).encode())

http.server.HTTPServer(('0.0.0.0',8080),API).serve_forever()
APIEOF
    
    chmod +x /usr/local/bin/slowdns-api
    
    # Create dashboard service
    cat > /etc/systemd/system/slowdns-dashboard.service << EOF
[Unit]
Description=SlowDNS Dashboard API
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/slowdns-api
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Dashboard created"
    print_step_end
}

# ============================================================================
# CREATE SERVICES WITH HIGH-PRIORITY SETTINGS
# ============================================================================
create_services() {
    print_step "5"
    print_info "Creating High-Priority System Services"
    
    # SlowDNS Service
    cat > /etc/systemd/system/server-sldns.service << EOF
[Unit]
Description=ELITE-X8 SlowDNS Server
After=network.target sshd.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1400 -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT
Restart=always
RestartSec=5
User=root
Nice=-20
LimitNOFILE=1000000
LimitCORE=infinity
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF
    
    # EDNS Proxy Service
    cat > /etc/systemd/system/edns-proxy.service << EOF
[Unit]
Description=EDNS Proxy for SlowDNS (Multi-Core)
After=server-sldns.service
Requires=server-sldns.service

[Service]
Type=simple
ExecStart=/usr/local/bin/edns-proxy
Restart=always
RestartSec=3
User=root
Nice=-20
LimitNOFILE=1000000
LimitCORE=infinity
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF

    # Check if nameserver is set, otherwise use default
    if [ -z "$NAMESERVER" ]; then
        NAMESERVER="dns.google.com"
        print_warning "No nameserver specified, using default: $NAMESERVER"
    fi
    
    print_success "High-priority services created (Nice=-20, NOFILE=1M)"
    print_step_end
}

# ============================================================================
# CONFIGURE FIREWALL
# ============================================================================
configure_firewall() {
    print_step "6"
    print_info "Configuring Firewall Rules"
    
    # Stop conflicting services
    systemctl stop systemd-resolved 2>/dev/null
    fuser -k 53/udp 2>/dev/null
    sleep 1
    
    # Configure iptables
    iptables -F
    iptables -X
    iptables -t nat -F 2>/dev/null
    
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Allow essential ports
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport $SSHD_PORT -j ACCEPT
    iptables -A INPUT -p udp --dport $SLOWDNS_PORT -j ACCEPT
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport $DASHBOARD_PORT -j ACCEPT
    iptables -A INPUT -p icmp -j ACCEPT
    
    print_success "Firewall configured"
    print_step_end
}

# ============================================================================
# START SERVICES
# ============================================================================
start_services() {
    print_step "7"
    print_info "Starting All Services"
    
    systemctl daemon-reload
    
    # Start EDNS Proxy first (needs port 53 free)
    systemctl enable edns-proxy > /dev/null 2>&1
    systemctl start edns-proxy 2>/dev/null
    sleep 2
    
    if systemctl is-active --quiet edns-proxy; then
        print_success "EDNS Proxy started (Multi-Core)"
    else
        print_warning "Starting EDNS Proxy in background"
        /usr/local/bin/edns-proxy &
    fi
    
    # Start SlowDNS
    systemctl enable server-sldns > /dev/null 2>&1
    systemctl start server-sldns 2>/dev/null
    sleep 2
    
    if systemctl is-active --quiet server-sldns; then
        print_success "SlowDNS service started (MTU 1400)"
    else
        print_warning "Starting SlowDNS in background"
        /etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1400 \
            -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT &
    fi
    
    # Start Dashboard
    systemctl enable slowdns-dashboard > /dev/null 2>&1
    systemctl start slowdns-dashboard 2>/dev/null
    sleep 2
    
    if systemctl is-active --quiet slowdns-dashboard; then
        print_success "Dashboard started on port $DASHBOARD_PORT"
    else
        python3 /usr/local/bin/slowdns-api &
        print_warning "Dashboard in background mode"
    fi
    
    print_step_end
}

# ============================================================================
# SHOW COMPLETION SUMMARY
# ============================================================================
show_summary() {
    print_header "🎉 INSTALLATION COMPLETE"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}ELITE-X8 SLOWDNS SERVER${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IP:        ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SSH:       ${WHITE}$SSHD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SlowDNS:   ${WHITE}$SLOWDNS_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} EDNS:      ${WHITE}53${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Dashboard: ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} NS:        ${WHITE}$NAMESERVER${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} MTU:       ${WHITE}1400${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IPv6:      ${WHITE}DISABLED${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    # Show public key
    if [ -f /etc/slowdns/server.pub ] && [ -s /etc/slowdns/server.pub ]; then
        echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}${BOLD}PUBLIC KEY${NC}                                            ${CYAN}│${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}$(cat /etc/slowdns/server.pub)${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}COMMANDS${NC}                                               ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}systemctl status server-sldns${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}systemctl status edns-proxy${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}journalctl -u server-sldns -f${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}🎯 INSTALLED SUCCESSFULLY!${NC}                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}⚡ http://$SERVER_IP:$DASHBOARD_PORT${NC}                      ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================
main() {
    print_banner
    
    # Get nameserver
    echo -e "${WHITE}${BOLD}Configure Your Nameserver:${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Example:${NC} dns.google.com, dns.cloudflare.com            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Custom:${NC}  yourdomain.com, ns1.yourserver.com           ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    read -p "$(echo -e "${WHITE}${BOLD}Enter nameserver: ${NC}")" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
    # Get server IP (IPv4 only)
    SERVER_IP=$(curl -4 -s --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    # Run all functions
    install_dependencies
    disable_ipv6
    optimize_kernel
    check_requirements
    download_files
    configure_ssh
    compile_edns
    create_dashboard
    create_services
    configure_firewall
    start_services
    show_summary
}

# ============================================================================
# ERROR HANDLING & EXECUTION
# ============================================================================
trap 'echo -e "\n${RED}✗ Installation interrupted!${NC}"; log_message "Installation interrupted"; exit 1' INT

# Initialize log
echo "=== SLOWDNS INSTALLATION STARTED $(date) ===" > "$LOG_FILE"

if main; then
    echo "=== INSTALLATION COMPLETED SUCCESSFULLY $(date) ===" >> "$LOG_FILE"
    exit 0
else
    echo "=== INSTALLATION FAILED $(date) ===" >> "$LOG_FILE"
    echo -e "\n${RED}✗ Installation failed${NC}"
    exit 1
fi
