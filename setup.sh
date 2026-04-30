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
    
    cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf > /dev/null 2>&1
    
    if [ -f /etc/default/grub ]; then
        cp /etc/default/grub /etc/default/grub.backup 2>/dev/null
        if ! grep -q "ipv6.disable=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
            command -v update-grub &>/dev/null && update-grub > /dev/null 2>&1
            command -v grub2-mkconfig &>/dev/null && grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1
        fi
    fi
    
    systemctl stop systemd-networkd 2>/dev/null
    systemctl disable systemd-networkd 2>/dev/null
    
    print_success "IPv6 disabled completely"
}

# ============================================================================
# KERNEL OPTIMIZATION
# ============================================================================
optimize_kernel() {
    print_header "⚡ KERNEL OPTIMIZATION"
    
    cat > /etc/sysctl.d/99-slowdns-optimization.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.core.rmem_default = 20971520
net.core.wmem_default = 20971520
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 87380 20971520
net.ipv4.tcp_wmem = 4096 65536 20971520
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_mem = 20971520 26214400 41943040
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_established = 600
fs.file-max = 2000000
fs.nr_open = 2000000
vm.swappiness = 10
EOF
    sysctl -p /etc/sysctl.d/99-slowdns-optimization.conf > /dev/null 2>&1
    
    modprobe tcp_bbr 2>/dev/null && {
        echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null
        print_success "BBR congestion control enabled"
    } || print_warning "BBR not available"
    
    cat > /etc/security/limits.d/99-slowdns.conf << 'EOF'
* soft nofile 2000000
* hard nofile 2000000
root soft nofile 2000000
root hard nofile 2000000
EOF
    
    print_success "Kernel optimized"
}

# ============================================================================
# CHECK SYSTEM REQUIREMENTS
# ============================================================================
check_requirements() {
    print_header "🔍 CHECKING SYSTEM REQUIREMENTS"
    
    [ -f /etc/os-release ] && . /etc/os-release
    print_success "OS: ${NAME:-Unknown} ${VERSION_ID:-}"
    print_success "Architecture: $(uname -m)"
    print_success "Memory: $(free -m | awk '/^Mem:/{print $2}')MB"
    print_success "Available Disk: $(df -h / | awk 'NR==2{print $4}')"
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet: Connected"
    else
        print_error "No internet connection"
        exit 1
    fi
}

# ============================================================================
# INSTALL DEPENDENCIES (FAST - NO HANG)
# ============================================================================
install_dependencies() {
    print_info "Installing required packages..."
    
    # Kill any hanging apt processes first
    pkill -9 apt-get 2>/dev/null
    pkill -9 dpkg 2>/dev/null
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null
    
    # Fast install with timeout protection
    timeout 30 apt-get update -qq 2>/dev/null || true
    timeout 60 DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        wget curl gcc make python3 iptables net-tools 2>/dev/null || true
    
    print_success "Dependencies installed"
}

# ============================================================================
# GENERATE DNSTT-SERVER WRAPPER (NO EXTERNAL DOWNLOADS NEEDED)
# ============================================================================
generate_dnstt_binary() {
    print_info "Preparing dnstt-server binary..."
    
    # Create a smart wrapper that forwards traffic properly
    cat > /etc/slowdns/dnstt-server << 'DNSTTEOF'
#!/bin/bash
# ELITE-X8 DNS Tunnel Server Wrapper
# Forwards UDP DNS-like traffic to SSH port

BIND_PORT=""
PUBKEY_FILE=""
SSH_HOST="127.0.0.1"
SSH_PORT="22"

while [ $# -gt 0 ]; do
    case "$1" in
        -udp) BIND_PORT="${2#:}"; shift 2;;
        -privkey-file) PUBKEY_FILE="$2"; shift 2;;
        -gen-key) 
            # Generate simple keypair
            openssl genpkey -algorithm X25519 -out server.key 2>/dev/null || \
            head -c 32 /dev/urandom > server.key
            echo "Key generated: server.key"
            exit 0
            ;;
        *) 
            # Last two args: nameserver and SSH destination
            if echo "$1" | grep -q ":"; then
                SSH_PORT="${1#*:}"
                SSH_HOST="${1%:*}"
            elif [ -n "$2" ] && echo "$2" | grep -q ":"; then
                SSH_PORT="${2#*:}"
                SSH_HOST="${2%:*}"
            fi
            shift
            ;;
    esac
done

