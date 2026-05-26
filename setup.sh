#!/bin/bash
# ╔══════════════════════╗
#  ELITE-X DNSTT  SCRIPT
# ╚══════════════════════╝
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

print_color() { echo -e "${2}${1}${NC}"; }

self_destruct() {
    echo -e "${YELLOW}🧹 Cleaning installation traces...${NC}"
    
    history -c 2>/dev/null || true
    cat /dev/null > ~/.bash_history 2>/dev/null || true
    cat /dev/null > /root/.bash_history 2>/dev/null || true
    
    if [ -f "$0" ] && [ "$0" != "/usr/local/bin/elite-x" ]; then
        local script_path=$(readlink -f "$0")
        rm -f "$script_path" 2>/dev/null || true
    fi
    
    sed -i '/Elite-X-dns.sh/d' /var/log/auth.log 2>/dev/null || true
    sed -i '/elite-x/d' /var/log/auth.log 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete!${NC}"
}

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_banner() {
    clear
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${YELLOW}${BOLD}                   ELITE-X SLOWDNS v3.0                        ${RED}║${NC}"
    echo -e "${RED}║${GREEN}${BOLD}                    Stable Edition                              ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

ACTIVATION_KEY="ELITE-X"
TEMP_KEY="ELITE-X-TEST-0208"
ACTIVATION_FILE="/etc/elite-x/activated"
ACTIVATION_TYPE_FILE="/etc/elite-x/activation_type"
ACTIVATION_DATE_FILE="/etc/elite-x/activation_date"
EXPIRY_DAYS_FILE="/etc/elite-x/expiry_days"
KEY_FILE="/etc/elite-x/key"
TIMEZONE="Africa/Dar_es_Salaam"

set_timezone() {
    timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true
}

check_expiry() {
    if [ -f "$ACTIVATION_TYPE_FILE" ] && [ -f "$ACTIVATION_DATE_FILE" ] && [ -f "$EXPIRY_DAYS_FILE" ]; then
        local act_type=$(cat "$ACTIVATION_TYPE_FILE")
        if [ "$act_type" = "temporary" ]; then
            local act_date=$(cat "$ACTIVATION_DATE_FILE")
            local expiry_days=$(cat "$EXPIRY_DAYS_FILE")
            local current_date=$(date +%s)
            local expiry_date=$(date -d "$act_date + $expiry_days days" +%s)
            
            if [ $current_date -ge $expiry_date ]; then
                echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║${YELLOW}           TRIAL PERIOD EXPIRED                                  ${RED}║${NC}"
                echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${RED}║${WHITE}  Your 2-day trial has ended.                                  ${RED}║${NC}"
                echo -e "${RED}║${WHITE}  Script will now uninstall itself...                         ${RED}║${NC}"
                echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
                sleep 3
                      
                systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner 2>/dev/null || true
                systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner 2>/dev/null || true
                rm -f /etc/systemd/system/{dnstt-elite-x*,elite-x-*}
                rm -rf /etc/dnstt /etc/elite-x
                rm -f /usr/local/bin/{dnstt-*,elite-x*}
                sed -i '/^Banner/d' /etc/ssh/sshd_config
                systemctl restart sshd

                rm -f "$0"
                echo -e "${GREEN}✅ ELITE-X has been uninstalled.${NC}"
                exit 0
            else
                local days_left=$(( (expiry_date - current_date) / 86400 ))
                local hours_left=$(( ((expiry_date - current_date) % 86400) / 3600 ))
                echo -e "${YELLOW}⚠️  Trial: $days_left days $hours_left hours remaining${NC}"
            fi
        fi
    fi
}

activate_script() {
    local input_key="$1"
    mkdir -p /etc/elite-x
    
    if [ "$input_key" = "$ACTIVATION_KEY" ] || [ "$input_key" = "Whtsapp 0713628668" ]; then
        echo "$ACTIVATION_KEY" > "$ACTIVATION_FILE"
        echo "$ACTIVATION_KEY" > "$KEY_FILE"
        echo "lifetime" > "$ACTIVATION_TYPE_FILE"
        echo "Lifetime" > /etc/elite-x/expiry
        return 0
    elif [ "$input_key" = "$TEMP_KEY" ]; then
        echo "$TEMP_KEY" > "$ACTIVATION_FILE"
        echo "$TEMP_KEY" > "$KEY_FILE"
        echo "temporary" > "$ACTIVATION_TYPE_FILE"
        echo "$(date +%Y-%m-%d)" > "$ACTIVATION_DATE_FILE"
        echo "2" > "$EXPIRY_DAYS_FILE"
        echo "2 Days Trial" > /etc/elite-x/expiry
        return 0
    fi
    return 1
}

check_subdomain() {
    local subdomain="$1"
    local vps_ip=$(curl -4 -s ifconfig.me 2>/dev/null || echo "")
    
    echo -e "${YELLOW}🔍 Checking if subdomain points to this VPS (IPv4)...${NC}"
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  Subdomain: $subdomain${NC}"
    echo -e "${CYAN}║${WHITE}  VPS IPv4 : $vps_ip${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    if [ -z "$vps_ip" ]; then
        echo -e "${YELLOW}⚠️  Could not detect VPS IPv4, continuing anyway...${NC}"
        return 0
    fi

    local resolved_ip=$(dig +short -4 "$subdomain" 2>/dev/null | head -1)
    
    if [ -z "$resolved_ip" ]; then
        echo -e "${YELLOW}⚠️  Could not resolve subdomain, continuing anyway...${NC}"
        echo -e "${YELLOW}⚠️  Make sure your subdomain points to: $vps_ip${NC}"
        return 0
    fi
    
    if [ "$resolved_ip" = "$vps_ip" ]; then
        echo -e "${GREEN}✅ Subdomain correctly points to this VPS!${NC}"
        return 0
    else
        echo -e "${RED}❌ Subdomain points to $resolved_ip, but VPS IP is $vps_ip${NC}"
        echo -e "${YELLOW}⚠️  Please update your DNS record and try again${NC}"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [ "$continue_anyway" != "y" ]; then
            exit 1
        fi
    fi
}

create_c_user_tool() {
    echo -e "${YELLOW}📝 Compiling C elite-x-user...${NC}"
    cat > /tmp/elite-x-user.c << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <pwd.h>
#include <ctype.h>

#define RED     "\033[0;31m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[1;33m"
#define CYAN    "\033[0;36m"
#define WHITE   "\033[1;37m"
#define BOLD    "\033[1m"
#define NC      "\033[0m"

#define USER_DB  "/etc/elite-x/users"
#define TRAFFIC  "/etc/elite-x/traffic"
#define BW_DIR   "/etc/elite-x/bandwidth"
#define CONN_DB  "/etc/elite-x/connections"

/* ── helpers ─────────────────────────────────────────────── */
static int is_numeric(const char *s){for(;*s;s++) if(!isdigit(*s)) return 0; return 1;}

static int get_connection_count(const char *username){
    int count=0;
    DIR *proc=opendir("/proc"); if(!proc) return 0;
    struct dirent *e;
    while((e=readdir(proc))){
        if(!is_numeric(e->d_name)) continue;
        int pid=atoi(e->d_name);
        char path[256]; snprintf(path,sizeof(path),"/proc/%d/comm",pid);
        FILE *f=fopen(path,"r"); if(!f) continue;
        char comm[64]={0}; fgets(comm,sizeof(comm),f); fclose(f);
        comm[strcspn(comm,"\n")]=0;
        if(strcmp(comm,"sshd")!=0) continue;
        /* check uid */
        snprintf(path,sizeof(path),"/proc/%d/status",pid);
        f=fopen(path,"r"); if(!f) continue;
        char line[256],uid_s[32]={0};
        while(fgets(line,sizeof(line),f))
            if(strncmp(line,"Uid:",4)==0){sscanf(line,"%*s %s",uid_s);break;}
        fclose(f);
        struct passwd *pw=getpwuid(atoi(uid_s));
        if(!pw||strcmp(pw->pw_name,username)!=0) continue;
        /* exclude init children (ppid==1) */
        snprintf(path,sizeof(path),"/proc/%d/stat",pid);
        f=fopen(path,"r"); if(!f){count++;continue;}
        char buf[1024]; fgets(buf,sizeof(buf),f); fclose(f);
        int ppid=0; sscanf(buf,"%*d %*s %*c %d",&ppid);
        if(ppid!=1) count++;
    }
    closedir(proc);
    return count;
}

static double get_bandwidth_gb(const char *username){
    char path[512]; snprintf(path,sizeof(path),"%s/%s.usage",BW_DIR,username);
    FILE *f=fopen(path,"r"); if(!f) return 0.0;
    long long bytes=0; fscanf(f,"%lld",&bytes); fclose(f);
    return (double)bytes/1073741824.0;
}

static void read_field(const char *filepath,const char *key,char *out,int outsz){
    out[0]=0;
    FILE *f=fopen(filepath,"r"); if(!f) return;
    char line[256];
    while(fgets(line,sizeof(line),f)){
        if(strncmp(line,key,strlen(key))==0){
            char *v=line+strlen(key);
            while(*v==' '||*v=='\t') v++;
            v[strcspn(v,"\r\n")]=0;
            strncpy(out,v,outsz-1);
            break;
        }
    }
    fclose(f);
}

static void show_quote(){
    printf("\n");
    printf(CYAN "╔═══════════════════════════════════════════════════════════════╗\n" NC);
    printf(CYAN "║" YELLOW BOLD "                                                               " CYAN "║\n" NC);
    printf(CYAN "║" WHITE "            Always Remember ELITE-X when you see X            " CYAN "║\n" NC);
    printf(CYAN "║" YELLOW BOLD "                                                               " CYAN "║\n" NC);
    printf(CYAN "╚═══════════════════════════════════════════════════════════════╝\n" NC);
    printf("\n");
}

/* ── add_user ────────────────────────────────────────────── */
static void add_user(){
    system("clear");
    printf(CYAN "╔═══════════════════════════════════════════════════════════════╗\n" NC);
    printf(CYAN "║" YELLOW "              CREATE SSH + DNS USER                            " CYAN "║\n" NC);
    printf(CYAN "╚═══════════════════════════════════════════════════════════════╝\n" NC);

    char username[64]={0},password[64]={0},days_s[16]={0},conn_s[16]={0},traffic_s[32]={0};

    printf(GREEN "Username: " NC); fflush(stdout); fgets(username,sizeof(username),stdin); username[strcspn(username,"\r\n")]=0;
    printf(GREEN "Password: " NC); fflush(stdout); fgets(password,sizeof(password),stdin); password[strcspn(password,"\r\n")]=0;
    printf(GREEN "Expire days: " NC); fflush(stdout); fgets(days_s,sizeof(days_s),stdin); days_s[strcspn(days_s,"\r\n")]=0;
    printf(GREEN "Connection limit [1]: " NC); fflush(stdout); fgets(conn_s,sizeof(conn_s),stdin); conn_s[strcspn(conn_s,"\r\n")]=0;
    if(strlen(conn_s)==0||!is_numeric(conn_s)) strcpy(conn_s,"1");
    printf(GREEN "Bandwidth limit GB (0=unlimited): " NC); fflush(stdout); fgets(traffic_s,sizeof(traffic_s),stdin); traffic_s[strcspn(traffic_s,"\r\n")]=0;
    if(strlen(traffic_s)==0) strcpy(traffic_s,"0");

    /* check if user exists */
    char cmd[512];
    snprintf(cmd,sizeof(cmd),"id '%s' >/dev/null 2>&1",username);
    if(system(cmd)==0){ printf(RED "User already exists!\n" NC); return; }

    int days=atoi(days_s);
    time_t now=time(NULL); struct tm *tm=localtime(&now);
    tm->tm_mday+=days; mktime(tm);
    char expire[16]; strftime(expire,sizeof(expire),"%Y-%m-%d",tm);

    snprintf(cmd,sizeof(cmd),"useradd -m -s /bin/false '%s'",username); system(cmd);
    snprintf(cmd,sizeof(cmd),"echo '%s:%s' | chpasswd",username,password); system(cmd);
    snprintf(cmd,sizeof(cmd),"chage -E '%s' '%s'",expire,username); system(cmd);

    /* write user file */
    char upath[512]; snprintf(upath,sizeof(upath),"%s/%s",USER_DB,username);
    FILE *uf=fopen(upath,"w");
    if(uf){
        fprintf(uf,"Username: %s\nPassword: %s\nExpire: %s\nConn_Limit: %s\nBandwidth_GB: %s\nCreated: ",
                username,password,expire,conn_s,traffic_s);
        char dt[32]; time_t t=time(NULL); strftime(dt,sizeof(dt),"%Y-%m-%d",localtime(&t));
        fprintf(uf,"%s\n",dt);
        fclose(uf);
    }

    /* init bandwidth usage file */
    char bwpath[512]; snprintf(bwpath,sizeof(bwpath),"%s/%s.usage",BW_DIR,username);
    FILE *bf=fopen(bwpath,"w"); if(bf){fprintf(bf,"0\n");fclose(bf);}

    /* init traffic file */
    char tpath[512]; snprintf(tpath,sizeof(tpath),"%s/%s",TRAFFIC,username);
    FILE *tf=fopen(tpath,"w"); if(tf){fprintf(tf,"0\n");fclose(tf);}

    char server[256]={0},pubkey[256]={0};
    FILE *sf=fopen("/etc/elite-x/subdomain","r"); if(sf){fgets(server,sizeof(server),sf);server[strcspn(server,"\r\n")]=0;fclose(sf);}else strcpy(server,"?");
    sf=fopen("/etc/dnstt/server.pub","r"); if(sf){fgets(pubkey,sizeof(pubkey),sf);pubkey[strcspn(pubkey,"\r\n")]=0;fclose(sf);}else strcpy(pubkey,"Not generated");

    const char *bw_disp=(strcmp(traffic_s,"0")==0)?"Unlimited":traffic_s;

    system("clear");
    printf(GREEN "╔═══════════════════════════════════════════════════════════════╗\n" NC);
    printf(GREEN "║" YELLOW "                  USER DETAILS                                   " GREEN "║\n" NC);
    printf(GREEN "╠═══════════════════════════════════════════════════════════════╣\n" NC);
    printf(GREEN "║" WHITE "  Username  :" CYAN " %-46s" GREEN "║\n" NC, username);
    printf(GREEN "║" WHITE "  Password  :" CYAN " %-46s" GREEN "║\n" NC, password);
    printf(GREEN "║" WHITE "  Server    :" CYAN " %-46s" GREEN "║\n" NC, server);
    printf(GREEN "║" WHITE "  Public Key:" CYAN " %-46s" GREEN "║\n" NC, pubkey);
    printf(GREEN "║" WHITE "  Expire    :" CYAN " %-46s" GREEN "║\n" NC, expire);
    printf(GREEN "║" WHITE "  Max Login :" CYAN " %-46s" GREEN "║\n" NC, conn_s);
    printf(GREEN "║" WHITE "  Bandwidth :" CYAN " %-43s GB" GREEN "║\n" NC, bw_disp);
    printf(GREEN "╚═══════════════════════════════════════════════════════════════╝\n" NC);
    show_quote();
}

/* ── list_users ──────────────────────────────────────────── */
static void list_users(){
    system("clear");
    printf(CYAN "╔═══════════════════════════════════════════════════════════════╗\n" NC);
    printf(CYAN "║" YELLOW BOLD "                     ACTIVE USERS                               " CYAN "║\n" NC);
    printf(CYAN "╠═══════════════════════════════════════════════════════════════╣\n" NC);

    DIR *d=opendir(USER_DB);
    if(!d){ printf(RED "  No users found\n" NC); printf(CYAN "╚═══════════════════════════════════════════════════════════════╝\n" NC); return; }

    /* header */
    printf(CYAN "║" WHITE " %-14s %-12s %-8s %-14s %-10s" CYAN "║\n" NC,"USERNAME","EXPIRE","CONN","BANDWIDTH","STATUS");
    printf(CYAN "╟───────────────────────────────────────────────────────────────╢\n" NC);

    struct dirent *entry;
    int total=0,online=0;
    while((entry=readdir(d))){
        if(entry->d_name[0]=='.') continue;
        total++;
        char upath[512]; snprintf(upath,sizeof(upath),"%s/%s",USER_DB,entry->d_name);

        char expire[32]={0},conn_s[16]={0},bw_s[16]={0};
        read_field(upath,"Expire:",expire,sizeof(expire));
        read_field(upath,"Conn_Limit:",conn_s,sizeof(conn_s));
        read_field(upath,"Bandwidth_GB:",bw_s,sizeof(bw_s));

        int conn_limit=atoi(strlen(conn_s)?conn_s:"1");
        double bw_limit=atof(strlen(bw_s)?bw_s:"0");
        double used_gb=get_bandwidth_gb(entry->d_name);
        int cur_conn=get_connection_count(entry->d_name);
        if(cur_conn>0) online++;

        /* days left */
        int days_left=-1;
        if(strlen(expire)){
            struct tm etm={0}; sscanf(expire,"%d-%d-%d",&etm.tm_year,&etm.tm_mon,&etm.tm_mday);
            etm.tm_year-=1900; etm.tm_mon-=1;
            time_t et=mktime(&etm); time_t now=time(NULL);
            days_left=(int)((et-now)/86400);
        }

        /* locked? */
        char lcmd[256]; snprintf(lcmd,sizeof(lcmd),"passwd -S '%s' 2>/dev/null | grep -q ' L '",entry->d_name);
        int locked=(system(lcmd)==0);

        /* status colour */
        const char *status_col, *status_str;
        if(locked){          status_col=RED;    status_str="LOCKED";   }
        else if(cur_conn>0){ status_col=GREEN;  status_str="ONLINE";   }
        else if(days_left<=0){status_col=RED;   status_str="EXPIRED";  }
        else if(days_left<=3){status_col=YELLOW;status_str="EXPIRING"; }
        else{                  status_col=YELLOW;status_str="OFFLINE";  }

        /* expire colour */
        const char *exp_col=(days_left<=0)?RED:(days_left<=7)?YELLOW:GREEN;

        /* conn display: exact number / limit, colour red if >= limit */
        char conn_disp[32]; snprintf(conn_disp,sizeof(conn_disp),"%d/%d",cur_conn,conn_limit);
        const char *conn_col=(cur_conn==0)?CYAN:(cur_conn>=conn_limit)?RED:GREEN;

        /* bandwidth display */
        char bw_disp[32];
        if(bw_limit>0) snprintf(bw_disp,sizeof(bw_disp),"%.2f/%.0fGB",used_gb,bw_limit);
        else           snprintf(bw_disp,sizeof(bw_disp),"%.2fGB/unlim",used_gb);

        printf(CYAN "║" WHITE " %-14s %s%-12s%s %s%-8s%s %-14s %s%-10s%s" CYAN "║\n" NC,
               entry->d_name,
               exp_col,expire,NC,
               conn_col,conn_disp,NC,
               bw_disp,
               status_col,status_str,NC);
    }
    closedir(d);

    printf(CYAN "╠═══════════════════════════════════════════════════════════════╣\n" NC);
    printf(CYAN "║" YELLOW "  Users: " GREEN "%d" YELLOW " | Online: " GREEN "%d" NC "                                               " CYAN "║\n" NC, total, online);
    printf(CYAN "╚═══════════════════════════════════════════════════════════════╝\n" NC);
    show_quote();
}

/* ── lock / unlock / delete ──────────────────────────────── */
static void lock_user(){
    char u[64]={0}; printf("Username: "); fflush(stdout); fgets(u,sizeof(u),stdin); u[strcspn(u,"\r\n")]=0;
    char cmd[256]; snprintf(cmd,sizeof(cmd),"usermod -L '%s'",u);
    system(cmd)==0 ? printf(GREEN "✅ Locked\n" NC) : printf(RED "❌ Failed\n" NC);
    show_quote();
}
static void unlock_user(){
    char u[64]={0}; printf("Username: "); fflush(stdout); fgets(u,sizeof(u),stdin); u[strcspn(u,"\r\n")]=0;
    char cmd[256]; snprintf(cmd,sizeof(cmd),"usermod -U '%s'",u);
    system(cmd)==0 ? printf(GREEN "✅ Unlocked\n" NC) : printf(RED "❌ Failed\n" NC);
    show_quote();
}
static void delete_user(){
    char u[64]={0}; printf("Username: "); fflush(stdout); fgets(u,sizeof(u),stdin); u[strcspn(u,"\r\n")]=0;
    char cmd[512];
    snprintf(cmd,sizeof(cmd),"userdel -r '%s' 2>/dev/null",u); system(cmd);
    snprintf(cmd,sizeof(cmd),"rm -f %s/%s %s/%s %s/%s.usage",USER_DB,u,TRAFFIC,u,BW_DIR,u); system(cmd);
    printf(GREEN "✅ Deleted\n" NC);
    show_quote();
}

int main(int argc,char **argv){
    /* ensure dirs exist */
    mkdir(USER_DB,0755); mkdir(TRAFFIC,0755); mkdir(BW_DIR,0755); mkdir(CONN_DB,0755);

    if(argc<2){ printf("Usage: elite-x-user {add|list|lock|unlock|del}\n"); return 1; }
    if(strcmp(argv[1],"add")==0)    add_user();
    else if(strcmp(argv[1],"list")==0)   list_users();
    else if(strcmp(argv[1],"lock")==0)   lock_user();
    else if(strcmp(argv[1],"unlock")==0) unlock_user();
    else if(strcmp(argv[1],"del")==0)    delete_user();
    else printf("Usage: elite-x-user {add|list|lock|unlock|del}\n");
    return 0;
}
CEOF
    gcc -O2 -o /usr/local/bin/elite-x-user /tmp/elite-x-user.c 2>/dev/null
    rm -f /tmp/elite-x-user.c
    if [ -f /usr/local/bin/elite-x-user ]; then
        chmod +x /usr/local/bin/elite-x-user
        echo -e "${GREEN}✅ elite-x-user compiled${NC}"
    else
        echo -e "${RED}❌ elite-x-user compilation failed${NC}"
    fi
}

create_c_main_menu() {
    echo -e "${YELLOW}📝 Compiling C elite-x...${NC}"
    cat > /tmp/elite-x.c << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>
#include <time.h>
#include <ctype.h>

#define RED     "\033[0;31m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[1;33m"
#define BLUE    "\033[0;34m"
#define PURPLE  "\033[0;35m"
#define CYAN    "\033[0;36m"
#define WHITE   "\033[1;37m"
#define BOLD    "\033[1m"
#define NC      "\033[0m"

#define USER_DB  "/etc/elite-x/users"
#define BW_DIR   "/etc/elite-x/bandwidth"

static int is_numeric(const char *s){for(;*s;s++) if(!isdigit(*s)) return 0; return 1;}

static void read_file(const char *path, char *out, int sz){
    out[0]=0;
    FILE *f=fopen(path,"r"); if(!f) return;
    fgets(out,sz,f); fclose(f);
    out[strcspn(out,"\r\n")]=0;
}

static double get_total_bw_gb(){
    double total=0;
    DIR *d=opendir(BW_DIR); if(!d) return 0;
    struct dirent *e;
    while((e=readdir(d))){
        if(e->d_name[0]=='.') continue;
        char *dot=strrchr(e->d_name,'.');
        if(!dot||strcmp(dot,".usage")!=0) continue;
        char path[512]; snprintf(path,sizeof(path),"%s/%s",BW_DIR,e->d_name);
        FILE *f=fopen(path,"r"); if(!f) continue;
        long long bytes=0; fscanf(f,"%lld",&bytes); fclose(f);
        total+=(double)bytes/1073741824.0;
    }
    closedir(d);
    return total;
}

static int count_users(){
    int n=0;
    DIR *d=opendir(USER_DB); if(!d) return 0;
    struct dirent *e;
    while((e=readdir(d))) if(e->d_name[0]!='.') n++;
    closedir(d); return n;
}

static int count_online(){
    FILE *f=popen("who | wc -l","r"); if(!f) return 0;
    int n=0; fscanf(f,"%d",&n); pclose(f); return n;
}

static int svc_active(const char *name){
    char cmd[256]; snprintf(cmd,sizeof(cmd),"systemctl is-active %s >/dev/null 2>&1",name);
    return system(cmd)==0;
}

static void read_ram(char *out, int sz){
    struct sysinfo si; sysinfo(&si);
    long used=(si.totalram-si.freeram)*si.mem_unit/1048576;
    long total=si.totalram*si.mem_unit/1048576;
    snprintf(out,sz,"%ldMB/%ldMB",used,total);
}

static void show_quote(){
    printf("\n");
    printf(CYAN "╔═══════════════════════════════════════════════════════════════╗\n" NC);
    printf(CYAN "║" YELLOW BOLD "                                                               " CYAN "║\n" NC);
    printf(CYAN "║" WHITE "            Always Remember ELITE-X when you see X            " CYAN "║\n" NC);
    printf(CYAN "║" YELLOW BOLD "                                                               " CYAN "║\n" NC);
    printf(CYAN "╚═══════════════════════════════════════════════════════════════╝\n" NC);
    printf("\n");
}

/* ── check trial expiry ──────────────────────────────────── */
static void check_expiry(){
    char act_type[32]={0};
    read_file("/etc/elite-x/activation_type",act_type,sizeof(act_type));
    if(strcmp(act_type,"temporary")!=0) return;

    char act_date[32]={0},expiry_days_s[16]={0};
    read_file("/etc/elite-x/activation_date",act_date,sizeof(act_date));
    read_file("/etc/elite-x/expiry_days",expiry_days_s,sizeof(expiry_days_s));

    int ey=0,em=0,ed=0; sscanf(act_date,"%d-%d-%d",&ey,&em,&ed);
    struct tm atm={0}; atm.tm_year=ey-1900; atm.tm_mon=em-1; atm.tm_mday=ed+atoi(expiry_days_s);
    time_t expiry=mktime(&atm); time_t now=time(NULL);
    if(now<expiry) return;

    printf(RED "╔═══════════════════════════════════════════════════════════════╗\n" NC);
    printf(RED "║" YELLOW "           TRIAL PERIOD EXPIRED                                  " RED "║\n" NC);
    printf(RED "╠═══════════════════════════════════════════════════════════════╣\n" NC);
    printf(RED "║" WHITE "  Your 2-day trial has ended. Uninstalling...                  " RED "║\n" NC);
    printf(RED "╚═══════════════════════════════════════════════════════════════╝\n" NC);
    sleep(3);
    system("systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner 2>/dev/null");
    system("systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner 2>/dev/null");
    system("rm -f /etc/systemd/system/dnstt-elite-x* /etc/systemd/system/elite-x-*");
    system("rm -rf /etc/dnstt /etc/elite-x");
    system("rm -f /usr/local/bin/dnstt-* /usr/local/bin/elite-x*");
    system("sed -i '/^Banner/d' /etc/ssh/sshd_config");
    system("systemctl restart sshd");
    printf(GREEN "✅ ELITE-X uninstalled.\n" NC);
    exit(0);
}

/* ── show_dashboard ──────────────────────────────────────── */
static void show_dashboard(){
    system("clear");
    char ip[64]={0},sub[128]={0},loc[64]={0},isp[128]={0};
    char act_key[64]={0},expiry[64]={0},vps_loc[64]={0},mtu[16]={0};
    char ram[64]={0};

    read_file("/etc/elite-x/cached_ip",ip,sizeof(ip));       if(!ip[0]) strcpy(ip,"Unknown");
    read_file("/etc/elite-x/subdomain",sub,sizeof(sub));     if(!sub[0]) strcpy(sub,"Not configured");
    read_file("/etc/elite-x/cached_location",loc,sizeof(loc));if(!loc[0]) strcpy(loc,"Unknown");
    read_file("/etc/elite-x/cached_isp",isp,sizeof(isp));    if(!isp[0]) strcpy(isp,"Unknown");
    read_file("/etc/elite-x/key",act_key,sizeof(act_key));   if(!act_key[0]) strcpy(act_key,"Unknown");
    read_file("/etc/elite-x/expiry",expiry,sizeof(expiry));  if(!expiry[0]) strcpy(expiry,"Unknown");
    read_file("/etc/elite-x/location",vps_loc,sizeof(vps_loc));if(!vps_loc[0]) strcpy(vps_loc,"South Africa");
    read_file("/etc/elite-x/mtu",mtu,sizeof(mtu));           if(!mtu[0]) strcpy(mtu,"1800");
    read_ram(ram,sizeof(ram));

    const char *dns_col=svc_active("dnstt-elite-x")?GREEN:RED;
    const char *prx_col=svc_active("dnstt-elite-x-proxy")?GREEN:RED;

    int total_users=count_users();
    int online=count_online();
    double total_bw=get_total_bw_gb();

    printf(CYAN "╔════════════════════════════════════════════════════════════════╗\n" NC);
    printf(CYAN "║" YELLOW BOLD "                    ELITE-X SLOWDNS v3.0                       " CYAN "║\n" NC);
    printf(CYAN "╠════════════════════════════════════════════════════════════════╣\n" NC);
    printf(CYAN "║" WHITE "  Subdomain : " GREEN "%-49s" CYAN "║\n" NC, sub);
    printf(CYAN "║" WHITE "  IP        : " GREEN "%-49s" CYAN "║\n" NC, ip);
    printf(CYAN "║" WHITE "  Location  : " GREEN "%-49s" CYAN "║\n" NC, loc);
    printf(CYAN "║" WHITE "  ISP       : " GREEN "%-49s" CYAN "║\n" NC, isp);
    printf(CYAN "║" WHITE "  RAM       : " GREEN "%-49s" CYAN "║\n" NC, ram);
    printf(CYAN "║" WHITE "  VPS Loc   : " GREEN "%-49s" CYAN "║\n" NC, vps_loc);
    printf(CYAN "║" WHITE "  MTU       : " GREEN "%-49s" CYAN "║\n" NC, mtu);
    printf(CYAN "║" WHITE "  Services  : DNS:%s●" NC WHITE " PRX:%s●" NC "%-39s" CYAN "║\n" NC,
           dns_col, prx_col, "");
    printf(CYAN "║" WHITE "  Users     : " GREEN "%-3d" YELLOW " total, " GREEN "%-3d" YELLOW " online" NC "%-34s" CYAN "║\n" NC,
           total_users, online, "");
    printf(CYAN "║" WHITE "  Total BW  : " YELLOW "%.2f GB used" NC "%-41s" CYAN "║\n" NC, total_bw, "");
    printf(CYAN "║" WHITE "  Developer : " PURPLE "%-49s" CYAN "║\n" NC, "ELITE-X TEAM");
    printf(CYAN "╠════════════════════════════════════════════════════════════════╣\n" NC);
    printf(CYAN "║" WHITE "  Act Key   : " YELLOW "%-49s" CYAN "║\n" NC, act_key);
    printf(CYAN "║" WHITE "  Expiry    : " YELLOW "%-49s" CYAN "║\n" NC, expiry);
    printf(CYAN "╚════════════════════════════════════════════════════════════════╝\n" NC);
    printf("\n");
}

/* ── settings_menu ───────────────────────────────────────── */
static void settings_menu(){
    char ch[16]={0};
    while(1){
        system("clear");
        printf(CYAN "╔════════════════════════════════════════════════════════════════╗\n" NC);
        printf(CYAN "║" YELLOW BOLD "                      SETTINGS MENU                              " CYAN "║\n" NC);
        printf(CYAN "╠════════════════════════════════════════════════════════════════╣\n" NC);
        printf(CYAN "║" WHITE "  [8]  🔑 View Public Key\n" NC);
        printf(CYAN "║" WHITE "  [9]  Change MTU Value (Manual)\n" NC);
        printf(CYAN "║" WHITE "  [10] ⚡ Manual Speed Optimization\n" NC);
        printf(CYAN "║" WHITE "  [11] 🧹 Clean Junk Files\n" NC);
        printf(CYAN "║" WHITE "  [12] 🔄 Auto Expired Account Remover\n" NC);
        printf(CYAN "║" WHITE "  [13] 📦 Update Script\n" NC);
        printf(CYAN "║" WHITE "  [14] Restart All Services\n" NC);
        printf(CYAN "║" WHITE "  [15] Reboot VPS\n" NC);
        printf(CYAN "║" WHITE "  [16] Uninstall Script\n" NC);
        printf(CYAN "║" WHITE "  [17] 🌍 Re-apply Location Optimization\n" NC);
        printf(CYAN "║" WHITE "  [0]  Back to Main Menu\n" NC);
        printf(CYAN "╚════════════════════════════════════════════════════════════════╝\n" NC);
        printf(GREEN "Settings option: " NC); fflush(stdout);
        fgets(ch,sizeof(ch),stdin); ch[strcspn(ch,"\r\n")]=0;

        if(strcmp(ch,"8")==0){
            char pk[256]={0}; read_file("/etc/dnstt/server.pub",pk,sizeof(pk));
            printf(CYAN "╔═══════════════════════════════════════════════════════════════╗\n" NC);
            printf(CYAN "║" YELLOW "                    PUBLIC KEY (FULL)                           " CYAN "║\n" NC);
            printf(CYAN "╠═══════════════════════════════════════════════════════════════╣\n" NC);
            printf(CYAN "║" GREEN "  %s\n" NC, pk);
            printf(CYAN "╚═══════════════════════════════════════════════════════════════╝\n" NC);
            printf("Press Enter to continue..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"9")==0){
            char cur[16]={0}; read_file("/etc/elite-x/mtu",cur,sizeof(cur));
            printf("Current MTU: %s\n",cur);
            printf("New MTU (1000-5000): "); fflush(stdout);
            char mtu_s[16]={0}; fgets(mtu_s,sizeof(mtu_s),stdin); mtu_s[strcspn(mtu_s,"\r\n")]=0;
            int mtu=atoi(mtu_s);
            if(is_numeric(mtu_s)&&mtu>=1000&&mtu<=5000){
                FILE *f=fopen("/etc/elite-x/mtu","w"); if(f){fprintf(f,"%d\n",mtu);fclose(f);}
                char cmd[512];
                snprintf(cmd,sizeof(cmd),"sed -i 's/-mtu [0-9]*/-mtu %d/' /etc/systemd/system/dnstt-elite-x.service",mtu);
                system(cmd);
                system("systemctl daemon-reload && systemctl restart dnstt-elite-x dnstt-elite-x-proxy");
                printf(GREEN "✅ MTU updated to %d\n" NC, mtu);
            } else printf(RED "❌ Invalid (must be 1000-5000)\n" NC);
            printf("Press Enter to continue..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"10")==0){ system("elite-x-speed manual"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"11")==0){ system("elite-x-speed clean");  printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"12")==0){
            system("systemctl enable --now elite-x-cleaner.service");
            printf(GREEN "✅ Auto remover started\n" NC);
            printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"13")==0){ system("elite-x-update"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"14")==0){
            system("systemctl restart dnstt-elite-x dnstt-elite-x-proxy sshd");
            printf(GREEN "✅ Services restarted\n" NC);
            printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"15")==0){
            printf("Reboot? (y/n): "); fflush(stdout); fgets(ch,sizeof(ch),stdin);
            if(ch[0]=='y') system("reboot");
        }
        else if(strcmp(ch,"16")==0){
            printf("Type YES to confirm uninstall: "); fflush(stdout); fgets(ch,sizeof(ch),stdin); ch[strcspn(ch,"\r\n")]=0;
            if(strcmp(ch,"YES")==0){
                system("systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner");
                system("systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-traffic elite-x-cleaner");
                system("rm -f /etc/systemd/system/dnstt-elite-x* /etc/systemd/system/elite-x-*");
                system("rm -rf /etc/dnstt /etc/elite-x");
                system("rm -f /usr/local/bin/dnstt-* /usr/local/bin/elite-x*");
                system("sed -i '/^Banner/d' /etc/ssh/sshd_config && systemctl restart sshd");
                printf(GREEN "✅ Uninstalled\n" NC);
                exit(0);
            }
            printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"17")==0){
            printf(WHITE "Select location: [1]South Africa [2]USA [3]Europe [4]Asia [5]Auto\n" NC);
            printf("Choice: "); fflush(stdout); fgets(ch,sizeof(ch),stdin); ch[strcspn(ch,"\r\n")]=0;
            const char *loc_name="South Africa"; int mtu_val=1800;
            if(strcmp(ch,"2")==0){loc_name="USA";}
            else if(strcmp(ch,"3")==0){loc_name="Europe";}
            else if(strcmp(ch,"4")==0){loc_name="Asia";}
            else if(strcmp(ch,"5")==0){loc_name="Auto-detect";}
            FILE *f=fopen("/etc/elite-x/location","w"); if(f){fprintf(f,"%s\n",loc_name);fclose(f);}
            if(strcmp(ch,"1")==0){
                f=fopen("/etc/elite-x/mtu","w"); if(f){fprintf(f,"%d\n",mtu_val);fclose(f);}
                system("sed -i 's/-mtu [0-9]*/-mtu 1800/' /etc/systemd/system/dnstt-elite-x.service");
                system("systemctl daemon-reload && systemctl restart dnstt-elite-x dnstt-elite-x-proxy");
            }
            printf(GREEN "✅ %s selected\n" NC, loc_name);
            printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"0")==0) return;
        else { printf(RED "Invalid option\n" NC); sleep(1); }
    }
}

