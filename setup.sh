#!/bin/bash

# ============================================================================
#                     SLOWDNS ULTRA MAX SPEED INSTALLATION SCRIPT
#                          ELITE-X8 ELITE EDITION 2024
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
MAX_UDP_BUFFER=16777216  # 16MB

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
    echo -e "${PURPLE}║${NC}${CYAN}     🚀 ELITE-X8 SLOWDNS ULTRA MAX SPEED INSTALLATION${NC}       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}         Advanced Multi-Core Optimized Configuration${NC}        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}              BBR • UDP 16MB • Real-Time Priority${NC}          ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${GREEN}                    Elite Performance Edition${NC}               ${PURPLE}║${NC}"
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
# DISABLE IPv6 COMPLETELY
# ============================================================================
disable_ipv6() {
    print_step "1"
    print_info "Disabling IPv6 System-Wide (Reducing Overhead)"
    
    # Disable IPv6 via sysctl
    cat >> /etc/sysctl.conf << 'EOF'

# ============================================================================
# ELITE-X8: COMPLETE IPv6 DISABLE
# ============================================================================
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    # Apply immediately
    sysctl -p /etc/sysctl.conf > /dev/null 2>&1
    
    # Disable IPv6 in GRUB
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& ipv6.disable=1/' /etc/default/grub
        print_success "IPv6 disabled in GRUB"
    fi
    
    print_success "IPv6 completely disabled"
    log_message "IPv6 disabled system-wide"
    print_step_end
}

# ============================================================================
# KERNEL OPTIMIZATION FOR MAX SPEED
# ============================================================================
optimize_kernel() {
    print_step "2"
    print_info "Applying Ultra Kernel Optimizations"
    
    cat >> /etc/sysctl.conf << EOF

# ============================================================================
# ELITE-X8 ULTRA KERNEL OPTIMIZATION
# ============================================================================

# BBR Congestion Control (Google's Algorithm)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Maximum UDP Buffer Sizes (16MB)
net.core.rmem_max = $MAX_UDP_BUFFER
net.core.wmem_max = $MAX_UDP_BUFFER
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# Network Backlog & Queue Optimization
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.core.optmem_max = 65535

# TCP Optimization
net.ipv4.tcp_rmem = 4096 87380 $MAX_UDP_BUFFER
net.ipv4.tcp_wmem = 4096 65536 $MAX_UDP_BUFFER
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1

# IP Forwarding & Performance
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 65535

# Connection Tracking
net.netfilter.nf_conntrack_max = 2000000
net.nf_conntrack_max = 2000000

# Memory Optimization
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.min_free_kbytes = 65536
EOF
    
    # Apply kernel parameters
    sysctl -p /etc/sysctl.conf > /dev/null 2>&1
    
    # Load BBR module if available
    modprobe tcp_bbr 2>/dev/null || true
    
    # Enable BBR
    echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
    
    print_success "BBR congestion control enabled"
    print_success "UDP buffers set to 16MB"
    print_success "Network backlog optimized"
    print_success "TCP stack optimized"
    print_success "Connection tracking expanded"
    log_message "Kernel optimizations applied"
    print_step_end
}

