#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
#  FALCON ULTRA X v4.0 - COMPLETE VPN SUITE
#  SSH + SNI + Payload + VMess/VLess + SlowDNS + Dropbear + SSL
#  SLOWDNS INABAKI KAMA ILIVYO (HAIJAGUSWA)
# ╚══════════════════════════════════════════════════════════════════╝
#  CREDIT: NevermoreSSH | ILYASS | FasterExE | Gemilangkinasih
#  WHATSAPP: +255713-628-668
# ═══════════════════════════════════════════════════════════════════

clear
# ═══════════════════════════════════════
# COLORS & VARIABLES
# ═══════════════════════════════════════
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; BOLD='\033[1m'
NC='\033[0m'
ORANGE='\033[0;33m'; LIGHT_RED='\033[1;31m'; LIGHT_GREEN='\033[1;32m'; GRAY='\033[0;90m'

STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE"
TIMEZONE="Africa/Dar_es_Salaam"

USER_DB="/etc/elite-x/users"
XDATA_DIR="/etc/elite-x"
CUSTOM_MSG_FILE="/etc/elite-x/switch_protocol_msg"
DEFAULT_SWITCH_MSG="HTTP/1.1 101 Switching Protocols"
SNI_CONF="/etc/elite-x/sni_config"
INSTALL_LOG="/root/falcon-install.log"

mkdir -p "$XDATA_DIR" /etc/xray /usr/local/bin /etc/nginx/conf.d
echo "$DEFAULT_SWITCH_MSG" > "$CUSTOM_MSG_FILE" 2>/dev/null

# ═══════════════════════════════════════
# FUNCTION: SET CUSTOM SWITCH PROTOCOL MESSAGE
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
        echo -e "${GREEN}✅ Reset to default${NC}"
    else
        echo "$new_msg" > "$CUSTOM_MSG_FILE"
        echo -e "${GREEN}✅ Message updated!${NC}"
    fi
    systemctl restart ws-tls ws-nontls ws-ovpn 2>/dev/null
    read -p "Press Enter to continue..."
}