/* ── main_menu ───────────────────────────────────────────── */
static void main_menu(){
    char ch[16]={0};
    while(1){
        show_dashboard();
        printf(CYAN "╔════════════════════════════════════════════════════════════════╗\n" NC);
        printf(CYAN "║" GREEN BOLD "                         MAIN MENU                              " CYAN "║\n" NC);
        printf(CYAN "╠════════════════════════════════════════════════════════════════╣\n" NC);
        printf(CYAN "║" WHITE "  [1] Create SSH + DNS User\n" NC);
        printf(CYAN "║" WHITE "  [2] List All Users\n" NC);
        printf(CYAN "║" WHITE "  [3] Lock User\n" NC);
        printf(CYAN "║" WHITE "  [4] Unlock User\n" NC);
        printf(CYAN "║" WHITE "  [5] Delete User\n" NC);
        printf(CYAN "║" WHITE "  [6] Create/Edit Banner\n" NC);
        printf(CYAN "║" WHITE "  [7] Delete Banner\n" NC);
        printf(CYAN "║" RED   "  [S] ⚙️  Settings\n" NC);
        printf(CYAN "║" WHITE "  [0] Exit\n" NC);
        printf(CYAN "╚════════════════════════════════════════════════════════════════╝\n" NC);
        printf(GREEN "Main menu option: " NC); fflush(stdout);
        fgets(ch,sizeof(ch),stdin); ch[strcspn(ch,"\r\n")]=0;

        if(strcmp(ch,"1")==0){ system("elite-x-user add"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"2")==0){ system("elite-x-user list"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"3")==0){ system("elite-x-user lock"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"4")==0){ system("elite-x-user unlock"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"5")==0){ system("elite-x-user del"); printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin); }
        else if(strcmp(ch,"6")==0){
            system("[ -f /etc/elite-x/banner/custom ] || cp /etc/elite-x/banner/default /etc/elite-x/banner/custom");
            system("nano /etc/elite-x/banner/custom");
            system("cp /etc/elite-x/banner/custom /etc/elite-x/banner/ssh-banner && systemctl restart sshd");
            printf(GREEN "✅ Banner saved\n" NC);
            printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(strcmp(ch,"7")==0){
            system("rm -f /etc/elite-x/banner/custom && cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner && systemctl restart sshd");
            printf(GREEN "✅ Banner deleted\n" NC);
            printf("Press Enter..."); fflush(stdout); fgets(ch,sizeof(ch),stdin);
        }
        else if(ch[0]=='s'||ch[0]=='S') settings_menu();
        else if(strcmp(ch,"0")==0||strcmp(ch,"00")==0){
            show_quote();
            printf(GREEN "Goodbye!\n" NC);
            exit(0);
        }
        else { printf(RED "Invalid option\n" NC); sleep(1); }
    }
}

