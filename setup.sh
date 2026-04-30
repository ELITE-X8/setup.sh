#!/bin/bash

# ============================================================================
#                     SLOWDNS MODERN INSTALLATION SCRIPT
#                          ELITE-X8 EDITION V3
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
USERS_DIR="/etc/slowdns/users"
GITHUB_BASE="https://raw.githubusercontent.com/ELITE-X8/setup.sh/main"
LOG_FILE="/var/log/slowdns-install.log"
BANDWIDTH_DIR="/etc/slowdns/bandwidth"

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
# UTILITY FUNCTIONS
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
    echo -e "${PURPLE}║${NC}${CYAN}          🚀 ELITE-X8 SLOWDNS MODERN INSTALLATION SCRIPT${NC}       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}            Fast & Professional Configuration V3${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${YELLOW}                Optimized for Maximum Performance${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${GREEN}               Complete Management Suite${NC}                       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_header() {
    echo -e "\n${PURPLE}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════${NC}"
}

print_success() { echo -e "  ${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"; }
print_error() { echo -e "  ${RED}${BOLD}✗${NC} ${RED}$1${NC}"; }
print_warning() { echo -e "  ${YELLOW}${BOLD}!${NC} ${YELLOW}$1${NC}"; }
print_info() { echo -e "  ${CYAN}${BOLD}ℹ${NC} ${CYAN}$1${NC}"; }

# ============================================================================
# SYSTEM OPTIMIZATION
# ============================================================================
optimize_system() {
    print_step "0"
    print_info "Applying System Optimizations"
    
    cat > /etc/sysctl.d/99-slowdns-optimize.conf << EOF
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.core.rmem_default = 20971520
net.core.wmem_default = 20971520
net.ipv4.udp_mem = 20971520 20971520 20971520
net.ipv4.udp_rmem_min = 20971520
net.ipv4.udp_wmem_min = 20971520
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    sysctl -p /etc/sysctl.d/99-slowdns-optimize.conf >/dev/null 2>&1
    
    if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
    fi
    
    if [ -f /etc/default/grub ]; then
        if ! grep -q "ipv6.disable=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/' /etc/default/grub
            update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
        fi
    fi
    
    systemctl disable --now systemd-resolved 2>/dev/null
    systemctl stop systemd-resolved 2>/dev/null
    sed -i '/^::1/s/^/#/' /etc/hosts 2>/dev/null
    
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
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        print_success "OS: $OS $VER"
    else
        print_error "Cannot detect OS"
        exit 1
    fi
    
    ARCH=$(uname -m)
    print_success "Architecture: $ARCH"
    
    MEM=$(free -m | awk '/^Mem:/{print $2}')
    print_success "Memory: ${MEM}MB"
    
    DISK=$(df -h / | awk 'NR==2{print $4}')
    print_success "Available Disk: $DISK"
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet: Connected"
    else
        print_error "No internet connection"
        exit 1
    fi
    
    CPU_CORES=$(nproc)
    print_success "CPU Cores: $CPU_CORES"
}

# ============================================================================
# DOWNLOAD FILES
# ============================================================================
download_files() {
    print_step "1"
    print_info "Downloading files from Repository"
    
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    
    echo -ne "  ${CYAN}Downloading dnstt-server...${NC}"
    if wget -q "$GITHUB_BASE/dnstt-server" -O dnstt-server 2>/dev/null; then
        chmod +x dnstt-server
        echo -e "\r  ${GREEN}✓ dnstt-server downloaded${NC}"
    else
        echo -e "\r  ${RED}✗ Failed${NC}"
        exit 1
    fi
    
    echo -ne "  ${CYAN}Downloading server.key...${NC}"
    if wget -q "$GITHUB_BASE/server.key" -O server.key 2>/dev/null; then
        chmod 600 server.key
        echo -e "\r  ${GREEN}✓ server.key downloaded${NC}"
    else
        echo -e "\r  ${RED}✗ Failed${NC}"
        exit 1
    fi
    
    echo -ne "  ${CYAN}Downloading server.pub...${NC}"
    if wget -q "$GITHUB_BASE/server.pub" -O server.pub 2>/dev/null; then
        chmod 644 server.pub
        echo -e "\r  ${GREEN}✓ server.pub downloaded${NC}"
    else
        echo -e "\r  ${RED}✗ Failed${NC}"
        exit 1
    fi
    
    print_success "All files downloaded"
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
    fi
    print_step_end
}

# ============================================================================
# COMPILE EDNS PROXY
# ============================================================================
compile_edns() {
    print_step "3"
    print_info "Compiling EDNS Proxy (Multi-core + IPv4 only)"
    
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

    sock=socket(AF_INET,SOCK_DGRAM,0);
    fcntl(sock,F_SETFL,O_NONBLOCK);
    int reuse=1;
    setsockopt(sock,SOL_SOCKET,SO_REUSEADDR,&reuse,sizeof(reuse));
    setsockopt(sock,SOL_SOCKET,SO_REUSEPORT,&reuse,sizeof(reuse));

    struct sockaddr_in a={0};
    a.sin_family=AF_INET; a.sin_port=htons(LISTEN_PORT);
    a.sin_addr.s_addr=INADDR_ANY;
    bind(sock,(void*)&a,sizeof(a));

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
    
    gcc -O3 -march=native -pipe -pthread /tmp/edns.c -o /usr/local/bin/edns-proxy 2>/dev/null
    
    if [ $? -eq 0 ]; then
        chmod +x /usr/local/bin/edns-proxy
        print_success "EDNS Proxy compiled (IPv4 only, SO_REUSEPORT enabled)"
    else
        print_warning "Compilation failed - installing pre-compiled"
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
    mkdir -p "$BANDWIDTH_DIR"
    
    # User management script
    cat > /usr/local/bin/slowdns-user << 'USERMGR'
#!/bin/bash

USERS_DIR="/etc/slowdns/users"
BANDWIDTH_DIR="/etc/slowdns/bandwidth"
PUBLIC_KEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "N/A")
NS=$(cat /etc/slowdns/ns.conf 2>/dev/null || echo "dns.google.com")
SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

generate_password() {
    openssl rand -base64 12 2>/dev/null || echo "$(date +%s | sha256sum | base64 | head -c 12)"
}

