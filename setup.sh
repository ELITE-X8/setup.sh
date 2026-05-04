#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
#  FALCON ULTRA X v4.0 - COMPLETE VPN SUITE (FIXED)
#  SSH + SNI + Payload + VMess/VLess + SlowDNS + Dropbear + SSL
# ╚══════════════════════════════════════════════════════════════════╝

clear
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
NC='\033[0m'

STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

USER_DB="/etc/elite-x/users"
XDATA_DIR="/etc/elite-x"
CUSTOM_MSG_FILE="/etc/elite-x/switch_protocol_msg"
DEFAULT_SWITCH_MSG="HTTP/1.1 101 Switching Protocols"
SNI_CONF="/etc/elite-x/sni_config"

mkdir -p "$XDATA_DIR" /etc/xray /usr/local/bin /etc/nginx/conf.d /home/vps/public_html 2>/dev/null
echo "$DEFAULT_SWITCH_MSG" > "$CUSTOM_MSG_FILE" 2>/dev/null

# ═══════════════════════════════════════
# FIX: Set custom switch protocol message function
# ═══════════════════════════════════════
set_custom_message() {
    clear
    current_msg=$(cat "$CUSTOM_MSG_FILE" 2>/dev/null || echo "$DEFAULT_SWITCH_MSG")
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}     CUSTOM SWITCH PROTOCOL MESSAGE    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "${WHITE}Current message:${NC}"
    echo -e "${GREEN}$current_msg${NC}"
    echo ""
    echo -e "${YELLOW}Enter new message (or press Enter for default):${NC}"
    read -p "> " new_msg
    if [ -z "$new_msg" ]; then
        echo "$DEFAULT_SWITCH_MSG" > "$CUSTOM_MSG_FILE"
    else
        echo "$new_msg" > "$CUSTOM_MSG_FILE"
    fi
    # Update WebSocket scripts with new message
    SWITCH_MSG=$(cat "$CUSTOM_MSG_FILE")
    sed -i "s|SWITCH_MSG = .*|SWITCH_MSG = \"$SWITCH_MSG\"|" /usr/local/bin/ws-tls 2>/dev/null
    sed -i "s|SWITCH_MSG = .*|SWITCH_MSG = \"$SWITCH_MSG\"|" /usr/local/bin/ws-nontls 2>/dev/null
    sed -i "s|SWITCH_MSG = .*|SWITCH_MSG = \"$SWITCH_MSG\"|" /usr/local/bin/ws-ovpn 2>/dev/null
    systemctl restart ws-tls ws-nontls ws-ovpn 2>/dev/null
    echo -e "${GREEN}✅ Message updated!${NC}"
    read -p "Press Enter to continue..."
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL BADVPN
# ═══════════════════════════════════════
install_badvpn() {
    echo -e "${YELLOW}📝 Installing BadVPN UDPGW...${NC}"
    wget -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/NevermoreSSH/hop/main/ssh/badvpn-udpgw64" 2>/dev/null
    chmod +x /usr/bin/badvpn-udpgw
    
    cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 1000
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable badvpn 2>/dev/null
    systemctl start badvpn 2>/dev/null
    echo -e "${GREEN}✅ BadVPN installed${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL DROPBEAR
# ═══════════════════════════════════════
install_dropbear() {
    echo -e "${YELLOW}📝 Installing Dropbear...${NC}"
    apt install -y dropbear 2>/dev/null
    
    cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109 -p 443"
EOF
    
    systemctl restart dropbear 2>/dev/null
    systemctl enable dropbear 2>/dev/null
    echo -e "${GREEN}✅ Dropbear installed (ports: 109, 143, 443)${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL STUNNEL4/SSL
# ═══════════════════════════════════════
install_stunnel() {
    echo -e "${YELLOW}📝 Installing Stunnel4 (SSL/TLS)...${NC}"
    apt install -y stunnel4 2>/dev/null
    
    cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/xray/xray.crt
key = /etc/xray/xray.key
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 445
connect = 127.0.0.1:109

[openssh]
accept = 777
connect = 127.0.0.1:22

[openvpn]
accept = 990
connect = 127.0.0.1:1194
EOF

    systemctl restart stunnel4 2>/dev/null
    systemctl enable stunnel4 2>/dev/null
    echo -e "${GREEN}✅ Stunnel4 installed (ports: 445, 777, 990)${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL WEBSOCKET PROXY
# ═══════════════════════════════════════
install_websocket() {
    echo -e "${YELLOW}📝 Installing WebSocket Proxies...${NC}"
    
    SWITCH_MSG=$(cat "$CUSTOM_MSG_FILE" 2>/dev/null || echo "$DEFAULT_SWITCH_MSG")
    
    # WebSocket Non-TLS (Port 80 → Dropbear 109)
    cat > /usr/local/bin/ws-nontls <<PYEOF
#!/usr/bin/python
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(sys.argv[1])
DEFAULT_HOST = '127.0.0.1:109'
BUFLEN = 4096 * 4
TIMEOUT = 60
SWITCH_MSG = "$SWITCH_MSG"

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, int(self.port)))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.threadsLock.acquire()
                if self.running: self.threads.append(conn)
                self.threadsLock.release()
        finally:
            self.running = False
            self.soc.close()
    def close(self):
        self.running = False
        self.threadsLock.acquire()
        for c in list(self.threads): c.close()
        self.threadsLock.release()

class ConnectionHandler(threading.Thread):
    def __init__(self, client, server, addr):
        threading.Thread.__init__(self)
        self.client = client
        self.server = server
        self.client_buffer = ''
        self.target = None
    def close(self):
        try: self.client.close()
        except: pass
        try:
            if self.target: self.target.close()
        except: pass
    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            i = DEFAULT_HOST.find(':')
            port = int(DEFAULT_HOST[i+1:])
            host = DEFAULT_HOST[:i]
            self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.target.connect((host, port))
            self.client.send(SWITCH_MSG + "\r\nContent-Length: 104857600000\r\n\r\n")
            socs = [self.client, self.target]
            count = 0
            error = False
            while True:
                count += 1
                recv, _, err = select.select(socs, [], socs, 3)
                if err: error = True
                if recv:
                    for in_ in recv:
                        try:
                            data = in_.recv(BUFLEN)
                            if data:
                                if in_ is self.target: self.client.send(data)
                                else:
                                    while data:
                                        byte = self.target.send(data)
                                        data = data[byte:]
                                count = 0
                            else: break
                        except:
                            error = True
                            break
                if count == TIMEOUT: error = True
                if error: break
        except: pass
        finally:
            self.close()
            self.server.threadsLock.acquire()
            if self in self.server.threads: self.server.threads.remove(self)
            self.server.threadsLock.release()

srv = Server(LISTENING_ADDR, LISTENING_PORT)
srv.start()
while True: time.sleep(10)
PYEOF
    chmod +x /usr/local/bin/ws-nontls

    # WebSocket TLS (Port 443 → SSH 22)
    cat > /usr/local/bin/ws-tls <<PYEOF2
#!/usr/bin/python
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(sys.argv[1])
DEFAULT_HOST = '127.0.0.1:22'
BUFLEN = 4096 * 4
TIMEOUT = 60
SWITCH_MSG = "$SWITCH_MSG"

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, int(self.port)))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.threadsLock.acquire()
                if self.running: self.threads.append(conn)
                self.threadsLock.release()
        finally:
            self.running = False
            self.soc.close()
    def close(self):
        self.running = False
        self.threadsLock.acquire()
        for c in list(self.threads): c.close()
        self.threadsLock.release()