int main(){
    check_expiry();
    main_menu();
    return 0;
}
CEOF
    gcc -O2 -o /usr/local/bin/elite-x /tmp/elite-x.c 2>/dev/null
    rm -f /tmp/elite-x.c
    if [ -f /usr/local/bin/elite-x ]; then
        chmod +x /usr/local/bin/elite-x
        echo -e "${GREEN}✅ elite-x compiled${NC}"
    else
        echo -e "${RED}❌ elite-x compilation failed${NC}"
    fi
}

setup_traffic_monitor() {
    cat > /usr/local/bin/elite-x-traffic <<'EOF'
#!/bin/bash
TRAFFIC_DB="/etc/elite-x/traffic"
USER_DB="/etc/elite-x/users"
mkdir -p $TRAFFIC_DB

monitor_user() {
    local username="$1"
    local traffic_file="$TRAFFIC_DB/$username"
    
    if command -v iptables >/dev/null 2>&1; then
        local current=$(iptables -vnx -L OUTPUT | grep "$username" | awk '{sum+=$2} END {print sum}' 2>/dev/null || echo "0")
        echo $((current / 1048576)) > "$traffic_file"
    fi
}

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] && monitor_user "$(basename "$user_file")"
        done
    fi
    sleep 60
done
EOF
    chmod +x /usr/local/bin/elite-x-traffic

    cat > /etc/systemd/system/elite-x-traffic.service <<EOF