create_user() {
    echo -e "\033[0;36m╔══════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m      \033[1;37mCREATE NEW SLOWDNS USER\033[0m              \033[0;36m║\033[0m"
    echo -e "\033[0;36m╚══════════════════════════════════════════╝\033[0m"
    
    read -p "$(echo -e "\033[1;33mEnter username: \033[0m")" USERNAME
    read -p "$(echo -e "\033[1;33mExpire days (0=unlimited): \033[0m")" EXPIRE_DAYS
    
    if [ -z "$USERNAME" ]; then
        echo -e "\033[0;31m[✗] Username cannot be empty!\033[0m"
        return 1
    fi
    
    EXPIRE_DAYS=${EXPIRE_DAYS:-30}
    
    if [ -f "$USERS_DIR/$USERNAME.json" ]; then
        echo -e "\033[0;31m[✗] User $USERNAME already exists!\033[0m"
        return 1
    fi
    
    PASSWORD=$(generate_password)
    
    # Calculate expire date
    if [ "$EXPIRE_DAYS" -eq 0 ]; then
        EXPIRE_DATE="unlimited"
    else
        EXPIRE_DATE=$(date -d "+$EXPIRE_DAYS days" '+%Y-%m-%d' 2>/dev/null || date -v+${EXPIRE_DAYS}d '+%Y-%m-%d' 2>/dev/null)
    fi
    
    # Create system user
    useradd -m -s /bin/bash "$USERNAME" 2>/dev/null
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    # Initialize bandwidth tracking
    echo "0" > "$BANDWIDTH_DIR/${USERNAME}.txt"
    
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
    "expire_date": "$EXPIRE_DATE",
    "status": "active",
    "connections": 0
}
EOF
    
    clear
    echo -e "\033[0;32m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;32m║\033[0m              \033[1;37mUSER CREATED SUCCESSFULLY\033[0m                     \033[0;32m║\033[0m"
    echo -e "\033[0;32m╠══════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mUsername:\033[0m    \033[1;37m$USERNAME\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mPassword:\033[0m    \033[1;37m$PASSWORD\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mExpire Date:\033[0m \033[1;37m$EXPIRE_DATE\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mPublic Key:\033[0m  \033[1;37m$PUBLIC_KEY\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mNS:\033[0m         \033[1;37m$NS\033[0m"
    echo -e "\033[0;32m║\033[0m \033[1;33mServer IP:\033[0m  \033[1;37m$SERVER_IP\033[0m"
    echo -e "\033[0;32m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
    echo -e "\033[1;36m📋 Client Config (http-custom):\033[0m"
    echo -e "\033[0;33mHost: $NS\033[0m"
    echo -e "\033[0;33mUser-Agent: [$USERNAME]\033[0m"
}

renew_user() {
    echo -e "\033[0;36m╔══════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m        \033[1;37mRENEW SLOWDNS USER\033[0m                  \033[0;36m║\033[0m"
    echo -e "\033[0;36m╚══════════════════════════════════════════╝\033[0m"
    
    read -p "$(echo -e "\033[1;33mEnter username: \033[0m")" USERNAME
    read -p "$(echo -e "\033[1;33mAdd days: \033[0m")" ADD_DAYS
    
    if [ ! -f "$USERS_DIR/$USERNAME.json" ]; then
        echo -e "\033[0;31m[✗] User not found!\033[0m"
        return 1
    fi
    
    ADD_DAYS=${ADD_DAYS:-30}
    NEW_EXPIRE=$(date -d "+$ADD_DAYS days" '+%Y-%m-%d' 2>/dev/null || date -v+${ADD_DAYS}d '+%Y-%m-%d' 2>/dev/null)
    
    # Update JSON
    python3 -c "
import json
with open('$USERS_DIR/$USERNAME.json', 'r') as f:
    data = json.load(f)
data['expire_date'] = '$NEW_EXPIRE'
data['status'] = 'active'
with open('$USERS_DIR/$USERNAME.json', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || {
        sed -i "s/\"expire_date\": \"[^\"]*\"/\"expire_date\": \"$NEW_EXPIRE\"/" "$USERS_DIR/$USERNAME.json"
        sed -i 's/"status": "[^"]*"/"status": "active"/' "$USERS_DIR/$USERNAME.json"
    }
    
    echo -e "\033[0;32m[✓] User $USERNAME renewed until $NEW_EXPIRE\033[0m"
}

list_users() {
    echo -e "\033[0;36m╔══════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m                    \033[1;37mREGISTERED USERS\033[0m                           \033[0;36m║\033[0m"
    echo -e "\033[0;36m╠══════════════════════════════════════════════════════════════════╣\033[0m"
    
    if [ -d "$USERS_DIR" ] && [ "$(ls -A $USERS_DIR/*.json 2>/dev/null)" ]; then
        printf "\033[0;36m║\033[0m \033[1;37m%-15s %-15s %-12s %-15s %-10s\033[0m \033[0;36m║\033[0m\n" "Username" "Password" "Expire" "Connections" "Usage"
        echo -e "\033[0;36m╠══════════════════════════════════════════════════════════════════╣\033[0m"
        for f in "$USERS_DIR"/*.json; do
            username=$(grep -o '"username": *"[^"]*"' "$f" | cut -d'"' -f4)
            password=$(grep -o '"password": *"[^"]*"' "$f" | cut -d'"' -f4)
            expire=$(grep -o '"expire_date": *"[^"]*"' "$f" | cut -d'"' -f4)
            
            # Get connection count for user
            conns=$(ss -tn | grep -c "$username" 2>/dev/null || echo 0)
            
            # Get bandwidth usage
            if [ -f "$BANDWIDTH_DIR/${username}.txt" ]; then
                bytes=$(cat "$BANDWIDTH_DIR/${username}.txt" 2>/dev/null || echo 0)
                usage=$(awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}")
            else
                usage="0.00 GB"
            fi
            
            printf "\033[0;36m║\033[0m \033[1;33m%-15s\033[0m \033[1;37m%-15s\033[0m \033[1;32m%-12s\033[0m \033[1;36m%-15s\033[0m \033[1;35m%-10s\033[0m \033[0;36m║\033[0m\n" \
                "$username" "$password" "$expire" "$conns" "$usage"
        done
    else
        echo -e "\033[0;36m║\033[0m   \033[0;33mNo users found\033[0m                                                \033[0;36m║\033[0m"
    fi
    echo -e "\033[0;36m╚══════════════════════════════════════════════════════════════════╝\033[0m"
}

delete_user() {
    echo -e "\033[0;36m╔══════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m        \033[1;37mDELETE SLOWDNS USER\033[0m                  \033[0;36m║\033[0m"
    echo -e "\033[0;36m╚══════════════════════════════════════════╝\033[0m"
    
    read -p "$(echo -e "\033[1;33mEnter username to delete: \033[0m")" USERNAME
    
    if [ -f "$USERS_DIR/$USERNAME.json" ]; then
        userdel -r "$USERNAME" 2>/dev/null
        rm -f "$USERS_DIR/$USERNAME.json"
        rm -f "$BANDWIDTH_DIR/${USERNAME}.txt"
        echo -e "\033[0;32m[✓] User $USERNAME deleted successfully!\033[0m"
    else
        echo -e "\033[0;31m[✗] User $USERNAME not found!\033[0m"
    fi
}

show_user_details() {
    read -p "$(echo -e "\033[1;33mEnter username: \033[0m")" USERNAME
    
    if [ -f "$USERS_DIR/$USERNAME.json" ]; then
        conns=$(ss -tn | grep -c "$USERNAME" 2>/dev/null || echo 0)
        if [ -f "$BANDWIDTH_DIR/${USERNAME}.txt" ]; then
            bytes=$(cat "$BANDWIDTH_DIR/${USERNAME}.txt" 2>/dev/null || echo 0)
            usage=$(awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}")
        else
            usage="0.00 GB"
        fi
        
        echo -e "\033[0;32m╔══════════════════════════════════════════╗\033[0m"
        echo -e "\033[0;32m║\033[0m         \033[1;37mUSER DETAILS\033[0m                       \033[0;32m║\033[0m"
        echo -e "\033[0;32m╠══════════════════════════════════════════╣\033[0m"
        cat "$USERS_DIR/$USERNAME.json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k,v in d.items():
    print(f'\033[1;33m{k}:\033[0m \033[1;37m{v}\033[0m')
" 2>/dev/null || cat "$USERS_DIR/$USERNAME.json"
        echo -e "\033[1;33mconnections:\033[0m \033[1;37m$conns\033[0m"
        echo -e "\033[1;33musage:\033[0m \033[1;37m$usage\033[0m"
        echo -e "\033[0;32m╚══════════════════════════════════════════╝\033[0m"
    else
        echo -e "\033[0;31m[✗] User $USERNAME not found!\033[0m"
    fi
}

case "$1" in
    create) create_user ;;
    list) list_users ;;
    delete) delete_user ;;
    details) show_user_details ;;
    renew) renew_user ;;
    *)
        echo "Usage: slowdns-user {create|list|delete|details|renew}"
        ;;
esac
USERMGR
    
    chmod +x /usr/local/bin/slowdns-user
    
    # Bandwidth monitoring script (runs as cron)
    cat > /usr/local/bin/slowdns-bandwidth << 'BWSCRIPT'
#!/bin/bash
BANDWIDTH_DIR="/etc/slowdns/bandwidth"
USERS_DIR="/etc/slowdns/users"
INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+' | head -1)

# Get current RX bytes
if [ -f /sys/class/net/$INTERFACE/statistics/rx_bytes ]; then
    CURRENT_RX=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
else
    CURRENT_RX=0
fi

# Update bandwidth for active users
for f in "$USERS_DIR"/*.json; do
    if [ -f "$f" ]; then
        username=$(grep -o '"username": *"[^"]*"' "$f" | cut -d'"' -f4)
        if [ -n "$username" ]; then
            # Check if user has active SSH connection
            conns=$(ss -tn | grep -c ":$username" 2>/dev/null || echo 0)
            if [ "$conns" -gt 0 ]; then
                # Add bandwidth (approximate based on interface)
                BW_FILE="$BANDWIDTH_DIR/${username}.txt"
                if [ -f "$BW_FILE" ]; then
                    PREV=$(cat "$BW_FILE")
                else
                    PREV=0
                fi
                # Estimate per-user bandwidth (divide by active connections)
                TOTAL_CONNS=$(ss -tn | grep -c ':22\|:5300' 2>/dev/null || echo 1)
                [ "$TOTAL_CONNS" -eq 0 ] && TOTAL_CONNS=1
                PER_USER=$(( (CURRENT_RX - PREV) / TOTAL_CONNS ))
                echo "$(( PREV + PER_USER ))" > "$BW_FILE"
            fi
        fi
    fi
done
BWSCRIPT
    chmod +x /usr/local/bin/slowdns-bandwidth
    
    # Add cron job for bandwidth monitoring every minute
    (crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/slowdns-bandwidth") | crontab -
    
    print_success "User management system created"
    print_step_end
}

# ============================================================================
# CREATE TERMINAL PANEL
# ============================================================================
create_terminal_panel() {
    print_step "5"
    print_info "Creating Terminal VPS Panel"
    
    cat > /usr/local/bin/slowdns-panel << 'PANELSCRIPT'
#!/bin/bash

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
BANDWIDTH_DIR="/etc/slowdns/bandwidth"
PUBLIC_KEY=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "N/A")
SERVER_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
NS=$(cat /etc/slowdns/ns.conf 2>/dev/null || echo "dns.google.com")
MTU=$(cat /etc/slowdns/mtu.conf 2>/dev/null || echo "1200")
BANNER_FILE="/etc/slowdns/banner.txt"

show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}          🚀 ELITE-X8 SLOWDNS VPS PANEL V3${NC}                ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}${WHITE}                    Management Console${NC}                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_status() {
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}📊 SYSTEM STATUS${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    
    # Services
    systemctl is-active --quiet server-sldns && echo -e "${CYAN}│${NC} ${GREEN}●${NC} SlowDNS: ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} SlowDNS: ${RED}Stopped${NC}"
    systemctl is-active --quiet edns-proxy && echo -e "${CYAN}│${NC} ${GREEN}●${NC} EDNS Proxy: ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} EDNS Proxy: ${RED}Stopped${NC}"
    systemctl is-active --quiet sshd && echo -e "${CYAN}│${NC} ${GREEN}●${NC} SSH: ${GREEN}Running${NC}" || echo -e "${CYAN}│${NC} ${RED}●${NC} SSH: ${RED}Stopped${NC}"
    
    # Resources
    CPU_LOAD=$(uptime | awk -F 'load average:' '{print $2}' | xargs)
    RAM_USED=$(free -h | awk '/^Mem:/{print $3}')
    RAM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
    DISK=$(df -h / | awk 'NR==2{printf "%s / %s", $3, $2}')
    DISK_PERCENT=$(df -h / | awk 'NR==2{print $5}')
    UP=$(uptime -p | sed 's/up //')
    
    CONNS=$(ss -tn | grep -c ':22\|:5300' 2>/dev/null || echo 0)
    
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} CPU Load:    ${YELLOW}$CPU_LOAD${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} RAM:         ${YELLOW}$RAM_USED / $RAM_TOTAL${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Disk:        ${YELLOW}$DISK ($DISK_PERCENT)${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Uptime:      ${YELLOW}$UP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Connections: ${YELLOW}$CONNS${NC}"
    
    # Total bandwidth
    TOTAL_BW=0
    for f in "$BANDWIDTH_DIR"/*.txt; do
        [ -f "$f" ] && TOTAL_BW=$(( TOTAL_BW + $(cat "$f" 2>/dev/null || echo 0) ))
    done
    TOTAL_GB=$(awk "BEGIN {printf \"%.2f GB\", $TOTAL_BW/1073741824}")
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Total Usage: ${YELLOW}$TOTAL_GB${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} MTU:         ${YELLOW}$MTU${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} NS:          ${YELLOW}$NS${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

show_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}        ${WHITE}${BOLD}🎮 MAIN MENU${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[1]${NC} ${WHITE}Server Status${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[2]${NC} ${WHITE}Create User${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[3]${NC} ${WHITE}List Users${NC}                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[4]${NC} ${WHITE}User Details${NC}                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[5]${NC} ${WHITE}Renew User${NC}                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[6]${NC} ${WHITE}Delete User${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[7]${NC} ${WHITE}Service Control${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[8]${NC} ${WHITE}Change MTU${NC}                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[9]${NC} ${WHITE}Edit Banner${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[10]${NC} ${WHITE}Reboot Server${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[11]${NC} ${WHITE}View Logs${NC}                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[12]${NC} ${WHITE}Network Monitor${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}[0]${NC} ${RED}Exit${NC}                               ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

service_control() {
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${WHITE}${BOLD}⚡ SERVICE CONTROL${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC} ${WHITE}Start All${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC} ${WHITE}Stop All${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC} ${WHITE}Restart All${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC} ${WHITE}Restart SSH${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[0]${NC} ${RED}Back${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    read -p "Select: " choice
    
    case $choice in
        1) systemctl start server-sldns edns-proxy; echo -e "${GREEN}[✓] All started${NC}";;
        2) systemctl stop server-sldns edns-proxy; echo -e "${RED}[✓] All stopped${NC}";;
        3) systemctl restart server-sldns edns-proxy; echo -e "${YELLOW}[✓] All restarted${NC}";;
        4) systemctl restart sshd; echo -e "${YELLOW}[✓] SSH restarted${NC}";;
    esac
    sleep 2
}

change_mtu() {
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${WHITE}${BOLD}⚙️ CHANGE MTU${NC}                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Current MTU: $MTU${NC}"
    read -p "Enter new MTU (900-1500): " NEW_MTU
    
    if [ -n "$NEW_MTU" ] && [ "$NEW_MTU" -ge 900 ] && [ "$NEW_MTU" -le 1500 ]; then
        echo "$NEW_MTU" > /etc/slowdns/mtu.conf
        sed -i "s/-mtu [0-9]*/-mtu $NEW_MTU/" /etc/systemd/system/server-sldns.service
        systemctl daemon-reload
        systemctl restart server-sldns
        MTU=$NEW_MTU
        echo -e "${GREEN}[✓] MTU changed to $NEW_MTU${NC}"
    else
        echo -e "${RED}[✗] Invalid MTU value${NC}"
    fi
    sleep 2
}

edit_banner() {
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${WHITE}${BOLD}📝 EDIT BANNER${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    
    if [ ! -f "$BANNER_FILE" ]; then
        echo "Welcome to ELITE-X8 SlowDNS Server" > "$BANNER_FILE"
    fi
    
    echo -e "${YELLOW}Current banner:${NC}"
    cat "$BANNER_FILE"
    echo ""
    read -p "Enter new banner text: " NEW_BANNER
    
    if [ -n "$NEW_BANNER" ]; then
        echo "$NEW_BANNER" > "$BANNER_FILE"
        echo "$NEW_BANNER" > /etc/motd
        echo -e "${GREEN}[✓] Banner updated${NC}"
    fi
    sleep 2
}

reboot_server() {
    echo -e "\n${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}         ${WHITE}${BOLD}⚠️ REBOOT SERVER${NC}               ${RED}║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    read -p "$(echo -e "${RED}Are you sure? (y/N): ${NC}")" confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e "${YELLOW}Rebooting...${NC}"
        reboot
    fi
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
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_header
    show_status
    show_menu
    read -p "$(echo -e "${WHITE}${BOLD}Select option [0-12]: ${NC}")" choice
    
    case $choice in
        1) show_status; read -p "Press Enter...";;
        2) slowdns-user create; read -p "Press Enter...";;
        3) slowdns-user list; read -p "Press Enter...";;
        4) slowdns-user details; read -p "Press Enter...";;
        5) slowdns-user renew; read -p "Press Enter...";;
        6) slowdns-user delete; read -p "Press Enter...";;
        7) service_control;;
        8) change_mtu;;
        9) edit_banner;;
        10) reboot_server;;
        11) clear; journalctl -u server-sldns --no-pager -n 30; read -p "Press Enter...";;
        12) network_monitor;;
        0) echo -e "\n${GREEN}👋 Goodbye!${NC}"; exit 0;;
        *) echo -e "${RED}Invalid!${NC}"; sleep 1;;
    esac