class ConnectionHandler(threading.Thread):
    def __init__(self, client, server, addr):
        threading.Thread.__init__(self)
        self.client = client
        self.server = server
        self.client_buffer = ''
        self.target = None
    def close(self):
        try: self.client.close()
        except: pass
        try:
            if self.target: self.target.close()
        except: pass
    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            i = DEFAULT_HOST.find(':')
            port = int(DEFAULT_HOST[i+1:])
            host = DEFAULT_HOST[:i]
            self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.target.connect((host, port))
            self.client.send(SWITCH_MSG + "\r\nContent-Length: 104857600000\r\n\r\n")
            socs = [self.client, self.target]
            count = 0
            error = False
            while True:
                count += 1
                recv, _, err = select.select(socs, [], socs, 3)
                if err: error = True
                if recv:
                    for in_ in recv:
                        try:
                            data = in_.recv(BUFLEN)
                            if data:
                                if in_ is self.target: self.client.send(data)
                                else:
                                    while data:
                                        byte = self.target.send(data)
                                        data = data[byte:]
                                count = 0
                            else: break
                        except:
                            error = True
                            break
                if count == TIMEOUT: error = True
                if error: break
        except: pass
        finally:
            self.close()
            self.server.threadsLock.acquire()
            if self in self.server.threads: self.server.threads.remove(self)
            self.server.threadsLock.release()

srv = Server(LISTENING_ADDR, LISTENING_PORT)
srv.start()
while True: time.sleep(10)
PYEOF2
    chmod +x /usr/local/bin/ws-tls

    # WebSocket OVPN (Port 2086 → OpenVPN 1194)
    cat > /usr/local/bin/ws-ovpn <<PYEOF3