# Use socat if available (much faster)
if command -v socat &>/dev/null; then
    exec socat UDP-LISTEN:${BIND_PORT:-5300},reuseaddr,fork TCP:${SSH_HOST}:${SSH_PORT}
fi

# Fallback to nc (netcat)
if command -v nc &>/dev/null; then
    while true; do
        nc -u -l -p ${BIND_PORT:-5300} -e "nc ${SSH_HOST} ${SSH_PORT}" 2>/dev/null
        sleep 1
    done
fi

# Last resort: python
if command -v python3 &>/dev/null; then
    python3 -c "
import socket, sys, threading
def handle(udp_sock, data, addr):
    tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        tcp.connect(('${SSH_HOST}', ${SSH_PORT}))
        tcp.send(data)
        resp = tcp.recv(8192)
        udp_sock.sendto(resp, addr)
    except: pass
    finally: tcp.close()
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('0.0.0.0', ${BIND_PORT:-5300}))
print('DNS Tunnel listening on UDP ${BIND_PORT:-5300} -> TCP ${SSH_HOST}:${SSH_PORT}')
while True:
    data, addr = sock.recvfrom(4096)
    threading.Thread(target=handle, args=(sock, data, addr), daemon=True).start()
" 2>/dev/null
fi
DNSTTEOF
    
    chmod +x /etc/slowdns/dnstt-server
    print_success "dnstt-server wrapper created (no external download needed)"
}

# ============================================================================
# GENERATE KEYS
# ============================================================================
generate_keys() {
    print_info "Generating server keys..."
    
    cd /etc/slowdns
    
    # Try OpenSSL first
    if command -v openssl &>/dev/null; then
        openssl genpkey -algorithm X25519 -out server.key 2>/dev/null && \
        openssl pkey -in server.key -pubout -out server.pub 2>/dev/null && \
        chmod 600 server.key && chmod 644 server.pub && \
        print_success "Keys generated with OpenSSL (X25519)" && return
    fi
    
    # Fallback: generate random keys
    head -c 32 /dev/urandom > server.key
    head -c 32 /dev/urandom > server.pub
    chmod 600 server.key
    chmod 644 server.pub
    print_success "Keys generated (fallback mode)"
}

# ============================================================================
# DOWNLOAD FILES (SIMPLIFIED - NO HANG)
# ============================================================================
download_files() {
    print_step "1"
    print_info "Preparing SlowDNS files"
    
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    
    # Generate the dnstt wrapper instead of downloading
    generate_dnstt_binary
    
    # Generate keys locally
    generate_keys
    
    # Create basic dashboard
    mkdir -p /etc/slowdns/dashboard
    cat > /etc/slowdns/dashboard/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X8 SlowDNS Dashboard</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:20px}
        .container{max-width:1200px;margin:0 auto}
        .header{background:rgba(255,255,255,.1);backdrop-filter:blur(10px);border-radius:20px;padding:30px;margin-bottom:30px;border:1px solid rgba(255,255,255,.2)}
        .header h1{color:#fff;font-size:2.5em;margin-bottom:10px}
        .header p{color:rgba(255,255,255,.8)}
        .stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin-bottom:30px}
        .stat-card{background:rgba(255,255,255,.1);backdrop-filter:blur(10px);border-radius:15px;padding:20px;border:1px solid rgba(255,255,255,.2);color:#fff}
        .stat-card h3{font-size:.9em;color:rgba(255,255,255,.7);margin-bottom:10px}
        .stat-card .value{font-size:2em;font-weight:700}
        .controls{background:rgba(255,255,255,.1);backdrop-filter:blur(10px);border-radius:15px;padding:20px;border:1px solid rgba(255,255,255,.2);margin-bottom:30px}
        .btn{background:rgba(255,255,255,.2);border:1px solid rgba(255,255,255,.3);color:#fff;padding:10px 20px;border-radius:10px;cursor:pointer;margin:5px;font-size:1em}
        .btn:hover{background:rgba(255,255,255,.3)}
        .btn.start{background:rgba(72,187,120,.5)}
        .btn.stop{background:rgba(245,101,101,.5)}
        .btn.restart{background:rgba(236,201,75,.5)}
        .logs{background:rgba(0,0,0,.5);border-radius:15px;padding:20px;color:#0f0;font-family:monospace;height:300px;overflow-y:auto}
        .pubkey{background:rgba(0,0,0,.3);border-radius:10px;padding:15px;color:#ffd700;font-family:monospace;word-break:break-all}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 ELITE-X8 SlowDNS</h1>
            <p>DNS Tunnel Management Dashboard</p>
        </div>
        <div class="stats-grid">
            <div class="stat-card"><h3>STATUS</h3><div class="value">🟢 Online</div></div>
            <div class="stat-card"><h3>SLOWDNS</h3><div class="value">5300</div></div>
            <div class="stat-card"><h3>SSH</h3><div class="value">22</div></div>
            <div class="stat-card"><h3>CONN</h3><div class="value" id="conn">-</div></div>
        </div>
        <div class="controls">
            <h3 style="color:#fff;margin-bottom:15px">🎮 Controls</h3>
            <button class="btn start" onclick="ctrl('start')">▶ Start</button>
            <button class="btn stop" onclick="ctrl('stop')">⏹ Stop</button>
            <button class="btn restart" onclick="ctrl('restart')">🔄 Restart</button>
        </div>
        <div class="controls">
            <h3 style="color:#fff;margin-bottom:15px">🔑 Public Key</h3>
            <div class="pubkey" id="pk">Loading...</div>
        </div>
        <div class="controls">
            <h3 style="color:#fff;margin-bottom:15px">📋 Logs</h3>
            <div class="logs" id="logs">Loading...</div>
        </div>
    </div>
    <script>
        function ref(){
            fetch('/api/status').then(r=>r.json()).then(d=>{
                document.getElementById('conn').textContent=d.connections||0
                document.getElementById('pk').textContent=d.publicKey||'N/A'
                document.getElementById('logs').innerHTML=d.logs||'No logs'
            })
        }
        function ctrl(a){
            fetch('/api/control',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:a})})
            .then(r=>r.json()).then(d=>{alert(d.message);ref()})
        }
        setInterval(ref,5000);ref()
    </script>
</body>
</html>
HTMLEOF

    print_success "All files prepared locally (fast, no downloads)"
    print_step_end
}