done
PANELSCRIPT
    
    chmod +x /usr/local/bin/slowdns-panel
    ln -sf /usr/local/bin/slowdns-panel /usr/bin/slowdns-panel 2>/dev/null
    
    print_success "Terminal panel created"
    print_step_end
}

# ============================================================================
# CREATE WEB DASHBOARD
# ============================================================================
create_dashboard() {
    print_step "6"
    print_info "Creating Web Dashboard"
    
    mkdir -p /etc/slowdns/dashboard
    
    cat > /etc/slowdns/dashboard/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X8 SlowDNS Dashboard V3</title>
    <style>
        :root {
            --bg: #0a0a1a;
            --card-bg: #1a1a2e;
            --border: #2a2a4a;
            --primary: #6c5ce7;
            --success: #00b894;
            --danger: #e17055;
            --warning: #fdcb6e;
            --info: #74b9ff;
            --text: #dfe6e9;
            --text-secondary: #b2bec3;
            --accent: #a29bfe;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
        }
        .app {
            display: flex;
            min-height: 100vh;
        }
        .sidebar {
            width: 260px;
            background: var(--card-bg);
            border-right: 1px solid var(--border);
            padding: 20px;
            position: fixed;
            height: 100vh;
            overflow-y: auto;
            z-index: 100;
        }
        .sidebar h2 {
            color: var(--accent);
            font-size: 1.3em;
            margin-bottom: 30px;
            text-align: center;
        }
        .sidebar nav a {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 12px 15px;
            color: var(--text-secondary);
            text-decoration: none;
            border-radius: 10px;
            margin-bottom: 5px;
            transition: all 0.3s;
            cursor: pointer;
        }
        .sidebar nav a:hover, .sidebar nav a.active {
            background: rgba(108, 92, 231, 0.2);
            color: var(--text);
        }
        .main-content {
            margin-left: 260px;
            flex: 1;
            padding: 30px;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
        }
        .header h1 { font-size: 1.8em; color: var(--text); }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 15px;
            padding: 20px;
            transition: transform 0.3s;
        }
        .stat-card:hover { transform: translateY(-3px); }
        .stat-card .icon { font-size: 1.5em; margin-bottom: 10px; }
        .stat-card .label { color: var(--text-secondary); font-size: 0.85em; margin-bottom: 5px; }
        .stat-card .value { font-size: 1.8em; font-weight: bold; }
        .stat-card .sub { color: var(--text-secondary); font-size: 0.8em; margin-top: 5px; }
        .panel {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 25px;
        }
        .panel h3 {
            color: var(--accent);
            margin-bottom: 20px;
            font-size: 1.2em;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-size: 0.9em;
            font-weight: 600;
            transition: all 0.3s;
            margin: 5px;
        }
        .btn-primary { background: var(--primary); color: white; }
        .btn-success { background: var(--success); color: white; }
        .btn-danger { background: var(--danger); color: white; }
        .btn-warning { background: var(--warning); color: #333; }
        .btn-info { background: var(--info); color: #333; }
        .btn:hover { opacity: 0.8; transform: translateY(-2px); }
        input, select {
            background: rgba(255,255,255,0.05);
            border: 1px solid var(--border);
            color: var(--text);
            padding: 12px 15px;
            border-radius: 10px;
            width: 100%;
            margin: 8px 0;
            font-size: 0.95em;
        }
        input:focus { outline: none; border-color: var(--primary); }
        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        .user-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .user-table th, .user-table td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid var(--border);
        }
        .user-table th {
            color: var(--accent);
            font-weight: 600;
            font-size: 0.85em;
            text-transform: uppercase;
        }
        .user-table tr:hover { background: rgba(108, 92, 231, 0.05); }
        .status-badge {
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: 600;
        }
        .status-active { background: rgba(0, 184, 148, 0.2); color: var(--success); }
        .status-expired { background: rgba(225, 112, 85, 0.2); color: var(--danger); }
        .status-unlimited { background: rgba(116, 185, 255, 0.2); color: var(--info); }
        .progress-bar {
            height: 8px;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            overflow: hidden;
            margin-top: 5px;
        }
        .progress-fill {
            height: 100%;
            border-radius: 10px;
            transition: width 0.5s;
        }
        .logs-container {
            background: #0a0a0a;
            border-radius: 10px;
            padding: 15px;
            max-height: 400px;
            overflow-y: auto;
            font-family: 'Courier New', monospace;
            font-size: 0.85em;
            color: var(--success);
            white-space: pre-wrap;
        }
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.7);
            z-index: 1000;
            justify-content: center;
            align-items: center;
        }
        .modal.active { display: flex; }
        .modal-content {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 20px;
            padding: 30px;
            max-width: 500px;
            width: 90%;
        }
        .modal-content h3 { margin-bottom: 20px; color: var(--accent); }
        .close-modal {
            float: right;
            cursor: pointer;
            font-size: 1.5em;
            color: var(--text-secondary);
        }
        .section { display: none; }
        .section.active { display: block; }
        .banner-preview {
            background: rgba(0,0,0,0.3);
            padding: 15px;
            border-radius: 10px;
            margin: 10px 0;
            font-family: monospace;
            white-space: pre-wrap;
        }
        @media (max-width: 768px) {
            .sidebar { width: 100%; height: auto; position: relative; }
            .main-content { margin-left: 0; }
            .form-row { grid-template-columns: 1fr; }
            .app { flex-direction: column; }
        }
    </style>