#!/usr/bin/python
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(sys.argv[1])
DEFAULT_HOST = '127.0.0.1:1194'
BUFLEN = 4096 * 4
TIMEOUT = 60
SWITCH_MSG = "$SWITCH_MSG"

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, int(self.port)))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.threadsLock.acquire()
                if self.running: self.threads.append(conn)
                self.threadsLock.release()
        finally:
            self.running = False
            self.soc.close()
    def close(self):
        self.running = False
        self.threadsLock.acquire()
        for c in list(self.threads): c.close()
        self.threadsLock.release()

class ConnectionHandler(threading.Thread):
    def __init__(self, client, server, addr):
        threading.Thread.__init__(self)
        self.client = client
        self.server = server
        self.client_buffer = ''
        self.target = None
    def close(self):
        try: self.client.close()
        except: pass
        try:
            if self.target: self.target.close()
        except: pass
    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            i = DEFAULT_HOST.find(':')
            port = int(DEFAULT_HOST[i+1:])
            host = DEFAULT_HOST[:i]
            self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.target.connect((host, port))
            self.client.send(SWITCH_MSG + "\r\nContent-Length: 104857600000\r\n\r\n")
            socs = [self.client, self.target]
            count = 0
            error = False
            while True:
                count += 1
                recv, _, err = select.select(socs, [], socs, 3)
                if err: error = True
                if recv:
                    for in_ in recv:
                        try:
                            data = in_.recv(BUFLEN)
                            if data:
                                if in_ is self.target: self.client.send(data)
                                else:
                                    while data:
                                        byte = self.target.send(data)
                                        data = data[byte:]
                                count = 0
                            else: break
                        except:
                            error = True
                            break
                if count == TIMEOUT: error = True
                if error: break
        except: pass
        finally:
            self.close()
            self.server.threadsLock.acquire()
            if self in self.server.threads: self.server.threads.remove(self)
            self.server.threadsLock.release()

srv = Server(LISTENING_ADDR, LISTENING_PORT)
srv.start()
while True: time.sleep(10)
PYEOF3
    chmod +x /usr/local/bin/ws-ovpn

    # Systemd services
    cat > /etc/systemd/system/ws-nontls.service <<EOF
[Unit]
Description=WebSocket Non-TLS Proxy (Port 80 -> Dropbear)
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python /usr/local/bin/ws-nontls 80
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/ws-tls.service <<EOF
[Unit]
Description=WebSocket TLS Proxy (Port 443 -> SSH)
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python /usr/local/bin/ws-tls 443
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/ws-ovpn.service <<EOF
[Unit]
Description=WebSocket OVPN Proxy (Port 2086 -> OpenVPN)
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python /usr/local/bin/ws-ovpn 2086
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ws-nontls ws-tls ws-ovpn 2>/dev/null
    systemctl start ws-nontls ws-tls ws-ovpn 2>/dev/null
    echo -e "${GREEN}✅ WebSocket Proxies installed${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL OPENVPN
