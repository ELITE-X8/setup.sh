#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  ELITE-X DNSTT SCRIPT v3.3.3 - FALCON ULTIMATE EDITION
#  + GB Limits + C Boosters + Auto-Delete + Banner System
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

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
BANNER_DIR="/etc/elite-x/banner"
SERVER_MSG_DIR="/etc/elite-x/server_msg"

show_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}      ELITE-X SLOWDNS v3.3.3 FALCON ULTIMATE EDITION        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}  GB Limits • C Boosters • Auto-Delete • Banner System        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}${BOLD}        TURBO BOOST EDITION - BBR + FQ + C ENGINE              ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_color() { echo -e "${2}${1}${NC}"; }
set_timezone() { timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true; }

# ═══════════════════════════════════════════════════════════
# BANNER & SERVER MESSAGE SYSTEM
# ═══════════════════════════════════════════════════════════
setup_banner_system() {
    echo -e "${YELLOW}🎨 Setting up Banner System...${NC}"
    
    mkdir -p "$BANNER_DIR" "$SERVER_MSG_DIR"
    
    # Default SSH Banner (shown before login)
    cat > "$BANNER_DIR/default" <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║           ELITE-X v3.3.3 FALCON ULTIMATE EDITION              ║
║      GB Limits • Bandwidth Monitor • C Engine Boost          ║
╚═══════════════════════════════════════════════════════════════╝
EOF

    # Default Server Message (shown after successful login)
    cat > "$SERVER_MSG_DIR/default" <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║         🚀 WELCOME TO ELITE-X PREMIUM SERVER 🚀              ║
╠═══════════════════════════════════════════════════════════════╣
║  ✅ Connected Successfully!                                  ║
║  📊 Type: menu  to see options                              ║
║  🔧 Type: elite-x-user details  to check your account        ║
╚═══════════════════════════════════════════════════════════════╝
EOF

    cp "$BANNER_DIR/default" "$BANNER_DIR/ssh-banner"
    echo "default" > "$SERVER_MSG_DIR/active"
    
    # Add banner to SSH config if not already there
    if ! grep -q "Banner $BANNER_DIR/ssh-banner" /etc/ssh/sshd_config 2>/dev/null; then
        echo "Banner $BANNER_DIR/ssh-banner" >> /etc/ssh/sshd_config
    fi
    
    # Create user auto-details display on login
    cat > /etc/profile.d/elite-x-user-details.sh <<'PROFILEEOF'
#!/bin/bash
if [ -n "$SSH_CONNECTION" ] && [ "$USER" != "root" ]; then
    USER_DB="/etc/elite-x/users"
    BW_DIR="/etc/elite-x/bandwidth"
    SERVER_MSG_DIR="/etc/elite-x/server_msg"
    
    ACTIVE_MSG=$(cat "$SERVER_MSG_DIR/active" 2>/dev/null || echo "default")
    
    # Show server message
    if [ -f "$SERVER_MSG_DIR/$ACTIVE_MSG" ]; then
        cat "$SERVER_MSG_DIR/$ACTIVE_MSG"
    fi
    
    echo ""
    echo -e "\033[1;36m╔═══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m║\033[1;33m                    📋 USER ACCOUNT DETAILS                       \033[1;36m║\033[0m"
    echo -e "\033[1;36m╠═══════════════════════════════════════════════════════════════╣\033[0m"
    
    if [ -f "$USER_DB/$USER" ]; then
        username="$USER"
        expire_date=$(grep "Expire:" "$USER_DB/$USER" 2>/dev/null | awk '{print $2}')
        conn_limit=$(grep "Conn_Limit:" "$USER_DB/$USER" 2>/dev/null | awk '{print $2}')
        conn_limit=${conn_limit:-1}
        bandwidth_gb=$(grep "Bandwidth_GB:" "$USER_DB/$USER" 2>/dev/null | awk '{print $2}')
        bandwidth_gb=${bandwidth_gb:-0}
        
        total_gb="0.00"
        if [ -f "$BW_DIR/${USER}.usage" ]; then
            total_bytes=$(cat "$BW_DIR/${USER}.usage" 2>/dev/null || echo 0)
            total_gb=$(echo "scale=2; $total_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")
        fi
        
        current_conn=$(who | grep -wc "$USER" 2>/dev/null)
        [ "$current_conn" -eq 0 ] && current_conn=$(ps aux 2>/dev/null | grep "sshd:" | grep "$USER" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
        
        remaining="Active"
        if [ -n "$expire_date" ]; then
            expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
            current_ts=$(date +%s)
            if [ "$expire_ts" -gt "$current_ts" ]; then
                diff_sec=$((expire_ts - current_ts))
                diff_days=$((diff_sec / 86400))
                diff_hrs=$(((diff_sec % 86400) / 3600))
                if [ $diff_days -gt 0 ]; then
                    remaining="${diff_days}day"
                    [ $diff_days -gt 1 ] && remaining="${diff_days}days"
                    [ $diff_hrs -gt 0 ] && remaining="${remaining} + ${diff_hrs}hr"
                else
                    remaining="${diff_hrs}hr"
                fi
            else
                remaining="\033[0;31mEXPIRED\033[0m"
            fi
        fi
        
        echo -e "\033[1;36m║\033[0m \033[1;37mFile Name    :\033[0m \033[1;32m$username\033[0m"
        echo -e "\033[1;36m║\033[0m \033[1;37mLimit GB     :\033[0m \033[1;33m${bandwidth_gb} GB\033[0m"
        echo -e "\033[1;36m║\033[0m \033[1;37mUsage GB     :\033[0m \033[1;36m${total_gb} GB\033[0m"
        echo -e "\033[1;36m║\033[0m \033[1;37mConnection   :\033[0m \033[1;35m${current_conn}/${conn_limit} (Total connections on user ACCOUNT)\033[0m"
        echo -e "\033[1;36m║\033[0m \033[1;37mExpire       :\033[0m \033[1;31m${expire_date}\033[0m (\033[1;32m${remaining}\033[0m)"
    else
        echo -e "\033[1;36m║\033[0m \033[1;31m⚠️  Account details not found\033[0m"
    fi
    
    echo -e "\033[1;36m╚═══════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
fi
PROFILEEOF
    chmod +x /etc/profile.d/elite-x-user-details.sh
    
    echo -e "${GREEN}✅ Banner System ready${NC}"
}

manage_banners() {
    while true; do
        clear
        ACTIVE_MSG=$(cat "$SERVER_MSG_DIR/active" 2>/dev/null || echo "default")
        
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}              🎨 BANNER & MESSAGE MANAGER              ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Edit SSH Banner (Before Login)${NC}"
        echo -e "${PURPLE}║${WHITE}  [2] Edit Server Message (After Login)${NC}"
        echo -e "${PURPLE}║${WHITE}  [3] Switch Active Server Message${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Create New Server Message${NC}"
        echo -e "${PURPLE}║${WHITE}  [5] View SSH Banner${NC}"
        echo -e "${PURPLE}║${WHITE}  [6] View Server Message${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset to Default${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Back${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${CYAN}  Active Message: ${GREEN}$ACTIVE_MSG${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        
        case $ch in
            1)
                nano "$BANNER_DIR/ssh-banner"
                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
                echo -e "${GREEN}✅ SSH Banner updated${NC}"
                read -p "Press Enter..."
                ;;
            2)
                nano "$SERVER_MSG_DIR/$ACTIVE_MSG"
                echo -e "${GREEN}✅ Server Message updated${NC}"
                read -p "Press Enter..."
                ;;
            3)
                echo -e "${YELLOW}Available messages:${NC}"
                ls -1 "$SERVER_MSG_DIR/" | grep -v "active"
                echo ""
                read -p "Enter message name to activate: " msg_name
                if [ -f "$SERVER_MSG_DIR/$msg_name" ]; then
                    echo "$msg_name" > "$SERVER_MSG_DIR/active"
                    echo -e "${GREEN}✅ Activated: $msg_name${NC}"
                else
                    echo -e "${RED}❌ Not found${NC}"
                fi
                read -p "Press Enter..."
                ;;
            4)
                read -p "New message name: " new_name
                [ -z "$new_name" ] && continue
                cat > "$SERVER_MSG_DIR/${new_name}" <<'TMPEOF'