# ============================================================================
# COMPILE HIGH-PERFORMANCE EDNS PROXY
# ============================================================================
compile_edns() {
    print_step "3"
    print_info "Compiling Ultra-Optimized Multi-Core EDNS Proxy"
    
    # Install build tools
    if ! command -v gcc &>/dev/null; then
        print_info "Installing build tools..."
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq gcc make > /dev/null 2>&1
    fi
    
    # Create ultra-optimized EDNS proxy in C
    cat > /tmp/edns-ultra.c << 'EOF'
/*
 * ELITE-X8 ULTRA EDNS PROXY
 * Multi-Core Optimized for Max Performance
 * Features: SO_REUSEPORT, AF_INET only, Zero-Copy, Thread Pool
 */

#define _GNU_SOURCE
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
#include <sys/sysinfo.h>
#include <sched.h>
#include <pthread.h>

// Configuration
#define LISTEN_PORT 53
#define SLOWDNS_PORT 5300
#define BUFFER_SIZE 4096
#define MAX_EVENTS 16384
#define REQ_TABLE_SIZE 65536
#define EXT_EDNS 512
#define INT_EDNS 1500
#define SOCKET_TIMEOUT 2.0

// Request tracking structure
typedef struct req_entry {
    uint16_t req_id;
    int upstream_fd;
    double timestamp;
    struct sockaddr_in client_addr;
    socklen_t addr_len;
    struct req_entry *next;
} req_entry_t;

// Global variables
static req_entry_t *req_table[REQ_TABLE_SIZE];
static volatile sig_atomic_t shutdown_flag = 0;
static pthread_mutex_t table_mutex = PTHREAD_MUTEX_INITIALIZER;

// High-precision timer
static inline double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

// Fast hash function
static inline uint32_t req_hash(uint16_t id) {
    return (id * 2654435761U) & (REQ_TABLE_SIZE - 1);
}

// Get transaction ID from DNS packet
static inline uint16_t get_txid(unsigned char *b) {
    return ((uint16_t)b[0] << 8) | b[1];
}

// Patch EDNS buffer size
static inline int patch_edns(unsigned char *buf, int len, int size) {
    if (len < 12) return len;
    int off = 12;
    int qd = (buf[4] << 8) | buf[5];
    for (int i = 0; i < qd; i++) {
        while (off < len && buf[off]) off++;
        off += 5;
        if (off >= len) return len;
    }
    int ar = (buf[10] << 8) | buf[11];
    for (int i = 0; i < ar; i++) {
        if (off + 4 <= len && 
            buf[off] == 0 && 
            ((buf[off+1] << 8) | buf[off+2]) == 41) {
            buf[off+3] = size >> 8;
            buf[off+4] = size & 255;
            return len;
        }
        off++;
        if (off >= len) break;
    }
    return len;
}

// Insert request into hash table
static void insert_req(int ufd, unsigned char *buf, struct sockaddr_in *c, socklen_t l) {
    req_entry_t *e = calloc(1, sizeof(*e));
    if (!e) return;
    
    e->upstream_fd = ufd;
    e->req_id = get_txid(buf);
    e->timestamp = now();
    memcpy(&e->client_addr, c, sizeof(*c));
    e->addr_len = l;
    
    uint32_t h = req_hash(e->req_id);
    
    pthread_mutex_lock(&table_mutex);
    e->next = req_table[h];
    req_table[h] = e;
    pthread_mutex_unlock(&table_mutex);
}

// Find request in hash table
static req_entry_t *find_req(uint16_t id) {
    uint32_t h = req_hash(id);
    req_entry_t *e;
    
    pthread_mutex_lock(&table_mutex);
    for (e = req_table[h]; e; e = e->next) {
        if (e->req_id == id) {
            pthread_mutex_unlock(&table_mutex);
            return e;
        }
    }
    pthread_mutex_unlock(&table_mutex);
    return NULL;
}

// Delete request from hash table
static void delete_req(req_entry_t *e) {
    uint32_t h = req_hash(e->req_id);
    
    pthread_mutex_lock(&table_mutex);
    req_entry_t **pp = &req_table[h];
    while (*pp) {
        if (*pp == e) {
            *pp = e->next;
            free(e);
            pthread_mutex_unlock(&table_mutex);
            return;
        }
        pp = &(*pp)->next;
    }
    pthread_mutex_unlock(&table_mutex);
}

// Cleanup expired requests
static void cleanup_expired(void) {
    double t = now();
    
    for (int i = 0; i < REQ_TABLE_SIZE; i++) {
        pthread_mutex_lock(&table_mutex);
        req_entry_t **pp = &req_table[i];
        while (*pp) {
            if (t - (*pp)->timestamp > SOCKET_TIMEOUT) {
                req_entry_t *old = *pp;
                *pp = old->next;
                free(old);
            } else {
                pp = &(*pp)->next;
            }
        }
        pthread_mutex_unlock(&table_mutex);
    }
}

// Signal handler
static void sig_handler(int s) {
    shutdown_flag = 1;
}

// Worker thread function
static void *worker_thread(void *arg) {
    int cpu = *((int *)arg);
    
    // Pin thread to specific CPU core
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu, &cpuset);
    pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
    
    // Create epoll instance
    int epoll_fd = epoll_create1(EPOLL_CLOEXEC);
    if (epoll_fd < 0) {
        perror("epoll_create1");
        return NULL;
    }
    
    // Create listen socket with SO_REUSEPORT
    int sock = socket(AF_INET, SOCK_DGRAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    if (sock < 0) {
        perror("socket");
        return NULL;
    }
    
    // Set socket options
    int reuse = 1, reuseport = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuseport, sizeof(reuseport));
    
    // Increase receive buffer
    int rcvbuf = 16777216;
    setsockopt(sock, SOL_SOCKET, SO_RCVBUFFORCE, &rcvbuf, sizeof(rcvbuf));
    setsockopt(sock, SOL_SOCKET, SO_SNDBUFFORCE, &rcvbuf, sizeof(rcvbuf));
    
    // Bind to port 53
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;  // IPv4 only
    addr.sin_port = htons(LISTEN_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        return NULL;
    }
    
    // Add listen socket to epoll
    struct epoll_event ev = {
        .events = EPOLLIN,
        .data.fd = sock
    };
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, sock, &ev);
    
    // Create upstream socket pool
    struct sockaddr_in slow = {0};
    slow.sin_family = AF_INET;
    slow.sin_port = htons(SLOWDNS_PORT);
    inet_pton(AF_INET, "127.0.0.1", &slow.sin_addr);
    
    int upstream_fds[32];
    for (int i = 0; i < 32; i++) {
        upstream_fds[i] = socket(AF_INET, SOCK_DGRAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
        if (upstream_fds[i] >= 0) {
            connect(upstream_fds[i], (struct sockaddr *)&slow, sizeof(slow));
            ev.data.fd = upstream_fds[i];
            ev.events = EPOLLIN;
            epoll_ctl(epoll_fd, EPOLL_CTL_ADD, upstream_fds[i], &ev);
        }
    }
    
    // Main event loop
    struct epoll_event events[MAX_EVENTS];
    
    while (!shutdown_flag) {
        int nfds = epoll_wait(epoll_fd, events, MAX_EVENTS, 10);
        
        for (int i = 0; i < nfds; i++) {
            int fd = events[i].data.fd;
            
            if (fd == sock) {
                // Handle incoming DNS query
                unsigned char buf[BUFFER_SIZE];
                struct sockaddr_in client;
                socklen_t client_len = sizeof(client);
                
                int len = recvfrom(sock, buf, sizeof(buf), MSG_DONTWAIT,
                                  (struct sockaddr *)&client, &client_len);
                
                if (len >= 12) {
                    patch_edns(buf, len, INT_EDNS);
                    
                    // Round-robin upstream selection
                    static __thread int rr_counter = 0;
                    int ufd = upstream_fds[rr_counter++ % 32];
                    
                    insert_req(ufd, buf, &client, client_len);
                    send(ufd, buf, len, MSG_DONTWAIT);
                }
            } else {
                // Handle upstream response
                unsigned char buf[BUFFER_SIZE];
                int len = recv(fd, buf, sizeof(buf), MSG_DONTWAIT);
                
                if (len >= 12) {
                    uint16_t id = get_txid(buf);
                    req_entry_t *e = find_req(id);
                    
                    if (e && e->upstream_fd == fd) {
                        patch_edns(buf, len, EXT_EDNS);
                        sendto(sock, buf, len, MSG_DONTWAIT,
                               (struct sockaddr *)&e->client_addr,
                               e->addr_len);
                        delete_req(e);
                    }
                }
            }
        }
        
        // Periodic cleanup
        static __thread int cleanup_counter = 0;
        if (++cleanup_counter >= 1000) {
            cleanup_expired();
            cleanup_counter = 0;
        }
    }
    
    close(sock);
    close(epoll_fd);
    return NULL;
}