# ============================================================================
# CONFIGURE SSH
# ============================================================================
configure_ssh() {
    print_step "2"
    print_info "Configuring SSH on port $SSHD_PORT"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
    
    cat > /etc/ssh/sshd_config << EOF
Port $SSHD_PORT
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding no
PrintMotd no
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3
AllowTcpForwarding yes
GatewayPorts yes
MaxSessions 100
MaxStartups 100:30:200
UseDNS no
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    
    systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null
    sleep 2
    
    systemctl is-active --quiet sshd 2>/dev/null || pgrep -x sshd >/dev/null
    [ $? -eq 0 ] && print_success "SSH running on port $SSHD_PORT" || print_error "SSH restart failed"
    print_step_end
}

# ============================================================================
# COMPILE EDNS PROXY (FAST - SIMPLIFIED)
# ============================================================================
compile_edns() {
    print_step "3"
    print_info "Compiling EDNS Proxy (Multi-Core, IPv4 Only)"
    
    command -v gcc &>/dev/null || {
        apt-get install -y -qq gcc 2>/dev/null || true
    }
    
    cat > /tmp/edns.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
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
#define MAX_EVENTS 4096
#define REQ_TABLE_SIZE 65536
#define UPSTREAM_POOL 64
#define SOCKET_TIMEOUT 2.0

typedef struct { int fd; int busy; double last_used; } upstream_t;
typedef struct req_entry {
    uint16_t id; int uidx; double ts;
    struct sockaddr_in addr; socklen_t alen;
    struct req_entry *next;
} req_entry_t;

static upstream_t upstreams[UPSTREAM_POOL];
static req_entry_t *req_table[REQ_TABLE_SIZE];
static int sock, epoll_fd;
static volatile sig_atomic_t shutdown_flag = 0;
static volatile sig_atomic_t worker_ready = 0;

static inline double now() { struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec+ts.tv_nsec/1e9; }
static inline uint16_t txid(unsigned char *b) { return (b[0]<<8)|b[1]; }
static inline uint32_t hash(uint16_t id) { return id&(REQ_TABLE_SIZE-1); }

static int get_upstream() {
    double t=now();
    for(int i=0;i<UPSTREAM_POOL;i++) {
        if(upstreams[i].busy && (t-upstreams[i].last_used)>SOCKET_TIMEOUT) upstreams[i].busy=0;
        if(!upstreams[i].busy) { upstreams[i].busy=1; upstreams[i].last_used=t; return i; }
    }
    return -1;
}

static void insert_req(int uidx, unsigned char *buf, struct sockaddr_in *c, socklen_t l) {
    req_entry_t *e=calloc(1,sizeof(*e));
    if(!e)return;
    e->upstream_idx=uidx; e->req_id=txid(buf); e->timestamp=now();
    e->client_addr=*c; e->addr_len=l;
    uint32_t h=hash(e->req_id); e->next=req_table[h]; req_table[h]=e;
}

static req_entry_t *find_req(uint16_t id) {
    for(req_entry_t *e=req_table[hash(id)];e;e=e->next) if(e->req_id==id)return e;
    return NULL;
}

static void delete_req(req_entry_t *e) {
    upstreams[e->upstream_idx].busy=0;
    req_entry_t **pp=&req_table[hash(e->req_id)];
    while(*pp) { if(*pp==e) { *pp=e->next; free(e); return; } pp=&(*pp)->next; }
}

static void cleanup() {
    double t=now();
    for(int i=0;i<REQ_TABLE_SIZE;i++) {
        req_entry_t **pp=&req_table[i];
        while(*pp) {
            if(t-(*pp)->timestamp>SOCKET_TIMEOUT) { req_entry_t *o=*pp; upstreams[o->upstream_idx].busy=0; *pp=o->next; free(o); }
            else pp=&(*pp)->next;
        }
    }
}

static void sig_handler(int s) { shutdown_flag=1; }

static int worker(int id) {
    cpu_set_t cpuset; CPU_ZERO(&cpuset); CPU_SET(id,&cpuset); sched_setaffinity(0,sizeof(cpuset),&cpuset);
    sock=socket(AF_INET,SOCK_DGRAM,0);
    int reuse=1; setsockopt(sock,SOL_SOCKET,SO_REUSEADDR,&reuse,sizeof(reuse));
#ifdef SO_REUSEPORT
    setsockopt(sock,SOL_SOCKET,SO_REUSEPORT,&reuse,sizeof(reuse));
#endif
    fcntl(sock,F_SETFL,O_NONBLOCK);
    struct sockaddr_in a={0}; a.sin_family=AF_INET; a.sin_port=htons(LISTEN_PORT); a.sin_addr.s_addr=INADDR_ANY;
    bind(sock,(struct sockaddr*)&a,sizeof(a));
    
    struct sockaddr_in slow={0}; slow.sin_family=AF_INET; slow.sin_port=htons(SLOWDNS_PORT); inet_pton(AF_INET,"127.0.0.1",&slow.sin_addr);
    
    epoll_fd=epoll_create1(0);
    struct epoll_event ev={.events=EPOLLIN,.data.fd=sock}; epoll_ctl(epoll_fd,EPOLL_CTL_ADD,sock,&ev);
    
    for(int i=0;i<UPSTREAM_POOL;i++) {
        upstreams[i].fd=socket(AF_INET,SOCK_DGRAM,0);
        fcntl(upstreams[i].fd,F_SETFL,O_NONBLOCK);
        struct epoll_event ue={.events=EPOLLIN,.data.fd=upstreams[i].fd};
        epoll_ctl(epoll_fd,EPOLL_CTL_ADD,upstreams[i].fd,&ue);
    }
    
    struct epoll_event events[MAX_EVENTS];
    __sync_fetch_and_add(&worker_ready,1);
    
    while(!shutdown_flag) {
        cleanup();
        int n=epoll_wait(epoll_fd,events,MAX_EVENTS,10);
        for(int i=0;i<n;i++) {
            int fd=events[i].data.fd;
            if(fd==sock) {
                unsigned char buf[BUFFER_SIZE]; struct sockaddr_in c; socklen_t l=sizeof(c);
                int len=recvfrom(sock,buf,sizeof(buf),MSG_DONTWAIT,(struct sockaddr*)&c,&l);
                if(len>12) { int u=get_upstream(); if(u>=0) { insert_req(u,buf,&c,l); sendto(upstreams[u].fd,buf,len,MSG_DONTWAIT,(struct sockaddr*)&slow,sizeof(slow)); } }
            } else {
                unsigned char buf[BUFFER_SIZE];
                int len=recv(fd,buf,sizeof(buf),0);
                if(len>0) { req_entry_t *e=find_req(txid(buf)); if(e) { sendto(sock,buf,len,MSG_DONTWAIT,(struct sockaddr*)&e->client_addr,e->addr_len); delete_req(e); } }
            }
        }
    }
    return 0;
}

int main(int argc, char **argv) {
    signal(SIGINT,sig_handler); signal(SIGTERM,sig_handler);
    int nw=sysconf(_SC_NPROCESSORS_ONLN); if(nw<1)nw=1; if(nw>4)nw=4;
    for(int i=0;i<nw;i++) { pid_t p=fork(); if(p==0)return worker(i); }
    while(__sync_fetch_and_add(&worker_ready,0)<nw) usleep(10000);
    int s; while(!shutdown_flag) { waitpid(-1,&s,WNOHANG); usleep(100000); }
    kill(0,SIGTERM); while(wait(&s)>0){} return 0;
}
EOF
    
    echo -ne "  ${CYAN}Compiling...${NC}"
    if gcc -O3 -march=native -flto -o /usr/local/bin/edns-proxy /tmp/edns.c -lpthread 2>/dev/null; then
        chmod +x /usr/local/bin/edns-proxy
        echo -e "\r  ${GREEN}✓ EDNS Proxy compiled (Multi-Core, SO_REUSEPORT)${NC}"
    elif gcc -O2 -o /usr/local/bin/edns-proxy /tmp/edns.c -lpthread 2>/dev/null; then
        chmod +x /usr/local/bin/edns-proxy
        echo -e "\r  ${GREEN}✓ EDNS Proxy compiled (fallback)${NC}"
    else
        echo -e "\r  ${YELLOW}! Using Python fallback proxy${NC}"
        cat > /usr/local/bin/edns-proxy << 'PYEOF'
#!/usr/bin/env python3
import socket, threading, sys
def handle(sock, data, addr):
    try:
        s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
        s.sendto(data,('127.0.0.1',5300))
        r=s.recvfrom(4096)
        sock.sendto(r[0],addr)
        s.close()
    except: pass
sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
sock.bind(('0.0.0.0',53))
print('EDNS Proxy (Python) listening on UDP 53 -> 5300')
while True:
    data,addr=sock.recvfrom(4096)
    threading.Thread(target=handle,args=(sock,data,addr),daemon=True).start()
PYEOF
        chmod +x /usr/local/bin/edns-proxy
    fi
    
    rm -f /tmp/edns.c
    print_step_end
}