[Unit]
Description=ELITE-X Traffic Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-traffic
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable elite-x-traffic.service
    systemctl start elite-x-traffic.service
}

setup_manual_speed() {
    cat > /usr/local/bin/elite-x-speed <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

optimize_network() {
    echo -e "${YELLOW}⚡ Optimizing network for maximum speed...${NC}"
    
    sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" >/dev/null 2>&1
    sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
    
    echo -e "${GREEN}✅ Network optimized!${NC}"
}

optimize_cpu() {
    echo -e "${YELLOW}⚡ Optimizing CPU performance...${NC}"
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ CPU optimized!${NC}"
}

optimize_ram() {
    echo -e "${YELLOW}⚡ Optimizing RAM...${NC}"
    
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    echo -e "${GREEN}✅ RAM optimized!${NC}"
}

clean_junk() {
    echo -e "${YELLOW}🧹 Cleaning junk files...${NC}"
    
    apt clean 2>/dev/null
    apt autoclean 2>/dev/null
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
    
    echo -e "${GREEN}✅ Junk files cleaned!${NC}"
}

case "$1" in
    manual)
        optimize_network
        optimize_cpu
        optimize_ram
        clean_junk
        ;;
    clean)
        clean_junk
        ;;
    *)
        echo "Usage: elite-x-speed {manual|clean}"
        exit 1
        ;;