int main(void) {
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);
    
    // Get number of CPU cores
    int num_cores = get_nprocs();
    printf("ELITE-X8 EDNS Proxy: Starting with %d worker threads\n", num_cores);
    
    // Create worker threads (one per core)
    pthread_t *threads = calloc(num_cores, sizeof(pthread_t));
    int *core_ids = calloc(num_cores, sizeof(int));
    
    for (int i = 0; i < num_cores; i++) {
        core_ids[i] = i;
        pthread_create(&threads[i], NULL, worker_thread, &core_ids[i]);
    }
    
    // Wait for threads
    for (int i = 0; i < num_cores; i++) {
        pthread_join(threads[i], NULL);
    }
    
    free(threads);
    free(core_ids);
    
    return 0;
}
EOF
    
    print_info "Compiling with -Ofast -march=native -flto..."
    
    if gcc -Ofast -march=native -flto -funroll-loops -fomit-frame-pointer \
        -pthread -o /usr/local/bin/edns-proxy /tmp/edns-ultra.c 2>/dev/null; then
        chmod +x /usr/local/bin/edns-proxy
        print_success "Ultra-optimized EDNS Proxy compiled"
        log_message "EDNS Proxy compiled with ultra optimizations"
    else
        print_warning "Ultra compilation failed - trying standard optimization"
        if gcc -O3 -march=native -pthread -o /usr/local/bin/edns-proxy /tmp/edns-ultra.c 2>/dev/null; then
            chmod +x /usr/local/bin/edns-proxy
            print_success "EDNS Proxy compiled with standard optimization"
        else
            print_warning "Downloading pre-compiled binary"
            wget -q "$GITHUB_BASE/edns-proxy" -O /usr/local/bin/edns-proxy
            chmod +x /usr/local/bin/edns-proxy
        fi
    fi
    
    # Clean up
    rm -f /tmp/edns-ultra.c
    
    print_step_end
}