</head>
<body>
    <div class="app">
        <!-- Sidebar -->
        <div class="sidebar" id="sidebar">
            <h2>🚀 ELITE-X8 V3</h2>
            <nav>
                <a onclick="showSection('dashboard')" class="active" id="nav-dashboard">📊 Dashboard</a>
                <a onclick="showSection('users')" id="nav-users">👥 User Management</a>
                <a onclick="showSection('create-user')" id="nav-create-user">➕ Create User</a>
                <a onclick="showSection('settings')" id="nav-settings">⚙️ Settings</a>
                <a onclick="showSection('logs')" id="nav-logs">📋 Logs</a>
                <a onclick="showSection('network')" id="nav-network">📡 Network</a>
                <a onclick="rebootServer()" style="color: var(--danger);">🔄 Reboot</a>
            </nav>
        </div>
        
        <!-- Main Content -->
        <div class="main-content">
            <!-- Dashboard Section -->
            <div class="section active" id="section-dashboard">
                <div class="header">
                    <h1>📊 Dashboard</h1>
                    <button class="btn btn-primary" onclick="refreshAll()">🔄 Refresh</button>
                </div>
                <div class="stats-grid" id="statsGrid"></div>
                <div class="panel">
                    <h3>📈 Total Bandwidth Usage</h3>
                    <div class="stats-grid" id="totalBandwidth"></div>
                </div>
                <div class="panel">
                    <h3>👥 Active Users</h3>
                    <div id="activeUsersTable"></div>
                </div>
            </div>
            
            <!-- Users Section -->
            <div class="section" id="section-users">
                <div class="header">
                    <h1>👥 User Management</h1>
                    <button class="btn btn-primary" onclick="loadUsers()">🔄 Refresh</button>
                </div>
                <div class="panel">
                    <div id="usersTable"></div>
                </div>
            </div>
            
            <!-- Create User Section -->
            <div class="section" id="section-create-user">
                <div class="header"><h1>➕ Create New User</h1></div>
                <div class="panel">
                    <div class="form-row">
                        <div>
                            <label>Username</label>
                            <input type="text" id="newUsername" placeholder="Enter username">
                        </div>
                        <div>
                            <label>Expire Days (0=unlimited)</label>
                            <input type="number" id="expireDays" value="30" min="0">
                        </div>
                    </div>
                    <button class="btn btn-success" onclick="createUser()" style="margin-top:15px;">✅ Create User</button>
                    <div id="createUserResult" style="margin-top:15px;"></div>
                </div>
            </div>
            
            <!-- Settings Section -->
            <div class="section" id="section-settings">
                <div class="header"><h1>⚙️ Settings</h1></div>
                <div class="panel">
                    <h3>🔧 MTU Configuration</h3>
                    <div class="form-row">
                        <div>
                            <label>Current MTU: <strong id="currentMTU">1200</strong></label>
                            <input type="number" id="mtuValue" placeholder="900-1500" min="900" max="1500">
                        </div>
                    </div>
                    <button class="btn btn-primary" onclick="changeMTU()">💾 Save MTU</button>
                    <div id="mtuResult" style="margin-top:10px;"></div>
                </div>
                <div class="panel">
                    <h3>📝 Banner Configuration</h3>
                    <label>Current Banner:</label>
                    <div class="banner-preview" id="currentBanner"></div>
                    <textarea id="bannerText" rows="4" style="width:100%;margin-top:10px;background:rgba(255,255,255,0.05);border:1px solid var(--border);color:var(--text);padding:15px;border-radius:10px;" placeholder="Enter new banner text..."></textarea>
                    <button class="btn btn-primary" onclick="saveBanner()">💾 Save Banner</button>
                    <div id="bannerResult" style="margin-top:10px;"></div>
                </div>
                <div class="panel">
                    <h3>🔄 Reboot Server</h3>
                    <button class="btn btn-danger" onclick="rebootServer()">🔄 Reboot Now</button>
                </div>
            </div>
            
            <!-- Logs Section -->
            <div class="section" id="section-logs">
                <div class="header">
                    <h1>📋 Service Logs</h1>
                    <button class="btn btn-primary" onclick="loadLogs()">🔄 Refresh</button>
                </div>
                <div class="panel">
                    <div class="logs-container" id="logsContainer"></div>
                </div>
            </div>
            
            <!-- Network Section -->
            <div class="section" id="section-network">
                <div class="header">
                    <h1>📡 Network Monitor</h1>
                    <button class="btn btn-primary" onclick="loadNetwork()">🔄 Refresh</button>
                </div>
                <div class="panel">
                    <div class="logs-container" id="networkContainer"></div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- User Details Modal -->
    <div class="modal" id="userModal">
        <div class="modal-content">
            <span class="close-modal" onclick="closeModal()">✕</span>
            <h3>👤 User Details</h3>
            <div id="userModalContent"></div>
        </div>
    </div>
    
    <script>
        const API = '/api';
        
        async function fetchAPI(endpoint, method = 'GET', body = null) {
            const opts = { method, headers: { 'Content-Type': 'application/json' } };
            if (body) opts.body = JSON.stringify(body);
            const res = await fetch(API + endpoint, opts);
            return res.json();
        }
        
        function showSection(section) {
            document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
            document.querySelectorAll('.sidebar nav a').forEach(a => a.classList.remove('active'));
            const target = document.getElementById('section-' + section);
            if (target) target.classList.add('active');
            const nav = document.getElementById('nav-' + section);
            if (nav) nav.classList.add('active');
            
            if (section === 'dashboard') loadDashboard();
            else if (section === 'users') loadUsers();
            else if (section === 'logs') loadLogs();
            else if (section === 'network') loadNetwork();
            else if (section === 'settings') loadSettings();
        }
        
        async function loadDashboard() {
            const status = await fetchAPI('/status');
            const users = await fetchAPI('/users/list');
            
            // Stats grid
            let html = '';
            const cards = [
                { icon: '🖥️', label: 'CPU Load', value: status.cpu || 'N/A', sub: status.cpu_cores + ' cores' },
                { icon: '💾', label: 'RAM', value: status.ram_used + ' / ' + status.ram_total, sub: status.ram_percent },
                { icon: '💿', label: 'Disk', value: status.disk_used + ' / ' + status.disk_total, sub: status.disk_percent },
                { icon: '⏱️', label: 'Uptime', value: status.uptime || 'N/A', sub: '' },
                { icon: '🔌', label: 'Connections', value: status.connections || 0, sub: 'Active' },
                { icon: '📡', label: 'Nameserver', value: status.ns || 'N/A', sub: 'MTU: ' + (status.mtu || '1200') },
                { icon: '🔑', label: 'Public Key', value: (status.public_key || '').substring(0, 20) + '...', sub: 'Server Key' },
                { icon: '📊', label: 'Total Usage', value: status.total_bandwidth || '0 GB', sub: 'All users' }
            ];
            cards.forEach(c => {
                html += `<div class="stat-card">
                    <div class="icon">${c.icon}</div>
                    <div class="label">${c.label}</div>
                    <div class="value">${c.value}</div>
                    <div class="sub">${c.sub}</div>
                </div>`;
            });
            document.getElementById('statsGrid').innerHTML = html;
            
            // Active users table
            let userHtml = '<table class="user-table"><tr><th>User</th><th>Connections</th><th>Usage</th><th>Expire</th><th>Status</th><th>Actions</th></tr>';
            if (users.users && users.users.length > 0) {
                users.users.forEach(u => {
                    const statusClass = u.expire_date === 'unlimited' ? 'status-unlimited' : 
                        (new Date(u.expire_date) > new Date() ? 'status-active' : 'status-expired');
                    userHtml += `<tr>
                        <td><strong>${u.username}</strong></td>
                        <td>${u.connections || 0}</td>
                        <td>${u.usage || '0 GB'}</td>
                        <td>${u.expire_date || 'N/A'}</td>
                        <td><span class="status-badge ${statusClass}">${u.expire_date === 'unlimited' ? 'Unlimited' : (new Date(u.expire_date) > new Date() ? 'Active' : 'Expired')}</span></td>
                        <td>
                            <button class="btn btn-info" style="padding:5px 10px;font-size:0.8em;" onclick="showUserDetails('${u.username}')">View</button>
                            <button class="btn btn-warning" style="padding:5px 10px;font-size:0.8em;" onclick="renewUser('${u.username}')">Renew</button>
                            <button class="btn btn-danger" style="padding:5px 10px;font-size:0.8em;" onclick="deleteUser('${u.username}')">Delete</button>
                        </td>
                    </tr>`;
                });
            } else {
                userHtml += '<tr><td colspan="6" style="text-align:center;">No users found</td></tr>';
            }
            userHtml += '</table>';
            document.getElementById('activeUsersTable').innerHTML = userHtml;
            
            // Total bandwidth
            document.getElementById('totalBandwidth').innerHTML = `
                <div class="stat-card"><div class="icon">📊</div><div class="label">Total Bandwidth</div><div class="value">${status.total_bandwidth || '0 GB'}</div></div>
                <div class="stat-card"><div class="icon">👥</div><div class="label">Total Users</div><div class="value">${users.users ? users.users.length : 0}</div></div>
            `;
        }
        
        async function loadUsers() {
            const users = await fetchAPI('/users/list');
            let html = '<table class="user-table"><tr><th>Username</th><th>Password</th><th>Expire</th><th>Connections</th><th>Usage</th><th>Actions</th></tr>';
            if (users.users && users.users.length > 0) {
                users.users.forEach(u => {
                    const statusClass = u.expire_date === 'unlimited' ? 'status-unlimited' : 
                        (new Date(u.expire_date) > new Date() ? 'status-active' : 'status-expired');
                    html += `<tr>
                        <td><strong>${u.username}</strong></td>
                        <td>${u.password}</td>
                        <td><span class="status-badge ${statusClass}">${u.expire_date}</span></td>
                        <td>${u.connections || 0}</td>
                        <td>${u.usage || '0 GB'}</td>
                        <td>
                            <button class="btn btn-info" style="padding:5px 10px;font-size:0.8em;" onclick="showUserDetails('${u.username}')">View</button>
                            <button class="btn btn-warning" style="padding:5px 10px;font-size:0.8em;" onclick="renewUser('${u.username}')">Renew</button>
                            <button class="btn btn-danger" style="padding:5px 10px;font-size:0.8em;" onclick="deleteUser('${u.username}')">Delete</button>
                        </td>
                    </tr>`;
                });
            } else {
                html += '<tr><td colspan="6" style="text-align:center;">No users found</td></tr>';
            }
            html += '</table>';
            document.getElementById('usersTable').innerHTML = html;
        }
        
        async function createUser() {
            const username = document.getElementById('newUsername').value;
            const expireDays = document.getElementById('expireDays').value || 30;
            if (!username) { alert('Enter username'); return; }
            
            const result = await fetchAPI('/users/create', 'POST', { username, expire_days: parseInt(expireDays) });
            if (result.user) {
                document.getElementById('createUserResult').innerHTML = `
                    <div class="panel" style="background:rgba(0,184,148,0.1);">
                        <h3>✅ User Created!</h3>
                        <p><strong>Username:</strong> ${result.user.username}</p>
                        <p><strong>Password:</strong> ${result.user.password}</p>
                        <p><strong>Expire:</strong> ${result.user.expire_date}</p>
                        <p><strong>Public Key:</strong> ${result.user.public_key}</p>
                        <p><strong>NS:</strong> ${result.user.nameserver}</p>
                        <p><strong>Server IP:</strong> ${result.user.server_ip}</p>
                        <p><strong>SSH Port:</strong> ${result.user.ssh_port}</p>
                        <p><strong>DNS Port:</strong> ${result.user.edns_port}</p>
                    </div>`;
                document.getElementById('newUsername').value = '';
            } else {
                document.getElementById('createUserResult').innerHTML = `<div style="color:var(--danger);">Error: ${result.error || 'Unknown'}</div>`;
            }
        }
        
        async function showUserDetails(username) {
            const result = await fetchAPI('/users/details/' + username);
            if (result.user) {
                const u = result.user;
                document.getElementById('userModalContent').innerHTML = `
                    <p><strong>Username:</strong> ${u.username}</p>
                    <p><strong>Password:</strong> ${u.password}</p>
                    <p><strong>Expire:</strong> ${u.expire_date}</p>
                    <p><strong>Connections:</strong> ${u.connections}</p>
                    <p><strong>Usage:</strong> ${u.usage}</p>
                    <p><strong>Public Key:</strong> ${u.public_key}</p>
                    <p><strong>NS:</strong> ${u.nameserver}</p>
                    <p><strong>Server IP:</strong> ${u.server_ip}</p>
                    <p><strong>SSH Port:</strong> ${u.ssh_port}</p>
                    <p><strong>DNS Port:</strong> ${u.edns_port}</p>
                    <p><strong>Created:</strong> ${u.created}</p>`;
                document.getElementById('userModal').classList.add('active');
            }
        }
        
        function closeModal() {
            document.getElementById('userModal').classList.remove('active');
        }
        
        async function renewUser(username) {
            const days = prompt('Add how many days?', '30');
            if (!days) return;
            const result = await fetchAPI('/users/renew', 'POST', { username, days: parseInt(days) });
            alert(result.message || 'Renewed!');
            loadUsers();
            loadDashboard();
        }
        
        async function deleteUser(username) {
            if (!confirm(`Delete user ${username}?`)) return;
            const result = await fetchAPI('/users/delete', 'POST', { username });
            alert(result.message || 'Deleted!');
            loadUsers();
            loadDashboard();
        }
        
        async function loadLogs() {
            const status = await fetchAPI('/status');
            document.getElementById('logsContainer').textContent = status.logs || 'No logs available';
        }
        
        async function loadNetwork() {
            const status = await fetchAPI('/network');
            document.getElementById('networkContainer').textContent = status.network || 'No data';
        }
        
        async function loadSettings() {
            const status = await fetchAPI('/status');
            document.getElementById('currentMTU').textContent = status.mtu || '1200';
            document.getElementById('mtuValue').value = status.mtu || '1200';
            document.getElementById('currentBanner').textContent = status.banner || 'Welcome to ELITE-X8 SlowDNS Server';
            document.getElementById('bannerText').value = status.banner || '';
        }
        
        async function changeMTU() {
            const mtu = document.getElementById('mtuValue').value;
            const result = await fetchAPI('/settings/mtu', 'POST', { mtu: parseInt(mtu) });
            document.getElementById('mtuResult').innerHTML = `<div style="color:var(--success);">${result.message}</div>`;
            setTimeout(() => location.reload(), 2000);
        }
        
        async function saveBanner() {
            const banner = document.getElementById('bannerText').value;
            const result = await fetchAPI('/settings/banner', 'POST', { banner });
            document.getElementById('bannerResult').innerHTML = `<div style="color:var(--success);">${result.message}</div>`;
        }
        
        async function rebootServer() {
            if (!confirm('Reboot the server?')) return;
            await fetchAPI('/settings/reboot', 'POST');
            alert('Rebooting...');
        }
        
        function refreshAll() {
            loadDashboard();
            loadUsers();
        }
        
        // Auto-refresh dashboard
        setInterval(() => {
            if (document.getElementById('section-dashboard').classList.contains('active')) {
                loadDashboard();
            }
        }, 10000);
        
        // Initial load
        loadDashboard();
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
import re
from datetime import datetime, timedelta
from urllib.parse import urlparse, parse_qs