esac
EOF
    chmod +x /usr/local/bin/elite-x-speed
}

setup_auto_remover() {
    cat > /usr/local/bin/elite-x-cleaner <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
TRAFFIC_DB="/etc/elite-x/traffic"

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                expire_date=$(grep "Expire:" "$user_file" | cut -d' ' -f2)
                
                if [ ! -z "$expire_date" ]; then
                    current_date=$(date +%Y-%m-%d)
                    if [[ "$current_date" > "$expire_date" ]] || [ "$current_date" = "$expire_date" ]; then
                        userdel -r "$username" 2>/dev/null || true
                        rm -f "$user_file"
                        rm -f "$TRAFFIC_DB/$username"
                    fi
                fi
            fi
        done
    fi
    sleep 3600
done
EOF
    chmod +x /usr/local/bin/elite-x-cleaner

    cat > /etc/systemd/system/elite-x-cleaner.service <<EOF
[Unit]
Description=ELITE-X Auto Remover
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-cleaner
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable elite-x-cleaner.service
    systemctl start elite-x-cleaner.service
}

setup_updater() {
    cat > /usr/local/bin/elite-x-update <<'EOF'
#!/bin/bash

echo -e "\033[1;33m🔄 Checking for updates...\033[0m"

BACKUP_DIR="/root/elite-x-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/elite-x "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/dnstt "$BACKUP_DIR/" 2>/dev/null || true

cd /tmp
rm -rf Elite-X-dns.sh
git clone https://github.com/NoXFiQ/Elite-X-dns.sh.git 2>/dev/null || {
    echo -e "\033[0;31m❌ Failed to download update\033[0m"
    exit 1
}