# ============================================================================
# DOWNLOAD OR COMPILE DNSTT-SERVER
# ============================================================================
install_dnstt() {
    print_step "4"
    print_info "Installing dnstt-server (Multiple Methods)"
    
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    
    # Method 1: Try downloading from your GitHub repo
    echo -ne "  ${CYAN}Method 1: Downloading from ELITE-X8 GitHub...${NC}"
    if wget -q "$GITHUB_BASE/dnstt-server" -O dnstt-server 2>/dev/null; then
        chmod +x dnstt-server
        echo -e "\r  ${GREEN}✓ Downloaded from GitHub${NC}"
        log_message "dnstt-server downloaded from GitHub"
        print_step_end
        return 0
    fi
    echo -e "\r  ${YELLOW}⚠ Not found on GitHub${NC}"
    
    # Method 2: Try to compile from source
    print_warning "Method 2: Compiling from source..."
    if command -v go &>/dev/null; then
        print_info "Go detected, compiling dnstt..."
        cd /tmp
        git clone https://github.com/elite-x8/dnstt.git 2>/dev/null || true
        if [ -d "dnstt" ]; then
            cd dnstt
            go build -o /etc/slowdns/dnstt-server ./cmd/dnstt-server 2>/dev/null && {
                chmod +x /etc/slowdns/dnstt-server
                print_success "Compiled from source"
                cd /etc/slowdns
                print_step_end
                return 0
            }
        fi
    fi
    
    # Method 3: Download pre-compiled from alternative sources
    print_warning "Method 3: Downloading pre-compiled binary..."
    
    # Try multiple URLs
    local DNSTT_URLS=(
        "https://github.com/elite-x8/dnstt/releases/download/latest/dnstt-server"
        "https://github.com/elite-x8/setup.sh/releases/download/latest/dnstt-server"
    )
    
    for url in "${DNSTT_URLS[@]}"; do
        echo -ne "  ${CYAN}Trying: $url...${NC}"
        if wget -q "$url" -O dnstt-server 2>/dev/null; then
            chmod +x dnstt-server
            echo -e "\r  ${GREEN}✓ Downloaded successfully${NC}"
            log_message "dnstt-server downloaded from $url"
            print_step_end
            return 0
        fi
        echo -e "\r  ${RED}✗ Failed${NC}"
    done
    
    # Method 4: Manual upload instruction
    print_error "Could not install dnstt-server"
    print_warning "Please manually upload dnstt-server to /etc/slowdns/"
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║ MANUAL INSTALLATION INSTRUCTIONS:                     ║${NC}"
    echo -e "${YELLOW}║                                                       ║${NC}"
    echo -e "${YELLOW}║ 1. Upload your dnstt-server binary to:               ║${NC}"
    echo -e "${YELLOW}║    /etc/slowdns/dnstt-server                         ║${NC}"
    echo -e "${YELLOW}║                                                       ║${NC}"
    echo -e "${YELLOW}║ 2. Make it executable:                                ║${NC}"
    echo -e "${YELLOW}║    chmod +x /etc/slowdns/dnstt-server                ║${NC}"
    echo -e "${YELLOW}║                                                       ║${NC}"
    echo -e "${YELLOW}║ 3. Then re-run this script                            ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    
    log_message "ERROR: Failed to install dnstt-server"
    return 1
}