# ═══════════════════════════════════════
install_openvpn() {
    echo -e "${YELLOW}📝 Installing OpenVPN...${NC}"
    apt install -y openvpn easy-rsa 2>/dev/null
    
    mkdir -p /etc/openvpn/server/easy-rsa/
    cd /etc/openvpn/
    wget -q https://raw.githubusercontent.com/FasterExE/VIP-Autoscript/main/ssh/vpn.zip
    unzip -o vpn.zip 2>/dev/null
    rm -f vpn.zip
    
    mkdir -p /usr/lib/openvpn/
    cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/ 2>/dev/null
    
    IPVPS=$(curl -s ifconfig.me)
    NET=$(ip -o -4 route show to default | awk '{print $5}')
    
    cat > /etc/openvpn/server/server-tcp.conf <<OVPNEOF
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
verify-client-cert none
username-as-common-name
server 10.6.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 5 30
comp-lzo
persist-key
persist-tun
status openvpn-tcp.log
verb 3
OVPNEOF

    cat > /etc/openvpn/server/server-udp.conf <<OVPNEOF2
port 2200
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
verify-client-cert none
username-as-common-name
server 10.7.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 5 30
comp-lzo
persist-key
persist-tun
status openvpn-udp.log
verb 3
explicit-exit-notify
OVPNEOF2

    mkdir -p /home/vps/public_html
    
    cat > /home/vps/public_html/client-tcp-1194.ovpn <<OVPNCLIENT
client
dev tun
proto tcp
remote $IPVPS 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
<ca>
$(cat /etc/openvpn/server/ca.crt 2>/dev/null)
</ca>
OVPNCLIENT

    cat > /home/vps/public_html/client-udp-2200.ovpn <<OVPNCLIENT2
client
dev tun
proto udp
remote $IPVPS 2200
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
<ca>
$(cat /etc/openvpn/server/ca.crt 2>/dev/null)
</ca>
OVPNCLIENT2

    sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn
    systemctl enable openvpn-server@server-tcp 2>/dev/null
    systemctl enable openvpn-server@server-udp 2>/dev/null
    systemctl start openvpn-server@server-tcp 2>/dev/null
    systemctl start openvpn-server@server-udp 2>/dev/null
    
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -I POSTROUTING -s 10.6.0.0/24 -o $NET -j MASQUERADE 2>/dev/null
    iptables -t nat -I POSTROUTING -s 10.7.0.0/24 -o $NET -j MASQUERADE 2>/dev/null
    
    echo -e "${GREEN}✅ OpenVPN installed${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL XRAY + VMESS/VLESS
# ═══════════════════════════════════════
install_xray() {
    echo -e "${YELLOW}📝 Installing Xray Core...${NC}"
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.8.4 2>/dev/null
    
    domain=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "localhost")
    uuid=$(cat /proc/sys/kernel/random/uuid)
    mkdir -p /etc/xray /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 777 /var/log/xray/*.log 2>/dev/null
    
    cat > /etc/xray/config.json <<XRAYEOF
{
  "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
  "inbounds": [
    {"listen": "127.0.0.1", "port": 10085, "protocol": "dokodemo-door", "settings": {"address": "127.0.0.1"}, "tag": "api"},
    {"listen": "127.0.0.1", "port": 14016, "protocol": "vless", "settings": {"decryption": "none", "clients": [{"id": "$uuid"}]}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}},
    {"listen": "127.0.0.1", "port": 23456, "protocol": "vmess", "settings": {"clients": [{"id": "$uuid", "alterId": 0}]}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}},
    {"listen": "127.0.0.1", "port": 24456, "protocol": "vless", "settings": {"decryption": "none", "clients": [{"id": "$uuid"}]}, "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "vless-grpc"}}},
    {"listen": "127.0.0.1", "port": 31234, "protocol": "vmess", "settings": {"clients": [{"id": "$uuid", "alterId": 0}]}, "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "vmess-grpc"}}}
  ],
  "outbounds": [{"protocol": "freedom", "settings": {}}, {"protocol": "blackhole", "settings": {}, "tag": "blocked"}],
  "routing": {"rules": [{"type": "field", "ip": ["0.0.0.0/8","10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"], "outboundTag": "blocked"}, {"inboundTag": ["api"], "outboundTag": "api", "type": "field"}]}
}
XRAYEOF

    # Nginx config
    cat > /etc/nginx/conf.d/xray.conf <<NGXEOF
server {
    listen 81;
    server_name _;
    root /home/vps/public_html;
    
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:23456;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:14016;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    location ^~ /vless-grpc {
        grpc_pass grpc://127.0.0.1:24456;
    }
    location ^~ /vmess-grpc {
        grpc_pass grpc://127.0.0.1:31234;
    }
}
NGXEOF

    systemctl restart xray nginx 2>/dev/null
    systemctl enable xray 2>/dev/null
    echo -e "${GREEN}✅ Xray + VMess/VLess installed${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL XRAY SCRIPTS
# ═══════════════════════════════════════
install_xray_scripts() {
    echo -e "${YELLOW}📝 Installing VMess/VLess scripts...${NC}"
    
    cat > /usr/local/bin/add-vmess <<'ADDVMESS'
#!/bin/bash
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'
domain=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "localhost")
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}           CREATE VMESS ACCOUNT           ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
read -p "Username: " user; [ -z "$user" ] && { echo "Invalid!"; exit 1; }
read -p "Expired (days) [30]: " days; days=${days:-30}
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "+$days days" +"%Y-%m-%d")
sed -i '/#vmess$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vmessgrpc$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
systemctl restart xray 2>/dev/null
vm_tls="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"tls\":\"tls\"}"
vm_nt="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"tls\":\"none\"}"
vm_grpc="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess-grpc\",\"tls\":\"tls\"}"
clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}      VMESS ACCOUNT CREATED     ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE} User: ${CYAN}$user${NC}  ${WHITE}Exp: ${CYAN}$exp${NC}"
echo -e "${GREEN}║${WHITE} UUID: ${CYAN}$uuid${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WS TLS (443):${NC}"
echo -e "${GREEN}║${WHITE} vmess://$(echo $vm_tls | base64 -w 0)${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WS Non-TLS (80):${NC}"
echo -e "${GREEN}║${WHITE} vmess://$(echo $vm_nt | base64 -w 0)${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} gRPC (443):${NC}"
echo -e "${GREEN}║${WHITE} vmess://$(echo $vm_grpc | base64 -w 0)${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
read -p "Press Enter..."
ADDVMESS
    chmod +x /usr/local/bin/add-vmess

    cat > /usr/local/bin/add-vless <<'ADDVLESS'
#!/bin/bash
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'
domain=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "localhost")
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}           CREATE VLESS ACCOUNT           ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
read -p "Username: " user; [ -z "$user" ] && { echo "Invalid!"; exit 1; }
read -p "Expired (days) [30]: " days; days=${days:-30}
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "+$days days" +"%Y-%m-%d")
sed -i '/#vless$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vlessgrpc$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
systemctl restart xray 2>/dev/null
clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}      VLESS ACCOUNT CREATED     ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE} User: ${CYAN}$user${NC}  ${WHITE}Exp: ${CYAN}$exp${NC}"
echo -e "${GREEN}║${WHITE} UUID: ${CYAN}$uuid${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WS TLS:${NC}"
echo -e "${GREEN}║${WHITE} vless://${uuid}@${domain}:443?security=tls&encryption=none&type=ws&path=/vless&sni=${domain}#${user}${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WS Non-TLS:${NC}"
echo -e "${GREEN}║${WHITE} vless://${uuid}@${domain}:80?security=none&encryption=none&type=ws&path=/vless#${user}${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} gRPC:${NC}"
echo -e "${GREEN}║${WHITE} vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
read -p "Press Enter..."
ADDVLESS
    chmod +x /usr/local/bin/add-vless
    echo -e "${GREEN}✅ Xray scripts installed${NC}"
}

# ═══════════════════════════════════════
# FIX: CREATE PROPER MENU SCRIPT
# ═══════════════════════════════════════
create_menu() {
    cat > /usr/local/bin/menu <<'MENUEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
PURPLE='\033[0;35m'; WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

while true; do
    clear
    IP=$(curl -s ifconfig.me 2>/dev/null || echo "N/A")
    DOMAIN=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "N/A")
    SNI=$(cat /etc/elite-x/sni_config 2>/dev/null || echo "N/A")
    TOTAL=$(ls /etc/elite-x/users 2>/dev/null | wc -l)
    ONLINE=$(who | wc -l)
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}         FALCON ULTRA X v4.0 - MAIN MENU          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE} IP: ${GREEN}$IP${WHITE} | Domain: ${GREEN}$DOMAIN${NC}"
    echo -e "${PURPLE}║${WHITE} SNI: ${GREEN}$SNI${WHITE} | Users: ${GREEN}$TOTAL${WHITE} | Online: ${GREEN}$ONLINE${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}                    MAIN MENU                      ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE} [1]  Create SSH User       [2]  List Users${NC}"
    echo -e "${PURPLE}║${WHITE} [3]  Delete User           [4]  Renew User${NC}"
    echo -e "${PURPLE}║${WHITE} [5]  Lock/Unlock User      [6]  Create VMess${NC}"
    echo -e "${PURPLE}║${WHITE} [7]  Create VLess           [8]  Restart All Services${NC}"
    echo -e "${PURPLE}║${WHITE} [9]  Custom Switch Msg      [10] Check User Login${NC}"
    echo -e "${PURPLE}║${WHITE} [11] Speed Test             [12] Reboot VPS${NC}"
    echo -e "${PURPLE}║${WHITE} [0]  Exit${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $GREEN"Option: "$NC)" opt
    
    case $opt in
        1) adduser ;;
        2) 
            clear
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}                         USER LIST${NC}"
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
            printf "${WHITE}%-15s %-14s %-10s %-10s${NC}\n" "USERNAME" "EXPIRE" "STATUS" "ONLINE"
            echo "──────────────────────────────────────────────────────────"
            for uf in /etc/elite-x/users/*; do
                [ ! -f "$uf" ] && continue
                u=$(basename "$uf")
                ex=$(grep "Expire:" "$uf" | cut -d' ' -f2)
                if passwd -S "$u" 2>/dev/null | grep -q "L"; then
                    st="${RED}LOCKED${NC}"
                else
                    exp_ts=$(date -d "$ex" +%s 2>/dev/null || echo 0)
                    [ $(date +%s) -gt $exp_ts ] && st="${RED}EXPIRED${NC}" || st="${GREEN}ACTIVE${NC}"
                fi
                c=$(who | grep -wc "$u" 2>/dev/null || echo 0)
                [ "$c" -gt 0 ] && on="${GREEN}$c${NC}" || on="${GRAY}0${NC}"
                printf "%-15s %-14b %-10b %-10b\n" "$u" "$ex" "$st" "$on"
            done
            echo ""
            echo -e "${YELLOW}Total: ${GREEN}$TOTAL${YELLOW} | Online: ${GREEN}$ONLINE${NC}"
            read -p "Press Enter..." ;;
        3) read -p "Username to delete: " u; pkill -u "$u" 2>/dev/null; userdel -r "$u" 2>/dev/null; rm -f "/etc/elite-x/users/$u"; echo -e "${GREEN}✅ Deleted${NC}"; read -p "Press Enter..." ;;
        4) read -p "Username: " u; read -p "Add days: " d; cur=$(grep "Expire:" "/etc/elite-x/users/$u" | cut -d' ' -f2); new=$(date -d "$cur +$d days" +"%Y-%m-%d"); sed -i "s/Expire: .*/Expire: $new/" "/etc/elite-x/users/$u"; chage -E "$new" "$u" 2>/dev/null; usermod -U "$u" 2>/dev/null; echo -e "${GREEN}✅ Renewed${NC}"; read -p "Press Enter..." ;;
        5) read -p "Username: " u; echo "1)Lock 2)Unlock"; read l; [ "$l" = "1" ] && { usermod -L "$u"; pkill -u "$u"; echo "Locked"; } || { usermod -U "$u"; echo "Unlocked"; }; read -p "Press Enter..." ;;
        6) add-vmess ;;
        7) add-vless ;;
        8) for s in ssh dropbear stunnel4 nginx xray ws-tls ws-nontls ws-ovpn badvpn openvpn-server@server-tcp openvpn-server@server-udp dnstt-elite-x dnstt-elite-x-proxy; do systemctl restart $s 2>/dev/null; done; echo -e "${GREEN}✅ All restarted${NC}"; read -p "Press Enter..." ;;
        9) set_custom_message ;;
        10) 
            clear
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}                    ACTIVE SSH LOGINS${NC}"
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
            who
            echo ""
            netstat -tnlp | grep -E ':(22|109|143|443|80|777|990|1194|2200|2086)' 2>/dev/null | while read line; do
                echo "$line"
            done
            read -p "Press Enter..." ;;
        11) curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - 2>/dev/null || echo "Speedtest not available"; read -p "Press Enter..." ;;
        12) read -p "Reboot VPS? (y/n): " r; [ "$r" = "y" ] && reboot ;;
        0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    esac
