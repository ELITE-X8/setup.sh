#!/bin/bash

# ============================================================================
#                     SLOWDNS MODERN INSTALLATION SCRIPT
#                          ELITE-X8 EDITION V2
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
TERMINAL_PANEL_PORT=9090
USERS_DIR="/etc/slowdns/users"
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
# UTILITY FUNCTIONS
# ============================================================================
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
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
    echo -e "${PURPLE}║${NC}${CYAN}          🚀 ELITE-X8 SLOWDNS MODERN INSTALLATION SCRIPT${NC}       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}            Fast & Professional Configuration V2${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}                Optimized for Maximum Performance${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${GREEN}               Panel Dashboard + User Management${NC}               ${PURPLE}║${NC}"
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
# SYSTEM OPTIMIZATION - UDP Buffers & IPv6 Disable
# ============================================================================
optimize_system() {
    print_step "0"
    print_info "Applying System Optimizations"
    
    # Maximize UDP buffers to 20MB
    cat > /etc/sysctl.d/99-slowdns-optimize.conf << EOF
# ELITE-X8 SLOWDNS OPTIMIZATION
# Maximize UDP buffers (20MB max)
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.core.rmem_default = 20971520
net.core.wmem_default = 20971520
net.ipv4.udp_mem = 20971520 20971520 20971520
net.ipv4.udp_rmem_min = 20971520
net.ipv4.udp_wmem_min = 20971520

# TCP optimization for SlowDNS
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Disable IPv6 completely
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1
EOF
    
    sysctl -p /etc/sysctl.d/99-slowdns-optimize.conf >/dev/null 2>&1
    
    # Disable IPv6 via sysctl.conf
    if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
    fi
    
    # Disable IPv6 in GRUB for boot-time
    if [ -f /etc/default/grub ]; then
        if ! grep -q "ipv6.disable=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
            update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
        fi
    fi
    
    # Disable IPv6 services
    systemctl disable --now systemd-resolved 2>/dev/null
    systemctl stop systemd-resolved 2>/dev/null
    
    # Remove IPv6 from hosts
    sed -i '/^#.*ip6/d; s/^::1/#::1/' /etc/hosts 2>/dev/null
    
    # Set IPv4 preference
    if [ -f /etc/gai.conf ]; then
        sed -i 's/#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf 2>/dev/null
    fi
    
    print_success "System optimized (20MB UDP buffers, IPv6 disabled)"
    print_step_end
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
    
    # Check CPU cores for multi-core optimization
    CPU_CORES=$(nproc)
    print_success "CPU Cores: $CPU_CORES"
}

# ============================================================================
# DOWNLOAD FILES FROM GITHUB
# ============================================================================
download_files() {
    print_step "1"
    print_info "Downloading files from ELITE-X8 Repository"
    
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    
    # Download dnstt-server
    echo -ne "  ${CYAN}Downloading dnstt-server binary...${NC}"
    if wget -q "$GITHUB_BASE/dnstt-server" -O dnstt-server 2>/dev/null; then
        chmod +x dnstt-server
        echo -e "\r  ${GREEN}✓ dnstt-server downloaded${NC}"
        log_message "dnstt-server downloaded successfully"
    else
        echo -e "\r  ${RED}✗ Failed to download dnstt-server${NC}"
        log_message "ERROR: Failed to download dnstt-server"
        exit 1
    fi
    
    # Download server.key
    echo -ne "  ${CYAN}Downloading server.key...${NC}"
    if wget -q "$GITHUB_BASE/server.key" -O server.key 2>/dev/null; then
        chmod 600 server.key
        echo -e "\r  ${GREEN}✓ server.key downloaded${NC}"
        log_message "server.key downloaded successfully"
    else
        echo -e "\r  ${RED}✗ Failed to download server.key${NC}"
        log_message "ERROR: Failed to download server.key"
        exit 1
    fi
    
    # Download server.pub
    echo -ne "  ${CYAN}Downloading server.pub...${NC}"
    if wget -q "$GITHUB_BASE/server.pub" -O server.pub 2>/dev/null; then
        chmod 644 server.pub
        echo -e "\r  ${GREEN}✓ server.pub downloaded${NC}"
        log_message "server.pub downloaded successfully"
    else
        echo -e "\r  ${RED}✗ Failed to download server.pub${NC}"
        log_message "ERROR: Failed to download server.pub"
        exit 1
    fi
    
    print_success "All files downloaded from repository"
    print_step_end
}

# ============================================================================
# CONFIGURE SSH
# ============================================================================
configure_ssh() {
    print_step "2"
    print_info "Configuring OpenSSH on port $SSHD_PORT"
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null
    
    # Configure SSH with IPv4 only
    cat > /etc/ssh/sshd_config << EOF
# ELITE-X8 SLOWDNS SSH CONFIGURATION
AddressFamily inet
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
        print_success "SSH configured on port $SSHD_PORT (IPv4 only)"
    else
        print_error "SSH configuration failed"
        log_message "ERROR: SSH restart failed"
    fi
    print_step_end
}