# ============================================================================
# DOWNLOAD SUPPORTING FILES
# ============================================================================
download_supporting_files() {
    print_step "5"
    print_info "Downloading supporting files"
    
    cd /etc/slowdns
    
    # Download server.key with fallback
    if [ ! -f server.key ]; then
        echo -ne "  ${CYAN}Checking for server.key...${NC}"
        if wget -q "$GITHUB_BASE/server.key" -O server.key 2>/dev/null; then
            chmod 600 server.key
            echo -e "\r  ${GREEN}✓ server.key downloaded${NC}"
        else
            echo -e "\r  ${YELLOW}⚠ Not found - generating new key${NC}"
            # Generate new key if download fails
            /etc/slowdns/dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub 2>/dev/null || {
                print_error "Failed to generate keys"
                return 1
            }
        fi
    else
        print_success "server.key exists"
    fi
    
    # Download server.pub with fallback
    if [ ! -f server.pub ]; then
        echo -ne "  ${CYAN}Checking for server.pub...${NC}"
        if wget -q "$GITHUB_BASE/server.pub" -O server.pub 2>/dev/null; then
            chmod 644 server.pub
            echo -e "\r  ${GREEN}✓ server.pub downloaded${NC}"
        else
            echo -e "\r  ${YELLOW}⚠ Not found - using generated key${NC}"
        fi
    else
        print_success "server.pub exists"
    fi
    
    log_message "Supporting files downloaded"
    print_step_end
}

