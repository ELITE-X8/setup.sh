#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║      ELITE-X8 FALCON ULTIMATE v5.2 - FULLY FIXED 1GBPS EDITION              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
PURPLE='\033[0;35m'; WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

# ==============================================================================
# FIX FIRST - REPAIR THE BROKEN elitex COMMAND
# ==============================================================================
echo -e "${YELLOW}🔧 Fixing elitex command...${NC}"

cat > /usr/local/bin/elitex << 'PANELEND'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
PURPLE='\033[0;35m'; WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
IP=$(cat /etc/elite-x/cached_ip 2>/dev/null)
NS=$(cat /etc/elite-x/subdomain 2>/dev/null)

show_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}${CYAN}     🚀 ELITE-X8 FALCON ULTIMATE v5.2 - 1GBPS EDITION${NC}        ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}📊 SERVER STATUS${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    
    if pgrep -f "dnstt-server" > /dev/null; then
        echo -e "${CYAN}│${NC} ${GREEN}●${NC} SlowDNS:    ${GREEN}Running${NC}"
    else
        echo -e "${CYAN}│${NC} ${RED}●${NC} SlowDNS:    ${RED}Stopped${NC}"
    fi
    
    if pgrep -f "edns-proxy" > /dev/null; then
        echo -e "${CYAN}│${NC} ${GREEN}●${NC} EDNS Proxy:  ${GREEN}Running${NC}"
    else
        echo -e "${CYAN}│${NC} ${RED}●${NC} EDNS Proxy:  ${RED}Stopped${NC}"
    fi
    
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} NS:   ${WHITE}$NS${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} IP:   ${WHITE}$IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} KEY:  ${WHITE}${PUBLIC_KEY:0:40}...${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Create User   ${GREEN}[2]${NC} List Users     ${GREEN}[3]${NC} Delete User${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} Restart All   ${GREEN}[5]${NC} Test Speed     ${GREEN}[0]${NC} Exit${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
}

while true; do
    show_header
    read -p "$(echo -e "${WHITE}Select: ${NC}")" choice
    case $choice in
        1)
            elite-x8-user add
            echo -e "\n${GREEN}Press Enter...${NC}"
            read
            ;;
        2)
            elite-x8-user list
            echo -e "\n${GREEN}Press Enter...${NC}"
            read
            ;;
        3)
            elite-x8-user del
            echo -e "\n${GREEN}Press Enter...${NC}"
            read
            ;;
        4)
            echo -e "${YELLOW}Restarting services...${NC}"
            pkill -f dnstt-server 2>/dev/null
            pkill -f edns-proxy 2>/dev/null
            sleep 2
            /usr/local/bin/dnstt-server -udp :5300 -mtu 1400 -privkey-file /etc/dnstt/server.key "$NS" 127.0.0.1:22 &
            /usr/local/bin/edns-proxy &
            echo -e "${GREEN}✅ Services restarted${NC}"
            sleep 2
            ;;
        5)
            echo -e "${YELLOW}Testing connectivity...${NC}"
            ping -c 4 8.8.8.8
            echo -e "\n${GREEN}Press Enter...${NC}"
            read
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done
PANELEND

chmod +x /usr/local/bin/elitex

# ==============================================================================
# FIX THE USER MANAGEMENT SCRIPT
# ==============================================================================
echo -e "${YELLOW}🔧 Fixing user management...${NC}"

cat > /usr/local/bin/elite-x8-user << 'USEREOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'

UD="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
NS=$(cat /etc/elite-x/subdomain 2>/dev/null)
IP=$(cat /etc/elite-x/cached_ip 2>/dev/null)