done
MENUEOF
    chmod +x /usr/local/bin/menu
}

# ═══════════════════════════════════════
# FIX: CREATE ADDUSER SCRIPT
# ═══════════════════════════════════════
create_adduser() {
    cat > /usr/local/bin/adduser <<'ADDUSEREOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}${BOLD}        CREATE SSH + ALL SERVICES USER        ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Username: " username
if id "$username" &>/dev/null; then echo -e "${RED}User exists!${NC}"; exit 1; fi

read -p "Password [auto]: " password
[ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10) && echo -e "${GREEN}Generated: ${YELLOW}$password${NC}"

read -p "Expire (days) [30]: " days; days=${days:-30}
read -p "Max Devices [2]: " maxdev; maxdev=${maxdev:-2}

useradd -m -s /bin/false "$username"
echo "$username:$password" | chpasswd
exp_date=$(date -d "+$days days" +"%Y-%m-%d")
chage -E "$exp_date" "$username"

mkdir -p /etc/elite-x/users
cat > "/etc/elite-x/users/$username" <<INFO
Username: $username
Password: $password
Expire: $exp_date
Max_Devices: $maxdev
Created: $(date)
INFO

IP=$(curl -s ifconfig.me 2>/dev/null || echo "N/A")
DOMAIN=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "N/A")
PUBKEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "N/A")
SNI=$(cat /etc/elite-x/sni_config 2>/dev/null || echo "N/A")

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}              ACCOUNT CREATED SUCCESSFULLY              ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE} Username   : ${CYAN}$username${NC}"
echo -e "${GREEN}║${WHITE} Password   : ${CYAN}$password${NC}"
echo -e "${GREEN}║${WHITE} Expired    : ${CYAN}$exp_date${NC}"
echo -e "${GREEN}║${WHITE} Max Devices: ${CYAN}$maxdev${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW}                   SERVER INFORMATION                     ${GREEN}║${NC}"
echo -e "${GREEN}║${WHITE} IP/Host    : ${CYAN}$IP${NC}"
echo -e "${GREEN}║${WHITE} SNI/Domain : ${CYAN}$DOMAIN${NC}"
echo -e "${GREEN}║${WHITE} CDN/SNI    : ${CYAN}$SNI${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW}                   SERVICE PORTS                          ${GREEN}║${NC}"
echo -e "${GREEN}║${WHITE} SSH Direct  : 22${NC}"
echo -e "${GREEN}║${WHITE} SSH WS TLS  : 443 (WebSocket)${NC}"
echo -e "${GREEN}║${WHITE} SSH WS HTTP : 80 (WebSocket)${NC}"
echo -e "${GREEN}║${WHITE} Dropbear    : 109, 143${NC}"
echo -e "${GREEN}║${WHITE} SSL/TLS     : 445, 777, 990${NC}"
echo -e "${GREEN}║${WHITE} OpenVPN TCP : 1194 | WS: 2086${NC}"
echo -e "${GREEN}║${WHITE} OpenVPN UDP : 2200${NC}"
echo -e "${GREEN}║${WHITE} BadVPN      : 7100, 7200, 7300${NC}"
echo -e "${GREEN}║${WHITE} VMess WS    : 443 (TLS), 80 (Non-TLS)${NC}"
echo -e "${GREEN}║${WHITE} VMess gRPC  : 443${NC}"
echo -e "${GREEN}║${WHITE} VLess WS    : 443 (TLS), 80 (Non-TLS)${NC}"
echo -e "${GREEN}║${WHITE} VLess gRPC  : 443${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW}                   SLOWDNS CONFIG                          ${GREEN}║${NC}"
echo -e "${GREEN}║${WHITE} NS         : ${CYAN}$DOMAIN${NC}"
echo -e "${GREEN}║${WHITE} Public Key : ${CYAN}$PUBKEY${NC}"
echo -e "${GREEN}║${WHITE} Port       : 53${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW}                   PAYLOADS (WebSocket)                    ${GREEN}║${NC}"
echo -e "${GREEN}║${WHITE} WS TLS:${NC}"
echo -e "${GREEN}║${CYAN} GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e "${GREEN}║${WHITE} WS CDN (Cloudflare/Nginx/BunnyCDN/Cloudfront):${NC}"
echo -e "${GREEN}║${CYAN} GET wss://$SNI/ HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
read -p "Press Enter to continue..."
ADDUSEREOF
    chmod +x /usr/local/bin/adduser
}