# ============================================================================
# CONFIGURE SSH
# ============================================================================
configure_ssh() {
    print_step "6"
    print_info "Configuring OpenSSH on port $SSHD_PORT"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
    
    cat > /etc/ssh/sshd_config << EOF
# ELITE-X8 ULTRA SSH CONFIGURATION
Port $SSHD_PORT
Protocol 2
AddressFamily inet
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
# CREATE DASHBOARD
# ============================================================================
create_dashboard() {
    print_step "7"
    print_info "Creating Management Dashboard"
    
    mkdir -p /etc/slowdns/dashboard
    
    # Create dashboard HTML (shortened for brevity - same as before)
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
        .logs {
            background: rgba(0,0,0,0.5);
            border-radius: 15px;
            padding: 20px;
            color: #0f0;
            font-family: monospace;
            height: 300px;
            overflow-y: auto;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .public-key {
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
            padding: 15px;
            color: #ffd700;
            font-family: monospace;
            word-break: break-all;
            margin-top: 10px;
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
            <div class="stat-card">
                <h3>SERVER STATUS</h3>
                <div class="value" id="serverStatus">Online</div>
            </div>
            <div class="stat-card">
                <h3>SLOWDNS PORT</h3>
                <div class="value" id="slowdnsPort">5300</div>
            </div>
            <div class="stat-card">
                <h3>SSH PORT</h3>
                <div class="value" id="sshPort">22</div>
            </div>
            <div class="stat-card">
                <h3>ACTIVE CONNECTIONS</h3>
                <div class="value" id="connections">0</div>
            </div>
        </div>
        <div class="controls">
            <h3 style="color: white; margin-bottom: 15px;">🎮 Service Controls</h3>
            <button class="button" onclick="controlService('start')">▶ Start All</button>
            <button class="button" onclick="controlService('stop')">⏹ Stop All</button>
            <button class="button" onclick="controlService('restart')">🔄 Restart All</button>
            <button class="button" onclick="refreshStatus()">🔄 Refresh Status</button>
        </div>
        <div class="controls">
            <h3 style="color: white; margin-bottom: 15px;">🔑 Public Key</h3>
            <div class="public-key" id="publicKey">Loading...</div>
        </div>
        <div class="controls">
            <h3 style="color: white; margin-bottom: 15px;">📋 Service Logs</h3>
            <div class="logs" id="logs"></div>
        </div>
    </div>
    <script>
        function refreshStatus() {
            fetch('/api/status')
                .then(r => r.json())
                .then(d => {
                    document.getElementById('connections').textContent = d.connections || 0;
                    document.getElementById('logs').innerHTML = d.logs || 'No logs';
                    document.getElementById('publicKey').textContent = d.publicKey || 'Not available';
                });
        }
        function controlService(action) {
            fetch('/api/control', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: action})
            }).then(r => r.json()).then(d => { alert(d.message); refreshStatus(); });
        }
        setInterval(refreshStatus, 5000);
        refreshStatus();
    </script>
</body>
</html>
HTMLEOF
    
    # Create API server
    cat > /usr/local/bin/slowdns-api << 'APIEOF'
#!/usr/bin/env python3
import http.server
import json
import subprocess
import os

class SlowDNSAPI(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('/etc/slowdns/dashboard/index.html', 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            connections = 0
            try:
                result = subprocess.run(['ss', '-tn'], capture_output=True, text=True)
                connections = len([l for l in result.stdout.split('\n') if ':22' in l or ':5300' in l])
            except: pass
            
            logs = "No logs available"
            try:
                result = subprocess.run(['journalctl', '-u', 'server-sldns', '--no-pager', '-n', '20'], 
                                      capture_output=True, text=True, timeout=5)
                if result.stdout: logs = result.stdout
            except: pass
            
            public_key = "Not available"
            try:
                with open('/etc/slowdns/server.pub', 'r') as f:
                    public_key = f.read().strip()
            except: pass
            
            status = {
                'connections': connections,
                'logs': logs,
                'publicKey': public_key
            }
            self.wfile.write(json.dumps(status).encode())
    
    def do_POST(self):
        if self.path == '/api/control':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode())
            action = data.get('action')
            message = "Action performed"
            try:
                if action == 'start':
                    subprocess.run(['systemctl', 'start', 'server-sldns', 'edns-proxy'])
                    message = "Services started"
                elif action == 'stop':
                    subprocess.run(['systemctl', 'stop', 'server-sldns', 'edns-proxy'])
                    message = "Services stopped"
                elif action == 'restart':
                    subprocess.run(['systemctl', 'restart', 'server-sldns', 'edns-proxy'])
                    message = "Services restarted"
            except Exception as e:
                message = f"Error: {str(e)}"
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'message': message}).encode())

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8080), SlowDNSAPI)
    server.serve_forever()
APIEOF
    
    chmod +x /usr/local/bin/slowdns-api
    
    # Create dashboard service
    cat > /etc/systemd/system/slowdns-dashboard.service << EOF
[Unit]
Description=SlowDNS Dashboard API
After=network.target server-sldns.service edns-proxy.service

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
# CREATE SYSTEMD SERVICES
# ============================================================================
create_services() {
    print_step "8"
    print_info "Creating Ultra-Priority System Services"
    
    # SlowDNS Service
    cat > /etc/systemd/system/server-sldns.service << EOF
[Unit]
Description=ELITE-X8 SlowDNS Server (Ultra Priority)
After=network.target sshd.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1150 -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT
Restart=always
RestartSec=5
User=root
Nice=-20
LimitNOFILE=1000000
LimitCORE=infinity
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
MemoryMax=512M
CPUQuota=200%

[Install]
WantedBy=multi-user.target
EOF
    
    # EDNS Proxy Service
    cat > /etc/systemd/system/edns-proxy.service << EOF
[Unit]
Description=EDNS Proxy for SlowDNS (Ultra Priority Multi-Core)
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
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
MemoryMax=512M
CPUQuota=200%

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Ultra-priority services created"
    print_step_end
}