╔═══════════════════════════════════════════════════════════════╗
║              YOUR CUSTOM MESSAGE HERE                         ║
║              Edit this template                               ║
╚═══════════════════════════════════════════════════════════════╝
TMPEOF
                nano "$SERVER_MSG_DIR/${new_name}"
                echo -e "${GREEN}✅ Created: ${new_name}${NC}"
                read -p "Activate now? (y/n): " act
                [ "$act" = "y" ] && echo "$new_name" > "$SERVER_MSG_DIR/active"
                read -p "Press Enter..."
                ;;
            5)
                clear
                echo -e "${CYAN}SSH Banner (Before Login):${NC}"
                echo -e "${YELLOW}═══════════════════════════════════════${NC}"
                cat "$BANNER_DIR/ssh-banner"
                echo -e "${YELLOW}═══════════════════════════════════════${NC}"
                read -p "Press Enter..."
                ;;
            6)
                clear
                echo -e "${CYAN}Active Server Message (After Login):${NC}"
                echo -e "${YELLOW}═══════════════════════════════════════${NC}"
                cat "$SERVER_MSG_DIR/$ACTIVE_MSG"
                echo -e "${YELLOW}═══════════════════════════════════════${NC}"
                read -p "Press Enter..."
                ;;
            7)
                cp "$BANNER_DIR/default" "$BANNER_DIR/ssh-banner"
                cp "$SERVER_MSG_DIR/default" "$SERVER_MSG_DIR/default" 2>/dev/null
                echo "default" > "$SERVER_MSG_DIR/active"
                systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
                echo -e "${GREEN}✅ Reset to default${NC}"
                read -p "Press Enter..."
                ;;
            0) return ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
# C COMPILER SETUP
# ═══════════════════════════════════════════════════════════
setup_c_compiler() {
    echo -e "${YELLOW}🔧 Setting up C compiler...${NC}"
    apt-get install -y gcc make build-essential 2>/dev/null
    echo -e "${GREEN}✅ C compiler ready${NC}"
}

# ═══════════════════════════════════════════════════════════
# C-BASED EDNS PROXY
# ═══════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}📝 Compiling C EDNS Proxy...${NC}"
    
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

#define BUFFER_SIZE 4096
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
    memcpy(&qdcount, data+4, 2); qdcount = ntohs(qdcount);
    memcpy(&ancount, data+6, 2); ancount = ntohs(ancount);
    memcpy(&nscount, data+8, 2); nscount = ntohs(nscount);
    memcpy(&arcount, data+10, 2); arcount = ntohs(arcount);
    
    int i;
    for(i=0; i<qdcount; i++) { offset=skip_name(data,offset,*len); if(offset+4>*len) return; offset+=4; }
    for(i=0; i<ancount+nscount; i++) {
        offset=skip_name(data,offset,*len);
        if(offset+10>*len) return;
        unsigned short rdlength; memcpy(&rdlength, data+offset+8, 2); rdlength=ntohs(rdlength);
        offset+=10+rdlength;
    }
    for(i=0; i<arcount; i++) {
        offset=skip_name(data,offset,*len);
        if(offset+10>*len) return;
        unsigned short rrtype; memcpy(&rrtype, data+offset, 2); rrtype=ntohs(rrtype);
        if(rrtype==41) { unsigned short size=htons(max_size); memcpy(data+offset+2,&size,2); return; }
        unsigned short rdlength; memcpy(&rdlength, data+offset+8, 2); rdlength=ntohs(rdlength);
        offset+=10+rdlength;
    }
}