USERS_DIR = "/etc/slowdns/users"
BANDWIDTH_DIR = "/etc/slowdns/bandwidth"
PUBLIC_KEY = ""
SERVER_IP = ""
NS = ""
MTU = "1200"
BANNER_FILE = "/etc/slowdns/banner.txt"

def load_config():
    global PUBLIC_KEY, SERVER_IP, NS, MTU
    try:
        with open('/etc/slowdns/server.pub', 'r') as f:
            PUBLIC_KEY = f.read().strip()
    except: PUBLIC_KEY = "N/A"
    
    try:
        with open('/etc/slowdns/ns.conf', 'r') as f:
            NS = f.read().strip()
    except: NS = "dns.google.com"
    
    try:
        with open('/etc/slowdns/mtu.conf', 'r') as f:
            MTU = f.read().strip()
    except: MTU = "1200"
    
    try:
        result = subprocess.run(['curl', '-s', '--connect-timeout', '3', 'ifconfig.me'], 
                              capture_output=True, text=True, timeout=5)
        SERVER_IP = result.stdout.strip()
    except:
        try:
            result = subprocess.run(['hostname', '-I'], capture_output=True, text=True)
            SERVER_IP = result.stdout.strip().split()[0]
        except: SERVER_IP = "127.0.0.1"