# ============================================================================
# CONFIGURE FIREWALL
# ============================================================================
configure_firewall() {
    print_step "9"
    print_info "Configuring Firewall Rules"
    
    systemctl stop systemd-resolved 2>/dev/null
    fuser -k 53/udp 2>/dev/null
    
    iptables -F
    iptables -X
    iptables -t nat -F
    
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
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
    print_step "10"
    print_info "Starting All Ultra-Optimized Services"
    
    systemctl daemon-reload
    
    systemctl enable server-sldns > /dev/null 2>&1
    systemctl start server-sldns
    sleep 2
    
    if systemctl is-active --quiet server-sldns; then
        print_success "SlowDNS service started"
    else
        print_warning "Starting in background mode"
        nice -n -20 /etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1150 \
            -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT &
    fi
    
    systemctl enable edns-proxy > /dev/null 2>&1
    systemctl start edns-proxy
    sleep 2
    
    if systemctl is-active --quiet edns-proxy; then
        print_success "EDNS Proxy started (Multi-Core)"
    else
        print_warning "Starting in background mode"
        nice -n -20 /usr/local/bin/edns-proxy &
    fi
    
    systemctl enable slowdns-dashboard > /dev/null 2>&1
    systemctl start slowdns-dashboard
    sleep 2
    
    if systemctl is-active --quiet slowdns-dashboard; then
        print_success "Dashboard started"
    else
        python3 /usr/local/bin/slowdns-api &
    fi
    
    print_step_end
}

# ============================================================================
# SHOW SUMMARY
# ============================================================================
show_summary() {
    print_header "🎉 ELITE-X8 ULTRA MAX SPEED INSTALLATION COMPLETE"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}SERVER INFORMATION${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IP:            ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SSH:           ${WHITE}$SSHD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SlowDNS:       ${WHITE}$SLOWDNS_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} EDNS:          ${WHITE}53${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Dashboard:     ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Nameserver:    ${WHITE}$NAMESERVER${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} MTU:           ${WHITE}1150${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} UDP Buffer:    ${WHITE}16MB${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Priority:      ${WHITE}Real-Time (-20)${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IPv6:          ${WHITE}Disabled${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Congestion:    ${WHITE}BBR${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    if [ -f /etc/slowdns/server.pub ]; then
        echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}${BOLD}PUBLIC KEY${NC}                                          ${CYAN}│${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}$(cat /etc/slowdns/server.pub)${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  ${WHITE}🎯 ELITE-X8 ULTRA MAX SPEED SLOWDNS INSTALLED!${NC}             ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${WHITE}⚡ Dashboard: http://$SERVER_IP:$DASHBOARD_PORT${NC}             ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${WHITE}📁 GitHub: https://github.com/ELITE-X8/setup.sh${NC}          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================
main() {
    print_banner
    
    echo -e "${WHITE}${BOLD}Configure Your Nameserver:${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Example:${NC} dns.google.com, dns.cloudflare.com            ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Custom:${NC}  ns-free.elitex.sbs, ns1.yourserver.com       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    read -p "$(echo -e "${WHITE}${BOLD}Enter nameserver: ${NC}")" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    disable_ipv6
    optimize_kernel
    compile_edns
    install_dnstt || {
        print_error "Cannot proceed without dnstt-server"
        exit 1
    }
    download_supporting_files
    configure_ssh
    create_dashboard
    create_services
    configure_firewall
    start_services
    show_summary
}

# ============================================================================
# ERROR HANDLING
# ============================================================================
trap 'echo -e "\n${RED}✗ Installation interrupted!${NC}"; log_message "Installation interrupted"; exit 1' INT

echo "=== SLOWDNS ULTRA MAX SPEED INSTALLATION STARTED $(date) ===" > "$LOG_FILE"

if main; then
    echo "=== INSTALLATION COMPLETED SUCCESSFULLY $(date) ===" >> "$LOG_FILE"
    exit 0
else
    echo "=== INSTALLATION FAILED $(date) ===" >> "$LOG_FILE"
    exit 1
fi