int main() {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if(sock < 0) { perror("socket"); return 1; }
    
    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(DNS_PORT);
    
    system("fuser -k 53/udp 2>/dev/null");
    usleep(1000000);
    
    if(bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        system("fuser -k 53/udp 2>/dev/null");
        usleep(2000000);
        if(bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
            perror("bind"); close(sock); return 1;
        }
    }
    
    struct timeval tv; tv.tv_sec=1; tv.tv_usec=0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    
    fprintf(stderr, "C-EDNS Proxy on port 53\n");
    
    struct sockaddr_in backend_addr;
    memset(&backend_addr, 0, sizeof(backend_addr));
    backend_addr.sin_family = AF_INET;
    backend_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    backend_addr.sin_port = htons(BACKEND_PORT);
    
    unsigned char buffer[BUFFER_SIZE], response[BUFFER_SIZE];
    
    while(running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int n = recvfrom(sock, buffer, BUFFER_SIZE, 0, (struct sockaddr*)&client_addr, &client_len);
        if(n < 0) { if(errno==EAGAIN||errno==EWOULDBLOCK) continue; if(!running) break; continue; }
        
        int len = n;
        modify_edns(buffer, &len, MAX_EDNS_SIZE);
        
        int backend_sock = socket(AF_INET, SOCK_DGRAM, 0);
        if(backend_sock < 0) continue;
        
        struct timeval btv; btv.tv_sec=5; btv.tv_usec=0;
        setsockopt(backend_sock, SOL_SOCKET, SO_RCVTIMEO, &btv, sizeof(btv));
        
        sendto(backend_sock, buffer, len, 0, (struct sockaddr*)&backend_addr, sizeof(backend_addr));
        
        socklen_t back_len = sizeof(backend_addr);
        int rn = recvfrom(backend_sock, response, BUFFER_SIZE, 0, (struct sockaddr*)&backend_addr, &back_len);
        
        if(rn > 0) { len=rn; modify_edns(response, &len, MIN_EDNS_SIZE); sendto(sock, response, len, 0, (struct sockaddr*)&client_addr, client_len); }
        close(backend_sock);
    }
    close(sock);
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-edns-proxy /tmp/edns_proxy.c 2>/dev/null
    rm -f /tmp/edns_proxy.c
    
    if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
        chmod +x /usr/local/bin/elite-x-edns-proxy
        echo -e "${GREEN}✅ C EDNS Proxy compiled${NC}"
        return 0
    else
        echo -e "${RED}❌ EDNS Proxy compilation failed${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# C BANDWIDTH MONITOR
# ═══════════════════════════════════════════════════════════
create_c_bandwidth_monitor() {
    echo -e "${YELLOW}📝 Compiling C Bandwidth Monitor...${NC}"
    
    cat > /tmp/bw_monitor.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <signal.h>
#include <pwd.h>
#include <ctype.h>

#define USER_DB "/etc/elite-x/users"
#define BW_DIR "/etc/elite-x/bandwidth"
#define PID_DIR "/etc/elite-x/bandwidth/pidtrack"
#define BANNED_DIR "/etc/elite-x/banned"
#define SCAN_INTERVAL 30

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

long long get_process_io(int pid) {
    char path[256]; snprintf(path, sizeof(path), "/proc/%d/io", pid);
    FILE *f = fopen(path, "r"); if(!f) return 0;
    long long rchar=0, wchar=0; char line[256];
    while(fgets(line, sizeof(line), f)) {
        if(strncmp(line, "rchar:", 6)==0) sscanf(line+7, "%lld", &rchar);
        else if(strncmp(line, "wchar:", 6)==0) sscanf(line+7, "%lld", &wchar);
    }
    fclose(f); return rchar + wchar;
}

int is_numeric(const char *str) { for(;*str;str++) if(!isdigit(*str)) return 0; return 1; }

int get_sshd_pids(const char *username, int *pids, int max) {
    int count=0;
    DIR *proc=opendir("/proc"); if(!proc) return 0;
    struct dirent *e;
    while((e=readdir(proc)) && count<max) {
        if(!is_numeric(e->d_name)) continue;
        int pid=atoi(e->d_name);
        char cp[256]; snprintf(cp, sizeof(cp), "/proc/%d/comm", pid);
        FILE *f=fopen(cp,"r"); if(!f) continue;
        char comm[256]={0}; fgets(comm, sizeof(comm), f); fclose(f);
        comm[strcspn(comm,"\n")]=0;
        if(strcmp(comm,"sshd")==0) {
            char sp[256]; snprintf(sp, sizeof(sp), "/proc/%d/status", pid);
            FILE *sf=fopen(sp,"r"); if(!sf) continue;
            char line[256], uid_str[32]={0};
            while(fgets(line, sizeof(line), sf)) {
                if(strncmp(line,"Uid:",4)==0) { sscanf(line,"%*s %s", uid_str); break; }
            }
            fclose(sf);
            struct passwd *pw=getpwuid(atoi(uid_str));
            if(pw && strcmp(pw->pw_name, username)==0) {
                char stp[256]; snprintf(stp, sizeof(stp), "/proc/%d/stat", pid);
                FILE *stf=fopen(stp,"r"); if(stf) { int ppid; char sb[1024]; fgets(sb,sizeof(sb),stf); sscanf(sb,"%*d %*s %*c %d",&ppid); fclose(stf); if(ppid!=1) pids[count++]=pid; }
            }
        }
    }
    closedir(proc); return count;
}

int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    mkdir(BW_DIR, 0755); mkdir(PID_DIR, 0755); mkdir(BANNED_DIR, 0755);
    
    while(running) {
        DIR *ud=opendir(USER_DB); if(!ud) { sleep(SCAN_INTERVAL); continue; }
        struct dirent *ue;
        while((ue=readdir(ud))) {
            if(ue->d_name[0]=='.') continue;
            char uf[512]; snprintf(uf, sizeof(uf), "%s/%s", USER_DB, ue->d_name);
            FILE *u=fopen(uf,"r"); if(!u) continue;
            double bw_gb=0; char line[256];
            while(fgets(line, sizeof(line), u)) if(strncmp(line,"Bandwidth_GB:",13)==0) sscanf(line+13,"%lf",&bw_gb);
            fclose(u); if(bw_gb<=0) continue;
            
            int pids[100]; int pc=get_sshd_pids(ue->d_name, pids, 100);
            if(pc==0) { char cmd[512]; snprintf(cmd, sizeof(cmd), "rm -f %s/%s__*.last 2>/dev/null", PID_DIR, ue->d_name); system(cmd); continue; }
            
            long long delta=0;
            for(int i=0; i<pc; i++) {
                long long cur=get_process_io(pids[i]);
                char pf[512]; snprintf(pf, sizeof(pf), "%s/%s__%d.last", PID_DIR, ue->d_name, pids[i]);
                FILE *p=fopen(pf,"r"); if(p) { long long prev; fscanf(p,"%lld",&prev); fclose(p); delta+=(cur>=prev?cur-prev:cur); }
                p=fopen(pf,"w"); if(p) { fprintf(p,"%lld\n",cur); fclose(p); }
            }
            
            char usf[512]; snprintf(usf, sizeof(usf), "%s/%s.usage", BW_DIR, ue->d_name);
            long long acc=0; FILE *af=fopen(usf,"r"); if(af) { fscanf(af,"%lld",&acc); fclose(af); }
            long long ntotal=acc+delta;
            af=fopen(usf,"w"); if(af) { fprintf(af,"%lld\n",ntotal); fclose(af); }
            
            long long quota=(long long)(bw_gb*1073741824.0);
            if(ntotal>=quota) {
                char cmd[1024]; snprintf(cmd, sizeof(cmd), "passwd -S %s 2>/dev/null | grep -q 'L' || (usermod -L %s 2>/dev/null && killall -u %s -9 2>/dev/null && echo '$(date) - BLOCKED: BW %.1fGB' >> %s/%s)", ue->d_name, ue->d_name, ue->d_name, bw_gb, BANNED_DIR, ue->d_name);
                system(cmd);
            }
        }
        closedir(ud); sleep(SCAN_INTERVAL);
    }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-bandwidth-c /tmp/bw_monitor.c 2>/dev/null
    rm -f /tmp/bw_monitor.c
    
    if [ -f /usr/local/bin/elite-x-bandwidth-c ]; then
        chmod +x /usr/local/bin/elite-x-bandwidth-c
        cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X C Bandwidth Monitor
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
        echo -e "${GREEN}✅ C Bandwidth Monitor compiled${NC}"
    else
        echo -e "${RED}❌ Bandwidth Monitor failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C CONNECTION MONITOR
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

int is_numeric(const char *str) { for(;*str;str++) if(!isdigit(*str)) return 0; return 1; }

int get_conn(const char *username) {
    int count=0;
    DIR *proc=opendir("/proc"); if(!proc) return 0;
    struct dirent *e;
    while((e=readdir(proc))) {
        if(!is_numeric(e->d_name)) continue;
        int pid=atoi(e->d_name);
        char cp[256]; snprintf(cp, sizeof(cp), "/proc/%d/comm", pid);
        FILE *f=fopen(cp,"r"); if(!f) continue;
        char comm[256]={0}; fgets(comm, sizeof(comm), f); fclose(f); comm[strcspn(comm,"\n")]=0;
        if(strcmp(comm,"sshd")==0) {
            char sp[256]; snprintf(sp, sizeof(sp), "/proc/%d/status", pid);
            FILE *sf=fopen(sp,"r"); if(!sf) continue;
            char line[256], uid_str[32]={0};
            while(fgets(line, sizeof(line), sf)) if(strncmp(line,"Uid:",4)==0) { sscanf(line,"%*s %s",uid_str); break; }
            fclose(sf);
            struct passwd *pw=getpwuid(atoi(uid_str));
            if(pw && strcmp(pw->pw_name, username)==0) {
                char stp[256]; snprintf(stp, sizeof(stp), "/proc/%d/stat", pid);
                FILE *stf=fopen(stp,"r"); if(stf) { int ppid; char sb[1024]; fgets(sb,sizeof(sb),stf); sscanf(sb,"%*d %*s %*c %d",&ppid); fclose(stf); if(ppid!=1) count++; }
            }
        }
    }
    closedir(proc); return count;
}

void del_user(const char *username, const char *reason) {
    char cmd[2048]; snprintf(cmd, sizeof(cmd), "cp %s/%s %s/%s_$(date +%%Y%%m%%d_%%H%%M%%S) 2>/dev/null; pkill -u %s 2>/dev/null; killall -u %s -9 2>/dev/null; userdel -r %s 2>/dev/null; rm -f %s/%s /etc/elite-x/data_usage/%s %s/%s %s/%s %s/%s.usage; rm -f %s/%s__*.last 2>/dev/null; logger -t 'elite-x' 'Auto-deleted: %s (%s)'", USER_DB, username, DELETED_DIR, username, username, username, username, USER_DB, username, username, CONN_DB, username, BANNED_DIR, username, BW_DIR, username, PID_DIR, username, username, reason);
    system(cmd);
}

int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    mkdir(CONN_DB,0755); mkdir(BANNED_DIR,0755); mkdir(DELETED_DIR,0755); mkdir(BW_DIR,0755); mkdir(PID_DIR,0755);
    
    while(running) {
        time_t now=time(NULL);
        DIR *ud=opendir(USER_DB); if(!ud) { sleep(SCAN_INTERVAL); continue; }
        struct dirent *ue;
        while((ue=readdir(ud))) {
            if(ue->d_name[0]=='.') continue;
            struct passwd *pw=getpwnam(ue->d_name);
            if(!pw) { char c[512]; snprintf(c,sizeof(c),"rm -f %s/%s",USER_DB,ue->d_name); system(c); continue; }
            
            char uf[512]; snprintf(uf,sizeof(uf),"%s/%s",USER_DB,ue->d_name);
            FILE *u=fopen(uf,"r"); if(!u) continue;
            char ed[32]={0}; int cl=1; char line[256];
            while(fgets(line,sizeof(line),u)) { if(strncmp(line,"Expire:",7)==0) sscanf(line+8,"%s",ed); else if(strncmp(line,"Conn_Limit:",11)==0) sscanf(line+12,"%d",&cl); }
            fclose(u);
            
            if(strlen(ed)>0) { struct tm tm={0}; if(strptime(ed,"%Y-%m-%d",&tm)) { if(now>mktime(&tm)) { char r[256]; snprintf(r,sizeof(r),"Expired %s",ed); del_user(ue->d_name,r); continue; } } }
            
            int cc=get_conn(ue->d_name);
            char cf[512]; snprintf(cf,sizeof(cf),"%s/%s",CONN_DB,ue->d_name);
            FILE *cff=fopen(cf,"w"); if(cff) { fprintf(cff,"%d\n",cc); fclose(cff); }
            
            FILE *af=fopen(AUTOBAN_FLAG,"r"); int ab=0; if(af) { fscanf(af,"%d",&ab); fclose(af); }
            if(cc>cl && ab==1) { char lc[1024]; snprintf(lc,sizeof(lc),"passwd -S %s 2>/dev/null | grep -q 'L' || (usermod -L %s 2>/dev/null && pkill -u %s 2>/dev/null && echo '$(date) - BLOCKED: %d/%d' >> %s/%s)", ue->d_name, ue->d_name, ue->d_name, cc, cl, BANNED_DIR, ue->d_name); system(lc); }
        }
        closedir(ud); sleep(SCAN_INTERVAL);
    }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-connmon-c /tmp/conn_monitor.c 2>/dev/null
    rm -f /tmp/conn_monitor.c
    
    if [ -f /usr/local/bin/elite-x-connmon-c ]; then
        chmod +x /usr/local/bin/elite-x-connmon-c
        cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X C Connection Monitor
After=network.target ssh.service
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
        echo -e "${GREEN}✅ C Connection Monitor compiled${NC}"
    else
        echo -e "${RED}❌ Connection Monitor failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C NETWORK BOOSTER
# ═══════════════════════════════════════════════════════════
create_c_network_booster() {
    echo -e "${YELLOW}📝 Compiling C Network Booster...${NC}"
    
    cat > /tmp/net_booster.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
void apply() {
    system("sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1");
    system("sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1");
    system("sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_rmem='4096 87380 134217728' >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_wmem='4096 65536 134217728' >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_mtu_probing=1 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1");
    system("sysctl -w net.core.somaxconn=8192 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_max_syn_backlog=8192 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_tw_reuse=1 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_fin_timeout=10 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.tcp_keepalive_time=60 >/dev/null 2>&1");
    system("sysctl -w net.ipv4.udp_mem='65536 131072 262144' >/dev/null 2>&1");
    fprintf(stderr, "C Network Booster: Applied\n");
}
int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    apply();
    while(running) { sleep(3600); if(running) apply(); }
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/elite-x-netbooster /tmp/net_booster.c 2>/dev/null
    rm -f /tmp/net_booster.c
    
    if [ -f /usr/local/bin/elite-x-netbooster ]; then
        chmod +x /usr/local/bin/elite-x-netbooster
        cat > /etc/systemd/system/elite-x-netbooster.service <<EOF
[Unit]
Description=ELITE-X C Network Booster
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-netbooster
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Network Booster compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C DNS CACHE
# ═══════════════════════════════════════════════════════════
create_c_dns_cache() {
    echo -e "${YELLOW}📝 Compiling C DNS Cache...${NC}"
    cat > /tmp/dns_cache.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    while(running) {
        system("resolvectl flush-caches 2>/dev/null || true");
        sleep(1800);
    }
    return 0;
}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-dnscache /tmp/dns_cache.c 2>/dev/null
    rm -f /tmp/dns_cache.c
    if [ -f /usr/local/bin/elite-x-dnscache ]; then
        chmod +x /usr/local/bin/elite-x-dnscache
        cat > /etc/systemd/system/elite-x-dnscache.service <<EOF
[Unit]
Description=ELITE-X C DNS Cache
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-dnscache
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C DNS Cache compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C RAM CLEANER
# ═══════════════════════════════════════════════════════════
create_c_ram_cleaner() {
    echo -e "${YELLOW}📝 Compiling C RAM Cleaner...${NC}"
    cat > /tmp/ram_cleaner.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    while(running) {
        system("sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null");
        sleep(900);
    }
    return 0;
}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-ramcleaner /tmp/ram_cleaner.c 2>/dev/null
    rm -f /tmp/ram_cleaner.c
    if [ -f /usr/local/bin/elite-x-ramcleaner ]; then
        chmod +x /usr/local/bin/elite-x-ramcleaner
        cat > /etc/systemd/system/elite-x-ramcleaner.service <<EOF
[Unit]
Description=ELITE-X C RAM Cleaner
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
        echo -e "${GREEN}✅ C RAM Cleaner compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C IRQ OPTIMIZER
# ═══════════════════════════════════════════════════════════
create_c_irq_optimizer() {
    echo -e "${YELLOW}📝 Compiling C IRQ Optimizer...${NC}"
    cat > /tmp/irq_optimizer.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    while(running) {
        system("for i in /sys/class/net/eth*/queues/rx-*/rps_cpus /sys/class/net/ens*/queues/rx-*/rps_cpus; do echo ffffffff > $i 2>/dev/null; done");
        sleep(600);
    }
    return 0;
}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-irqopt /tmp/irq_optimizer.c 2>/dev/null
    rm -f /tmp/irq_optimizer.c
    if [ -f /usr/local/bin/elite-x-irqopt ]; then
        chmod +x /usr/local/bin/elite-x-irqopt
        cat > /etc/systemd/system/elite-x-irqopt.service <<EOF
[Unit]
Description=ELITE-X C IRQ Optimizer
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-irqopt
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C IRQ Optimizer compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C DATA USAGE
# ═══════════════════════════════════════════════════════════
create_c_data_usage() {
    echo -e "${YELLOW}📝 Compiling C Data Usage...${NC}"
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
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    while(running) {
        DIR *ud=opendir("/etc/elite-x/users"); if(!ud) { sleep(30); continue; }
        struct dirent *e;
        while((e=readdir(ud))) {
            if(e->d_name[0]=='.') continue;
            char bf[512]; snprintf(bf,sizeof(bf),"/etc/elite-x/bandwidth/%s.usage",e->d_name);
            long long tb=0; FILE *f=fopen(bf,"r"); if(f) { fscanf(f,"%lld",&tb); fclose(f); }
            char uf[512]; snprintf(uf,sizeof(uf),"/etc/elite-x/data_usage/%s",e->d_name);
            f=fopen(uf,"w"); if(f) { fprintf(f,"total_gb: %.2f\n",tb/1073741824.0); fclose(f); }
        }
        closedir(ud); sleep(30);
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
Description=ELITE-X C Data Usage
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-datausage-c
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
        echo -e "${GREEN}✅ C Data Usage compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C LOG CLEANER
# ═══════════════════════════════════════════════════════════
create_c_log_cleaner() {
    echo -e "${YELLOW}📝 Compiling C Log Cleaner...${NC}"
    cat > /tmp/log_cleaner.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
static volatile int running = 1;
void signal_handler(int sig) { running = 0; }
int main() {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    while(running) {
        system("journalctl --vacuum-size=50M 2>/dev/null; find /var/log -name '*.gz' -mtime +3 -delete 2>/dev/null");
        sleep(3600);
    }
    return 0;
}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-logcleaner /tmp/log_cleaner.c 2>/dev/null
    rm -f /tmp/log_cleaner.c
    if [ -f /usr/local/bin/elite-x-logcleaner ]; then
        chmod +x /usr/local/bin/elite-x-logcleaner
        cat > /etc/systemd/system/elite-x-logcleaner.service <<EOF
[Unit]
Description=ELITE-X C Log Cleaner
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
        echo -e "${GREEN}✅ C Log Cleaner compiled${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# USER MANAGEMENT
# ═══════════════════════════════════════════════════════════
create_user_script() {
    cat > /usr/local/bin/elite-x-user <<'USEREOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';LIGHT_RED='\033[1;31m';LIGHT_GREEN='\033[1;32m';GRAY='\033[0;90m';NC='\033[0m'

UD="/etc/elite-x/users";USAGE_DB="/etc/elite-x/data_usage";DD="/etc/elite-x/deleted";BD="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections";BW_DIR="/etc/elite-x/bandwidth";PID_DIR="$BW_DIR/pidtrack"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
mkdir -p "$UD" "$USAGE_DB" "$DD" "$BD" "$CONN_DB" "$BW_DIR" "$PID_DIR"

get_conn() { local u="$1" c=0; who|grep -qw "$u" 2>/dev/null && c=$(who|grep -wc "$u"); [ "$c" -eq 0 ] && c=$(ps aux|grep "sshd:"|grep "$u"|grep -v grep|grep -v "sshd:.*@notty"|wc -l); echo ${c:-0}; }
get_bw() { local u="$1" f="$BW_DIR/${u}.usage"; if [ -f "$f" ]; then local b=$(cat "$f" 2>/dev/null||echo 0); echo "scale=2;$b/1073741824"|bc 2>/dev/null||echo "0.00"; else echo "0.00"; fi; }
get_remaining() {
    local ed="$1"
    [ -z "$ed" ] && { echo "No expiry"; return; }
    local et=$(date -d "$ed" +%s 2>/dev/null||echo 0) ct=$(date +%s)
    [ "$et" -le "$ct" ] && { echo "Expired"; return; }
    local ds=$((et-ct)) dd=$((ds/86400)) dh=$(((ds%86400)/3600))
    [ $dd -gt 0 ] && { local r="${dd}day"; [ $dd -gt 1 ] && r="${dd}days"; [ $dh -gt 0 ] && r="${r} + ${dh}hr"; echo "$r"; } || echo "${dh}hr"
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE SSH + DNS USER (ULTIMATE)                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    id "$u" &>/dev/null && { echo -e "${RED}Exists!${NC}"; return; }
    read -p "$(echo -e $GREEN"Password [auto]: "$NC)" p
    [ -z "$p" ] && p=$(head /dev/urandom|tr -dc 'A-Za-z0-9'|head -c 8) && echo -e "${GREEN}🔑 $p${NC}"
    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" d; d=${d:-30}
    [[ ! "$d" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid!${NC}"; return; }
    read -p "$(echo -e $GREEN"Conn limit [1]: "$NC)" cl; cl=${cl:-1}
    [[ ! "$cl" =~ ^[0-9]+$ ]] && cl=1
    read -p "$(echo -e $GREEN"BW limit GB (0=unlimited) [0]: "$NC)" bw; bw=${bw:-0}
    [[ ! "$bw" =~ ^[0-9]+\.?[0-9]*$ ]] && bw=0
    
    useradd -m -s /bin/false "$u"
    echo "$u:$p"|chpasswd
    ed=$(date -d "+$d days" +"%Y-%m-%d")
    chage -E "$ed" "$u"
    
    cat > "$UD/$u" <<INFO
Username: $u
Password: $p
Expire: $ed
Conn_Limit: $cl
Bandwidth_GB: $bw
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO
    echo "0" > "$BW_DIR/${u}.usage"
    
    local bw_d="Unlimited"; [ "$bw" != "0" ] && bw_d="${bw} GB"
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null||echo "?")
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null||echo "?")
    PUBKEY=$(cat /etc/elite-x/public_key 2>/dev/null||echo "?")
    rem=$(get_remaining "$ed")
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER CREATED SUCCESSFULLY                    ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  File Name   :${CYAN} $u${NC}"
    echo -e "${GREEN}║${WHITE}  Password    :${CYAN} $p${NC}"
    echo -e "${GREEN}║${WHITE}  Server NS   :${CYAN} $SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Server IP   :${CYAN} $IP${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key  :${CYAN} $PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE}  Limit GB    :${CYAN} $bw_d${NC}"
    echo -e "${GREEN}║${WHITE}  Connection  :${CYAN} Max $cl${NC}"
    echo -e "${GREEN}║${WHITE}  Expire      :${CYAN} $ed ($rem)${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  SLOWDNS CONFIG:${NC}"
    echo -e "${GREEN}║${WHITE}  NS    : ${CYAN}$SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY: ${CYAN}$PUBKEY${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                  ACTIVE USERS + BANDWIDTH + STATUS (ULTIMATE)                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    [ -z "$(ls -A "$UD" 2>/dev/null)" ] && { echo -e "${CYAN}║${RED}  No users${NC}"; echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"; return; }
    printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-14s %-20s${CYAN} ║${NC}\n" "FILE NAME" "EXPIRE" "LOGIN" "BANDWIDTH" "STATUS"
    echo -e "${CYAN}╟──────────────────────────────────────────────────────────────────────────────────────────────────────╢${NC}"
    for user in "$UD"/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user"|cut -d' ' -f2)
        limit=$(grep "Conn_Limit:" "$user"|awk '{print $2}'); limit=${limit:-1}
        bw_limit=$(grep "Bandwidth_GB:" "$user"|awk '{print $2}'); bw_limit=${bw_limit:-0}
        tg=$(get_bw "$u"); cc=$(get_conn "$u"); rem=$(get_remaining "$ex")
        et=$(date -d "$ex" +%s 2>/dev/null||echo 0); ct=$(date +%s); dl=$(((et-ct)/86400))
        
        if passwd -S "$u" 2>/dev/null|grep -q "L"; then st="${RED}🔒 LOCKED${NC}"
        elif [ "$cc" -gt 0 ]; then st="${LIGHT_GREEN}🟢 ONLINE${NC}"
        elif [ $dl -le 0 ]; then st="${RED}⛔ EXPIRED${NC}"
        elif [ $dl -le 3 ]; then st="${LIGHT_RED}⚠️ $rem${NC}"
        elif [ $dl -le 7 ]; then st="${YELLOW}⚠️ $rem${NC}"
        else st="${YELLOW}⚫ OFFLINE${NC}"; fi
        
        [ "$bw_limit" != "0" ] && [ -n "$bw_limit" ] && { bp=$(echo "scale=1;($tg/$bw_limit)*100"|bc 2>/dev/null||echo "0"); [ "$(echo "$bp>=100"|bc 2>/dev/null)" = "1" ] && bd="${RED}${tg}/${bw_limit}GB${NC}" || [ "$(echo "$bp>80"|bc 2>/dev/null)" = "1" ] && bd="${YELLOW}${tg}/${bw_limit}GB${NC}" || bd="${GREEN}${tg}/${bw_limit}GB${NC}"; } || bd="${GRAY}${tg}GB/∞${NC}"
        [ "$cc" -ge "$limit" ] && ld="${RED}${cc}/${limit}${NC}" || ld="${GREEN}${cc}/${limit}${NC}"; [ "$cc" -eq 0 ] && ld="${GRAY}0/${limit}${NC}"
        [ $dl -le 0 ] && ed="${RED}${ex}${NC}" || ed="${GREEN}${ex}${NC}"; [ $dl -le 7 ] && [ $dl -gt 0 ] && ed="${YELLOW}${ex}${NC}"
        printf "${CYAN}║${WHITE} %-14s %-12b %-8b %-14b %-20b${CYAN} ║${NC}\n" "$u" "$ed" "$ld" "$bd" "$st"
    done
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW}  📊 Users: ${GREEN}$(ls "$UD" 2>/dev/null|wc -l)${YELLOW} | Online: ${GREEN}$(who|wc -l)${NC}                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

details_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }
    clear
    tg=$(get_bw "$u"); bw=$(grep "Bandwidth_GB:" "$UD/$u" 2>/dev/null|awk '{print $2}'); bw=${bw:-0}
    cc=$(get_conn "$u"); ed=$(grep "Expire:" "$UD/$u" 2>/dev/null|awk '{print $2}')
    rem=$(get_remaining "$ed"); cl=$(grep "Conn_Limit:" "$UD/$u" 2>/dev/null|awk '{print $2}'); cl=${cl:-1}
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                   📋 USER ACCOUNT DETAILS                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  File Name   : ${GREEN}$u${NC}"
    echo -e "${CYAN}║${WHITE}  Limit GB    : ${YELLOW}${bw:-Unlimited} GB${NC}"
    echo -e "${CYAN}║${WHITE}  Usage GB    : ${CYAN}${tg} GB${NC}"
    echo -e "${CYAN}║${WHITE}  Connection  : ${PURPLE}${cc}/${cl} (Total connections on user ACCOUNT)${NC}"
    echo -e "${CYAN}║${WHITE}  Expire      : ${RED}${ed}${NC} (${GREEN}${rem}${NC})"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

renew_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; read -p "Days: " d; ce=$(grep "Expire:" "$UD/$u"|cut -d' ' -f2); ne=$(date -d "$ce +$d days" +"%Y-%m-%d"); sed -i "s/Expire: .*/Expire: $ne/" "$UD/$u"; chage -E "$ne" "$u" 2>/dev/null; usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Renewed: $ne ($(get_remaining "$ne"))${NC}"; }
set_bw() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; read -p "New BW limit (0=unlimited): " nb; [[ ! "$nb" =~ ^[0-9]+\.?[0-9]*$ ]] && { echo -e "${RED}Invalid${NC}"; return; }; grep -q "Bandwidth_GB:" "$UD/$u" && sed -i "s/Bandwidth_GB: .*/Bandwidth_GB: $nb/" "$UD/$u" || echo "Bandwidth_GB: $nb" >> "$UD/$u"; [ "$nb" = "0" ] && usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Updated${NC}"; }
reset_bw() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; echo "0" > "$BW_DIR/${u}.usage"; rm -rf "$PID_DIR/${u}" 2>/dev/null; rm -f "$PID_DIR/${u}__"*.last 2>/dev/null; usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Reset${NC}"; }
lock_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; usermod -L "$u" 2>/dev/null; pkill -u "$u" 2>/dev/null; echo "$(date) - LOCKED" >> "$BD/$u"; echo -e "${GREEN}✅ Locked${NC}"; }
unlock_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; usermod -U "$u" 2>/dev/null; echo "$(date) - UNLOCKED" >> "$BD/$u"; echo -e "${GREEN}✅ Unlocked${NC}"; }
delete_user() { read -p "Username: " u; [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found${NC}"; return; }; cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)"; pkill -u "$u" 2>/dev/null; killall -u "$u" -9 2>/dev/null; userdel -r "$u" 2>/dev/null; rm -f "$UD/$u" "$USAGE_DB/$u" "$CONN_DB/$u" "$BD/$u" "$BW_DIR/${u}.usage"; rm -rf "$PID_DIR/${u}" 2>/dev/null; echo -e "${GREEN}✅ Deleted${NC}"; }

case $1 in
    add) add_user ;;
    list) list_users ;;
    details) details_user ;;
    renew) renew_user ;;
    setlimit) read -p "Username: " u; read -p "New limit: " l; [ -f "$UD/$u" ] && { sed -i "s/Conn_Limit: .*/Conn_Limit: $l/" "$UD/$u"; echo -e "${GREEN}✅ Updated${NC}"; } || echo -e "${RED}Not found${NC}" ;;
    setbw) set_bw ;;
    resetdata) reset_bw ;;
    deleted) ls "$DD/" 2>/dev/null|head -20||echo "No deleted" ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    del) delete_user ;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setlimit|setbw|resetdata|deleted|lock|unlock|del}" ;;