# ═══════════════════════════════════════
# FUNCTION: BAD VPN UDPGW
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
# FUNCTION: INSTALL WEBSOCKET PROXY (PYTHON)
# ═══════════════════════════════════════
install_websocket() {
    echo -e "${YELLOW}📝 Installing Python WebSocket Proxy...${NC}"
    
    SWITCH_MSG=$(cat "$CUSTOM_MSG_FILE" 2>/dev/null || echo "$DEFAULT_SWITCH_MSG")
    
    # WebSocket untuk Dropbear (port 80)
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
            hostPort = '127.0.0.1:109'
            i = hostPort.find(':')
            port = int(hostPort[i+1:])
            host = hostPort[:i]
            self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.target.connect((host, port))
            self.client.send(SWITCH_MSG + "\\r\\nConnection: Upgrade\\r\\nUpgrade: websocket\\r\\n\\r\\n")
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

Server(LISTENING_ADDR, LISTENING_PORT).start()
while True: time.sleep(10)
PYEOF
    chmod +x /usr/local/bin/ws-nontls

    # WebSocket TLS (port 443)
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
            hostPort = '127.0.0.1:22'
            i = hostPort.find(':')
            port = int(hostPort[i+1:])
            host = hostPort[:i]
            self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.target.connect((host, port))
            self.client.send(SWITCH_MSG + "\\r\\nConnection: Upgrade\\r\\nUpgrade: websocket\\r\\n\\r\\n")
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

Server(LISTENING_ADDR, LISTENING_PORT).start()
while True: time.sleep(10)
PYEOF2
    chmod +x /usr/local/bin/ws-tls

    # WebSocket OVPN (port 2086)
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
            hostPort = '127.0.0.1:1194'
            i = hostPort.find(':')
            port = int(hostPort[i+1:])
            host = hostPort[:i]
            self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.target.connect((host, port))
            self.client.send(SWITCH_MSG + "\\r\\nConnection: Upgrade\\r\\nUpgrade: websocket\\r\\n\\r\\n")
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

Server(LISTENING_ADDR, LISTENING_PORT).start()
while True: time.sleep(10)
PYEOF3
    chmod +x /usr/local/bin/ws-ovpn

    # Create systemd services
    cat > /etc/systemd/system/ws-nontls.service <<EOF
[Unit]
Description=WebSocket Non-TLS Proxy
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
Description=WebSocket TLS Proxy
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
Description=WebSocket OVPN Proxy
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
    
    echo -e "${GREEN}✅ WebSocket Proxies installed (ports: 80, 443, 2086)${NC}"
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
    
    IPVPS=$(curl -s ipinfo.io/ip)
    NET=$(ip -o -4 route show to default | awk '{print $5}')
    
    # TCP config
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

    # UDP config
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

    # Client configs
    cat > /etc/openvpn/client-tcp-1194.ovpn <<OVPNCLIENT
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

    cat > /etc/openvpn/client-udp-2200.ovpn <<OVPNCLIENT2
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

    mkdir -p /home/vps/public_html
    cp /etc/openvpn/client-*.ovpn /home/vps/public_html/ 2>/dev/null
    
    sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn
    systemctl enable --now openvpn-server@server-tcp 2>/dev/null
    systemctl enable --now openvpn-server@server-udp 2>/dev/null
    
    echo 1 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -I POSTROUTING -s 10.6.0.0/24 -o $NET -j MASQUERADE
    iptables -t nat -I POSTROUTING -s 10.7.0.0/24 -o $NET -j MASQUERADE
    
    echo -e "${GREEN}✅ OpenVPN installed (TCP:1194, UDP:2200)${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL XRAY + VMESS/VLESS
# ═══════════════════════════════════════
install_xray() {
    echo -e "${YELLOW}📝 Installing Xray Core + VMess/VLess...${NC}"
    
    # Install Xray
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.8.4 2>/dev/null
    chown www-data:www-data /var/log/xray 2>/dev/null
    
    domain=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "localhost")
    uuid=$(cat /proc/sys/kernel/random/uuid)
    
    mkdir -p /etc/xray /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 777 /var/log/xray/*.log 2>/dev/null
    
    # Create Xray config
    cat > /etc/xray/config.json <<XRAYEOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {"address": "127.0.0.1"},
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": 14016,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{"id": "$uuid"}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vless"}
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 23456,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$uuid", "alterId": 0}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vmess"}
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 24456,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{"id": "$uuid"}]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "vless-grpc"}
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 31234,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$uuid", "alterId": 0}]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {"serviceName": "vmess-grpc"}
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "settings": {}},
    {"protocol": "blackhole", "settings": {}, "tag": "blocked"}
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["0.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
        "outboundTag": "blocked"
      },
      {"inboundTag": ["api"], "outboundTag": "api", "type": "field"}
    ]
  }
}
XRAYEOF

    # Nginx config for Xray
    cat > /etc/nginx/conf.d/xray.conf <<NGXEOF
server {
    listen 443 ssl http2;
    server_name $domain;
    
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    
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
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_pass grpc://127.0.0.1:24456;
    }
    
    location ^~ /vmess-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_pass grpc://127.0.0.1:31234;
    }
}
NGXEOF

    systemctl restart xray nginx 2>/dev/null
    systemctl enable xray 2>/dev/null
    
    echo -e "${GREEN}✅ Xray + VMess/VLess WebSocket + gRPC installed${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: INSTALL XRAY SCRIPTS
# ═══════════════════════════════════════
install_xray_scripts() {
    echo -e "${YELLOW}📝 Installing Xray management scripts...${NC}"
    
    # Add VMess
    cat > /usr/local/bin/add-vmess <<'ADDVMESS'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'

domain=$(cat /etc/xray/domain 2>/dev/null || cat /etc/elite-x/subdomain 2>/dev/null || echo "localhost")
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}           CREATE VMESS ACCOUNT           ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

read -p "Username: " user
[ -z "$user" ] && { echo "Invalid!"; exit 1; }
grep -w "### $user" /etc/xray/config.json >/dev/null && { echo "User exists!"; exit 1; }

read -p "Expired (days): " days
days=${days:-30}
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "+$days days" +"%Y-%m-%d")

sed -i '/#vmess$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vmessgrpc$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json

systemctl restart xray 2>/dev/null

vmess_tls="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"host\":\"\",\"tls\":\"tls\"}"
vmess_nontls="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"host\":\"\",\"tls\":\"none\"}"
vmess_grpc="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess-grpc\",\"host\":\"\",\"tls\":\"tls\"}"

link_tls="vmess://$(echo $vmess_tls | base64 -w 0)"
link_nontls="vmess://$(echo $vmess_nontls | base64 -w 0)"
link_grpc="vmess://$(echo $vmess_grpc | base64 -w 0)"

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}      VMESS ACCOUNT CREATED     ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE} User      : ${CYAN}$user${NC}"
echo -e "${GREEN}║${WHITE} Domain    : ${CYAN}$domain${NC}"
echo -e "${GREEN}║${WHITE} UUID      : ${CYAN}$uuid${NC}"
echo -e "${GREEN}║${WHITE} Expired   : ${CYAN}$exp${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WebSocket TLS (443):${NC}"
echo -e "${GREEN}║${WHITE} $link_tls${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WebSocket Non-TLS (80):${NC}"
echo -e "${GREEN}║${WHITE} $link_nontls${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} gRPC (443):${NC}"
echo -e "${GREEN}║${WHITE} $link_grpc${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
read -p "Press Enter to continue..."
ADDVMESS
    chmod +x /usr/local/bin/add-vmess

    # Add VLess (similar structure)
    cat > /usr/local/bin/add-vless <<'ADDVLESS'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'

domain=$(cat /etc/xray/domain 2>/dev/null || cat /etc/elite-x/subdomain 2>/dev/null || echo "localhost")
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}           CREATE VLESS ACCOUNT           ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

read -p "Username: " user
[ -z "$user" ] && { echo "Invalid!"; exit 1; }
grep -w "### $user" /etc/xray/config.json >/dev/null && { echo "User exists!"; exit 1; }

read -p "Expired (days): " days
days=${days:-30}
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "+$days days" +"%Y-%m-%d")

sed -i '/#vless$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vlessgrpc$/a### '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

systemctl restart xray 2>/dev/null

link_tls="vless://${uuid}@${domain}:443?security=tls&encryption=none&type=ws&path=/vless&sni=${domain}#${user}"
link_nontls="vless://${uuid}@${domain}:80?security=none&encryption=none&type=ws&path=/vless#${user}"
link_grpc="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}      VLESS ACCOUNT CREATED     ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE} User      : ${CYAN}$user${NC}"
echo -e "${GREEN}║${WHITE} Domain    : ${CYAN}$domain${NC}"
echo -e "${GREEN}║${WHITE} UUID      : ${CYAN}$uuid${NC}"
echo -e "${GREEN}║${WHITE} Expired   : ${CYAN}$exp${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WebSocket TLS (443):${NC}"
echo -e "${GREEN}║${WHITE} $link_tls${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} WebSocket Non-TLS (80):${NC}"
echo -e "${GREEN}║${WHITE} $link_nontls${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW} gRPC (443):${NC}"
echo -e "${GREEN}║${WHITE} $link_grpc${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
read -p "Press Enter to continue..."
ADDVLESS
    chmod +x /usr/local/bin/add-vless

    echo -e "${GREEN}✅ Xray management scripts installed${NC}"
}

# ═══════════════════════════════════════
# FUNCTION: CREATE USER (ENHANCED)
# ═══════════════════════════════════════
create_enhanced_user() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}        CREATE SSH + ALL SERVICES USER        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    if id "$username" &>/dev/null; then echo -e "${RED}User already exists!${NC}"; return; fi
    
    read -p "$(echo -e $GREEN"Password [auto]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10) && echo -e "${GREEN}Generated: ${YELLOW}$password${NC}"
    
    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" days; days=${days:-30}
    read -p "$(echo -e $GREEN"Max Devices [2]: "$NC)" maxdev; maxdev=${maxdev:-2}
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$exp_date" "$username"
    
    # Save user info
    cat > "$USER_DB/$username" <<USERINFO
Username: $username
Password: $password
Expire: $exp_date
Max_Devices: $maxdev
Created: $(date)
USERINFO
    
    # Get server details
    IP=$(curl -s ifconfig.me)
    DOMAIN=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not set")
    PUBKEY=$(cat /etc/elite-x/public_key 2>/dev/null)
    SNI=$(cat "$SNI_CONF" 2>/dev/null || echo "Not set")
    
    # Display results
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
    echo -e "${GREEN}║${WHITE} Domain/SNI : ${CYAN}$DOMAIN${NC}"
    echo -e "${GREEN}║${WHITE} SNI Server : ${CYAN}$SNI${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}                   SERVICE PORTS                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${WHITE} SSH (Direct)        : 22${NC}"
    echo -e "${GREEN}║${WHITE} SSH WS (TLS)        : 443${NC}"
    echo -e "${GREEN}║${WHITE} SSH WS (Non-TLS)    : 80${NC}"
    echo -e "${GREEN}║${WHITE} Dropbear            : 109, 143, 443${NC}"
    echo -e "${GREEN}║${WHITE} SSL/TLS (Stunnel)   : 445, 777, 990${NC}"
    echo -e "${GREEN}║${WHITE} OpenVPN TCP         : 1194${NC}"
    echo -e "${GREEN}║${WHITE} OpenVPN UDP         : 2200${NC}"
    echo -e "${GREEN}║${WHITE} OpenVPN WS          : 2086${NC}"
    echo -e "${GREEN}║${WHITE} BadVPN UDPGW        : 7100, 7200, 7300${NC}"
    echo -e "${GREEN}║${WHITE} VMess WS TLS        : 443${NC}"
    echo -e "${GREEN}║${WHITE} VMess WS NT         : 80${NC}"
    echo -e "${GREEN}║${WHITE} VMess gRPC          : 443${NC}"
    echo -e "${GREEN}║${WHITE} VLess WS TLS        : 443${NC}"
    echo -e "${GREEN}║${WHITE} VLess WS NT         : 80${NC}"
    echo -e "${GREEN}║${WHITE} VLess gRPC          : 443${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}                   SLOWDNS CONFIG                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${WHITE} NS        : ${CYAN}$DOMAIN${NC}"
    echo -e "${GREEN}║${WHITE} Public Key: ${CYAN}$PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE} Port      : 53${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${YELLOW}                   WEBSOCKET PAYLOADS                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${WHITE} WS TLS    : GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "${GREEN}║${WHITE} WS HTTP   : GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "${GREEN}║${WHITE} WS CDN    : GET wss://${DOMAIN}/ HTTP/1.1[crlf]Host: ${SNI}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    read -p "Press Enter to continue..."
}
# ═══════════════════════════════════════
# FUNCTION: USER MANAGEMENT SCRIPT
# ═══════════════════════════════════════
create_user_management_script() {
    cat > /usr/local/bin/falcon-user <<'USERMGMT'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'
UD="/etc/elite-x/users"

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                    USER LIST                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${WHITE} %-15s %-14s %-10s %-12s${CYAN} ║${NC}\n" "USERNAME" "EXPIRE" "STATUS" "ONLINE"
    echo -e "${CYAN}╟──────────────────────────────────────────────────────────────╢${NC}"
    
    for uf in "$UD"/*; do
        [ ! -f "$uf" ] && continue
        u=$(basename "$uf")
        ex=$(grep "Expire:" "$uf" | cut -d' ' -f2)
        
        # Check status
        if passwd -S "$u" 2>/dev/null | grep -q "L"; then
            status="${RED}🔒 LOCK${NC}"
        else
            exp_ts=$(date -d "$ex" +%s 2>/dev/null || echo 0)
            now_ts=$(date +%s)
            if [ $now_ts -gt $exp_ts ]; then
                status="${RED}⛔ EXPIRED${NC}"
            else
                status="${GREEN}✅ ACTIVE${NC}"
            fi
        fi
        
        # Count connections
        conn=$(who | grep -wc "$u" 2>/dev/null || echo 0)
        [ "$conn" -gt 0 ] && online="${GREEN}$conn${NC}" || online="${GRAY}0${NC}"
        
        printf "${CYAN}║${WHITE} %-15s %-14b %-10b %-12b${CYAN} ║${NC}\n" "$u" "$ex" "$status" "$online"
    done
    
    total=$(ls "$UD" 2>/dev/null | wc -l)
    online_total=$(who | wc -l)
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW} Total: ${GREEN}$total${YELLOW} | Online: ${GREEN}$online_total${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

delete_user() {
    read -p "Username to delete: " u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }
    pkill -u "$u" 2>/dev/null
    userdel -r "$u" 2>/dev/null
    rm -f "$UD/$u"
    echo -e "${GREEN}✅ User $u deleted${NC}"
}

renew_user() {
    read -p "Username: " u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}Not found!${NC}"; return; }
    read -p "Add days: " days
    cur=$(grep "Expire:" "$UD/$u" | cut -d' ' -f2)
    new=$(date -d "$cur +$days days" +"%Y-%m-%d")
    sed -i "s/Expire: .*/Expire: $new/" "$UD/$u"
    chage -E "$new" "$u" 2>/dev/null
    usermod -U "$u" 2>/dev/null
    echo -e "${GREEN}✅ Renewed to $new${NC}"
}