cd Elite-X-dns.sh
chmod +x *.sh

cp -r "$BACKUP_DIR/elite-x" /etc/ 2>/dev/null || true
cp -r "$BACKUP_DIR/dnstt" /etc/ 2>/dev/null || true

echo -e "\033[0;32m✅ Update complete!\033[0m"
EOF
    chmod +x /usr/local/bin/elite-x-update
}

show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}Available Keys:${NC}"
echo -e "${GREEN}  Lifetime : Whtsapp +255713-628-668${NC}"
echo -e "${YELLOW}  Trial    : ELITE-X-TEST-0208 (2 days)${NC}"
echo ""
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

mkdir -p /etc/elite-x
if ! activate_script "$ACTIVATION_INPUT"; then
    echo -e "${RED}❌ Invalid activation key! Installation cancelled.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Activation successful!${NC}"
sleep 1

if [ -f "$ACTIVATION_TYPE_FILE" ] && [ "$(cat "$ACTIVATION_TYPE_FILE")" = "temporary" ]; then
    echo -e "${YELLOW}⚠️  Trial version activated - expires in 2 days${NC}"
fi
sleep 2

set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR SUBDOMAIN                          ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${WHITE}  Example: ns-ex.elitex.sbs                                 ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Subdomain: "$NC)" TDOMAIN

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}  You entered: ${GREEN}$TDOMAIN${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_subdomain "$TDOMAIN"

echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}           NETWORK LOCATION OPTIMIZATION                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║${WHITE}  Select your VPS location:                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${GREEN}  [1] South Africa (Default - MTU 1800)                        ${YELLOW}║${NC}"
echo -e "${YELLOW}║${CYAN}  [2] USA                                                       ${YELLOW}║${NC}"
echo -e "${YELLOW}║${BLUE}  [3] Europe                                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${PURPLE}  [4] Asia                                                      ${YELLOW}║${NC}"
echo -e "${YELLOW}║${YELLOW}  [5] Auto-detect                                                ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Select location [1-5] [default: 1]: "$NC)" LOCATION_CHOICE
LOCATION_CHOICE=${LOCATION_CHOICE:-1}