esac
USEREOF
    chmod +x /usr/local/bin/elite-x-user
}

# ═══════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════
create_main_menu() {
    cat > /usr/local/bin/elite-x <<'MENUEOF'
#!/bin/bash
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m';PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';LIGHT_RED='\033[1;31m';LIGHT_GREEN='\033[1;32m';GRAY='\033[0;90m';NC='\033[0m'

UD="/etc/elite-x/users";BW_DIR="/etc/elite-x/bandwidth";AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"

show_dashboard() {
    clear
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null||echo "?"); SUB=$(cat /etc/elite-x/subdomain 2>/dev/null||echo "?")
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null||echo "?"); MTU=$(cat /etc/elite-x/mtu 2>/dev/null||echo "?")
    RAM=$(free -h|awk '/^Mem:/{print $3"/"$2}')
    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    BW=$(systemctl is-active elite-x-bandwidth 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    NB=$(systemctl is-active elite-x-netbooster 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    DC=$(systemctl is-active elite-x-dnscache 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    RC=$(systemctl is-active elite-x-ramcleaner 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    IQ=$(systemctl is-active elite-x-irqopt 2>/dev/null|grep -q active && echo "${GREEN}●${NC}"||echo "${RED}●${NC}")
    TU=$(ls -1 "$UD" 2>/dev/null|wc -l); ON=$(who|wc -l)
    TB=0
    [ -d "$BW_DIR" ] && for f in "$BW_DIR"/*.usage; do [ -f "$f" ] && { b=$(cat "$f" 2>/dev/null||echo 0); gb=$(echo "scale=2;$b/1073741824"|bc 2>/dev/null||echo "0"); TB=$(echo "$TB+$gb"|bc 2>/dev/null||echo "$TB"); }; done
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}     ELITE-X v3.3.3 - FALCON ULTIMATE EDITION     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  NS:${GREEN} $SUB  ${WHITE}IP:${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location:${GREEN} $LOCATION${WHITE}  MTU:${GREEN} $MTU${WHITE}  RAM:${GREEN} $RAM${NC}"
    echo -e "${PURPLE}║${WHITE}  Core: DNS:$DNS PRX:$PRX BW:$BW${NC}"
    echo -e "${PURPLE}║${WHITE}  Boost: NET:$NB DNS:$DC RAM:$RC IRQ:$IQ${NC}"
    echo -e "${PURPLE}║${WHITE}  Users:${GREEN} $TU ${WHITE}| Online:${GREEN} $ON ${WHITE}| BW:${YELLOW} ${TB}GB${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

settings_menu() {
    while true; do
        clear
        autoban=$(cat "$AUTOBAN_FLAG" 2>/dev/null||echo "0")
        [ "$autoban" = "1" ] && AS="${RED}ON${NC}" || AS="${GREEN}OFF${NC}"
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}                 SETTINGS MENU                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Change MTU  [2] Speed Optimize  [3] Clean Cache${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] 🎨 Banner Manager  [5] Traffic Stats${NC}"
        echo -e "${PURPLE}║${WHITE}  [6] Reset All BW  [7] Auto-Ban: $AS${NC}"
        echo -e "${PURPLE}║${WHITE}  [8] Restart All   [9] Reboot  [10] Uninstall${NC}"
        echo -e "${PURPLE}║${WHITE}  [11] Recompile C   [0] Back${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        case $ch in
            1) read -p "MTU (1000-5000): " m; [[ "$m" =~ ^[0-9]+$ ]] && [ $m -ge 1000 ] && [ $m -le 5000 ] && { echo "$m">/etc/elite-x/mtu; sed -i "s/-mtu [0-9]*/-mtu $m/" /etc/systemd/system/dnstt-elite-x.service; systemctl daemon-reload; systemctl restart dnstt-elite-x dnstt-elite-x-proxy; echo -e "${GREEN}✅ Done${NC}"; }||echo -e "${RED}Invalid${NC}"; read -p "Enter..." ;;
            2) sysctl -w net.core.default_qdisc=fq net.ipv4.tcp_congestion_control=bbr net.core.rmem_max=134217728 net.core.wmem_max=134217728 net.ipv4.tcp_fastopen=3 >/dev/null 2>&1; systemctl restart elite-x-netbooster 2>/dev/null; echo -e "${GREEN}✅ Optimized${NC}"; read -p "Enter..." ;;
            3) sync; echo 3>/proc/sys/vm/drop_caches 2>/dev/null; systemctl restart elite-x-ramcleaner 2>/dev/null; echo -e "${GREEN}✅ Cleaned${NC}"; read -p "Enter..." ;;
            4) manage_banners ;;
            5) ix=$(ip route|grep default|awk '{print $5}'|head -1); rx=$(cat /sys/class/net/$ix/statistics/rx_bytes 2>/dev/null||echo 0); tx=$(cat /sys/class/net/$ix/statistics/tx_bytes 2>/dev/null||echo 0); echo -e "RX: $(echo "scale=2;$rx/1073741824"|bc) GB"; echo -e "TX: $(echo "scale=2;$tx/1073741824"|bc) GB"; read -p "Enter..." ;;
            6) for f in "$BW_DIR"/*.usage; do [ -f "$f" ] && echo "0">"$f"; done; for u in "$UD"/*; do [ -f "$u" ] && usermod -U "$(basename "$u")" 2>/dev/null; done; echo -e "${GREEN}✅ Reset${NC}"; read -p "Enter..." ;;
            7) [ "$autoban" = "1" ] && echo "0">"$AUTOBAN_FLAG"||echo "1">"$AUTOBAN_FLAG"; systemctl restart elite-x-connmon 2>/dev/null; echo -e "${GREEN}✅ Toggled${NC}"; read -p "Enter..." ;;
            8) for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner sshd; do systemctl restart "$s" 2>/dev/null||true; done; echo -e "${GREEN}✅ Restarted${NC}"; read -p "Enter..." ;;
            9) read -p "Reboot? (y/n): " c; [ "$c" = "y" ] && reboot ;;
            10) read -p "Type YES: " c; [ "$c" = "YES" ] && { for u in "$UD"/*; do [ -f "$u" ] && { un=$(basename "$u"); pkill -u "$un" 2>/dev/null; userdel -r "$un" 2>/dev/null; }; done; for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner; do systemctl stop "$s" 2>/dev/null; systemctl disable "$s" 2>/dev/null; done; rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*}; rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x; rm -f /usr/local/bin/{dnstt-*,elite-x*}; sed -i '/^Banner/d' /etc/ssh/sshd_config; rm -f /etc/profile.d/elite-x-*.sh; sed -i '/elite-x/d' ~/.bashrc; systemctl daemon-reload; echo -e "${GREEN}✅ Uninstalled${NC}"; exit 0; }; read -p "Enter..." ;;
            11) create_c_edns_proxy; create_c_bandwidth_monitor; create_c_connection_monitor; create_c_network_booster; create_c_dns_cache; create_c_ram_cleaner; create_c_irq_optimizer; create_c_log_cleaner; create_c_data_usage; systemctl daemon-reload; for s in dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner elite-x-datausage; do systemctl restart "$s" 2>/dev/null||true; done; echo -e "${GREEN}✅ Recompiled${NC}"; read -p "Enter..." ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}               MAIN MENU v3.3.3                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Create User   [2] List Users      [3] User Details${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Renew User    [5] Set Conn Limit   [6] Set BW Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset BW      [8] Lock User        [9] Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] Delete User  [11] Deleted List     [S] Settings${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Exit${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch
        case $ch in
            1) elite-x-user add; read -p "Enter..." ;;
            2) elite-x-user list; read -p "Enter..." ;;
            3) elite-x-user details; read -p "Enter..." ;;
            4) elite-x-user renew; read -p "Enter..." ;;
            5) elite-x-user setlimit; read -p "Enter..." ;;
            6) elite-x-user setbw; read -p "Enter..." ;;
            7) elite-x-user resetdata; read -p "Enter..." ;;
            8) elite-x-user lock; read -p "Enter..." ;;
            9) elite-x-user unlock; read -p "Enter..." ;;
            10) elite-x-user del; read -p "Enter..." ;;
            11) elite-x-user deleted; read -p "Enter..." ;;
            [Ss]) settings_menu ;;
            0) echo -e "${GREEN}Bye!${NC}"; exit 0 ;;
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
show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

if [ "$ACTIVATION_INPUT" != "$ACTIVATION_KEY" ] && [ "$ACTIVATION_INPUT" != "Whtsapp +255713-628-668" ]; then
    echo -e "${RED}❌ Invalid key!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Activated${NC}"
sleep 1

set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR NAMESERVER [NS]                    ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $GREEN"Nameserver: "$NC)" TDOMAIN

echo -e "${YELLOW}Select VPS location:${NC}"
echo -e "  [1] South Africa (MTU 1800)"
echo -e "  [2] USA (MTU 1500)"
echo -e "  [3] Europe (MTU 1500)"
echo -e "  [4] Asia (MTU 1400)"
echo -e "  [5] Custom MTU"
read -p "$(echo -e $GREEN"Choice [1]: "$NC)" LOC; LOC=${LOC:-1}
case $LOC in
    2) SEL_LOC="USA"; MTU=1500 ;; 3) SEL_LOC="Europe"; MTU=1500 ;;
    4) SEL_LOC="Asia"; MTU=1400 ;; 5) SEL_LOC="Custom"; read -p "MTU: " MTU; [[ ! "$MTU" =~ ^[0-9]+$ ]] && MTU=1800 ;;
    *) SEL_LOC="South Africa"; MTU=1800 ;;
esac

echo -e "${YELLOW}🔄 Cleaning...${NC}"
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-{bandwidth,datausage,connmon,cleaner,traffic,netbooster,dnscache,ramcleaner,irqopt,logcleaner} 3proxy-elite; do
    systemctl stop "$s" 2>/dev/null||true; systemctl disable "$s" 2>/dev/null||true
done
pkill -f dnstt-server 2>/dev/null||true; pkill -f elite-x-edns-proxy 2>/dev/null||true
rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*,3proxy-elite*} 2>/dev/null
rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x 2>/dev/null
rm -f /usr/local/bin/{dnstt-*,elite-x*,3proxy} 2>/dev/null
rm -f /etc/ssh/sshd_config.d/elite-x-vpn.conf 2>/dev/null
rm -f /etc/sysctl.d/99-elite-x-vpn.conf 2>/dev/null
rm -f /etc/profile.d/elite-x-*.sh 2>/dev/null
sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null
systemctl restart sshd 2>/dev/null||true
sleep 2

# Create directories
mkdir -p /etc/elite-x/{banner,users,deleted,data_usage,connections,banned,bandwidth/pidtrack,server_msg}
mkdir -p /var/run/elite-x/bandwidth
echo "$TDOMAIN">/etc/elite-x/subdomain
echo "$SEL_LOC">/etc/elite-x/location
echo "$MTU">/etc/elite-x/mtu
echo "0">"$AUTOBAN_FLAG"
echo "$STATIC_PRIVATE_KEY">/etc/elite-x/private_key
echo "$STATIC_PUBLIC_KEY">/etc/elite-x/public_key

# Setup banner system
setup_banner_system

# Configure DNS
[ -f /etc/systemd/resolved.conf ] && { sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf; systemctl restart systemd-resolved 2>/dev/null||true; }
[ -L /etc/resolv.conf ] && rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8">/etc/resolv.conf
echo "nameserver 8.8.4.4">>/etc/resolv.conf

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y
apt install -y curl jq iptables ethtool dnsutils net-tools iproute2 bc build-essential git gcc make 2>/dev/null

setup_c_compiler

# Download DNSTT
echo -e "${YELLOW}📥 Downloading DNSTT...${NC}"
curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null || {
    curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null
}
chmod +x /usr/local/bin/dnstt-server

# Setup DNSTT keys
mkdir -p /etc/dnstt
echo "$STATIC_PRIVATE_KEY">/etc/dnstt/server.key
echo "$STATIC_PUBLIC_KEY">/etc/dnstt/server.pub
chmod 600 /etc/dnstt/server.key

# Create DNSTT service (SIMPLE - no extra configs that break connection)
cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=5
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF

# Create C-based EDNS proxy
create_c_edns_proxy

if [ -f /usr/local/bin/elite-x-edns-proxy ]; then
    cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X C EDNS Proxy
After=dnstt-elite-x.service
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-edns-proxy
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
fi

# Create all C monitors
create_c_bandwidth_monitor
create_c_connection_monitor
create_c_data_usage
create_c_network_booster
create_c_dns_cache
create_c_ram_cleaner
create_c_irq_optimizer
create_c_log_cleaner

# Create user scripts
create_user_script
create_main_menu

# Enable and start services
systemctl daemon-reload
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt elite-x-logcleaner; do
    [ -f "/etc/systemd/system/${s}.service" ] && { systemctl enable "$s" 2>/dev/null||true; systemctl start "$s" 2>/dev/null||true; }
done

# Cache IP
IP=$(curl -4 -s ifconfig.me 2>/dev/null||echo "Unknown")
echo "$IP">/etc/elite-x/cached_ip

# Dashboard only for root
cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
[ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ] && [ "$USER" = "root" ] && { export ELITE_X_SHOWN=1; /usr/local/bin/elite-x; }
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

# Aliases
cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
alias adduser='elite-x-user add'
alias users='elite-x-user list'
alias setbw='elite-x-user setbw'
alias boost='systemctl restart elite-x-netbooster elite-x-dnscache elite-x-ramcleaner elite-x-irqopt'
alias editbanner='nano /etc/elite-x/banner/ssh-banner && systemctl restart sshd'
alias editmsg='nano /etc/elite-x/server_msg/$(cat /etc/elite-x/server_msg/active)'
EOF

# ═══════════════════════════════════════════════════════════
# FINAL
# ═══════════════════════════════════════════════════════════
clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}  ELITE-X v3.3.3 FALCON ULTIMATE - INSTALLED!          ${GREEN}║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Domain :${CYAN} $TDOMAIN${NC}"
echo -e "${GREEN}║${WHITE}  IP     :${CYAN} $IP${NC}"
echo -e "${GREEN}║${WHITE}  MTU    :${CYAN} $MTU${NC}"
echo -e "${GREEN}║${WHITE}  PUBKEY :${CYAN} $STATIC_PUBLIC_KEY${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"

for s in "DNSTT:dnstt-elite-x" "EDNS:dnstt-elite-x-proxy" "SSH:sshd" "BW:elite-x-bandwidth" "Conn:elite-x-connmon" "Boost:elite-x-netbooster" "DNS:elite-x-dnscache" "RAM:elite-x-ramcleaner" "IRQ:elite-x-irqopt" "Log:elite-x-logcleaner"; do
    name="${s%%:*}"; svc="${s##*:}"
    systemctl is-active "$svc" >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ $name: Running${NC}" || echo -e "${RED}║  ❌ $name: Failed${NC}"
done

echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Commands: menu | users | adduser | setbw | boost${NC}"
echo -e "${YELLOW}Banners: editbanner | editmsg${NC}"
echo -e "${CYAN}📋 User sees on login:${NC}"
echo -e "${WHITE}  File Name | Limit GB | Usage GB | Connection | Expire (days+hrs)${NC}"
echo ""
echo -e "${CYAN}SLOWDNS CLIENT CONFIG:${NC}"
echo -e "${WHITE}  NS     : ${GREEN}$TDOMAIN${NC}"
echo -e "${WHITE}  PUBKEY : ${GREEN}$STATIC_PUBLIC_KEY${NC}"