lock_user() {
    read -p "Username: " u
    usermod -L "$u" 2>/dev/null
    pkill -u "$u" 2>/dev/null
    echo -e "${GREEN}✅ Locked${NC}"
}

unlock_user() {
    read -p "Username: " u
    usermod -U "$u" 2>/dev/null
    echo -e "${GREEN}✅ Unlocked${NC}"
}

case "$1" in
    add) /usr/local/bin/falcon-create-user ;;
    list) list_users ;;
    del) delete_user ;;
    renew) renew_user ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    *) echo "Usage: falcon-user {add|list|del|renew|lock|unlock}" ;;
esac
USERMGMT
    chmod +x /usr/local/bin/falcon-user
    
    # Link the create user function
    ln -sf /usr/local/bin/falcon-create-user /usr/local/bin/falcon-user-add 2>/dev/null
}

# ═══════════════════════════════════════
# FUNCTION: CREATE MAIN MENU
# ═══════════════════════════════════════
create_main_menu_script() {
    cat > /usr/local/bin/falcon-menu <<'MENUSCRIPT'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
PURPLE='\033[0;35m'; WHITE='\033[1;37m'; BOLD='\033[1m'; NC='\033[0m'

show_dashboard() {
    clear
    IP=$(curl -s ifconfig.me)
    DOMAIN=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "N/A")
    SNI=$(cat /etc/elite-x/sni_config 2>/dev/null || echo "N/A")
    RAM=$(free -h | awk '/^Mem:/{print $3"/"$2}')
    TOTAL=$(ls /etc/elite-x/users 2>/dev/null | wc -l)
    ONLINE=$(who | wc -l)
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}         FALCON ULTRA X v4.0 - MAIN MENU          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE} IP        : ${GREEN}$IP${NC}"
    echo -e "${PURPLE}║${WHITE} Domain    : ${GREEN}$DOMAIN${NC}"
    echo -e "${PURPLE}║${WHITE} SNI/CF    : ${GREEN}$SNI${NC}"
    echo -e "${PURPLE}║${WHITE} RAM       : ${GREEN}$RAM${NC}"
    echo -e "${PURPLE}║${WHITE} Users     : ${GREEN}$TOTAL${WHITE} | Online: ${GREEN}$ONLINE${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