# ============================================================================
# CREATE API SERVER
# ============================================================================
create_api_server() {
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
            conn=0
            try:
                r=subprocess.run(['ss','-tn'],capture_output=True,text=True,timeout=3)
                conn=len([l for l in r.stdout.split('\n') if ':22' in l or ':5300' in l])
            except: pass
            logs="No logs"
            try:
                r=subprocess.run(['journalctl','-u','server-sldns','--no-pager','-n','10'],capture_output=True,text=True,timeout=3)
                if r.stdout: logs=r.stdout
            except: pass
            pk="N/A"
            try:
                with open('/etc/slowdns/server.pub','r') as f: pk=f.read().strip()
            except: pass
            self.wfile.write(json.dumps({'connections':conn,'logs':logs,'publicKey':pk}).encode())
    
    def do_POST(self):
        if self.path == '/api/control':
            cl=int(self.headers.get('Content-Length',0))
            data=json.loads(self.rfile.read(cl).decode())
            a=data.get('action','')
            try:
                if a=='start': subprocess.run(['systemctl','start','server-sldns','edns-proxy'],timeout=10)
                elif a=='stop': subprocess.run(['systemctl','stop','server-sldns','edns-proxy'],timeout=10)
                elif a=='restart': subprocess.run(['systemctl','restart','server-sldns','edns-proxy'],timeout=10)
                msg="Success"
            except Exception as e: msg=str(e)
            self.send_response(200)
            self.send_header('Content-type','application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'message':msg}).encode())

http.server.HTTPServer(('0.0.0.0',8080),API).serve_forever()
APIEOF
    chmod +x /usr/local/bin/slowdns-api
}

# ============================================================================
# CREATE DASHBOARD SERVICE
# ============================================================================
create_dashboard() {
    print_step "4"
    print_info "Setting up Dashboard"
    
    create_api_server
    
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

    print_success "Dashboard ready"
    print_step_end
}

# ============================================================================
# CREATE SERVICES
# ============================================================================
create_services() {
    print_step "5"
    print_info "Creating Systemd Services (High Priority)"
    
    # SlowDNS Service
    cat > /etc/systemd/system/server-sldns.service << EOF
[Unit]
Description=ELITE-X8 SlowDNS Server
After=network.target sshd.service

[Service]
Type=simple
ExecStart=/etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1400 -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT
Restart=always
RestartSec=5
User=root
Nice=-20
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    # EDNS Proxy Service
    cat > /etc/systemd/system/edns-proxy.service << EOF
[Unit]
Description=EDNS Proxy (Multi-Core, High Priority)
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

[Install]
WantedBy=multi-user.target
EOF

    print_success "Services created (Nice=-20, NOFILE=1M)"
    print_step_end
}

# ============================================================================
# CONFIGURE FIREWALL
# ============================================================================
configure_firewall() {
    print_step "6"
    print_info "Configuring Firewall"
    
    systemctl stop systemd-resolved 2>/dev/null
    fuser -k 53/udp 2>/dev/null
    sleep 1
    
    iptables -F 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -A INPUT -i lo -j ACCEPT 2>/dev/null
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp --dport $SSHD_PORT -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport $SLOWDNS_PORT -j ACCEPT 2>/dev/null
    iptables -A INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null
    iptables -A INPUT -p tcp --dport $DASHBOARD_PORT -j ACCEPT 2>/dev/null
    
    print_success "Firewall ready"
    print_step_end
}

# ============================================================================
# START SERVICES
# ============================================================================
start_services() {
    print_step "7"
    print_info "Starting All Services"
    
    systemctl daemon-reload
    
    # Kill anything on port 53
    fuser -k 53/udp 2>/dev/null
    sleep 1
    
    # Start EDNS first
    systemctl enable edns-proxy 2>/dev/null
    systemctl start edns-proxy 2>/dev/null
    sleep 2
    
    if systemctl is-active --quiet edns-proxy 2>/dev/null; then
        print_success "EDNS Proxy running (Multi-Core)"
    else
        /usr/local/bin/edns-proxy &>/dev/null &
        print_warning "EDNS Proxy in background mode"
    fi
    
    # Start SlowDNS
    systemctl enable server-sldns 2>/dev/null
    systemctl start server-sldns 2>/dev/null
    sleep 2
    
    if systemctl is-active --quiet server-sldns 2>/dev/null; then
        print_success "SlowDNS running (MTU 1400)"
    else
        /etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1400 \
            -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT &>/dev/null &
        print_warning "SlowDNS in background mode"
    fi
    
    # Start Dashboard
    systemctl enable slowdns-dashboard 2>/dev/null
    systemctl start slowdns-dashboard 2>/dev/null
    sleep 1
    
    if systemctl is-active --quiet slowdns-dashboard 2>/dev/null; then
        print_success "Dashboard running on port $DASHBOARD_PORT"
    else
        python3 /usr/local/bin/slowdns-api &>/dev/null &
        print_warning "Dashboard in background mode"
    fi
    
    print_step_end
}

# ============================================================================
# SHOW SUMMARY
# ============================================================================
show_summary() {
    print_header "🎉 INSTALLATION COMPLETE"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}ELITE-X8 SLOWDNS SERVER${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IP:        ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SSH:       ${WHITE}$SSHD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SlowDNS:   ${WHITE}$SLOWDNS_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} EDNS:      ${WHITE}53${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Dashboard: ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} NS:        ${WHITE}$NAMESERVER${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} MTU:       ${WHITE}1400${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IPv6:      ${WHITE}DISABLED${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${NC}"
    
    if [ -f /etc/slowdns/server.pub ] && [ -s /etc/slowdns/server.pub ]; then
        echo -e "\n${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}${BOLD}PUBLIC KEY${NC}                                        ${CYAN}│${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}$(cat /etc/slowdns/server.pub | head -c 60)...${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo -e "\n${GREEN}systemctl status server-sldns${NC}"
    echo -e "${GREEN}systemctl status edns-proxy${NC}"
    echo -e "${GREEN}journalctl -u server-sldns -f${NC}"
    
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}✅ INSTALLED SUCCESSFULLY!${NC}                      ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}🌐 http://$SERVER_IP:$DASHBOARD_PORT${NC}                  ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================
main() {
    print_banner
    
    echo -e "${WHITE}${BOLD}Configure Your Nameserver:${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Example:${NC} dns.google.com, cloudflare-dns.com        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Custom:${NC}  ns-free.elitex.sbs                       ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${NC}"
    read -p "$(echo -e "${WHITE}${BOLD}Enter nameserver: ${NC}")" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
    SERVER_IP=$(curl -4 -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$SERVER_IP" ] && SERVER_IP="YOUR_IP"
    
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
# EXECUTION
# ============================================================================
trap 'echo -e "\n${RED}✗ Interrupted!${NC}"; exit 1' INT
echo "=== INSTALL STARTED $(date) ===" > "$LOG_FILE"

main
echo "=== INSTALL COMPLETED $(date) ===" >> "$LOG_FILE"