# ═══════════════════════════════════════
# MAIN INSTALLATION
# ═══════════════════════════════════════
run_installation() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}      FALCON ULTRA X v4.0 - INSTALLATION       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Enter Activation Key:${NC}"
    read -p "> " key
    if [ "$key" != "$ACTIVATION_KEY" ] && [ "$key" != "Whtsapp +255713-628-668" ]; then
        echo -e "${RED}❌ Invalid key!${NC}"; exit 1
    fi
    echo -e "${GREEN}✅ Activated!${NC}"; sleep 1
    
    timedatectl set-timezone $TIMEZONE 2>/dev/null
    
    # STEP 1: SNI
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  STEP 1: ENTER YOUR SNI/DOMAIN (Pointed to VPS)   ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    read -p "SNI/Domain: " SNI_DOMAIN
    echo "$SNI_DOMAIN" > "$SNI_CONF"
    
    # STEP 2: NS
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  STEP 2: ENTER YOUR NAMESERVER (NS)             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    read -p "NS [default: $SNI_DOMAIN]: " NS_DOMAIN
    [ -z "$NS_DOMAIN" ] && NS_DOMAIN="$SNI_DOMAIN"
    echo "$NS_DOMAIN" > /etc/elite-x/subdomain
    
    # STEP 3: Location
    echo ""
    echo -e "${YELLOW}Select Location:${NC}"
    echo "  [1] South Africa (MTU 1800)"
    echo "  [2] USA (MTU 1500)"
    echo "  [3] Europe (MTU 1500)"
    echo "  [4] Asia (MTU 1400)"
    read -p "Choice [1]: " loc; loc=${loc:-1}
    case $loc in
        2) MTU=1500; LOC_NAME="USA" ;;
        3) MTU=1500; LOC_NAME="Europe" ;;
        4) MTU=1400; LOC_NAME="Asia" ;;
        *) MTU=1800; LOC_NAME="South Africa" ;;
    esac
    echo "$LOC_NAME" > /etc/elite-x/location
    echo "$MTU" > /etc/elite-x/mtu
    
    echo ""
    echo -e "${YELLOW}🔄 Installing...${NC}"
    
    apt update -y
    apt install -y curl wget jq bc net-tools python python3 unzip nginx dropbear stunnel4 openvpn easy-rsa build-essential gcc 2>/dev/null
    
    # Create directories
    mkdir -p /etc/elite-x/users /etc/dnstt /etc/xray /home/vps/public_html
    
    # Save keys
    echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key
    echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key
    echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
    echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
    
    # Install components
    install_badvpn
    install_dropbear
    install_websocket
    install_openvpn
    
    # SSL Certificate
    openssl req -new -x509 -days 3650 -nodes -out /etc/xray/xray.crt -keyout /etc/xray/xray.key \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Falcon/OU=Falcon/CN=$SNI_DOMAIN" 2>/dev/null
    chmod 644 /etc/xray/xray.crt /etc/xray/xray.key
    
    install_stunnel
    install_xray
    install_xray_scripts
    
    # DNSTT (SlowDNS)
    curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null
    chmod +x /usr/local/bin/dnstt-server
    
    cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=DNSTT Server