while true; do
    show_dashboard
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}                 FALCON v4.0 MENU                  ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE} [1]  Create SSH User       [2]  List Users${NC}"
    echo -e "${PURPLE}║${WHITE} [3]  Delete User           [4]  Renew User${NC}"
    echo -e "${PURPLE}║${WHITE} [5]  Lock/Unlock User      [6]  Create VMess Account${NC}"
    echo -e "${PURPLE}║${WHITE} [7]  Create VLess Account   [8]  Change Ports${NC}"
    echo -e "${PURPLE}║${WHITE} [9]  Restart All Services   [10] Speed Test${NC}"
    echo -e "${PURPLE}║${WHITE} [11] Custom Switch Msg      [S]  Settings${NC}"
    echo -e "${PURPLE}║${WHITE} [0]  Exit${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    read -p "$(echo -e $GREEN"Option: "$NC)" opt
    
    case $opt in
        1) falcon-user add ;;
        2) falcon-user list ; read -p "Enter..." ;;
        3) falcon-user del ; read -p "Enter..." ;;
        4) falcon-user renew ; read -p "Enter..." ;;
        5) echo "1)Lock 2)Unlock"; read l; [ "$l" = "1" ] && falcon-user lock || falcon-user unlock; read -p "Enter..." ;;
        6) add-vmess ;;
        7) add-vless ;;
        8) echo "Port change feature coming soon..."; read -p "Enter..." ;;
        9) 
            for s in ssh dropbear stunnel4 nginx xray ws-tls ws-nontls ws-ovpn badvpn openvpn-server@server-tcp openvpn-server@server-udp; do
                systemctl restart $s 2>/dev/null
            done
            echo -e "${GREEN}✅ All services restarted${NC}"
            read -p "Enter..." ;;
        10) speedtest 2>/dev/null || curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ; read -p "Enter..." ;;
        11) set_custom_message ;;
        [Ss]) echo "Settings..."; read -p "Enter..." ;;
        0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    esac