load_config()

def get_system_stats():
    stats = {}
    
    # CPU
    try:
        result = subprocess.run(['uptime'], capture_output=True, text=True)
        cpu_load = result.stdout.split('load average:')[-1].strip()
        stats['cpu'] = cpu_load
    except: stats['cpu'] = 'N/A'
    
    stats['cpu_cores'] = os.cpu_count() or 1
    
    # RAM
    try:
        result = subprocess.run(['free', '-h'], capture_output=True, text=True)
        mem = result.stdout.split('\n')[1].split()
        stats['ram_total'] = mem[1]
        stats['ram_used'] = mem[2]
        result2 = subprocess.run(['free'], capture_output=True, text=True)
        mem2 = result2.stdout.split('\n')[1].split()
        stats['ram_percent'] = f"{int(int(mem2[2])/int(mem2[1])*100)}%"
    except:
        stats['ram_total'] = 'N/A'
        stats['ram_used'] = 'N/A'
        stats['ram_percent'] = 'N/A'
    
    # Disk
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
        disk = result.stdout.split('\n')[1].split()
        stats['disk_total'] = disk[1]
        stats['disk_used'] = disk[2]
        stats['disk_percent'] = disk[4]
    except:
        stats['disk_total'] = 'N/A'
        stats['disk_used'] = 'N/A'
        stats['disk_percent'] = 'N/A'
    
    # Uptime
    try:
        result = subprocess.run(['uptime', '-p'], capture_output=True, text=True)
        stats['uptime'] = result.stdout.strip().replace('up ', '')
    except: stats['uptime'] = 'N/A'
    
    # Connections
    try:
        result = subprocess.run(['ss', '-tn'], capture_output=True, text=True)
        stats['connections'] = len([l for l in result.stdout.split('\n') if ':22 ' in l or ':5300 ' in l])
    except: stats['connections'] = 0
    
    # Services
    stats['slowdns_status'] = 'running' if os.system('systemctl is-active --quiet server-sldns') == 0 else 'stopped'
    stats['edns_status'] = 'running' if os.system('systemctl is-active --quiet edns-proxy') == 0 else 'stopped'
    stats['ssh_status'] = 'running' if os.system('systemctl is-active --quiet sshd') == 0 else 'stopped'
    
    stats['ns'] = NS
    stats['mtu'] = MTU
    stats['public_key'] = PUBLIC_KEY
    stats['server_ip'] = SERVER_IP
    
    # Banner
    try:
        with open(BANNER_FILE, 'r') as f:
            stats['banner'] = f.read()
    except: stats['banner'] = 'Welcome to ELITE-X8 SlowDNS Server'
    
    # Total bandwidth
    total_bytes = 0
    if os.path.exists(BANDWIDTH_DIR):
        for f in os.listdir(BANDWIDTH_DIR):
            if f.endswith('.txt'):
                try:
                    with open(os.path.join(BANDWIDTH_DIR, f), 'r') as bf:
                        total_bytes += int(bf.read().strip() or 0)
                except: pass
    stats['total_bandwidth'] = f"{total_bytes/1073741824:.2f} GB"
    
    return stats