After=network.target
[Service]
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu $MTU -privkey-file /etc/dnstt/server.key $NS_DOMAIN 127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    # Nginx default
    cat > /etc/nginx/sites-enabled/default <<NGXEOF
server {
    listen 80;
    server_name _;
    root /home/vps/public_html;
    location / { try_files \$uri \$uri/ /index.html; }
}
NGXEOF

    # Create menu & adduser
    create_menu
    create_adduser
    
    # Create users command
    cat > /usr/local/bin/users <<'USERSEOF'
#!/bin/bash
clear
echo -e "══════════════════════════════════════════════════════════════"
echo -e "                         USER LIST"
echo -e "══════════════════════════════════════════════════════════════"
printf "%-15s %-14s %-10s %-10s\n" "USERNAME" "EXPIRE" "STATUS" "ONLINE"
echo "──────────────────────────────────────────────────────────"
for uf in /etc/elite-x/users/*; do
    [ ! -f "$uf" ] && continue
    u=$(basename "$uf")
    ex=$(grep "Expire:" "$uf" | cut -d' ' -f2)
    if passwd -S "$u" 2>/dev/null | grep -q "L"; then st="LOCKED"
    else [ $(date +%s) -gt $(date -d "$ex" +%s 2>/dev/null) ] && st="EXPIRED" || st="ACTIVE"; fi
    c=$(who | grep -wc "$u" 2>/dev/null || echo 0)
    printf "%-15s %-14s %-10s %-10s\n" "$u" "$ex" "$st" "$c"
done
echo ""
USERSEOF
    chmod +x /usr/local/bin/users
    
    # Fix permissions
    chown -R www-data:www-data /home/vps/public_html 2>/dev/null
    
    # Start all services
    systemctl daemon-reload
    for svc in ssh dropbear stunnel4 nginx xray ws-tls ws-nontls ws-ovpn badvpn openvpn-server@server-tcp openvpn-server@server-udp dnstt-elite-x; do
        systemctl enable $svc 2>/dev/null
        systemctl restart $svc 2>/dev/null
    done
    
    # Aliases (FIXED)
    cat >> ~/.bashrc <<'BASHRCEOF'
alias menu='clear && /usr/local/bin/menu'
alias adduser='/usr/local/bin/adduser'
alias users='/usr/local/bin/users'
alias addvmess='/usr/local/bin/add-vmess'
alias addvless='/usr/local/bin/add-vless'
alias restart-all='for s in ssh dropbear stunnel4 nginx xray ws-tls ws-nontls ws-ovpn badvpn openvpn-server@server-tcp openvpn-server@server-udp dnstt-elite-x; do systemctl restart $s 2>/dev/null; done && echo "All restarted!"'
BASHRCEOF
    
    source ~/.bashrc 2>/dev/null
    
    # Final display
    IP=$(curl -s ifconfig.me 2>/dev/null)
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}     FALCON ULTRA X v4.0 INSTALLED SUCCESSFULLY!      ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE} SNI/Domain : ${CYAN}$SNI_DOMAIN${NC}"
    echo -e "${GREEN}║${WHITE} Nameserver : ${CYAN}$NS_DOMAIN${NC}"
    echo -e "${GREEN}║${WHITE} IP         : ${CYAN}$IP${NC}"
    echo -e "${GREEN}║${WHITE} Location   : ${CYAN}$LOC_NAME (MTU: $MTU)${NC}"
    echo -e "${GREEN}║${WHITE} Public Key : ${CYAN}$STATIC_PUBLIC_KEY${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW} SLOWDNS CLIENT CONFIG:${NC}"
    echo -e "${GREEN}║${WHITE} NS     : ${CYAN}$NS_DOMAIN${NC}"
    echo -e "${GREEN}║${WHITE} PUBKEY : ${CYAN}$STATIC_PUBLIC_KEY${NC}"
    echo -e "${GREEN}║${WHITE} PORT   : 53${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW} TYPE 'menu' TO ACCESS MAIN MENU${NC}"
    echo -e "${GREEN}║${YELLOW} Commands: menu | adduser | users | addvmess | addvless${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Run
run_installation