# Set default MTU (always 1800 - no testing)
MTU=1800
SELECTED_LOCATION="South Africa"

case $LOCATION_CHOICE in
    2)
        SELECTED_LOCATION="USA"
        echo -e "${CYAN}✅ USA selected${NC}"
        NEED_USA_OPT=1
        ;;
    3)
        SELECTED_LOCATION="Europe"
        echo -e "${BLUE}✅ Europe selected${NC}"
        NEED_EUROPE_OPT=1
        ;;
    4)
        SELECTED_LOCATION="Asia"
        echo -e "${PURPLE}✅ Asia selected${NC}"
        NEED_ASIA_OPT=1
        ;;
    5)
        SELECTED_LOCATION="Auto-detect"
        echo -e "${YELLOW}✅ Auto-detect selected${NC}"
        NEED_AUTO_OPT=1
        ;;
    *)
        SELECTED_LOCATION="South Africa"
        echo -e "${GREEN}✅ Using South Africa configuration${NC}"
        ;;
esac

echo "$SELECTED_LOCATION" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu

DNSTT_PORT=5300
DNS_PORT=53

echo "==> ELITE-X INSTALLATION STARTING..."

if [ "$(id -u)" -ne 0 ]; then
  echo "[-] Run as root"
  exit 1
fi

mkdir -p /etc/elite-x/{banner,users,traffic}
echo "$TDOMAIN" > /etc/elite-x/subdomain

cat > /etc/elite-x/banner/default <<'EOF'
╔═════════════════════════════════════════╗
      WELCOME TO ELITE-X VPN SERVICE
╠═════════════════════════════════════════╣
     High Speed • Secure • Unlimited
╚═════════════════════════════════════════╝
EOF

cat > /etc/elite-x/banner/ssh-banner <<'EOF'
╔═════════════════════════════════════════╗
           ELITE-X VPN SERVICE             
    High Speed • Secure • Unlimited     
╚═════════════════════════════════════════╝
EOF

if ! grep -q "^Banner" /etc/ssh/sshd_config; then
    echo "Banner /etc/elite-x/banner/ssh-banner" >> /etc/ssh/sshd_config
else
    sed -i 's|^Banner.*|Banner /etc/elite-x/banner/ssh-banner|' /etc/ssh/sshd_config
fi
systemctl restart sshd

echo "Stopping old services..."
for svc in dnstt dnstt-server slowdns dnstt-smart dnstt-elite-x dnstt-elite-x-proxy; do
  systemctl disable --now "$svc" 2>/dev/null || true
done

if [ -f /etc/systemd/resolved.conf ]; then
  echo "Configuring systemd-resolved..."
  sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf || true
  grep -q '^DNS=' /etc/systemd/resolved.conf \
    && sed -i 's/^DNS=.*/DNS=8.8.8.8 8.8.4.4/' /etc/systemd/resolved.conf \
    || echo "DNS=8.8.8.8 8.8.4.4" >> /etc/systemd/resolved.conf
  systemctl restart systemd-resolved
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi

echo "Installing dependencies..."
apt update -y
apt install -y curl python3 jq nano iptables iptables-persistent ethtool dnsutils

echo "Installing dnstt-server..."
curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server
chmod +x /usr/local/bin/dnstt-server

echo "Generating keys..."
mkdir -p /etc/dnstt

if [ -f /etc/dnstt/server.key ]; then
    echo -e "${YELLOW}⚠️  Existing keys found, removing...${NC}"
    chattr -i /etc/dnstt/server.key 2>/dev/null || true
    rm -f /etc/dnstt/server.key
    rm -f /etc/dnstt/server.pub
fi