def get_user_list():
    users = []
    if os.path.exists(USERS_DIR):
        for f in os.listdir(USERS_DIR):
            if f.endswith('.json'):
                try:
                    with open(os.path.join(USERS_DIR, f), 'r') as jf:
                        user = json.load(jf)
                except: continue
                
                username = user.get('username', '')
                
                # Get connections
                try:
                    result = subprocess.run(['ss', '-tn'], capture_output=True, text=True)
                    conns = len([l for l in result.stdout.split('\n') if username.lower() in l.lower()])
                except: conns = 0
                user['connections'] = conns
                
                # Get bandwidth
                bw_file = os.path.join(BANDWIDTH_DIR, f"{username}.txt")
                if os.path.exists(bw_file):
                    try:
                        with open(bw_file, 'r') as bf:
                            bytes_used = int(bf.read().strip() or 0)
                        user['usage'] = f"{bytes_used/1073741824:.2f} GB"
                    except: user['usage'] = "0.00 GB"
                else:
                    user['usage'] = "0.00 GB"
                
                users.append(user)
    return users

class SlowDNSAPI(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            try:
                with open('/etc/slowdns/dashboard/index.html', 'rb') as f:
                    self.wfile.write(f.read())
            except:
                self.wfile.write(b'Dashboard not found')
        
        elif self.path == '/api/status':
            stats = get_system_stats()
            self.send_json(stats)
        
        elif self.path == '/api/users/list':
            users = get_user_list()
            self.send_json({'users': users})
        
        elif self.path.startswith('/api/users/details/'):
            username = self.path.split('/')[-1]
            users = get_user_list()
            user = next((u for u in users if u['username'] == username), None)
            if user:
                self.send_json({'user': user})
            else:
                self.send_json({'error': 'User not found'}, 404)
        
        elif self.path == '/api/network':
            try:
                result = subprocess.run(['ss', '-tunap'], capture_output=True, text=True, timeout=5)
                network = result.stdout
            except: network = 'No data'
            self.send_json({'network': network})
        
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = {}
        if content_length > 0:
            try:
                post_data = json.loads(self.rfile.read(content_length))
            except: pass
        
        if self.path == '/api/users/create':
            username = post_data.get('username', '')
            expire_days = post_data.get('expire_days', 30)
            
            if not username:
                self.send_json({'error': 'Username required'}, 400)
                return
            
            user_file = os.path.join(USERS_DIR, f"{username}.json")
            if os.path.exists(user_file):
                self.send_json({'error': 'User already exists'}, 400)
                return
            
            password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
            
            if expire_days == 0:
                expire_date = 'unlimited'
            else:
                expire_date = (datetime.now() + timedelta(days=expire_days)).strftime('%Y-%m-%d')
            
            # Create system user
            try:
                subprocess.run(['useradd', '-m', '-s', '/bin/bash', username], capture_output=True, timeout=5)
                subprocess.run(['chpasswd'], input=f"{username}:{password}".encode(), capture_output=True, timeout=5)
            except: pass
            
            # Initialize bandwidth
            os.makedirs(BANDWIDTH_DIR, exist_ok=True)
            with open(os.path.join(BANDWIDTH_DIR, f"{username}.txt"), 'w') as f:
                f.write('0')
            
            user_data = {
                'username': username,
                'password': password,
                'server_ip': SERVER_IP,
                'ssh_port': '22',
                'slowdns_port': '5300',
                'edns_port': '53',
                'public_key': PUBLIC_KEY,
                'nameserver': NS,
                'created': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'expire_date': expire_date,
                'status': 'active',
                'connections': 0
            }
            
            os.makedirs(USERS_DIR, exist_ok=True)
            with open(user_file, 'w') as f:
                json.dump(user_data, f, indent=2)
            
            self.send_json({'message': 'User created', 'user': user_data})
        
        elif self.path == '/api/users/renew':
            username = post_data.get('username', '')
            days = post_data.get('days', 30)
            
            user_file = os.path.join(USERS_DIR, f"{username}.json")
            if not os.path.exists(user_file):
                self.send_json({'error': 'User not found'}, 404)
                return
            
            try:
                with open(user_file, 'r') as f:
                    user = json.load(f)
                
                if user.get('expire_date') != 'unlimited':
                    current_expire = datetime.strptime(user['expire_date'], '%Y-%m-%d')
                    new_expire = (current_expire + timedelta(days=days)).strftime('%Y-%m-%d')
                else:
                    new_expire = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
                
                user['expire_date'] = new_expire
                user['status'] = 'active'
                
                with open(user_file, 'w') as f:
                    json.dump(user, f, indent=2)
                
                self.send_json({'message': f'User {username} renewed until {new_expire}'})
            except Exception as e:
                self.send_json({'error': str(e)}, 500)
        
        elif self.path == '/api/users/delete':
            username = post_data.get('username', '')
            
            user_file = os.path.join(USERS_DIR, f"{username}.json")
            if os.path.exists(user_file):
                os.remove(user_file)
                bw_file = os.path.join(BANDWIDTH_DIR, f"{username}.txt")
                if os.path.exists(bw_file):
                    os.remove(bw_file)
                try:
                    subprocess.run(['userdel', '-r', username], capture_output=True, timeout=5)
                except: pass
                self.send_json({'message': f'User {username} deleted'})
            else:
                self.send_json({'error': 'User not found'}, 404)
        
        elif self.path == '/api/settings/mtu':
            mtu = post_data.get('mtu', 1200)
            if 900 <= mtu <= 1500:
                with open('/etc/slowdns/mtu.conf', 'w') as f:
                    f.write(str(mtu))
                subprocess.run(['sed', '-i', f's/-mtu [0-9]*/-mtu {mtu}/', '/etc/systemd/system/server-sldns.service'])
                subprocess.run(['systemctl', 'daemon-reload'])
                subprocess.run(['systemctl', 'restart', 'server-sldns'])
                global MTU
                MTU = str(mtu)
                self.send_json({'message': f'MTU changed to {mtu}'})
            else:
                self.send_json({'error': 'Invalid MTU (900-1500)'}, 400)
        
        elif self.path == '/api/settings/banner':
            banner = post_data.get('banner', '')
            with open(BANNER_FILE, 'w') as f:
                f.write(banner)
            subprocess.run(['bash', '-c', f'echo "{banner}" > /etc/motd'])
            self.send_json({'message': 'Banner updated'})
        
        elif self.path == '/api/settings/reboot':
            self.send_json({'message': 'Rebooting...'})
            subprocess.run(['reboot'])
        
        else:
            self.send_json({'error': 'Not found'}, 404)

if __name__ == '__main__':
    os.makedirs(USERS_DIR, exist_ok=True)
    os.makedirs(BANDWIDTH_DIR, exist_ok=True)
    if not os.path.exists(BANNER_FILE):
        with open(BANNER_FILE, 'w') as f:
            f.write('Welcome to ELITE-X8 SlowDNS Server')
    
    server = http.server.HTTPServer(('0.0.0.0', 8080), SlowDNSAPI)
    print("SlowDNS API Server running on port 8080")
    server.serve_forever()
APIEOF
    
    chmod +x /usr/local/bin/slowdns-api
    
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
    
    echo "$NAMESERVER" > /etc/slowdns/ns.conf
    echo "1200" > /etc/slowdns/mtu.conf
    echo "Welcome to ELITE-X8 SlowDNS Server" > /etc/slowdns/banner.txt
    
    print_success "Service files created"
    print_step_end
}

