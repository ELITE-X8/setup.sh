#!/bin/bash

# ============================================================================
# ELITE-X WEB DASHBOARD INSTALLER
# With Login System - Port 8080
# ============================================================================

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;31m[✗]\033[0m Run as root: sudo bash setup.sh"
    exit 1
fi

# ============================================================================
# CONFIGURATION
# ============================================================================
PANEL_PORT=8080
PANEL_USER="elite-x"
PANEL_PASS="elite2026"
PANEL_DIR="/etc/elite-x/web"
USERS_DIR="/etc/elite-x/users"
USAGE_DIR="/etc/elite-x/data_usage"
BANNED_DIR="/etc/elite-x/banned"
DELETED_DIR="/etc/elite-x/deleted"

# ============================================================================
# COLORS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# BANNER
# ============================================================================
show_banner() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}         ELITE-X WEB DASHBOARD INSTALLER                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}         Login System + Full User Management                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================
install_dependencies() {
    echo -e "${YELLOW}[1/5] Installing dependencies...${NC}"
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq python3 python3-pip curl net-tools bc > /dev/null 2>&1
    pip3 install flask flask-login 2>/dev/null || apt-get install -y python3-flask python3-flask-login > /dev/null 2>&1
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# ============================================================================
# CREATE DIRECTORY STRUCTURE
# ============================================================================
create_directories() {
    echo -e "${YELLOW}[2/5] Creating directory structure...${NC}"
    mkdir -p "$PANEL_DIR"
    mkdir -p "$PANEL_DIR/templates"
    mkdir -p "$PANEL_DIR/static"
    mkdir -p "$USERS_DIR"
    mkdir -p "$USAGE_DIR"
    mkdir -p "$BANNED_DIR"
    mkdir -p "$DELETED_DIR"
    echo -e "${GREEN}✓ Directories created${NC}"
}

# ============================================================================
# CREATE WEB APPLICATION (FLASK)
# ============================================================================
create_web_app() {
    echo -e "${YELLOW}[3/5] Creating web application...${NC}"
    
    # Main Flask Application
    cat > "$PANEL_DIR/app.py" << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from flask import Flask, render_template, request, redirect, url_for, session, jsonify
from functools import wraps
import subprocess
import os
import datetime
import json
import glob
import bcrypt

app = Flask(__name__)
app.secret_key = 'elite-x-secret-key-2026-ultra-secure'

# Configuration
PANEL_USER = "elite-x"
PANEL_PASS = "elite2026"
USERS_DIR = "/etc/elite-x/users"
USAGE_DIR = "/etc/elite-x/data_usage"
BANNED_DIR = "/etc/elite-x/banned"
DELETED_DIR = "/etc/elite-x/deleted"
AUTOBAN_FLAG = "/etc/elite-x/autoban_enabled"
SUBDOMAIN_FILE = "/etc/elite-x/subdomain"
MTU_FILE = "/etc/elite-x/mtu"
LOCATION_FILE = "/etc/elite-x/location"

# Login required decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Helper functions
def get_system_info():
    """Get system information"""
    info = {}
    
    # Server IP
    try:
        info['ip'] = subprocess.check_output("curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'", 
                                              shell=True).decode().strip()
    except:
        info['ip'] = "Unknown"
    
    # Subdomain/NS
    try:
        with open(SUBDOMAIN_FILE) as f:
            info['ns'] = f.read().strip()
    except:
        info['ns'] = "Not configured"
    
    # Location & MTU
    try:
        with open(LOCATION_FILE) as f:
            info['location'] = f.read().strip()
    except:
        info['location'] = "South Africa"
    
    try:
        with open(MTU_FILE) as f:
            info['mtu'] = f.read().strip()
    except:
        info['mtu'] = "1800"
    
    # RAM
    try:
        result = subprocess.check_output("free -h | awk '/^Mem:/{print $3\"/\"$2}'", shell=True).decode().strip()
        info['ram'] = result
    except:
        info['ram'] = "Unknown"
    
    # Uptime
    try:
        info['uptime'] = subprocess.check_output("uptime -p", shell=True).decode().strip()
    except:
        info['uptime'] = "Unknown"
    
    # BBR Status
    try:
        bbr = subprocess.check_output("sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}'", 
                                       shell=True).decode().strip()
        info['bbr'] = "ACTIVE" if bbr == "bbr" else "INACTIVE"
    except:
        info['bbr'] = "Unknown"
    
    # Services status
    services = ['dnstt-elite-x', 'dnstt-elite-x-proxy', 'elite-x-datausage', 'ssh']
    info['services'] = {}
    for svc in services:
        try:
            result = subprocess.run(['systemctl', 'is-active', svc], capture_output=True, text=True)
            info['services'][svc] = 'active' if 'active' in result.stdout else 'inactive'
        except:
            info['services'][svc] = 'unknown'
    
    # Connection count
    try:
        info['connections'] = int(subprocess.check_output("ss -tn | grep ESTAB | wc -l", shell=True).decode().strip())
    except:
        info['connections'] = 0
    
    # Auto-ban status
    try:
        with open(AUTOBAN_FLAG) as f:
            info['autoban'] = f.read().strip() == "1"
    except:
        info['autoban'] = False
    
    return info

def get_connection_count(username):
    """Get active connections for user"""
    try:
        who_count = int(subprocess.check_output(f"who | grep -w {username} | wc -l", shell=True).decode().strip())
        ps_count = int(subprocess.check_output(f"ps aux | grep 'sshd:' | grep {username} | grep -v grep | wc -l", 
                                                shell=True).decode().strip())
        last_count = int(subprocess.check_output(f"last | grep {username} | grep 'still logged in' | wc -l", 
                                                  shell=True).decode().strip())
        return max(who_count, last_count, ps_count)
    except:
        return 0

def get_monthly_usage(username):
    """Get monthly data usage for user"""
    usage_file = os.path.join(USAGE_DIR, username)
    if os.path.exists(usage_file):
        try:
            with open(usage_file) as f:
                content = f.read()
                rx = 0.0
                tx = 0.0
                total = 0.0
                for line in content.split('\n'):
                    if line.startswith('rx_gb:'):
                        rx = float(line.split(':')[1].strip())
                    if line.startswith('tx_gb:'):
                        tx = float(line.split(':')[1].strip())
                    if line.startswith('total_gb:'):
                        total = float(line.split(':')[1].strip())
                return {'rx': rx, 'tx': tx, 'total': total}
        except:
            pass
    return {'rx': 0.0, 'tx': 0.0, 'total': 0.0}

# Routes
@app.route('/')
def login():
    """Login page"""
    if 'logged_in' in session:
        return redirect(url_for('dashboard'))
    return render_template('login.html')

@app.route('/login', methods=['POST'])
def do_login():
    """Handle login"""
    username = request.form.get('username', '')
    password = request.form.get('password', '')
    
    if username == PANEL_USER and password == PANEL_PASS:
        session['logged_in'] = True
        session['username'] = username
        return redirect(url_for('dashboard'))
    
    return render_template('login.html', error="Invalid credentials!")

@app.route('/logout')
def logout():
    """Logout"""
    session.clear()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    """Main dashboard"""
    info = get_system_info()
    
    # Get user stats
    users_list = []
    if os.path.exists(USERS_DIR):
        for filename in os.listdir(USERS_DIR):
            filepath = os.path.join(USERS_DIR, filename)
            if os.path.isfile(filepath):
                with open(filepath) as f:
                    user_data = {}
                    for line in f:
                        if ':' in line:
                            key, val = line.split(':', 1)
                            user_data[key.strip()] = val.strip()
                    
                    username = user_data.get('Username', filename)
                    expire = user_data.get('Expire', 'Unknown')
                    conn_limit = int(user_data.get('Conn_Limit', 1))
                    current_conn = get_connection_count(username)
                    usage = get_monthly_usage(username)
                    
                    # Calculate days left
                    try:
                        exp_date = datetime.datetime.strptime(expire, '%Y-%m-%d')
                        days_left = (exp_date - datetime.datetime.now()).days
                    except:
                        days_left = -1
                    
                    # Determine status
                    try:
                        locked = 'L' in subprocess.check_output(f"passwd -S {username}", 
                                                                 shell=True, stderr=subprocess.DEVNULL).decode()
                    except:
                        locked = False
                    
                    if locked:
                        status = 'locked'
                    elif days_left <= 0:
                        status = 'expired'
                    elif current_conn > 0:
                        status = 'online'
                    else:
                        status = 'offline'
                    
                    users_list.append({
                        'username': username,
                        'password': user_data.get('Password', '****'),
                        'expire': expire,
                        'days_left': days_left,
                        'conn_limit': conn_limit,
                        'current_conn': current_conn,
                        'usage': usage,
                        'status': status
                    })
    
    return render_template('dashboard.html', info=info, users=users_list)

@app.route('/api/add_user', methods=['POST'])
@login_required
def api_add_user():
    """Add new user via API"""
    try:
        username = request.form.get('username')
        password = request.form.get('password')
        days = request.form.get('days', '30')
        conn_limit = request.form.get('conn_limit', '1')
        
        if not username or not password:
            return jsonify({'success': False, 'message': 'Username and password required'})
        
        # Check if user exists
        if os.path.exists(os.path.join(USERS_DIR, username)):
            return jsonify({'success': False, 'message': 'User already exists!'})
        
        # Create system user
        subprocess.run(['useradd', '-m', '-s', '/bin/false', username], capture_output=True)
        subprocess.run(['chpasswd'], input=f"{username}:{password}".encode(), capture_output=True)
        
        # Calculate expiry
        expire_date = (datetime.datetime.now() + datetime.timedelta(days=int(days))).strftime('%Y-%m-%d')
        subprocess.run(['chage', '-E', expire_date, username], capture_output=True)
        
        # Save user info
        user_file = os.path.join(USERS_DIR, username)
        with open(user_file, 'w') as f:
            f.write(f"Username: {username}\n")
            f.write(f"Password: {password}\n")
            f.write(f"Expire: {expire_date}\n")
            f.write(f"Conn_Limit: {conn_limit}\n")
            f.write(f"Created: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        # Initialize usage
        usage_file = os.path.join(USAGE_DIR, username)
        with open(usage_file, 'w') as f:
            f.write(f"month: {datetime.datetime.now().strftime('%Y-%m')}\n")
            f.write("total_rx: 0\n")
            f.write("total_tx: 0\n")
            f.write("rx_gb: 0.00\n")
            f.write("tx_gb: 0.00\n")
            f.write("total_gb: 0.00\n")
            f.write(f"last_updated: {datetime.datetime.now()}\n")
        
        # Get NS for response
        try:
            with open(SUBDOMAIN_FILE) as f:
                ns = f.read().strip()
        except:
            ns = "Unknown"
        
        return jsonify({
            'success': True, 
            'message': f'User {username} created successfully!',
            'user': {
                'username': username,
                'password': password,
                'ns': ns,
                'expire': expire_date,
                'conn_limit': conn_limit
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/api/delete_user', methods=['POST'])
@login_required
def api_delete_user():
    """Delete user via API"""
    username = request.form.get('username')
    if not username:
        return jsonify({'success': False, 'message': 'Username required'})
    
    user_file = os.path.join(USERS_DIR, username)
    if not os.path.exists(user_file):
        return jsonify({'success': False, 'message': 'User not found'})
    
    # Backup
    backup_file = os.path.join(DELETED_DIR, f"{username}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}")
    subprocess.run(['cp', user_file, backup_file], capture_output=True)
    
    # Kill sessions & delete
    subprocess.run(['pkill', '-u', username], capture_output=True)
    subprocess.run(['pkill', '-f', f'sshd:.*{username}'], capture_output=True)
    subprocess.run(['userdel', '-r', username], capture_output=True)
    
    # Remove files
    for f in [user_file, os.path.join(USAGE_DIR, username), os.path.join(BANNED_DIR, username)]:
        if os.path.exists(f):
            os.remove(f)
    
    return jsonify({'success': True, 'message': f'User {username} deleted'})

@app.route('/api/renew_user', methods=['POST'])
@login_required
def api_renew_user():
    """Renew user expiry"""
    username = request.form.get('username')
    days = request.form.get('days', '30')
    
    user_file = os.path.join(USERS_DIR, username)
    if not os.path.exists(user_file):
        return jsonify({'success': False, 'message': 'User not found'})
    
    # Read current expiry
    current_expire = None
    with open(user_file) as f:
        for line in f:
            if line.startswith('Expire:'):
                current_expire = line.split(':', 1)[1].strip()
    
    if current_expire:
        try:
            exp_date = datetime.datetime.strptime(current_expire, '%Y-%m-%d')
            new_expire = (exp_date + datetime.timedelta(days=int(days))).strftime('%Y-%m-%d')
        except:
            new_expire = (datetime.datetime.now() + datetime.timedelta(days=int(days))).strftime('%Y-%m-%d')
    else:
        new_expire = (datetime.datetime.now() + datetime.timedelta(days=int(days))).strftime('%Y-%m-%d')
    
    # Update file
    lines = []
    with open(user_file) as f:
        for line in f:
            if line.startswith('Expire:'):
                lines.append(f'Expire: {new_expire}\n')
            else:
                lines.append(line)
    
    with open(user_file, 'w') as f:
        f.writelines(lines)
    
    # Update system
    subprocess.run(['chage', '-E', new_expire, username], capture_output=True)
    
    return jsonify({'success': True, 'message': f'User {username} renewed until {new_expire}'})

@app.route('/api/lock_user', methods=['POST'])
@login_required
def api_lock_user():
    """Lock user"""
    username = request.form.get('username')
    
    user_file = os.path.join(USERS_DIR, username)
    if not os.path.exists(user_file):
        return jsonify({'success': False, 'message': 'User not found'})
    
    subprocess.run(['usermod', '-L', username], capture_output=True)
    subprocess.run(['pkill', '-u', username], capture_output=True)
    subprocess.run(['pkill', '-f', f'sshd:.*{username}'], capture_output=True)
    
    # Log
    ban_file = os.path.join(BANNED_DIR, username)
    with open(ban_file, 'a') as f:
        f.write(f"{datetime.datetime.now()} - MANUALLY LOCKED via web\n")
    
    return jsonify({'success': True, 'message': f'User {username} locked'})

@app.route('/api/unlock_user', methods=['POST'])
@login_required
def api_unlock_user():
    """Unlock user"""
    username = request.form.get('username')
    
    user_file = os.path.join(USERS_DIR, username)
    if not os.path.exists(user_file):
        return jsonify({'success': False, 'message': 'User not found'})
    
    subprocess.run(['usermod', '-U', username], capture_output=True)
    
    # Log
    ban_file = os.path.join(BANNED_DIR, username)
    with open(ban_file, 'a') as f:
        f.write(f"{datetime.datetime.now()} - UNLOCKED via web\n")
    
    return jsonify({'success': True, 'message': f'User {username} unlocked'})

@app.route('/api/set_limit', methods=['POST'])
@login_required
def api_set_limit():
    """Set connection limit"""
    username = request.form.get('username')
    limit = request.form.get('limit', '1')
    
    user_file = os.path.join(USERS_DIR, username)
    if not os.path.exists(user_file):
        return jsonify({'success': False, 'message': 'User not found'})
    
    lines = []
    found = False
    with open(user_file) as f:
        for line in f:
            if line.startswith('Conn_Limit:'):
                lines.append(f'Conn_Limit: {limit}\n')
                found = True
            else:
                lines.append(line)
    
    if not found:
        lines.append(f'Conn_Limit: {limit}\n')
    
    with open(user_file, 'w') as f:
        f.writelines(lines)
    
    return jsonify({'success': True, 'message': f'Connection limit set to {limit} for {username}'})

@app.route('/api/reset_usage', methods=['POST'])
@login_required
def api_reset_usage():
    """Reset data usage"""
    username = request.form.get('username')
    
    usage_file = os.path.join(USAGE_DIR, username)
    with open(usage_file, 'w') as f:
        f.write(f"month: {datetime.datetime.now().strftime('%Y-%m')}\n")
        f.write("total_rx: 0\n")
        f.write("total_tx: 0\n")
        f.write("rx_gb: 0.00\n")
        f.write("tx_gb: 0.00\n")
        f.write("total_gb: 0.00\n")
        f.write(f"last_updated: {datetime.datetime.now()}\n")
    
    return jsonify({'success': True, 'message': f'Usage reset for {username}'})

@app.route('/api/toggle_autoban', methods=['POST'])
@login_required
def api_toggle_autoban():
    """Toggle auto-ban"""
    try:
        with open(AUTOBAN_FLAG) as f:
            current = f.read().strip()
    except:
        current = "0"
    
    new_val = "0" if current == "1" else "1"
    with open(AUTOBAN_FLAG, 'w') as f:
        f.write(new_val)
    
    subprocess.run(['systemctl', 'restart', 'elite-x-connmon'], capture_output=True)
    
    status = "ENABLED" if new_val == "1" else "DISABLED"
    return jsonify({'success': True, 'message': f'Auto-Ban {status}', 'autoban': new_val == "1"})

@app.route('/api/restart_services', methods=['POST'])
@login_required
def api_restart_services():
    """Restart all services"""
    services = ['dnstt-elite-x', 'dnstt-elite-x-proxy', 'elite-x-datausage', 'elite-x-connmon', 'sshd']
    for svc in services:
        subprocess.run(['systemctl', 'restart', svc], capture_output=True)
    
    return jsonify({'success': True, 'message': 'All services restarted'})

@app.route('/api/apply_speed', methods=['POST'])
@login_required
def api_apply_speed():
    """Apply speed optimization"""
    subprocess.run(['/usr/local/bin/elite-x-speed', 'full'], capture_output=True)
    return jsonify({'success': True, 'message': 'Speed optimizations applied'})

@app.route('/api/change_mtu', methods=['POST'])
@login_required
def api_change_mtu():
    """Change MTU value"""
    mtu = request.form.get('mtu', '1800')
    
    try:
        mtu_int = int(mtu)
        if mtu_int < 1000 or mtu_int > 5000:
            return jsonify({'success': False, 'message': 'MTU must be between 1000-5000'})
    except:
        return jsonify({'success': False, 'message': 'Invalid MTU value'})
    
    # Update files
    with open(MTU_FILE, 'w') as f:
        f.write(mtu)
    
    # Update service file
    subprocess.run(['sed', '-i', f's/-mtu [0-9]*/-mtu {mtu}/', '/etc/systemd/system/dnstt-elite-x.service'])
    subprocess.run(['systemctl', 'daemon-reload'])
    subprocess.run(['systemctl', 'restart', 'dnstt-elite-x', 'dnstt-elite-x-proxy'])
    
    return jsonify({'success': True, 'message': f'MTU changed to {mtu}'})

@app.route('/api/reboot', methods=['POST'])
@login_required
def api_reboot():
    """Reboot VPS"""
    subprocess.run(['reboot'])
    return jsonify({'success': True, 'message': 'Rebooting...'})

@app.route('/api/uninstall', methods=['POST'])
@login_required
def api_uninstall():
    """Uninstall script"""
    # Kill services
    services = ['dnstt-elite-x', 'dnstt-elite-x-proxy', 'elite-x-cleaner', 
                'elite-x-datausage', 'elite-x-connmon', 'elite-x-traffic', 'elite-x-web']
    for svc in services:
        subprocess.run(['systemctl', 'stop', svc], capture_output=True)
        subprocess.run(['systemctl', 'disable', svc], capture_output=True)
    
    # Remove service files
    for svc in services:
        path = f'/etc/systemd/system/{svc}.service'
        if os.path.exists(path):
            os.remove(path)
    
    # Remove directories
    subprocess.run(['rm', '-rf', '/etc/dnstt', '/etc/elite-x', '/var/run/elite-x'])
    
    # Remove binaries
    for bin_file in glob.glob('/usr/local/bin/dnstt-*') + glob.glob('/usr/local/bin/elite-x*'):
        if os.path.exists(bin_file):
            os.remove(bin_file)
    
    # Remove SSH banner
    subprocess.run(['sed', '-i', '/^Banner/d', '/etc/ssh/sshd_config'])
    subprocess.run(['systemctl', 'restart', 'sshd'])
    
    return jsonify({'success': True, 'message': 'Uninstalled. Server will need manual cleanup.'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
PYEOF
    
    chmod +x "$PANEL_DIR/app.py"
    echo -e "${GREEN}✓ Web application created${NC}"
}

# ============================================================================
# CREATE HTML TEMPLATES
# ============================================================================
create_templates() {
    echo -e "${YELLOW}[4/5] Creating web templates...${NC}"
    
    # Login Page
    cat > "$PANEL_DIR/templates/login.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X | Login</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(20px);
            border-radius: 24px;
            padding: 50px 40px;
            width: 100%;
            max-width: 420px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 25px 60px rgba(0, 0, 0, 0.3);
        }
        .logo {
            text-align: center;
            margin-bottom: 40px;
        }
        .logo h1 {
            color: #ffd700;
            font-size: 2.2em;
            font-weight: 800;
            letter-spacing: 2px;
        }
        .logo p {
            color: rgba(255, 255, 255, 0.6);
            font-size: 0.9em;
            margin-top: 8px;
        }
        .form-group {
            margin-bottom: 25px;
        }
        .form-group label {
            display: block;
            color: rgba(255, 255, 255, 0.8);
            margin-bottom: 8px;
            font-weight: 500;
            font-size: 0.9em;
        }
        .form-group input {
            width: 100%;
            padding: 14px 18px;
            background: rgba(255, 255, 255, 0.08);
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 12px;
            color: white;
            font-size: 1em;
            transition: all 0.3s;
            outline: none;
        }
        .form-group input:focus {
            border-color: #ffd700;
            box-shadow: 0 0 0 3px rgba(255, 215, 0, 0.1);
        }
        .form-group input::placeholder {
            color: rgba(255, 255, 255, 0.3);
        }
        .login-btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #ffd700, #ff8c00);
            border: none;
            border-radius: 12px;
            color: #1a1a2e;
            font-size: 1.1em;
            font-weight: 700;
            cursor: pointer;
            transition: all 0.3s;
            margin-top: 10px;
        }
        .login-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(255, 215, 0, 0.3);
        }
        .error-msg {
            background: rgba(255, 0, 0, 0.1);
            border: 1px solid rgba(255, 0, 0, 0.3);
            border-radius: 10px;
            padding: 12px 15px;
            color: #ff6b6b;
            margin-bottom: 20px;
            font-size: 0.9em;
            text-align: center;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: rgba(255, 255, 255, 0.4);
            font-size: 0.8em;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>🚀 ELITE-X</h1>
            <p>Advanced DNS Tunnel Management</p>
        </div>
        
        {% if error %}
        <div class="error-msg">{{ error }}</div>
        {% endif %}
        
        <form method="POST" action="/login">
            <div class="form-group">
                <label for="username">👤 Username</label>
                <input type="text" id="username" name="username" placeholder="Enter username" required autofocus>
            </div>
            <div class="form-group">
                <label for="password">🔒 Password</label>
                <input type="password" id="password" name="password" placeholder="Enter password" required>
            </div>
            <button type="submit" class="login-btn">🔓 Sign In</button>
        </form>
        
        <div class="footer">
            <p>© 2026 ELITE-X • Secure Panel</p>
        </div>
    </div>
</body>
</html>
HTMLEOF

    # Dashboard Page
    cat > "$PANEL_DIR/templates/dashboard.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X | Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a2e;
            color: #e0e0e0;
            min-height: 100vh;
        }
        
        /* Sidebar */
        .sidebar {
            position: fixed;
            left: 0;
            top: 0;
            bottom: 0;
            width: 260px;
            background: #16213e;
            padding: 20px;
            overflow-y: auto;
            border-right: 1px solid rgba(255, 255, 255, 0.05);
            z-index: 100;
        }
        .sidebar-logo {
            padding: 20px 0;
            text-align: center;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            margin-bottom: 30px;
        }
        .sidebar-logo h2 {
            color: #ffd700;
            font-size: 1.6em;
            font-weight: 800;
        }
        .sidebar-logo span {
            color: rgba(255, 255, 255, 0.5);
            font-size: 0.8em;
        }
        .nav-menu { list-style: none; }
        .nav-menu li { margin-bottom: 5px; }
        .nav-menu li a {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 18px;
            color: rgba(255, 255, 255, 0.7);
            text-decoration: none;
            border-radius: 10px;
            transition: all 0.3s;
            cursor: pointer;
        }
        .nav-menu li a:hover, .nav-menu li a.active {
            background: rgba(255, 215, 0, 0.1);
            color: #ffd700;
        }
        .nav-divider {
            height: 1px;
            background: rgba(255, 255, 255, 0.05);
            margin: 20px 0;
        }
        
        /* Main Content */
        .main-content {
            margin-left: 260px;
            padding: 30px;
        }
        
        /* Top Bar */
        .top-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
        }
        .top-bar h1 {
            font-size: 1.8em;
            color: white;
        }
        .logout-btn {
            padding: 10px 20px;
            background: rgba(255, 0, 0, 0.1);
            border: 1px solid rgba(255, 0, 0, 0.3);
            color: #ff6b6b;
            border-radius: 8px;
            text-decoration: none;
            transition: all 0.3s;
        }
        .logout-btn:hover { background: rgba(255, 0, 0, 0.2); }
        
        /* Stats Grid */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: #16213e;
            padding: 20px;
            border-radius: 15px;
            border: 1px solid rgba(255, 255, 255, 0.05);
            transition: transform 0.3s;
        }
        .stat-card:hover { transform: translateY(-3px); }
        .stat-card .label {
            font-size: 0.85em;
            color: rgba(255, 255, 255, 0.5);
            margin-bottom: 8px;
        }
        .stat-card .value {
            font-size: 1.6em;
            font-weight: 700;
        }
        .value.gold { color: #ffd700; }
        .value.green { color: #48bb78; }
        .value.red { color: #ff6b6b; }
        .value.blue { color: #63b3ed; }
        .value.purple { color: #b794f4; }
        
        /* Service Status */
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .service-badge {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 12px 15px;
            background: #16213e;
            border-radius: 10px;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
        }
        .status-dot.active { background: #48bb78; }
        .status-dot.inactive { background: #ff6b6b; }
        
        /* Panel */
        .panel {
            background: #16213e;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 30px;
            border: 1px solid rgba(255, 255, 255, 0.05);
        }
        .panel h2 {
            color: #ffd700;
            margin-bottom: 20px;
            font-size: 1.3em;
        }
        
        /* Table */
        .table-container { overflow-x: auto; }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        thead th {
            background: rgba(255, 255, 255, 0.03);
            padding: 12px 15px;
            text-align: left;
            color: rgba(255, 255, 255, 0.6);
            font-size: 0.85em;
            font-weight: 500;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }
        tbody td {
            padding: 12px 15px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.03);
            font-size: 0.9em;
        }
        tbody tr:hover { background: rgba(255, 255, 255, 0.02); }
        
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: 600;
        }
        .badge-online { background: rgba(72, 187, 120, 0.15); color: #48bb78; }
        .badge-offline { background: rgba(255, 255, 255, 0.05); color: rgba(255, 255, 255, 0.4); }
        .badge-expired { background: rgba(255, 107, 107, 0.15); color: #ff6b6b; }
        .badge-locked { background: rgba(255, 0, 0, 0.2); color: #ff0000; }
        .badge-warning { background: rgba(255, 215, 0, 0.1); color: #ffd700; }
        
        /* Buttons */
        .btn {
            padding: 6px 14px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.8em;
            font-weight: 600;
            transition: all 0.3s;
            margin: 2px;
        }
        .btn-sm { padding: 4px 10px; font-size: 0.75em; }
        .btn-danger { background: rgba(255, 0, 0, 0.1); color: #ff6b6b; border: 1px solid rgba(255, 0, 0, 0.2); }
        .btn-danger:hover { background: rgba(255, 0, 0, 0.2); }
        .btn-warning { background: rgba(255, 215, 0, 0.1); color: #ffd700; border: 1px solid rgba(255, 215, 0, 0.2); }
        .btn-warning:hover { background: rgba(255, 215, 0, 0.2); }
        .btn-success { background: rgba(72, 187, 120, 0.1); color: #48bb78; border: 1px solid rgba(72, 187, 120, 0.2); }
        .btn-success:hover { background: rgba(72, 187, 120, 0.2); }
        .btn-info { background: rgba(99, 179, 237, 0.1); color: #63b3ed; border: 1px solid rgba(99, 179, 237, 0.2); }
        .btn-info:hover { background: rgba(99, 179, 237, 0.2); }
        .btn-primary {
            background: linear-gradient(135deg, #ffd700, #ff8c00);
            color: #1a1a2e;
            font-weight: 700;
            border: none;
        }
        .btn-primary:hover { transform: translateY(-1px); box-shadow: 0 5px 15px rgba(255, 215, 0, 0.3); }
        
        /* Modal */
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0, 0, 0, 0.7);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        .modal.active { display: flex; }
        .modal-content {
            background: #16213e;
            border-radius: 20px;
            padding: 30px;
            width: 90%;
            max-width: 450px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            max-height: 80vh;
            overflow-y: auto;
        }
        .modal-content h2 { color: #ffd700; margin-bottom: 20px; }
        .modal-content input, .modal-content select {
            width: 100%;
            padding: 12px 15px;
            margin-bottom: 15px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 8px;
            color: white;
            font-size: 0.95em;
            outline: none;
        }
        .modal-content input:focus { border-color: #ffd700; }
        .modal-actions { display: flex; gap: 10px; margin-top: 20px; }
        .modal-actions button { flex: 1; padding: 12px; }
        
        /* Toast */
        .toast {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 15px 20px;
            border-radius: 10px;
            color: white;
            font-weight: 600;
            z-index: 2000;
            opacity: 0;
            transform: translateX(100%);
            transition: all 0.3s;
        }
        .toast.show { opacity: 1; transform: translateX(0); }
        .toast-success { background: #48bb78; }
        .toast-error { background: #ff6b6b; }
        
        /* Responsive */
        @media (max-width: 768px) {
            .sidebar { width: 200px; }
            .main-content { margin-left: 200px; padding: 20px; }
            .stats-grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 480px) {
            .sidebar { width: 60px; padding: 10px; }
            .sidebar-logo h2 { font-size: 0.9em; }
            .nav-menu li a span { display: none; }
            .main-content { margin-left: 60px; padding: 15px; }
        }
    </style>
</head>
<body>
    
    <!-- Sidebar -->
    <div class="sidebar">
        <div class="sidebar-logo">
            <h2>🚀 ELITE-X</h2>
            <span>v3.2.2 Panel</span>
        </div>
        <ul class="nav-menu">
            <li><a class="active" onclick="showSection('dashboard')">📊 Dashboard</a></li>
            <li><a onclick="showSection('users')">👥 Users</a></li>
            <li><a onclick="showSection('add-user')">➕ Add User</a></li>
            <li><a onclick="showSection('settings')">⚙️ Settings</a></li>
            <div class="nav-divider"></div>
            <li><a onclick="showSection('traffic')">📈 Traffic</a></li>
            <div class="nav-divider"></div>
            <li><a onclick="if(confirm('Reboot VPS?')) apiCall('/api/reboot')">🔄 Reboot</a></li>
            <li><a onclick="if(confirm('Uninstall completely?')) apiCall('/api/uninstall')">🗑️ Uninstall</a></li>
        </ul>
    </div>
    
    <!-- Main Content -->
    <div class="main-content">
        
        <!-- Top Bar -->
        <div class="top-bar">
            <h1>Welcome, <span style="color:#ffd700;">Admin</span></h1>
            <a href="/logout" class="logout-btn">🚪 Logout</a>
        </div>
        
        <!-- Toast -->
        <div class="toast" id="toast"></div>
        
        <!-- Dashboard Section -->
        <div id="section-dashboard">
            <!-- Stats -->
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="label">🌐 Server IP</div>
                    <div class="value blue">{{ info.ip }}</div>
                </div>
                <div class="stat-card">
                    <div class="label">🔗 Nameserver</div>
                    <div class="value purple">{{ info.ns }}</div>
                </div>
                <div class="stat-card">
                    <div class="label">👥 Total Users</div>
                    <div class="value gold">{{ users|length }}</div>
                </div>
                <div class="stat-card">
                    <div class="label">🔌 Active Connections</div>
                    <div class="value green">{{ info.connections }}</div>
                </div>
                <div class="stat-card">
                    <div class="label">💾 RAM Usage</div>
                    <div class="value blue">{{ info.ram }}</div>
                </div>
                <div class="stat-card">
                    <div class="label">⚡ BBR Status</div>
                    <div class="value {% if info.bbr == 'ACTIVE' %}green{% else %}red{% endif %}">{{ info.bbr }}</div>
                </div>
                <div class="stat-card">
                    <div class="label">🚫 Auto-Ban</div>
                    <div class="value {% if info.autoban %}red{% else %}green{% endif %}">
                        {{ 'ENABLED' if info.autoban else 'DISABLED' }}
                    </div>
                </div>
                <div class="stat-card">
                    <div class="label">⏱️ Uptime</div>
                    <div class="value blue" style="font-size:1.1em;">{{ info.uptime }}</div>
                </div>
            </div>
            
            <!-- Services -->
            <div class="panel">
                <h2>🔧 Services Status</h2>
                <div class="services-grid">
                    {% for svc, status in info.services.items() %}
                    <div class="service-badge">
                        <span class="status-dot {{ 'active' if status == 'active' else 'inactive' }}"></span>
                        <span>{{ svc }}</span>
                    </div>
                    {% endfor %}
                </div>
            </div>
        </div>
        
        <!-- Users Section -->
        <div id="section-users" style="display:none;">
            <div class="panel">
                <h2>👥 User List</h2>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Username</th>
                                <th>Password</th>
                                <th>Expire</th>
                                <th>Login</th>
                                <th>Data (GB)</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for user in users %}
                            <tr>
                                <td><strong>{{ user.username }}</strong></td>
                                <td><code>{{ user.password }}</code></td>
                                <td>
                                    {% if user.days_left < 0 %}
                                    <span style="color:#ff6b6b;">{{ user.expire }}</span>
                                    {% elif user.days_left < 3 %}
                                    <span style="color:#ff6b6b;">{{ user.expire }} ({{ user.days_left }}d)</span>
                                    {% elif user.days_left < 7 %}
                                    <span style="color:#ffd700;">{{ user.expire }} ({{ user.days_left }}d)</span>
                                    {% else %}
                                    <span style="color:#48bb78;">{{ user.expire }} ({{ user.days_left }}d)</span>
                                    {% endif %}
                                </td>
                                <td>{{ user.current_conn }}/{{ user.conn_limit }}</td>
                                <td>{{ user.usage.total }} GB</td>
                                <td>
                                    {% if user.status == 'online' %}
                                    <span class="badge badge-online">🟢 Online</span>
                                    {% elif user.status == 'locked' %}
                                    <span class="badge badge-locked">🔒 Locked</span>
                                    {% elif user.status == 'expired' %}
                                    <span class="badge badge-expired">⛔ Expired</span>
                                    {% else %}
                                    <span class="badge badge-offline">⚫ Offline</span>
                                    {% endif %}
                                </td>
                                <td>
                                    <button class="btn btn-sm btn-info" onclick="renewUser('{{ user.username }}')">🔄 Renew</button>
                                    <button class="btn btn-sm btn-warning" onclick="setLimit('{{ user.username }}')">⚡ Limit</button>
                                    <button class="btn btn-sm btn-success" onclick="resetUsage('{{ user.username }}')">📊 Reset</button>
                                    {% if user.status == 'locked' %}
                                    <button class="btn btn-sm btn-warning" onclick="unlockUser('{{ user.username }}')">🔓 Unlock</button>
                                    {% else %}
                                    <button class="btn btn-sm btn-warning" onclick="lockUser('{{ user.username }}')">🔒 Lock</button>
                                    {% endif %}
                                    <button class="btn btn-sm btn-danger" onclick="deleteUser('{{ user.username }}')">❌ Delete</button>
                                </td>
                            </tr>
                            {% endfor %}
                            {% if not users %}
                            <tr><td colspan="7" style="text-align:center;color:rgba(255,255,255,0.3);padding:30px;">No users found</td></tr>
                            {% endif %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <!-- Add User Section -->
        <div id="section-add-user" style="display:none;">
            <div class="panel" style="max-width:500px;">
                <h2>➕ Create New User</h2>
                <form onsubmit="addUser(event)">
                    <input type="text" id="new-username" placeholder="Username" required>
                    <input type="password" id="new-password" placeholder="Password" required style="margin-top:10px;">
                    <input type="number" id="new-days" placeholder="Expire Days (default: 30)" value="30" style="margin-top:10px;">
                    <input type="number" id="new-limit" placeholder="Connection Limit (default: 1)" value="1" style="margin-top:10px;">
                    <button type="submit" class="btn btn-primary" style="width:100%;padding:12px;margin-top:10px;">
                        ➕ Create User
                    </button>
                </form>
                <div id="add-user-result" style="margin-top:20px;"></div>
            </div>
        </div>
        
        <!-- Settings Section -->
        <div id="section-settings" style="display:none;">
            <div class="panel">
                <h2>⚙️ System Settings</h2>
                <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:15px;">
                    <button class="btn btn-success" onclick="apiCall('/api/apply_speed')" style="padding:15px;">⚡ Apply Turbo Boost</button>
                    <button class="btn btn-warning" onclick="apiCall('/api/restart_services')" style="padding:15px;">🔄 Restart Services</button>
                    <button class="btn btn-info" onclick="showMTUModal()" style="padding:15px;">📡 Change MTU (Current: {{ info.mtu }})</button>
                    <button class="btn btn-{{ 'danger' if info.autoban else 'success' }}" onclick="apiCall('/api/toggle_autoban')" style="padding:15px;">
                        🚫 {{ 'Disable' if info.autoban else 'Enable' }} Auto-Ban
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Traffic Section -->
        <div id="section-traffic" style="display:none;">
            <div class="panel">
                <h2>📈 User Data Usage</h2>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Username</th>
                                <th>Download (GB)</th>
                                <th>Upload (GB)</th>
                                <th>Total (GB)</th>
                                <th>Month</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for user in users %}
                            <tr>
                                <td>{{ user.username }}</td>
                                <td>{{ user.usage.rx }} GB</td>
                                <td>{{ user.usage.tx }} GB</td>
                                <td><strong>{{ user.usage.total }} GB</strong></td>
                                <td>{{ user.usage.month }}</td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
    </div>
    
    <!-- MTU Modal -->
    <div class="modal" id="mtuModal">
        <div class="modal-content">
            <h2>📡 Change MTU Value</h2>
            <input type="number" id="mtu-value" placeholder="Enter MTU (1000-5000)" min="1000" max="5000">
            <div class="modal-actions">
                <button class="btn btn-primary" onclick="changeMTU()">Apply</button>
                <button class="btn btn-danger" onclick="closeModal('mtuModal')">Cancel</button>
            </div>
        </div>
    </div>
    
    <!-- Renew Modal -->
    <div class="modal" id="renewModal">
        <div class="modal-content">
            <h2>🔄 Renew User</h2>
            <input type="hidden" id="renew-username">
            <input type="number" id="renew-days" placeholder="Additional days" value="30">
            <div class="modal-actions">
                <button class="btn btn-primary" onclick="renewUserConfirm()">Renew</button>
                <button class="btn btn-danger" onclick="closeModal('renewModal')">Cancel</button>
            </div>
        </div>
    </div>
    
    <!-- Limit Modal -->
    <div class="modal" id="limitModal">
        <div class="modal-content">
            <h2>⚡ Set Connection Limit</h2>
            <input type="hidden" id="limit-username">
            <input type="number" id="limit-value" placeholder="Max connections (1-10)" min="1" max="10">
            <div class="modal-actions">
                <button class="btn btn-primary" onclick="setLimitConfirm()">Apply</button>
                <button class="btn btn-danger" onclick="closeModal('limitModal')">Cancel</button>
            </div>
        </div>
    </div>
    
    <script>
        // Show section
        function showSection(name) {
            document.querySelectorAll('[id^="section-"]').forEach(el => el.style.display = 'none');
            const section = document.getElementById('section-' + name);
            if (section) section.style.display = 'block';
            
            // Update active nav
            document.querySelectorAll('.nav-menu li a').forEach(a => a.classList.remove('active'));
            event.target.classList.add('active');
            
            // Refresh dashboard
            if (name === 'dashboard' || name === 'users') location.reload();
        }
        
        // Toast
        function showToast(msg, type) {
            const toast = document.getElementById('toast');
            toast.textContent = msg;
            toast.className = 'toast toast-' + type + ' show';
            setTimeout(() => toast.classList.remove('show'), 3000);
        }
        
        // API call helper
        function apiCall(url, data = {}, method = 'POST') {
            const formData = new FormData();
            for (let key in data) formData.append(key, data[key]);
            
            fetch(url, { method, body: formData })
                .then(r => r.json())
                .then(res => {
                    showToast(res.message, res.success ? 'success' : 'error');
                    if (res.success) setTimeout(() => location.reload(), 1500);
                })
                .catch(err => showToast('Error: ' + err, 'error'));
        }
        
        // Add user
        function addUser(e) {
            e.preventDefault();
            const data = {
                username: document.getElementById('new-username').value,
                password: document.getElementById('new-password').value,
                days: document.getElementById('new-days').value,
                conn_limit: document.getElementById('new-limit').value
            };
            
            fetch('/api/add_user', { method: 'POST', body: new URLSearchParams(data) })
                .then(r => r.json())
                .then(res => {
                    if (res.success) {
                        let html = '<div style="background:rgba(72,187,120,0.1);padding:15px;border-radius:10px;">';
                        html += '<h3 style="color:#48bb78;">✅ User Created!</h3>';
                        html += '<p>Username: <strong>' + res.user.username + '</strong></p>';
                        html += '<p>Password: <strong>' + res.user.password + '</strong></p>';
                        html += '<p>NS: <strong>' + res.user.ns + '</strong></p>';
                        html += '<p>Expire: <strong>' + res.user.expire + '</strong></p>';
                        html += '<p>Limit: <strong>' + res.user.conn_limit + ' connections</strong></p>';
                        html += '</div>';
                        document.getElementById('add-user-result').innerHTML = html;
                    } else {
                        showToast(res.message, 'error');
                    }
                });
        }
        
        // Delete user
        function deleteUser(username) {
            if (confirm('Delete user ' + username + '?')) {
                apiCall('/api/delete_user', { username });
            }
        }
        
        // Lock user
        function lockUser(username) {
            apiCall('/api/lock_user', { username });
        }
        
        // Unlock user
        function unlockUser(username) {
            apiCall('/api/unlock_user', { username });
        }
        
        // Reset usage
        function resetUsage(username) {
            apiCall('/api/reset_usage', { username });
        }
        
        // Renew modal
        function renewUser(username) {
            document.getElementById('renew-username').value = username;
            document.getElementById('renewModal').classList.add('active');
        }
        function renewUserConfirm() {
            const username = document.getElementById('renew-username').value;
            const days = document.getElementById('renew-days').value;
            apiCall('/api/renew_user', { username, days });
            closeModal('renewModal');
        }
        
        // Limit modal
        function setLimit(username) {
            document.getElementById('limit-username').value = username;
            document.getElementById('limitModal').classList.add('active');
        }
        function setLimitConfirm() {
            const username = document.getElementById('limit-username').value;
            const limit = document.getElementById('limit-value').value;
            apiCall('/api/set_limit', { username, limit });
            closeModal('limitModal');
        }
        
        // MTU modal
        function showMTUModal() {
            document.getElementById('mtuModal').classList.add('active');
        }
        function changeMTU() {
            const mtu = document.getElementById('mtu-value').value;
            apiCall('/api/change_mtu', { mtu });
            closeModal('mtuModal');
        }
        
        // Close modal
        function closeModal(id) {
            document.getElementById(id).classList.remove('active');
        }
        
        // Close modal on outside click
        document.addEventListener('click', function(e) {
            if (e.target.classList.contains('modal')) {
                e.target.classList.remove('active');
            }
        });
    </script>
</body>
</html>
HTMLEOF
    
    echo -e "${GREEN}✓ Templates created${NC}"
}

# ============================================================================
# CREATE SYSTEMD SERVICE
# ============================================================================
create_service() {
    echo -e "${YELLOW}[5/5] Creating system service...${NC}"
    
    cat > /etc/systemd/system/elite-x-web.service << EOF
[Unit]
Description=ELITE-X Web Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PANEL_DIR
ExecStart=/usr/bin/python3 $PANEL_DIR/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable elite-x-web
    systemctl restart elite-x-web
    
    echo -e "${GREEN}✓ Service created and started${NC}"
}

# ============================================================================
# SHOW COMPLETION
# ============================================================================
show_completion() {
    IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}${BOLD}       ELITE-X WEB DASHBOARD INSTALLED!              ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  URL:      ${CYAN}http://$IP:$PANEL_PORT/${NC}"
    echo -e "${GREEN}║${WHITE}  Username: ${CYAN}$PANEL_USER${NC}"
    echo -e "${GREEN}║${WHITE}  Password: ${CYAN}$PANEL_PASS${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Commands:${NC}"
    echo -e "${GREEN}║${WHITE}  • Restart: ${CYAN}systemctl restart elite-x-web${NC}"
    echo -e "${GREEN}║${WHITE}  • Status:  ${CYAN}systemctl status elite-x-web${NC}"
    echo -e "${GREEN}║${WHITE}  • Logs:    ${CYAN}journalctl -u elite-x-web -f${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    show_banner
    install_dependencies
    create_directories
    create_web_app
    create_templates
    create_service
    show_completion
    
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo -e "${YELLOW}Open your browser and go to: http://$IP:$PANEL_PORT/${NC}"
    echo -e "${YELLOW}Login with:${NC}"
    echo -e "  ${WHITE}Username:${NC} ${CYAN}$PANEL_USER${NC}"
    echo -e "  ${WHITE}Password:${NC} ${CYAN}$PANEL_PASS${NC}"
}

# Run
main