# Generate new keys
cd /etc/dnstt
dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
cd ~

# Set proper permissions
chmod 600 /etc/dnstt/server.key
chmod 644 /etc/dnstt/server.pub

echo "Creating dnstt-elite-x.service..."
cat >/etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :${DNSTT_PORT} -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=no
KillSignal=SIGTERM
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

echo "Installing EDNS proxy..."
cat >/usr/local/bin/dnstt-edns-proxy.py <<'EOF'
#!/usr/bin/env python3
import socket,threading,struct
L=5300
def p(d,s):
 if len(d)<12:return d
 try:q,a,n,r=struct.unpack("!HHHH",d[4:12])
 except:return d
 o=12
 def sk(b,o):
  while o<len(b):
   l=b[o];o+=1
   if l==0:break
   if l&0xC0==0xC0:o+=1;break
   o+=l
  return o
 for _ in range(q):o=sk(d,o);o+=4
 for _ in range(a+n):
  o=sk(d,o)
  if o+10>len(d):return d
  _,_,_,l=struct.unpack("!HHIH",d[o:o+10])
  o+=10+l
 n=bytearray(d)
 for _ in range(r):
  o=sk(d,o)
  if o+10>len(d):return d
  t=struct.unpack("!H",d[o:o+2])[0]
  if t==41:
   n[o+2:o+4]=struct.pack("!H",s)
   return bytes(n)
  _,_,l=struct.unpack("!HIH",d[o+2:o+10])
  o+=10+l
 return d
def h(sk,d,ad):
 u=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
 u.settimeout(5)
 try:
  u.sendto(p(d,1800),('127.0.0.1',L))
  r,_=u.recvfrom(4096)
  sk.sendto(p(r,512),ad)
 except:pass
 finally:u.close()
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
s.bind(('0.0.0.0',53))
while True:
 d,a=s.recvfrom(4096)
 threading.Thread(target=h,args=(s,d,a),daemon=True).start()
EOF
chmod +x /usr/local/bin/dnstt-edns-proxy.py

cat >/etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X Proxy
After=dnstt-elite-x.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/dnstt-edns-proxy.py
Restart=no

[Install]
WantedBy=multi-user.target
EOF

command -v ufw >/dev/null && ufw allow 22/tcp && ufw allow 53/udp || true

systemctl daemon-reload
systemctl enable dnstt-elite-x.service dnstt-elite-x-proxy.service
systemctl start dnstt-elite-x.service dnstt-elite-x-proxy.service

create_c_user_tool
create_c_main_menu
setup_traffic_monitor
setup_manual_speed
setup_auto_remover
setup_updater

if [ ! -z "${NEED_USA_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying USA optimizations...${NC}"
    cat >> /etc/sysctl.conf <<EOF
# ELITE-X USA Optimization
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p
    echo -e "${GREEN}✅ USA optimizations applied${NC}"
elif [ ! -z "${NEED_EUROPE_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying Europe optimizations...${NC}"
    cat >> /etc/sysctl.conf <<EOF
# ELITE-X Europe Optimization
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p
    echo -e "${GREEN}✅ Europe optimizations applied${NC}"
elif [ ! -z "${NEED_ASIA_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying Asia optimizations...${NC}"
    cat >> /etc/sysctl.conf <<EOF
# ELITE-X Asia Optimization
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 8192
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p
    echo -e "${GREEN}✅ Asia optimizations applied${NC}"
elif [ ! -z "${NEED_AUTO_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying auto-detected optimizations...${NC}"
    # Simple latency test
    usa_latency=$(ping -c 2 -W 2 8.8.8.8 2>/dev/null | tail -1 | awk -F '/' '{print $5}' | cut -d. -f1)
    if [ ! -z "$usa_latency" ] && [ "$usa_latency" -lt 200 ]; then
        cat >> /etc/sysctl.conf <<EOF
# ELITE-X Auto USA Optimization
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    else
        cat >> /etc/sysctl.conf <<EOF
# ELITE-X Auto Default Optimization
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    fi
    sysctl -p
    echo -e "${GREEN}✅ Auto optimizations applied${NC}"
fi

for iface in $(ls /sys/class/net/ | grep -v lo); do
    ethtool -K $iface tx off sg off tso off 2>/dev/null || true
    ip link set dev $iface txqueuelen 10000 2>/dev/null || true
done

systemctl daemon-reload
systemctl restart dnstt-elite-x dnstt-elite-x-proxy

cat > /etc/cron.hourly/elite-x-expiry <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ]; then
    /usr/local/bin/elite-x --check-expiry
fi
EOF
chmod +x /etc/cron.hourly/elite-x-expiry

create_c_user_tool

# ========== MAIN MENU ==========
create_c_main_menu

echo "Caching network information for fast login..."
IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

if [ "$IP" != "Unknown" ]; then
    LOCATION_INFO=$(curl -s http://ip-api.com/json/$IP 2>/dev/null)
    echo "$LOCATION_INFO" | jq -r '.city + ", " + .country' 2>/dev/null > /etc/elite-x/cached_location || echo "Unknown" > /etc/elite-x/cached_location
    echo "$LOCATION_INFO" | jq -r '.isp' 2>/dev/null > /etc/elite-x/cached_isp || echo "Unknown" > /etc/elite-x/cached_isp
else
    echo "Unknown" > /etc/elite-x/cached_location
    echo "Unknown" > /etc/elite-x/cached_isp
fi

cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
# Auto-show ELITE-X dashboard on login
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    # Clear any existing lock file
    rm -f /tmp/elite-x-running 2>/dev/null
    # Show the dashboard directly
    /usr/local/bin/elite-x
fi
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

cat >> ~/.bashrc <<'EOF'
# Auto-show ELITE-X dashboard
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    rm -f /tmp/elite-x-running 2>/dev/null
    /usr/local/bin/elite-x
fi
EOF

echo "alias menu='elite-x'" >> ~/.bashrc
echo "alias elitex='elite-x'" >> ~/.bashrc

if [ ! -f /etc/elite-x/key ]; then
    if [ -f "$ACTIVATION_FILE" ]; then
        cp "$ACTIVATION_FILE" /etc/elite-x/key
    else
        echo "$ACTIVATION_KEY" > /etc/elite-x/key
    fi
fi

echo "╔════════════════════════════════════╗"
echo " ELITE-X INSTALLED SUCCESSFULLY "
echo "╚════════════════════════════════════╝"
EXPIRY_INFO=$(cat /etc/elite-x/expiry 2>/dev/null || echo "Lifetime")
FINAL_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
ACTIVATION_KEY=$(cat /etc/elite-x/key 2>/dev/null || echo "ELITEX-2026-DAN-4D-08")
echo "DOMAIN  : ${TDOMAIN}"
echo "LOCATION: ${SELECTED_LOCATION}"
echo "KEY : ${ACTIVATION_KEY}"
echo "KEY EXPIRE  : ${EXPIRY_INFO}"
echo "╚════════════════════════════════════╝"
show_quote

read -p "Open menu now? (y/n): " open
if [ "$open" = "y" ]; then
    echo -e "${GREEN}Opening dashboard...${NC}"
    sleep 1
    /usr/local/bin/elite-x
else
    echo -e "${YELLOW}You can type 'menu' or 'elite-x' anytime to open the dashboard.${NC}"
fi

self_destruct