done
MENUSCRIPT
    chmod +x /usr/local/bin/falcon-menu
}

# ═══════════════════════════════════════
# FUNCTION: MAIN INSTALLATION
# ═══════════════════════════════════════
run_falcon_installation() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}      FALCON ULTRA X v4.0 - INSTALLATION       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Activation
    echo -e "${YELLOW}Enter Activation Key:${NC}"
    read -p "> " key
    if [ "$key" != "$ACTIVATION_KEY" ] && [ "$key" != "Whtsapp +255713-628-668" ]; then
        echo -e "${RED}❌ Invalid key!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Activated!${NC}"
    sleep 1
    
    # Step 1: Domain/SNI
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  STEP 1: ENTER YOUR SNI/DOMAIN (Pointed to VPS)   ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "Enter your SNI/Domain: " SNI_DOMAIN
    echo "$SNI_DOMAIN" > "$SNI_CONF"
    
    # Step 2: Nameserver
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  STEP 2: ENTER YOUR NAMESERVER (NS)             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "Enter NS (or press Enter to use SNI): " NS_DOMAIN
    [ -z "$NS_DOMAIN" ] && NS_DOMAIN="$SNI_DOMAIN"
    echo "$NS_DOMAIN" > /etc/elite-x/subdomain
    
    # Step 3: Location
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
    
    # Start installation
    echo ""
    echo -e "${YELLOW}🔄 Starting installation...${NC}"
    
    # Update system
    apt update -y
    apt install -y curl wget jq bc net-tools python python3 unzip openssl nginx dropbear stunnel4 openvpn easy-rsa build-essential 2>/dev/null
    
    # Install all components
    install_badvpn
    install_dropbear
    install_websocket
    install_openvpn
    install_xray
    install_xray_scripts
    
    # Setup SSL certificate
    IP=$(curl -s ifconfig.me)
    mkdir -p /etc/xray
    openssl req -new -x509 -days 3650 -nodes -out /etc/xray/xray.crt -keyout /etc/xray/xray.key \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Falcon/OU=Falcon/CN=$SNI_DOMAIN" 2>/dev/null
    
    # Update Nginx
    cat > /etc/nginx/sites-enabled/default <<NGINXEOF