get_bw() {
    local f="$BW_DIR/${1}.usage"
    if [ -f "$f" ]; then
        bytes=$(cat "$f" 2>/dev/null || echo 0)
        echo "scale=2; $bytes / 1073741824" | bc 2>/dev/null || echo "0"
    else
        echo "0"
    fi
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
    
    read -p "$(echo -e $GREEN"Password (leave empty for auto): "$NC)" password
    if [ -z "$password" ]; then
        password=$(tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 10)
        if [ -z "$password" ]; then
            password="User123456"
        fi
        echo -e "${GREEN}Generated password: ${YELLOW}$password${NC}"
    fi
    
    read -p "$(echo -e $GREEN"Expire days [30]: "$NC)" days
    days=${days:-30}
    read -p "$(echo -e $GREEN"Connection limit [2]: "$NC)" conn
    conn=${conn:-2}
    read -p "$(echo -e $GREEN"Bandwidth GB [0=unlimited]: "$NC)" bw
    bw=${bw:-0}
    
    useradd -m -s /bin/false "$username" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create user!${NC}"
        return
    fi
    
    echo "$username:$password" | chpasswd
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username" 2>/dev/null
    
    mkdir -p "$UD" "$BW_DIR"
    cat > "$UD/$username" << EOF
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn
Bandwidth_GB: $bw
Created: $(date "+%Y-%m-%d %H:%M:%S")
EOF
    echo "0" > "$BW_DIR/${username}.usage"
    
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER CREATED SUCCESSFULLY                 ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username:   ${CYAN}$username${NC}"
    echo -e "${GREEN}║${WHITE}  Password:   ${CYAN}$password${NC}"
    echo -e "${GREEN}║${WHITE}  NS:         ${CYAN}$NS${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY:     ${CYAN}$PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE}  IP:         ${CYAN}$IP${NC}"
    echo -e "${GREEN}║${WHITE}  Expire:     ${CYAN}$expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login:  ${CYAN}$conn${NC}"
    echo -e "${GREEN}║${WHITE}  Bandwidth:  ${CYAN}$([ "$bw" != "0" ] && echo "${bw}GB" || echo "Unlimited")${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}  SLOWDNS CONFIGURATION:${NC}"
    echo -e "${GREEN}║${WHITE}  NS     : ${CYAN}$NS${NC}"
    echo -e "${GREEN}║${WHITE}  PUBKEY : ${CYAN}$PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE}  PORT   : ${CYAN}53${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                    ACTIVE USERS                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    
    if [ ! -d "$UD" ] || [ -z "$(ls -A "$UD" 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}                    No users found                            ${CYAN}║${NC}"
    else
        for u in "$UD"/*; do
            if [ -f "$u" ]; then
                name=$(basename "$u")
                exp=$(grep "Expire:" "$u" 2>/dev/null | cut -d' ' -f2)
                bw=$(get_bw "$name")
                echo -e "${CYAN}║${WHITE}  📱 $name | Expires: $exp | Usage: ${bw}GB${NC}"
            fi
        done
    fi
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

delete_user() {
    read -p "$(echo -e $GREEN"Username to delete: "$NC)" username
    if [ ! -f "$UD/$username" ]; then
        echo -e "${RED}User not found!${NC}"
        return
    fi
    userdel -r "$username" 2>/dev/null
    rm -f "$UD/$username" "$BW_DIR/${username}.usage"
    rm -rf "$BW_DIR/pidtrack/${username}"* 2>/dev/null
    echo -e "${GREEN}✅ User $username deleted${NC}"
}

case "$1" in
    add) add_user ;;
    list) list_users ;;
    del) delete_user ;;
    *) echo "Usage: elite-x8-user {add|list|del}" ;;
esac
USEREOF

chmod +x /usr/local/bin/elite-x8-user

# ==============================================================================
# ENSURE SERVICES ARE RUNNING WITH THE CORRECT NAMESERVER
# ==============================================================================
echo -e "${YELLOW}🔧 Ensuring services are running...${NC}"

# Get the actual nameserver from config
NS_CONFIG=$(cat /etc/elite-x/subdomain 2>/dev/null)
if [ -z "$NS_CONFIG" ]; then
    NS_CONFIG="ns-free.elitex.sbs"
fi

# Kill existing processes
pkill -f dnstt-server 2>/dev/null
pkill -f edns-proxy 2>/dev/null
sleep 2

# Start DNSTT server
/usr/local/bin/dnstt-server -udp :5300 -mtu 1400 -privkey-file /etc/dnstt/server.key "$NS_CONFIG" 127.0.0.1:22 &

# Start EDNS proxy
/usr/local/bin/edns-proxy &

sleep 2

# ==============================================================================
# FINAL VERIFICATION
# ==============================================================================
clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}              ELITE-X8 FALCON ULTIMATE v5.2 - READY!                   ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"

# Check DNSTT
if pgrep -f "dnstt-server" > /dev/null; then
    echo -e "${GREEN}║  ✅ DNSTT Server: Running on port 5300${NC}"
else
    echo -e "${RED}║  ❌ DNSTT Server: Not running${NC}"
fi

# Check EDNS Proxy
if pgrep -f "edns-proxy" > /dev/null; then
    echo -e "${GREEN}║  ✅ EDNS Proxy: Running on port 53${NC}"
else
    echo -e "${RED}║  ❌ EDNS Proxy: Not running${NC}"
fi

# Check SSH
if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
    echo -e "${GREEN}║  ✅ SSH Server: Running on port 22${NC}"
else
    echo -e "${RED}║  ❌ SSH Server: Not running${NC}"
fi

echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Nameserver:   ${CYAN}$NS_CONFIG${NC}"
echo -e "${GREEN}║${WHITE}  Server IP:    ${CYAN}195.238.122.222${NC}"
echo -e "${GREEN}║${WHITE}  Public Key:   ${CYAN}40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📌 QUICK COMMANDS:${NC}"
echo -e "   ${GREEN}elitex${NC}              - Open terminal panel"
echo -e "   ${GREEN}elite-x8-user add${NC}   - Create new user"
echo -e "   ${GREEN}elite-x8-user list${NC}  - List all users"
echo ""
echo -e "${CYAN}🎯 SLOWDNS CONFIG FOR CLIENTS:${NC}"
echo -e "   NS     : ${GREEN}$NS_CONFIG${NC}"
echo -e "   PUBKEY : ${GREEN}40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04${NC}"
echo -e "   PORT   : ${GREEN}53${NC}"
echo ""
echo -e "${GREEN}✅ Type 'elitex' to start the panel${NC}"

# Create alias for menu
echo "alias menu='elitex'" >> ~/.bashrc 2>/dev/null