# ============================================================================
# CONFIGURE FIREWALL
# ============================================================================
configure_firewall() {
    print_step "8"
    print_info "Configuring Firewall (IPv4 Only)"
    
    systemctl stop systemd-resolved 2>/dev/null
    fuser -k 53/udp 2>/dev/null
    fuser -k 53/tcp 2>/dev/null
    
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
    
    ip6tables -P INPUT DROP 2>/dev/null
    ip6tables -P OUTPUT DROP 2>/dev/null
    ip6tables -P FORWARD DROP 2>/dev/null
    
    print_success "Firewall configured"
    print_step_end
}

# ============================================================================
# START SERVICES
# ============================================================================
start_services() {
    print_step "9"
    print_info "Starting All Services"
    
    systemctl daemon-reload
    
    systemctl enable server-sldns > /dev/null 2>&1
    systemctl start server-sldns
    sleep 2
    
    if systemctl is-active --quiet server-sldns; then
        print_success "SlowDNS service started"
    else
        print_warning "Starting SlowDNS in background mode"
        /etc/slowdns/dnstt-server -udp :$SLOWDNS_PORT -mtu 1200 -privkey-file /etc/slowdns/server.key $NAMESERVER 127.0.0.1:$SSHD_PORT &
    fi
    
    systemctl enable edns-proxy > /dev/null 2>&1
    systemctl start edns-proxy
    sleep 2
    
    if systemctl is-active --quiet edns-proxy; then
        print_success "EDNS Proxy started"
    else
        print_warning "Starting EDNS Proxy in background"
        /usr/local/bin/edns-proxy &
    fi
    
    systemctl enable slowdns-dashboard > /dev/null 2>&1
    systemctl start slowdns-dashboard
    sleep 2
    
    if systemctl is-active --quiet slowdns-dashboard; then
        print_success "Dashboard started"
    else
        print_warning "Dashboard in background"
        python3 /usr/local/bin/slowdns-api &
    fi
    
    print_step_end
}

# ============================================================================
# SHOW SUMMARY
# ============================================================================
show_summary() {
    print_header "🎉 INSTALLATION COMPLETE"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}ELITE-X8 SLOWDNS SERVER V3${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Server IP:      ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SSH Port:       ${WHITE}$SSHD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SlowDNS Port:   ${WHITE}$SLOWDNS_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} EDNS Port:      ${WHITE}53${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Web Dashboard:  ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Terminal Panel: ${WHITE}slowdns-panel${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} User Manager:   ${WHITE}slowdns-user {create|list|renew|delete|details}${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Nameserver:     ${WHITE}$NAMESERVER${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IPv6:           ${WHITE}Disabled${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} UDP Buffer:     ${WHITE}20MB Max${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SO_REUSEPORT:   ${WHITE}Enabled${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    if [ -f /etc/slowdns/server.pub ]; then
        echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}${BOLD}PUBLIC KEY${NC}                                            ${CYAN}│${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}$(cat /etc/slowdns/server.pub)${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}🎯 ELITE-X8 SLOWDNS V3 INSTALLED SUCCESSFULLY!${NC}           ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}⚡ Dashboard: http://$SERVER_IP:$DASHBOARD_PORT${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}💻 Panel: slowdns-panel${NC}                                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    print_banner
    
    echo -e "${WHITE}${BOLD}Configure Your Nameserver:${NC}"
    echo -e "${CYAN}Examples: dns.google.com, dns.cloudflare.com${NC}"
    read -p "$(echo -e "${WHITE}${BOLD}Enter nameserver: ${NC}")" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
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

trap 'echo -e "\n${RED}✗ Installation interrupted!${NC}"; log_message "Installation interrupted"; exit 1' INT

echo "=== SLOWDNS INSTALLATION STARTED $(date) ===" > "$LOG_FILE"

if main; then
    echo "=== INSTALLATION COMPLETED SUCCESSFULLY $(date) ===" >> "$LOG_FILE"
    exit 0
else
    echo "=== INSTALLATION FAILED $(date) ===" >> "$LOG_FILE"
    exit 1
fi