server {
    listen 80;
    server_name _;
    root /home/vps/public_html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINXEOF
    
    # DNSTT Installation (SlowDNS - HAIGUSWA)
    curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null
    chmod +x /usr/local/bin/dnstt-server
    
    mkdir -p /etc/dnstt
    echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
    echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
    
    cat > /etc/systemd/system/dnstt-elite-x.service <<DNSTTEOF
[Unit]
Description=DNSTT Server
After=network.target
[Service]
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu $MTU -privkey-file /etc/dnstt/server.key $NS_DOMAIN 127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
DNSTTEOF
    
    # Recompile C EDNS proxy
    gcc -O3 -pthread -o /usr/local/bin/elite-x-edns-proxy /tmp/edns_proxy.c 2>/dev/null || true
    
    cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EDNSEOF
[Unit]
Description=EDNS Proxy
After=dnstt-elite-x.service
[Service]
ExecStart=/usr/local/bin/elite-x-edns-proxy
Restart=always
[Install]
WantedBy=multi-user.target
EDNSEOF
    
    # Create scripts
    create_user_management_script
    create_main_menu_script
    
    # Create the enhanced user creation script
    cat > /usr/local/bin/falcon-create-user <<'CREATEUSER'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${YELLOW}${BOLD}        CREATE SSH + ALL SERVICES USER        ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "$(echo -e $GREEN"Username: "$NC)" username
if id "$username" &>/dev/null; then echo -e "${RED}User exists!${NC}"; exit 1; fi

read -p "$(echo -e $GREEN"Password [auto]: "$NC)" password
[ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10) && echo -e "${GREEN}Generated: ${YELLOW}$password${NC}"

read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" days; days=${days:-30}
read -p "$(echo -e $GREEN"Max Devices [2]: "$NC)" maxdev; maxdev=${maxdev:-2}

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

IP=$(curl -s ifconfig.me)
DOMAIN=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "N/A")
PUBKEY=$(cat /etc/elite-x/public_key 2>/dev/null || echo "N/A")
SNI=$(cat /etc/elite-x/sni_config 2>/dev/null || echo "N/A")
SWITCH_MSG=$(cat /etc/elite-x/switch_protocol_msg 2>/dev/null || echo "HTTP/1.1 101 Switching Protocols")

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}              ACCOUNT CREATED SUCCESSFULLY              ${GREEN}║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE} Username   : ${CYAN}$username${NC}"
echo -e "${GREEN}║${WHITE} Password   : ${CYAN}$password${NC}"
echo -e "${GREEN}║${WHITE} Expired    : ${CYAN}$exp_date${NC}"
echo -e "${GREEN}║${WHITE} Max Devices: ${CYAN}$maxdev${NC}"
echo -e "${GREEN}║${WHITE} Server Msg : ${CYAN}$SWITCH_MSG${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW}                   SERVER INFORMATION                     ${GREEN}║${NC}"
echo -e "${GREEN}║${WHITE} IP/Host    : ${CYAN}$IP${NC}"
echo -e "${GREEN}║${WHITE} Domain/SNI : ${CYAN}$DOMAIN${NC}"
echo -e "${GREEN}║${WHITE} SNI/CDN    : ${CYAN}$SNI${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${YELLOW}                   SERVICE PORTS                          ${GREEN}║${NC}"
echo -e "${GREEN}║${WHITE} SSH Direct  : 22${NC}"
echo -e "${GREEN}║${WHITE} SSH WS TLS  : 443${NC}"
echo -e "${GREEN}║${WHITE} SSH WS HTTP : 80${NC}"
echo -e "${GREEN}║${WHITE} Dropbear    : 109, 143${NC}"
echo -e "${GREEN}║${WHITE} SSL/TLS     : 445, 777, 990${NC}"
echo -e "${GREEN}║${WHITE} OpenVPN TCP : 1194 | WS: 2086${NC}"
echo -e "${GREEN}║${WHITE} OpenVPN UDP : 2200${NC}"
echo -e "${GREEN}║${WHITE} BadVPN      : 7100-7300${NC}"
echo -e "${GREEN}║${WHITE} VMess WS    : 443 (TLS), 80 (NT)${NC}"
echo -e "${GREEN}║${WHITE} VMess gRPC  : 443${NC}"
echo -e "${GREEN}║${WHITE} VLess WS    : 443 (TLS), 80 (NT)${NC}"
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
CREATEUSER
    chmod +x /usr/local/bin/falcon-create-user
    
    # Fix permissions
    chown -R www-data:www-data /home/vps/public_html 2>/dev/null
    
    # Enable & start all services
    systemctl daemon-reload
    for svc in ssh dropbear stunnel4 nginx xray ws-tls ws-nontls ws-ovpn badvpn openvpn-server@server-tcp openvpn-server@server-udp dnstt-elite-x dnstt-elite-x-proxy; do
        systemctl enable $svc 2>/dev/null
        systemctl restart $svc 2>/dev/null
    done
    
    # Aliases
    echo "alias menu='falcon-menu'" >> ~/.bashrc
    echo "alias adduser='falcon-user add'" >> ~/.bashrc
    echo "alias users='falcon-user list'" >> ~/.bashrc
    echo "alias addvmess='add-vmess'" >> ~/.bashrc
    echo "alias addvless='add-vless'" >> ~/.bashrc
    
    # Final display
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}     FALCON ULTRA X v4.0 INSTALLED SUCCESSFULLY!      ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE} SNI/Domain : ${CYAN}$SNI_DOMAIN${NC}"
    echo -e "${GREEN}║${WHITE} Nameserver : ${CYAN}$NS_DOMAIN${NC}"
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
    echo ""
    echo -e "${CYAN}Installation complete! Run 'menu' to start.${NC}"
}

# Run installation
run_falcon_installation