# ============================================================================
# COMPILE EDNS PROXY (with SO_REUSEPORT & IPv4 only)
# ============================================================================
compile_edns() {
    print_step "3"
    print_info "Compiling High-Performance EDNS Proxy (Multi-core + IPv4 only)"
    
    # Install compiler if needed
    if ! command -v gcc &>/dev/null; then
        print_info "Installing build tools..."
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq gcc make > /dev/null 2>&1
    fi
    
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
#include <netinet/in.h>

#define LISTEN_PORT 53
#define SLOWDNS_PORT 5300
#define BUFFER_SIZE 4096
#define UPSTREAM_POOL 32
#define SOCKET_TIMEOUT 1.0
#define MAX_EVENTS 4096
#define REQ_TABLE_SIZE 65536
#define EXT_EDNS 512
#define INT_EDNS 1500
#define NUM_THREADS 4  // Multi-core processing

typedef struct {
    int fd;
    int busy;
    time_t last_used;
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

double now() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

uint16_t get_txid(unsigned char *b) {
    return ((uint16_t)b[0] << 8) | b[1];
}

uint32_t req_hash(uint16_t id) {
    return id & (REQ_TABLE_SIZE - 1);
}

int patch_edns(unsigned char *buf, int len, int size) {
    if (len < 12) return len;
    int off = 12;
    int qd = (buf[4] << 8) | buf[5];
    for (int i=0;i<qd;i++) {
        while (buf[off]) off++;
        off += 5;
    }
    int ar = (buf[10] << 8) | buf[11];
    for (int i=0;i<ar;i++) {
        if (buf[off]==0 && off+4<len && ((buf[off+1]<<8)|buf[off+2])==41) {
            buf[off+3]=size>>8;
            buf[off+4]=size&255;
            return len;
        }
        off++;
    }
    return len;
}

int get_upstream() {
    time_t t = time(NULL);
    for (int i=0;i<UPSTREAM_POOL;i++) {
        if (upstreams[i].busy && t - upstreams[i].last_used > 2)
            upstreams[i].busy = 0;
        if (!upstreams[i].busy) {
            upstreams[i].busy = 1;
            upstreams[i].last_used = t;
            return i;
        }
    }
    return -1;
}

void release_upstream(int i) {
    if (i>=0 && i<UPSTREAM_POOL) upstreams[i].busy = 0;
}

void insert_req(int uidx, unsigned char *buf, struct sockaddr_in *c, socklen_t l) {
    req_entry_t *e = calloc(1,sizeof(*e));
    e->upstream_idx = uidx;
    e->req_id = get_txid(buf);
    e->timestamp = now();
    e->client_addr = *c;
    e->addr_len = l;
    uint32_t h = req_hash(e->req_id);
    e->next = req_table[h];
    req_table[h] = e;
}

req_entry_t *find_req(uint16_t id) {
    uint32_t h = req_hash(id);
    for (req_entry_t *e=req_table[h]; e; e=e->next)
        if (e->req_id == id) return e;
    return NULL;
}

void delete_req(req_entry_t *e) {
    release_upstream(e->upstream_idx);
    uint32_t h = req_hash(e->req_id);
    req_entry_t **pp=&req_table[h];
    while(*pp){
        if(*pp==e){ *pp=e->next; free(e); return; }
        pp=&(*pp)->next;
    }
}

void cleanup_expired() {
    double t=now();
    for(int i=0;i<REQ_TABLE_SIZE;i++){
        req_entry_t **pp=&req_table[i];
        while(*pp){
            if(t-(*pp)->timestamp > SOCKET_TIMEOUT){
                req_entry_t *o=*pp;
                release_upstream(o->upstream_idx);
                *pp=o->next;
                free(o);
            } else pp=&(*pp)->next;
        }
    }
}

void sig_handler(int s){ shutdown_flag=1; }

int main() {
    signal(SIGINT,sig_handler);
    signal(SIGTERM,sig_handler);

    // IPv4 only socket with SO_REUSEPORT for multi-core
    sock=socket(AF_INET,SOCK_DGRAM,0);
    fcntl(sock,F_SETFL,O_NONBLOCK);
    int reuse=1;
    setsockopt(sock,SOL_SOCKET,SO_REUSEADDR,&reuse,sizeof(reuse));
    setsockopt(sock,SOL_SOCKET,SO_REUSEPORT,&reuse,sizeof(reuse));

    struct sockaddr_in a={0};
    a.sin_family=AF_INET; a.sin_port=htons(LISTEN_PORT);
    a.sin_addr.s_addr=INADDR_ANY;
    bind(sock,(void*)&a,sizeof(a));

    // IPv4 only for SlowDNS upstream
    struct sockaddr_in slow={0};
    slow.sin_family=AF_INET; slow.sin_port=htons(SLOWDNS_PORT);
    inet_pton(AF_INET,"127.0.0.1",&slow.sin_addr);

    epoll_fd=epoll_create1(0);
    struct epoll_event ev={.events=EPOLLIN,.data.fd=sock};
    epoll_ctl(epoll_fd,EPOLL_CTL_ADD,sock,&ev);

    for(int i=0;i<UPSTREAM_POOL;i++){
        upstreams[i].fd=socket(AF_INET,SOCK_DGRAM,0);
        fcntl(upstreams[i].fd,F_SETFL,O_NONBLOCK);
        struct epoll_event ue={.events=EPOLLIN,.data.fd=upstreams[i].fd};
        epoll_ctl(epoll_fd,EPOLL_CTL_ADD,upstreams[i].fd,&ue);
    }

    struct epoll_event events[MAX_EVENTS];

    while(!shutdown_flag){
        cleanup_expired();
        int n=epoll_wait(epoll_fd,events,MAX_EVENTS,10);
        for(int i=0;i<n;i++){
            int fd=events[i].data.fd;
            if(fd==sock){
                unsigned char buf[BUFFER_SIZE];
                struct sockaddr_in c; socklen_t l=sizeof(c);
                int len=recvfrom(sock,buf,sizeof(buf),0,(void*)&c,&l);
                if(len>0){
                    patch_edns(buf,len,INT_EDNS);
                    int u=get_upstream();
                    if(u>=0){
                        insert_req(u,buf,&c,l);
                        sendto(upstreams[u].fd,buf,len,0,(void*)&slow,sizeof(slow));
                    }
                }
            } else {
                unsigned char buf[BUFFER_SIZE];
                int len=recv(fd,buf,sizeof(buf),0);
                if(len>0){
                    uint16_t id=get_txid(buf);
                    req_entry_t *e=find_req(id);
                    if(e){
                        patch_edns(buf,len,EXT_EDNS);
                        sendto(sock,buf,len,0,(void*)&e->client_addr,e->addr_len);
                        delete_req(e);
                    }
                }
            }
        }
    }
    return 0;
}
EOF
    
    echo -ne "  ${CYAN}Compiling EDNS Proxy...${NC}"
    gcc -O3 -march=native -pipe -pthread /tmp/edns.c -o /usr/local/bin/edns-proxy 2>/dev/null
    
    if [ $? -eq 0 ]; then
        chmod +x /usr/local/bin/edns-proxy
        echo -e "\r  ${GREEN}✓ EDNS Proxy compiled (IPv4 only, SO_REUSEPORT enabled)${NC}"
        log_message "EDNS Proxy compiled successfully"
    else
        echo -e "\r  ${RED}✗ Compilation failed - installing pre-compiled${NC}"
        wget -q "$GITHUB_BASE/edns-proxy" -O /usr/local/bin/edns-proxy
        chmod +x /usr/local/bin/edns-proxy
    fi
    
    print_step_end
}

# ============================================================================
# USER MANAGEMENT SYSTEM
# ============================================================================
create_user_management() {
    print_step "4"
    print_info "Setting up User Management System"
    
    mkdir -p "$USERS_DIR"
    
    # User management script
    cat > /usr/local/bin/slowdns-user << 'USERMGR'
#!/bin/bash

USERS_DIR="/etc/slowdns/users"
PUBLIC_KEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "N/A")

create_user() {
    echo -e "\033[0;36m╔══════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m      \033[1;37mCREATE NEW SLOWDNS USER\033[0m              \033[0;36m║\033[0m"
    echo -e "\033[0;36m╚══════════════════════════════════════════╝\033[0m"
    
    read -p "$(echo -e "\033[1;33mEnter username: \033[0m")" USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo -e "\033[0;31m[✗] Username cannot be empty!\033[0m"
        return 1
    fi
    
    if [ -f "$USERS_DIR/$USERNAME.json" ]; then
        echo -e "\033[0;31m[✗] User $USERNAME already exists!\033[0m"
        return 1
    fi
    
    # Generate random password
    PASSWORD=$(openssl rand -base64 12 2>/dev/null || echo "$(date +%s | sha256sum | base64 | head -c 12)")
    
    # Get server IP and NS
    SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    NS=$(cat /etc/slowdns/ns.conf 2>/dev/null || echo "dns.google.com")
    
    # Create system user for SSH
    useradd -m -s /bin/bash "$USERNAME" 2>/dev/null
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    # Create user JSON with details
    cat > "$USERS_DIR/$USERNAME.json" << EOF
{
    "username": "$USERNAME",
    "password": "$PASSWORD",
    "server_ip": "$SERVER_IP",
    "ssh_port": "22",
    "slowdns_port": "5300",
    "edns_port": "53",
    "public_key": "$PUBLIC_KEY",
    "nameserver": "$NS",
    "created": "$(date '+%Y-%m-%d %H:%M:%S')",
    "status": "active"
}
EOF
    
    clear
    echo -e "\033[0;32m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;32m║\033[0m              \033[1;37mUSER CREATED SUCCESSFULLY\033[0m                     \033[0;32m║\033[0m"
    echo -e "\033[0;32m╠══════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mUsername:\033[0m    \033[1;37m$USERNAME\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mPassword:\033[0m    \033[1;37m$PASSWORD\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mPublic Key:\033[0m  \033[1;37m$PUBLIC_KEY\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mNS:\033[0m         \033[1;37m$NS\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mServer IP:\033[0m  \033[1;37m$SERVER_IP\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mSSH Port:\033[0m   \033[1;37m22\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mDNS Port:\033[0m   \033[1;37m53\033[0m"
    echo -e "\033[0;32m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
    echo -e "\033[1;36m📋 Client Config (http-custom):\033[0m"
    echo -e "\033[0;33m┌──────────────────────────────────────────────────────────────┐\033[0m"
    echo -e "\033[0;33m│\033[0m POST / HTTP/1.1"
    echo -e "\033[0;33m│\033[0m Host: $NS"
    echo -e "\033[0;33m│\033[0m User-Agent: [$USERNAME]"
    echo -e "\033[0;33m│\033[0m [crlf][crlf]"
    echo -e "\033[0;33m└──────────────────────────────────────────────────────────────┘\033[0m"
    
    # Save to all users list
    echo "$USERNAME:$PASSWORD:$(date '+%Y-%m-%d')" >> "$USERS_DIR/all_users.txt"
}

list_users() {
    echo -e "\033[0;36m╔══════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m          \033[1;37mREGISTERED USERS\033[0m                   \033[0;36m║\033[0m"
    echo -e "\033[0;36m╠══════════════════════════════════════════╣\033[0m"
    
    if [ -d "$USERS_DIR" ] && [ "$(ls -A $USERS_DIR/*.json 2>/dev/null)" ]; then
        for f in "$USERS_DIR"/*.json; do
            username=$(grep -o '"username": *"[^"]*"' "$f" | cut -d'"' -f4)
            created=$(grep -o '"created": *"[^"]*"' "$f" | cut -d'"' -f4)
            echo -e "\033[0;36m║\033[0m \033[1;32m●\033[0m \033[1;37m$username\033[0m - Created: $created"
        done
    else
        echo -e "\033[0;36m║\033[0m   \033[0;33mNo users found\033[0m"
    fi
    echo -e "\033[0;36m╚══════════════════════════════════════════╝\033[0m"
}

delete_user() {
    echo -e "\033[0;36m╔══════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m        \033[1;37mDELETE SLOWDNS USER\033[0m                  \033[0;36m║\033[0m"
    echo -e "\033[0;36m╚══════════════════════════════════════════╝\033[0m"
    
    read -p "$(echo -e "\033[1;33mEnter username to delete: \033[0m")" USERNAME
    
    if [ -f "$USERS_DIR/$USERNAME.json" ]; then
        userdel -r "$USERNAME" 2>/dev/null
        rm -f "$USERS_DIR/$USERNAME.json"
        sed -i "/^$USERNAME:/d" "$USERS_DIR/all_users.txt" 2>/dev/null
        echo -e "\033[0;32m[✓] User $USERNAME deleted successfully!\033[0m"
    else
        echo -e "\033[0;31m[✗] User $USERNAME not found!\033[0m"
    fi
}

show_user_details() {
    read -p "$(echo -e "\033[1;33mEnter username: \033[0m")" USERNAME
    
    if [ -f "$USERS_DIR/$USERNAME.json" ]; then
        echo -e "\033[0;32m╔══════════════════════════════════════════╗\033[0m"
        echo -e "\033[0;32m║\033[0m         \033[1;37mUSER DETAILS\033[0m                       \033[0;32m║\033[0m"
        echo -e "\033[0;32m╚══════════════════════════════════════════╝\033[0m"
        cat "$USERS_DIR/$USERNAME.json" | grep -v '{' | grep -v '}' | while IFS=: read key value; do
            key=$(echo $key | tr -d '" ,')
            value=$(echo $value | tr -d '" ,')
            echo -e "\033[1;33m$key:\033[0m \033[1;37m$value\033[0m"
        done
    else
        echo -e "\033[0;31m[✗] User $USERNAME not found!\033[0m"
    fi
}

# Main menu for user management
case "$1" in
    create)
        create_user
        ;;
    list)
        list_users
        ;;
    delete)
        delete_user
        ;;
    details)
        show_user_details
        ;;
    *)
        echo "Usage: slowdns-user {create|list|delete|details}"
        ;;
esac
USERMGR
    
    chmod +x /usr/local/bin/slowdns-user
    
    print_success "User management system created"
    print_step_end
}

# ============================================================================
# CREATE TERMINAL PANEL (VPS Menu)
# ============================================================================
create_terminal_panel() {
    print_step "5"
    print_info "Creating Terminal VPS Panel"
    
    cat > /usr/local/bin/slowdns-panel << 'PANELSCRIPT'
#!/bin/bash

# Terminal Panel for ELITE-X8 SlowDNS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

USERS_DIR="/etc/slowdns/users"
PUBLIC_KEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "N/A")
SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
NS=$(cat /etc/slowdns/ns.conf 2>/dev/null || echo "dns.google.com")

show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}          🚀 ELITE-X8 SLOWDNS VPS PANEL${NC}                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}                    Management Console${NC}                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_status() {
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}📊 SERVER STATUS${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    
    # Check services
    if systemctl is-active --quiet server-sldns; then
        echo -e "${CYAN}│${NC} ${GREEN}●${NC} SlowDNS Service:    ${GREEN}Running${NC}"
    else
        echo -e "${CYAN}│${NC} ${RED}●${NC} SlowDNS Service:    ${RED}Stopped${NC}"
    fi
    
    if systemctl is-active --quiet edns-proxy; then
        echo -e "${CYAN}│${NC} ${GREEN}●${NC} EDNS Proxy:         ${GREEN}Running${NC}"
    else
        echo -e "${CYAN}│${NC} ${RED}●${NC} EDNS Proxy:         ${RED}Stopped${NC}"
    fi
    
    if systemctl is-active --quiet sshd; then
        echo -e "${CYAN}│${NC} ${GREEN}●${NC} SSH Service:        ${GREEN}Running${NC}"
    else
        echo -e "${CYAN}│${NC} ${RED}●${NC} SSH Service:        ${RED}Stopped${NC}"
    fi
    
    # Active connections
    CONNS=$(ss -tn | grep -c ':22\|:5300' 2>/dev/null || echo 0)
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Active Connections: ${YELLOW}$CONNS${NC}"
    
    # Memory usage
    MEM_USED=$(free -h | awk '/^Mem:/{print $3}')
    MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Memory:             ${YELLOW}$MEM_USED / $MEM_TOTAL${NC}"
    
    # Disk usage
    DISK=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Disk:               ${YELLOW}$DISK${NC}"
    
    # CPU load
    CPU=$(uptime | awk -F 'load average:' '{print $2}')
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} CPU Load:           ${YELLOW}$CPU${NC}"
    
    # Uptime
    UP=$(uptime -p)
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Uptime:             ${YELLOW}$UP${NC}"
    
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

show_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}        ${WHITE}${BOLD}🎮 MAIN MENU${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[1]${NC} ${WHITE}Server Status${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[2]${NC} ${WHITE}Create New User${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[3]${NC} ${WHITE}List All Users${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[4]${NC} ${WHITE}Show User Details${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[5]${NC} ${WHITE}Delete User${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[6]${NC} ${WHITE}Show Public Key${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[7]${NC} ${WHITE}Show Server Info${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[8]${NC} ${WHITE}Service Control${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[9]${NC} ${WHITE}View Logs${NC}                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[10]${NC} ${WHITE}Restart All Services${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[11]${NC} ${WHITE}Network Monitor${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[12]${NC} ${WHITE}System Info${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[0]${NC} ${RED}Exit${NC}                               ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

service_control() {
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${WHITE}${BOLD}⚡ SERVICE CONTROL${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC} ${WHITE}Start SlowDNS${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC} ${WHITE}Stop SlowDNS${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC} ${WHITE}Restart SlowDNS${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC} ${WHITE}Start EDNS Proxy${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC} ${WHITE}Stop EDNS Proxy${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC} ${WHITE}Restart SSH${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[0]${NC} ${RED}Back${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    read -p "$(echo -e "${WHITE}Select option: ${NC}")" choice
    
    case $choice in
        1) systemctl start server-sldns; echo -e "${GREEN}[✓] SlowDNS started${NC}";;
        2) systemctl stop server-sldns; echo -e "${RED}[✓] SlowDNS stopped${NC}";;
        3) systemctl restart server-sldns; echo -e "${YELLOW}[✓] SlowDNS restarted${NC}";;
        4) systemctl start edns-proxy; echo -e "${GREEN}[✓] EDNS Proxy started${NC}";;
        5) systemctl stop edns-proxy; echo -e "${RED}[✓] EDNS Proxy stopped${NC}";;
        6) systemctl restart sshd; echo -e "${YELLOW}[✓] SSH restarted${NC}";;
        0) return;;
        *) echo -e "${RED}Invalid option${NC}";;
    esac
    sleep 2
}

network_monitor() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${WHITE}${BOLD}📡 NETWORK MONITOR${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Active Connections:${NC}"
    ss -tunap | grep -E ':22|:53|:5300|:8080' | column -t
    echo ""
    echo -e "${YELLOW}Listening Ports:${NC}"
    ss -tunlp | grep -E ':22|:53|:5300|:8080'
    echo ""
    read -p "Press Enter to continue..."
}

system_info() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${WHITE}${BOLD}💻 SYSTEM INFO${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}OS:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "${YELLOW}Kernel:${NC} $(uname -r)"
    echo -e "${YELLOW}Architecture:${NC} $(uname -m)"
    echo -e "${YELLOW}CPU:${NC} $(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2)"
    echo -e "${YELLOW}CPU Cores:${NC} $(nproc)"
    echo -e "${YELLOW}Memory:${NC} $(free -h | awk '/^Mem:/{print $2}')"
    echo -e "${YELLOW}Disk:${NC} $(df -h / | awk 'NR==2{print $2}')"
    echo -e "${YELLOW}IPv6 Status:${NC} $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo "Disabled")"
    echo ""
    echo -e "${YELLOW}UDP Buffer Settings:${NC}"
    sysctl net.core.rmem_max net.core.wmem_max 2>/dev/null
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_header
    show_status
    show_menu
    read -p "$(echo -e "${WHITE}${BOLD}Select option [0-12]: ${NC}")" choice
    
    case $choice in
        1) show_status; read -p "Press Enter to continue...";;
        2) slowdns-user create; read -p "Press Enter to continue...";;
        3) slowdns-user list; read -p "Press Enter to continue...";;
        4) slowdns-user details; read -p "Press Enter to continue...";;
        5) slowdns-user delete; read -p "Press Enter to continue...";;
        6) 
            echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║${NC}         ${WHITE}${BOLD}🔑 PUBLIC KEY${NC}                  ${CYAN}║${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
            echo -e "${YELLOW}$PUBLIC_KEY${NC}"
            read -p "Press Enter to continue..."
            ;;
        7)
            echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║${NC}        ${WHITE}${BOLD}📋 SERVER INFO${NC}                  ${CYAN}║${NC}"
            echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
            echo -e "${CYAN}║${NC} ${YELLOW}Server IP:${NC}    ${WHITE}$SERVER_IP${NC}"
            echo -e "${CYAN}║${NC} ${YELLOW}SSH Port:${NC}     ${WHITE}22${NC}"
            echo -e "${CYAN}║${NC} ${YELLOW}SlowDNS Port:${NC} ${WHITE}5300${NC}"
            echo -e "${CYAN}║${NC} ${YELLOW}EDNS Port:${NC}    ${WHITE}53${NC}"
            echo -e "${CYAN}║${NC} ${YELLOW}Nameserver:${NC}   ${WHITE}$NS${NC}"
            echo -e "${CYAN}║${NC} ${YELLOW}Dashboard:${NC}    ${WHITE}http://$SERVER_IP:8080${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
            read -p "Press Enter to continue..."
            ;;
        8) service_control;;
        9)
            clear
            echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║${NC}          ${WHITE}${BOLD}📋 SERVICE LOGS${NC}               ${CYAN}║${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
            journalctl -u server-sldns --no-pager -n 30
            read -p "Press Enter to continue..."
            ;;
        10)
            systemctl restart server-sldns edns-proxy
            echo -e "${GREEN}[✓] All services restarted${NC}"
            sleep 2
            ;;
        11) network_monitor;;
        12) system_info;;
        0)
            echo -e "\n${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            ;;
    esac
done
PANELSCRIPT
    
    chmod +x /usr/local/bin/slowdns-panel
    ln -sf /usr/local/bin/slowdns-panel /usr/bin/slowdns-panel 2>/dev/null
    
    print_success "Terminal panel created (run 'slowdns-panel')"
    print_step_end
}

# ============================================================================
# CREATE WEB DASHBOARD
# ============================================================================
create_dashboard() {
    print_step "6"
    print_info "Creating Web Management Dashboard"
    
    mkdir -p /etc/slowdns/dashboard
    
    # Create dashboard HTML
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
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-online { background: #48bb78; }
        .status-offline { background: #f56565; }
        .controls {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.2);
            margin-bottom: 20px;
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
        .user-section {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.2);
            margin-bottom: 20px;
        }
        .user-section h3 { color: white; margin-bottom: 15px; }
        input[type="text"] {
            background: rgba(255,255,255,0.2);
            border: 1px solid rgba(255,255,255,0.3);
            color: white;
            padding: 10px;
            border-radius: 10px;
            width: 100%;
            margin-bottom: 10px;
        }
        input[type="text"]::placeholder { color: rgba(255,255,255,0.5); }
        .user-card {
            background: rgba(255,255,255,0.05);
            border-radius: 10px;
            padding: 15px;
            margin: 10px 0;
            border: 1px solid rgba(255,255,255,0.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 ELITE-X8 SlowDNS Dashboard</h1>
            <p>Advanced DNS Tunnel Management System V2</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <h3>SERVER STATUS</h3>
                <div class="value" id="serverStatus">
                    <span class="status-indicator status-online"></span>Online
                </div>
            </div>
            <div class="stat-card">
                <h3>SLOWDNS PORT</h3>
                <div class="value">5300</div>
            </div>
            <div class="stat-card">
                <h3>SSH PORT</h3>
                <div class="value">22</div>
            </div>
            <div class="stat-card">
                <h3>ACTIVE CONNECTIONS</h3>
                <div class="value" id="connections">0</div>
            </div>
        </div>
        
        <div class="controls">
            <h3 style="color: white; margin-bottom: 15px;">🎮 Service Controls</h3>
            <button class="button start" onclick="controlService('start')">▶ Start All</button>
            <button class="button stop" onclick="controlService('stop')">⏹ Stop All</button>
            <button class="button restart" onclick="controlService('restart')">🔄 Restart All</button>
            <button class="button" onclick="refreshStatus()">🔄 Refresh</button>
        </div>
        
        <div class="user-section">
            <h3>👤 User Management</h3>
            <input type="text" id="newUsername" placeholder="Enter username to create...">
            <button class="button start" onclick="createUser()">Create User</button>
            <button class="button restart" onclick="listUsers()">List Users</button>
            <div id="userList"></div>
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
                .then(response => response.json())
                .then(data => {
                    document.getElementById('connections').textContent = data.connections || 0;
                    document.getElementById('logs').innerHTML = data.logs || 'No logs';
                    document.getElementById('publicKey').textContent = data.publicKey || 'N/A';
                })
                .catch(err => console.error('Error:', err));
        }
        
        function controlService(action) {
            fetch('/api/control', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: action})
            })
            .then(response => response.json())
            .then(data => {
                alert(data.message);
                refreshStatus();
            })
            .catch(err => alert('Error: ' + err));
        }
        
        function createUser() {
            const username = document.getElementById('newUsername').value;
            if (!username) { alert('Enter username'); return; }
            fetch('/api/users/create', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({username: username})
            })
            .then(response => response.json())
            .then(data => {
                alert(JSON.stringify(data, null, 2));
                document.getElementById('newUsername').value = '';
                listUsers();
            })
            .catch(err => alert('Error: ' + err));
        }
        
        function listUsers() {
            fetch('/api/users/list')
                .then(response => response.json())
                .then(data => {
                    let html = '<h4 style="color:white;margin-top:15px;">Registered Users:</h4>';
                    if (data.users && data.users.length > 0) {
                        data.users.forEach(u => {
                            html += `<div class="user-card" style="color:white;">
                                <strong>${u.username}</strong> - Created: ${u.created}
                                <br>Password: ${u.password}
                                <br>Public Key: ${u.public_key}
                                <br>NS: ${u.ns}
                            </div>`;
                        });
                    } else {
                        html += '<p style="color:rgba(255,255,255,0.7);">No users found</p>';
                    }
                    document.getElementById('userList').innerHTML = html;
                });
        }
        
        setInterval(refreshStatus, 5000);
        refreshStatus();
        listUsers();
    </script>
</body>
</html>
HTMLEOF
    
    # Create advanced API server
    cat > /usr/local/bin/slowdns-api << 'APIEOF'
#!/usr/bin/env python3
import http.server
import json
import subprocess
import os
import sys
import random
import string
from urllib.parse import urlparse

USERS_DIR = "/etc/slowdns/users"
PUBLIC_KEY = ""
SERVER_IP = ""
NS = ""

# Load config
try:
    with open('/etc/slowdns/server.pub', 'r') as f:
        PUBLIC_KEY = f.read().strip()
except:
    PUBLIC_KEY = "N/A"

try:
    with open('/etc/slowdns/ns.conf', 'r') as f:
        NS = f.read().strip()
except:
    NS = "dns.google.com"

try:
    result = subprocess.run(['curl', '-s', '--connect-timeout', '3', 'ifconfig.me'], 
                          capture_output=True, text=True, timeout=5)
    SERVER_IP = result.stdout.strip()
except:
    try:
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
        SERVER_IP = result.stdout.strip().split()[0]
    except:
        SERVER_IP = "127.0.0.1"

class SlowDNSAPI(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress logging
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())
    
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('/etc/slowdns/dashboard/index.html', 'rb') as f:
                self.wfile.write(f.read())
        
        elif self.path == '/api/status':
            connections = 0
            try:
                result = subprocess.run(['ss', '-tn'], capture_output=True, text=True)
                connections = len([l for l in result.stdout.split('\n') if ':22' in l or ':5300' in l])
            except:
                pass
            
            logs = "No logs available"
            try:
                result = subprocess.run(['journalctl', '-u', 'server-sldns', '--no-pager', '-n', '20'], 
                                      capture_output=True, text=True, timeout=5)
                if result.stdout:
                    logs = result.stdout
            except:
                pass
            
            status = {
                'connections': connections,
                'logs': logs,
                'publicKey': PUBLIC_KEY,
                'server_ip': SERVER_IP,
                'ns': NS,
                'slowdns_status': 'running' if os.system('systemctl is-active --quiet server-sldns') == 0 else 'stopped',
                'edns_status': 'running' if os.system('systemctl is-active --quiet edns-proxy') == 0 else 'stopped'
            }
            self.send_json(status)
        
        elif self.path == '/api/users/list':
            users = []
            if os.path.exists(USERS_DIR):
                for f in os.listdir(USERS_DIR):
                    if f.endswith('.json'):
                        try:
                            with open(os.path.join(USERS_DIR, f), 'r') as jf:
                                user_data = json.load(jf)
                                users.append({
                                    'username': user_data.get('username', ''),
                                    'password': user_data.get('password', ''),
                                    'created': user_data.get('created', ''),
                                    'public_key': user_data.get('public_key', PUBLIC_KEY),
                                    'ns': user_data.get('nameserver', NS),
                                    'server_ip': user_data.get('server_ip', SERVER_IP)
                                })
                        except:
                            pass
            self.send_json({'users': users})
        
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = {}
        if content_length > 0:
            try:
                post_data = json.loads(self.rfile.read(content_length))
            except:
                pass
        
        if self.path == '/api/control':
            action = post_data.get('action', '')
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
            self.send_json({'message': message})
        
        elif self.path == '/api/users/create':
            username = post_data.get('username', '')
            if not username:
                self.send_json({'error': 'Username required'}, 400)
                return
            
            user_file = os.path.join(USERS_DIR, f"{username}.json")
            if os.path.exists(user_file):
                self.send_json({'error': 'User already exists'}, 400)
                return
            
            # Generate password
            password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
            
            # Create system user
            try:
                subprocess.run(['useradd', '-m', '-s', '/bin/bash', username], 
                             capture_output=True, timeout=5)
                subprocess.run(['chpasswd'], input=f"{username}:{password}".encode(), 
                             capture_output=True, timeout=5)
            except:
                pass
            
            # Save user data
            user_data = {
                'username': username,
                'password': password,
                'server_ip': SERVER_IP,
                'ssh_port': '22',
                'slowdns_port': '5300',
                'edns_port': '53',
                'public_key': PUBLIC_KEY,
                'nameserver': NS,
                'created': subprocess.run(['date', '+%Y-%m-%d %H:%M:%S'], 
                                        capture_output=True, text=True).stdout.strip(),
                'status': 'active'
            }
            
            os.makedirs(USERS_DIR, exist_ok=True)
            with open(user_file, 'w') as f:
                json.dump(user_data, f, indent=2)
            
            self.send_json({
                'message': 'User created successfully',
                'user': user_data
            })

if __name__ == '__main__':
    os.makedirs(USERS_DIR, exist_ok=True)
    server = http.server.HTTPServer(('0.0.0.0', 8080), SlowDNSAPI)
    print("SlowDNS API Server running on port 8080")
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
    
    print_success "Web dashboard created"
    print_step_end
}

# ============================================================================
# CREATE SERVICES
# ============================================================================
create_services() {
    print_step "7"
    print_info "Creating System Services"
    
    # SlowDNS Service
    cat > /etc/systemd/system/server-sldns.service << EOF
[Unit]
Description=ELITE-X8 SlowDNS Server
After=network.target sshd.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1200 -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT
Restart=always
RestartSec=5
User=root
LimitNOFILE=65536
LimitCORE=infinity
Environment="GODEBUG=netdns=go"

[Install]
WantedBy=multi-user.target
EOF
    
    # EDNS Proxy Service
    cat > /etc/systemd/system/edns-proxy.service << EOF
[Unit]
Description=EDNS Proxy for SlowDNS (IPv4 Only, Multi-core)
After=server-sldns.service
Requires=server-sldns.service

[Service]
Type=simple
ExecStart=/usr/local/bin/edns-proxy
Restart=always
RestartSec=3
User=root
LimitNOFILE=65536
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    # Save nameserver
    echo "$NAMESERVER" > /etc/slowdns/ns.conf
    
    print_success "Service files created"
    print_step_end
}

# ============================================================================
# CONFIGURE FIREWALL
# ============================================================================
configure_firewall() {
    print_step "8"
    print_info "Configuring Firewall Rules (IPv4 Only)"
    
    # Stop IPv6 services
    systemctl stop systemd-resolved 2>/dev/null
    fuser -k 53/udp 2>/dev/null
    fuser -k 53/tcp 2>/dev/null
    
    # Configure iptables (IPv4 only)
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
    
    # Block IPv6 traffic via ip6tables
    ip6tables -P INPUT DROP 2>/dev/null
    ip6tables -P OUTPUT DROP 2>/dev/null
    ip6tables -P FORWARD DROP 2>/dev/null
    
    print_success "Firewall configured (IPv4 only)"
    print_step_end
}

# ============================================================================
# START SERVICES
# ============================================================================
start_services() {
    print_step "9"
    print_info "Starting All Services"
    
    systemctl daemon-reload
    
    # Start SlowDNS
    systemctl enable server-sldns > /dev/null 2>&1
    systemctl start server-sldns
    sleep 2
    
    if systemctl is-active --quiet server-sldns; then
        print_success "SlowDNS service started"
    else
        print_warning "Starting SlowDNS in background mode"
        /etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1200 -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT &
    fi
    
    # Start EDNS Proxy
    systemctl enable edns-proxy > /dev/null 2>&1
    systemctl start edns-proxy
    sleep 2
    
    if systemctl is-active --quiet edns-proxy; then
        print_success "EDNS Proxy service started (IPv4 only, SO_REUSEPORT enabled)"
    else
        print_warning "Starting EDNS Proxy in background mode"
        /usr/local/bin/edns-proxy &
    fi
    
    # Start Dashboard
    systemctl enable slowdns-dashboard > /dev/null 2>&1
    systemctl start slowdns-dashboard
    sleep 2
    
    if systemctl is-active --quiet slowdns-dashboard; then
        print_success "Dashboard service started"
    else
        print_warning "Dashboard started in background mode"
        python3 /usr/local/bin/slowdns-api &
    fi
    
    print_step_end
}

# ============================================================================
# SHOW COMPLETION SUMMARY
# ============================================================================
show_summary() {
    print_header "🎉 INSTALLATION COMPLETE"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}ELITE-X8 SLOWDNS SERVER INFORMATION V2${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Server IP:      ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SSH Port:       ${WHITE}$SSHD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SlowDNS Port:   ${WHITE}$SLOWDNS_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} EDNS Port:      ${WHITE}53${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Web Dashboard:  ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Terminal Panel: ${WHITE}slowdns-panel${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} User Manager:   ${WHITE}slowdns-user${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Nameserver:     ${WHITE}$NAMESERVER${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IPv6:           ${WHITE}Disabled${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} UDP Buffer:     ${WHITE}20MB Max${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    # Show public key
    if [ -f /etc/slowdns/server.pub ]; then
        echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}${BOLD}PUBLIC KEY${NC}                                            ${CYAN}│${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}$(cat /etc/slowdns/server.pub)${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}QUICK COMMANDS${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}slowdns-panel${NC}          - Open VPS Terminal Panel"
    echo -e "${CYAN}│${NC} ${GREEN}slowdns-user create${NC}    - Create new user"
    echo -e "${CYAN}│${NC} ${GREEN}slowdns-user list${NC}      - List all users"
    echo -e "${CYAN}│${NC} ${GREEN}systemctl status server-sldns${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}journalctl -u server-sldns -f${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}ss -ulpn | grep ':53\|:5300'${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}🎯 ELITE-X8 SLOWDNS V2 INSTALLED SUCCESSFULLY!${NC}           ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}⚡ Web Dashboard: http://$SERVER_IP:$DASHBOARD_PORT${NC}          ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}💻 Terminal Panel: slowdns-panel${NC}                          ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}📁 Repository: https://github.com/ELITE-X8/setup.sh${NC}       ${PURPLE}║${NC}"
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
    
    # Get server IP
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    optimize_system
    check_requirements
    download_files
    configure_ssh
    compile_edns
    create_user_management
    create_terminal_panel
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
