#!/bin/bash

# ============================================================================
#                     SLOWDNS MODERN INSTALLATION SCRIPT
#                          ELITE-X8 EDITION v2.0
#                     WITH LOGIN SYSTEM & USER MANAGEMENT
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
USERS_DB="/etc/slowdns/users.db"
CONFIG_FILE="/etc/slowdns/config.ini"

# Default credentials
ADMIN_USER="elite-x"
ADMIN_PASS="elite2026"

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
# PASSWORD HASHING FUNCTIONS
# ============================================================================
hash_password() {
    echo -n "$1" | sha256sum | awk '{print $1}'
}

verify_password() {
    local user="$1"
    local pass="$2"
    local stored_hash=$(grep "^$user:" "$USERS_DB" | cut -d: -f2)
    local input_hash=$(hash_password "$pass")
    
    if [ "$stored_hash" = "$input_hash" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# USER MANAGEMENT FUNCTIONS
# ============================================================================
init_users_db() {
    mkdir -p /etc/slowdns
    if [ ! -f "$USERS_DB" ]; then
        touch "$USERS_DB"
        chmod 600 "$USERS_DB"
        # Add default admin user
        local admin_hash=$(hash_password "$ADMIN_PASS")
        echo "$ADMIN_USER:$admin_hash:admin:active:$(date +%s)" >> "$USERS_DB"
        log_message "Users database initialized with admin user"
    fi
}

add_user() {
    local username="$1"
    local password="$2"
    local role="${3:-user}"
    
    if grep -q "^$username:" "$USERS_DB"; then
        return 1
    fi
    
    local pass_hash=$(hash_password "$password")
    echo "$username:$pass_hash:$role:active:$(date +%s)" >> "$USERS_DB"
    log_message "User added: $username ($role)"
    return 0
}

remove_user() {
    local username="$1"
    
    if [ "$username" = "$ADMIN_USER" ]; then
        return 1
    fi
    
    sed -i "/^$username:/d" "$USERS_DB"
    log_message "User removed: $username"
    return 0
}

list_users() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}${BOLD}REGISTERED USERS${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}USERNAME      ROLE      STATUS      CREATED${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    
    while IFS=: read -r user hash role status created; do
        local created_date=$(date -d "@$created" "+%Y-%m-%d" 2>/dev/null || echo "Unknown")
        printf "${CYAN}║${NC} %-13s %-9s %-10s %-12s ${CYAN}║${NC}\n" "$user" "$role" "$status" "$created_date"
    done < "$USERS_DB"
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

change_password() {
    local username="$1"
    local new_password="$2"
    
    if ! grep -q "^$username:" "$USERS_DB"; then
        return 1
    fi
    
    local role=$(grep "^$username:" "$USERS_DB" | cut -d: -f3)
    local status=$(grep "^$username:" "$USERS_DB" | cut -d: -f4)
    local created=$(grep "^$username:" "$USERS_DB" | cut -d: -f5)
    local new_hash=$(hash_password "$new_password")
    
    sed -i "/^$username:/d" "$USERS_DB"
    echo "$username:$new_hash:$role:$status:$created" >> "$USERS_DB"
    log_message "Password changed for user: $username"
    return 0
}

# ============================================================================
# C-BASED AUTHENTICATION SERVER
# ============================================================================
compile_auth_server() {
    print_info "Compiling Authentication Server..."
    
    cat > /tmp/auth_server.c << 'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <signal.h>

#define PORT 9090
#define BUFFER_SIZE 4096
#define USERS_FILE "/etc/slowdns/users.db"
#define SESSION_TIMEOUT 3600

typedef struct {
    char username[64];
    char session_id[128];
    time_t created;
    int active;
} session_t;

session_t sessions[100];
int session_count = 0;

// Simple SHA256 implementation for password hashing
void simple_hash(const char *input, char *output) {
    // Using shell command for simplicity
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "echo -n '%s' | sha256sum | awk '{print $1}'", input);
    FILE *fp = popen(cmd, "r");
    if (fp) {
        fgets(output, 33, fp);
        output[32] = '\0';
        pclose(fp);
    }
}

int verify_credentials(const char *username, const char *password) {
    FILE *fp = fopen(USERS_FILE, "r");
    if (!fp) return 0;
    
    char line[256];
    char input_hash[33];
    simple_hash(password, input_hash);
    
    while (fgets(line, sizeof(line), fp)) {
        char *user = strtok(line, ":");
        char *hash = strtok(NULL, ":");
        char *role = strtok(NULL, ":");
        char *status = strtok(NULL, ":");
        
        if (user && hash && strcmp(username, user) == 0) {
            if (strcmp(input_hash, hash) == 0 && strcmp(status, "active") == 0) {
                fclose(fp);
                return 1;
            }
        }
    }
    
    fclose(fp);
    return 0;
}

void generate_session_id(char *session_id) {
    const char *chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    srand(time(NULL) ^ getpid());
    for (int i = 0; i < 32; i++) {
        session_id[i] = chars[rand() % 62];
    }
    session_id[32] = '\0';
}

char *create_session(const char *username) {
    // Remove expired sessions
    time_t now = time(NULL);
    for (int i = 0; i < session_count; i++) {
        if (sessions[i].active && (now - sessions[i].created) > SESSION_TIMEOUT) {
            sessions[i].active = 0;
        }
    }
    
    // Find empty slot
    for (int i = 0; i < 100; i++) {
        if (!sessions[i].active) {
            strncpy(sessions[i].username, username, 63);
            generate_session_id(sessions[i].session_id);
            sessions[i].created = now;
            sessions[i].active = 1;
            if (i >= session_count) session_count = i + 1;
            return sessions[i].session_id;
        }
    }
    
    return NULL;
}

int validate_session(const char *session_id) {
    time_t now = time(NULL);
    for (int i = 0; i < session_count; i++) {
        if (sessions[i].active && 
            strcmp(sessions[i].session_id, session_id) == 0 &&
            (now - sessions[i].created) <= SESSION_TIMEOUT) {
            return 1;
        }
    }
    return 0;
}

void handle_request(int client_fd) {
    char buffer[BUFFER_SIZE];
    int bytes_read = read(client_fd, buffer, BUFFER_SIZE - 1);
    
    if (bytes_read <= 0) {
        close(client_fd);
        return;
    }
    
    buffer[bytes_read] = '\0';
    
    // Parse request
    char method[16] = {0};
    char path[256] = {0};
    sscanf(buffer, "%s %s", method, path);
    
    // Parse headers for session cookie
    char *cookie = strstr(buffer, "Cookie: session=");
    char session_id[128] = {0};
    if (cookie) {
        sscanf(cookie, "Cookie: session=%32s", session_id);
    }
    
    char response[BUFFER_SIZE * 2];
    
    if (strcmp(path, "/api/login") == 0 && strcmp(method, "POST") == 0) {
        // Handle login
        char *body = strstr(buffer, "\r\n\r\n");
        if (body) {
            body += 4;
            char username[64] = {0};
            char password[64] = {0};
            
            // Simple JSON parsing
            char *user_start = strstr(body, "\"username\"");
            char *pass_start = strstr(body, "\"password\"");
            
            if (user_start && pass_start) {
                sscanf(user_start, "\"username\":\"%63[^\"]\"", username);
                sscanf(pass_start, "\"password\":\"%63[^\"]\"", password);
                
                if (verify_credentials(username, password)) {
                    char *sid = create_session(username);
                    if (sid) {
                        snprintf(response, sizeof(response),
                            "HTTP/1.1 200 OK\r\n"
                            "Content-Type: application/json\r\n"
                            "Set-Cookie: session=%s; Path=/; HttpOnly\r\n"
                            "Access-Control-Allow-Origin: *\r\n"
                            "\r\n"
                            "{\"status\":\"success\",\"session\":\"%s\",\"username\":\"%s\"}",
                            sid, sid, username);
                    } else {
                        snprintf(response, sizeof(response),
                            "HTTP/1.1 500 Internal Server Error\r\n"
                            "Content-Type: application/json\r\n"
                            "Access-Control-Allow-Origin: *\r\n"
                            "\r\n"
                            "{\"status\":\"error\",\"message\":\"Session creation failed\"}");
                    }
                } else {
                    snprintf(response, sizeof(response),
                        "HTTP/1.1 401 Unauthorized\r\n"
                        "Content-Type: application/json\r\n"
                        "Access-Control-Allow-Origin: *\r\n"
                        "\r\n"
                        "{\"status\":\"error\",\"message\":\"Invalid credentials\"}");
                }
            }
        }
    } else if (strcmp(path, "/api/verify") == 0) {
        // Verify session
        if (validate_session(session_id)) {
            snprintf(response, sizeof(response),
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: application/json\r\n"
                "Access-Control-Allow-Origin: *\r\n"
                "\r\n"
                "{\"status\":\"success\",\"authenticated\":true}");
        } else {
            snprintf(response, sizeof(response),
                "HTTP/1.1 401 Unauthorized\r\n"
                "Content-Type: application/json\r\n"
                "Access-Control-Allow-Origin: *\r\n"
                "\r\n"
                "{\"status\":\"error\",\"authenticated\":false}");
        }
    } else if (strcmp(path, "/api/logout") == 0) {
        // Handle logout
        for (int i = 0; i < session_count; i++) {
            if (sessions[i].active && strcmp(sessions[i].session_id, session_id) == 0) {
                sessions[i].active = 0;
            }
        }
        snprintf(response, sizeof(response),
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Set-Cookie: session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "\r\n"
            "{\"status\":\"success\",\"message\":\"Logged out\"}");
    } else {
        snprintf(response, sizeof(response),
            "HTTP/1.1 404 Not Found\r\n"
            "Content-Type: application/json\r\n"
            "\r\n"
            "{\"status\":\"error\",\"message\":\"Not found\"}");
    }
    
    write(client_fd, response, strlen(response));
    close(client_fd);
}

int main() {
    signal(SIGCHLD, SIG_IGN);
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        return 1;
    }
    
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(PORT);
    
    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Bind failed");
        return 1;
    }
    
    if (listen(server_fd, 10) < 0) {
        perror("Listen failed");
        return 1;
    }
    
    printf("Auth server running on port %d\n", PORT);
    
    while (1) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
        
        if (client_fd < 0) continue;
        
        if (fork() == 0) {
            close(server_fd);
            handle_request(client_fd);
            exit(0);
        }
        
        close(client_fd);
    }
    
    return 0;
}
CEOF

    gcc -O3 -o /usr/local/bin/slowdns-auth-server /tmp/auth_server.c 2>/dev/null
    
    if [ $? -eq 0 ]; then
        chmod +x /usr/local/bin/slowdns-auth-server
        print_success "Authentication server compiled successfully"
        log_message "Auth server compiled successfully"
    else
        print_error "Auth server compilation failed, using Python fallback"
        log_message "Auth server compilation failed"
    fi
}

# ============================================================================
# CREATE ENHANCED DASHBOARD WITH LOGIN
# ============================================================================
create_dashboard() {
    print_step "4"
    print_info "Creating Enhanced Management Dashboard with Login"
    
    mkdir -p /etc/slowdns/dashboard
    
    # Create login page
    cat > /etc/slowdns/dashboard/login.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ELITE-X8 SlowDNS - Login</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .login-container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            width: 400px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .logo {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo h1 {
            color: white;
            font-size: 2em;
            margin-bottom: 10px;
        }
        .logo p {
            color: rgba(255, 255, 255, 0.7);
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            color: white;
            display: block;
            margin-bottom: 5px;
        }
        .form-group input {
            width: 100%;
            padding: 12px;
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 10px;
            background: rgba(255, 255, 255, 0.1);
            color: white;
            font-size: 1em;
        }
        .form-group input::placeholder {
            color: rgba(255, 255, 255, 0.5);
        }
        .login-btn {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
            border-radius: 10px;
            color: white;
            font-size: 1.1em;
            cursor: pointer;
            transition: transform 0.3s;
        }
        .login-btn:hover {
            transform: translateY(-2px);
        }
        .error-message {
            color: #ff6b6b;
            text-align: center;
            margin-top: 10px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1>🚀 ELITE-X8</h1>
            <p>SlowDNS Management System</p>
        </div>
        <form id="loginForm">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" id="username" placeholder="Enter username" required>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" placeholder="Enter password" required>
            </div>
            <button type="submit" class="login-btn">Sign In</button>
        </form>
        <div class="error-message" id="errorMessage"></div>
    </div>
    
    <script>
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('errorMessage');
            
            try {
                const response = await fetch('/api/login', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ username, password })
                });
                
                const data = await response.json();
                
                if (data.status === 'success') {
                    window.location.href = '/dashboard';
                } else {
                    errorDiv.textContent = data.message || 'Invalid credentials';
                    errorDiv.style.display = 'block';
                }
            } catch (error) {
                errorDiv.textContent = 'Connection error. Please try again.';
                errorDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>
HTMLEOF

    # Create main dashboard
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
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            color: white;
        }
        
        /* Sidebar */
        .sidebar {
            position: fixed;
            left: 0;
            top: 0;
            width: 250px;
            height: 100vh;
            background: rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
            padding: 20px;
            border-right: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .sidebar-header {
            text-align: center;
            padding: 20px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            margin-bottom: 20px;
        }
        
        .sidebar-header h2 {
            font-size: 1.5em;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .sidebar-menu {
            list-style: none;
        }
        
        .sidebar-menu li {
            margin-bottom: 10px;
        }
        
        .sidebar-menu a {
            color: rgba(255, 255, 255, 0.7);
            text-decoration: none;
            padding: 12px 15px;
            display: block;
            border-radius: 10px;
            transition: all 0.3s;
        }
        
        .sidebar-menu a:hover,
        .sidebar-menu a.active {
            background: rgba(102, 126, 234, 0.2);
            color: white;
        }
        
        .sidebar-menu .icon {
            margin-right: 10px;
        }
        
        /* Main Content */
        .main-content {
            margin-left: 250px;
            padding: 30px;
        }
        
        .top-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
            padding: 20px;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 15px;
        }
        
        .user-info {
            display: flex;
            align-items: center;
            gap: 15px;
        }
        
        .logout-btn {
            padding: 10px 20px;
            background: rgba(255, 0, 0, 0.2);
            border: 1px solid rgba(255, 0, 0, 0.3);
            border-radius: 10px;
            color: #ff6b6b;
            cursor: pointer;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 25px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            transition: transform 0.3s;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-card h3 {
            font-size: 0.9em;
            color: rgba(255, 255, 255, 0.6);
            margin-bottom: 15px;
        }
        
        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .panel {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 20px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .panel h3 {
            margin-bottom: 20px;
            color: #667eea;
        }
        
        .button {
            padding: 10px 20px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-size: 1em;
            margin: 5px;
            transition: all 0.3s;
        }
        
        .btn-primary { background: #667eea; color: white; }
        .btn-success { background: #48bb78; color: white; }
        .btn-danger { background: #f56565; color: white; }
        .btn-warning { background: #ecc94b; color: black; }
        
        .button:hover {
            opacity: 0.8;
            transform: translateY(-2px);
        }
        
        .logs {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 10px;
            padding: 20px;
            color: #0f0;
            font-family: monospace;
            height: 300px;
            overflow-y: auto;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .public-key {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 10px;
            padding: 15px;
            color: #ffd700;
            font-family: monospace;
            word-break: break-all;
            margin-top: 10px;
        }
        
        .user-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .user-table th,
        .user-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .user-table th {
            color: #667eea;
        }
        
        .status-active { color: #48bb78; }
        .status-inactive { color: #f56565; }
        
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.5);
            justify-content: center;
            align-items: center;
        }
        
        .modal-content {
            background: #1a1a2e;
            padding: 30px;
            border-radius: 15px;
            width: 400px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .modal-content input {
            width: 100%;
            padding: 10px;
            margin: 10px 0;
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 8px;
            color: white;
        }
        
        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        
        .tab {
            padding: 10px 20px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            cursor: pointer;
        }
        
        .tab.active {
            background: #667eea;
        }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">
            <h2>🚀 ELITE-X8</h2>
            <p style="color: rgba(255,255,255,0.5);">SlowDNS Panel</p>
        </div>
        <ul class="sidebar-menu">
            <li><a href="#" class="active" onclick="showSection('overview')"><span class="icon">📊</span> Overview</a></li>
            <li><a href="#" onclick="showSection('service-control')"><span class="icon">🎮</span> Service Control</a></li>
            <li><a href="#" onclick="showSection('user-management')"><span class="icon">👥</span> User Management</a></li>
            <li><a href="#" onclick="showSection('server-config')"><span class="icon">⚙️</span> Server Config</a></li>
            <li><a href="#" onclick="showSection('logs-monitor')"><span class="icon">📋</span> Logs & Monitor</a></li>
            <li><a href="#" onclick="showSection('ssh-manager')"><span class="icon">🔐</span> SSH Manager</a></li>
        </ul>
    </div>
    
    <div class="main-content">
        <div class="top-bar">
            <h1 id="sectionTitle">📊 Overview</h1>
            <div class="user-info">
                <span id="currentUser">User</span>
                <button class="logout-btn" onclick="logout()">🚪 Logout</button>
            </div>
        </div>
        
        <!-- Overview Section -->
        <div id="overview" class="section">
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
                <div class="stat-card">
                    <h3>TOTAL USERS</h3>
                    <div class="value" id="totalUsers">0</div>
                </div>
                <div class="stat-card">
                    <h3>UPTIME</h3>
                    <div class="value" id="uptime">0h</div>
                </div>
            </div>
            
            <div class="panel">
                <h3>🔑 Public Key (Copy for client configuration)</h3>
                <div class="public-key" id="publicKey">Loading...</div>
            </div>
        </div>
        
        <!-- Service Control Section -->
        <div id="service-control" class="section" style="display:none;">
            <div class="panel">
                <h3>🎮 Service Controls</h3>
                <button class="button btn-success" onclick="controlService('start','server-sldns')">▶ Start SlowDNS</button>
                <button class="button btn-danger" onclick="controlService('stop','server-sldns')">⏹ Stop SlowDNS</button>
                <button class="button btn-warning" onclick="controlService('restart','server-sldns')">🔄 Restart SlowDNS</button>
                <br><br>
                <button class="button btn-success" onclick="controlService('start','edns-proxy')">▶ Start EDNS Proxy</button>
                <button class="button btn-danger" onclick="controlService('stop','edns-proxy')">⏹ Stop EDNS Proxy</button>
                <button class="button btn-warning" onclick="controlService('restart','edns-proxy')">🔄 Restart EDNS Proxy</button>
            </div>
        </div>
        
        <!-- User Management Section -->
        <div id="user-management" class="section" style="display:none;">
            <div class="panel">
                <h3>👥 User Management</h3>
                <button class="button btn-primary" onclick="openAddUserModal()">➕ Add New User</button>
                <br><br>
                <div id="usersList"></div>
            </div>
        </div>
        
        <!-- Server Config Section -->
        <div id="server-config" class="section" style="display:none;">
            <div class="panel">
                <h3>⚙️ Server Configuration</h3>
                <div id="serverConfigInfo"></div>
            </div>
        </div>
        
        <!-- Logs Section -->
        <div id="logs-monitor" class="section" style="display:none;">
            <div class="panel">
                <h3>📋 Service Logs</h3>
                <div class="tabs">
                    <div class="tab active" onclick="loadLogs('slowdns')">SlowDNS</div>
                    <div class="tab" onclick="loadLogs('edns')">EDNS Proxy</div>
                    <div class="tab" onclick="loadLogs('system')">System</div>
                </div>
                <div class="logs" id="logs"></div>
            </div>
        </div>
        
        <!-- SSH Manager Section -->
        <div id="ssh-manager" class="section" style="display:none;">
            <div class="panel">
                <h3>🔐 SSH Manager</h3>
                <div id="sshInfo"></div>
            </div>
        </div>
    </div>
    
    <!-- Add User Modal -->
    <div class="modal" id="addUserModal">
        <div class="modal-content">
            <h3>Add New User</h3>
            <input type="text" id="newUsername" placeholder="Username">
            <input type="password" id="newPassword" placeholder="Password">
            <select id="newUserRole" style="width:100%;padding:10px;margin:10px 0;background:rgba(255,255,255,0.1);border:1px solid rgba(255,255,255,0.3);border-radius:8px;color:white;">
                <option value="user">User</option>
                <option value="admin">Admin</option>
            </select>
            <button class="button btn-success" onclick="addNewUser()">Create User</button>
            <button class="button btn-danger" onclick="closeModal('addUserModal')">Cancel</button>
        </div>
    </div>
    
    <script>
        let currentSection = 'overview';
        
        // Check authentication on load
        async function checkAuth() {
            try {
                const response = await fetch('/api/verify');
                const data = await response.json();
                
                if (!data.authenticated) {
                    window.location.href = '/login';
                }
            } catch (error) {
                window.location.href = '/login';
            }
        }
        
        // Show section
        function showSection(section) {
            document.querySelectorAll('.section').forEach(s => s.style.display = 'none');
            document.getElementById(section).style.display = 'block';
            
            const titles = {
                'overview': '📊 Overview',
                'service-control': '🎮 Service Control',
                'user-management': '👥 User Management',
                'server-config': '⚙️ Server Configuration',
                'logs-monitor': '📋 Logs & Monitor',
                'ssh-manager': '🔐 SSH Manager'
            };
            
            document.getElementById('sectionTitle').textContent = titles[section] || section;
            currentSection = section;
            
            // Update active menu
            document.querySelectorAll('.sidebar-menu a').forEach(a => a.classList.remove('active'));
            event.target.classList.add('active');
        }
        
        // Service control
        async function controlService(action, service) {
            try {
                const response = await fetch('/api/service-control', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ action, service })
                });
                const data = await response.json();
                alert(data.message);
                refreshDashboard();
            } catch (error) {
                alert('Error: ' + error);
            }
        }
        
        // User management
        function openAddUserModal() {
            document.getElementById('addUserModal').style.display = 'flex';
        }
        
        function closeModal(modalId) {
            document.getElementById(modalId).style.display = 'none';
        }
        
        async function addNewUser() {
            const username = document.getElementById('newUsername').value;
            const password = document.getElementById('newPassword').value;
            const role = document.getElementById('newUserRole').value;
            
            if (!username || !password) {
                alert('Please fill all fields');
                return;
            }
            
            try {
                const response = await fetch('/api/add-user', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ username, password, role })
                });
                const data = await response.json();
                alert(data.message);
                closeModal('addUserModal');
                loadUsers();
            } catch (error) {
                alert('Error: ' + error);
            }
        }
        
        async function removeUser(username) {
            if (!confirm(`Remove user ${username}?`)) return;
            
            try {
                const response = await fetch('/api/remove-user', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ username })
                });
                const data = await response.json();
                alert(data.message);
                loadUsers();
            } catch (error) {
                alert('Error: ' + error);
            }
        }
        
        async function loadUsers() {
            try {
                const response = await fetch('/api/list-users');
                const data = await response.json();
                
                let html = '<table class="user-table"><tr><th>Username</th><th>Role</th><th>Status</th><th>Actions</th></tr>';
                
                data.users.forEach(user => {
                    html += `<tr>
                        <td>${user.username}</td>
                        <td>${user.role}</td>
                        <td><span class="status-${user.status}">${user.status}</span></td>
                        <td>
                            <button class="button btn-warning" onclick="changePassword('${user.username}')">🔑 Password</button>
                            <button class="button btn-danger" onclick="removeUser('${user.username}')">🗑 Remove</button>
                        </td>
                    </tr>`;
                });
                
                html += '</table>';
                document.getElementById('usersList').innerHTML = html;
            } catch (error) {
                document.getElementById('usersList').innerHTML = 'Error loading users';
            }
        }
        
        async function changePassword(username) {
            const newPass = prompt(`Enter new password for ${username}:`);
            if (!newPass) return;
            
            try {
                const response = await fetch('/api/change-password', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ username, password: newPass })
                });
                const data = await response.json();
                alert(data.message);
            } catch (error) {
                alert('Error: ' + error);
            }
        }
        
        // Logs
        async function loadLogs(type) {
            try {
                const response = await fetch(`/api/logs?service=${type}`);
                const data = await response.json();
                document.getElementById('logs').innerHTML = data.logs || 'No logs available';
            } catch (error) {
                document.getElementById('logs').innerHTML = 'Error loading logs';
            }
        }
        
        // Refresh dashboard
        async function refreshDashboard() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                document.getElementById('connections').textContent = data.connections || 0;
                document.getElementById('publicKey').textContent = data.publicKey || 'Not available';
                document.getElementById('totalUsers').textContent = data.totalUsers || 0;
                document.getElementById('uptime').textContent = data.uptime || '0h';
                
                if (currentSection === 'user-management') loadUsers();
                if (currentSection === 'logs-monitor') loadLogs('slowdns');
            } catch (error) {
                console.error('Refresh error:', error);
            }
        }
        
        // Logout
        async function logout() {
            await fetch('/api/logout', { method: 'POST' });
            window.location.href = '/login';
        }
        
        // Initialize
        checkAuth();
        refreshDashboard();
        setInterval(refreshDashboard, 5000);
    </script>
</body>
</html>
HTMLEOF

    # Create enhanced API server with user management
    cat > /usr/local/bin/slowdns-api.py << 'APIEOF'
#!/usr/bin/env python3
import http.server
import json
import subprocess
import os
import sys
import time
import re
from urllib.parse import urlparse, parse_qs

USERS_DB = "/etc/slowdns/users.db"
LOG_FILE = "/var/log/slowdns-install.log"

def hash_password(password):
    import hashlib
    return hashlib.sha256(password.encode()).hexdigest()

def verify_credentials(username, password):
    try:
        with open(USERS_DB, 'r') as f:
            for line in f:
                parts = line.strip().split(':')
                if len(parts) >= 4 and parts[0] == username:
                    stored_hash = parts[1]
                    status = parts[3]
                    if hash_password(password) == stored_hash and status == 'active':
                        return True
    except:
        pass
    return False

def add_user_to_db(username, password, role='user'):
    try:
        with open(USERS_DB, 'r') as f:
            if any(line.startswith(username + ':') for line in f):
                return False, "User already exists"
        
        with open(USERS_DB, 'a') as f:
            pass_hash = hash_password(password)
            f.write(f"{username}:{pass_hash}:{role}:active:{int(time.time())}\n")
        return True, "User created successfully"
    except Exception as e:
        return False, str(e)

def remove_user_from_db(username):
    try:
        if username == 'elite-x':
            return False, "Cannot remove admin user"
        
        with open(USERS_DB, 'r') as f:
            lines = f.readlines()
        
        with open(USERS_DB, 'w') as f:
            for line in lines:
                if not line.startswith(username + ':'):
                    f.write(line)
        return True, "User removed successfully"
    except Exception as e:
        return False, str(e)

def list_users_from_db():
    users = []
    try:
        with open(USERS_DB, 'r') as f:
            for line in f:
                parts = line.strip().split(':')
                if len(parts) >= 4:
                    users.append({
                        'username': parts[0],
                        'role': parts[2],
                        'status': parts[3]
                    })
    except:
        pass
    return users

def change_user_password(username, new_password):
    try:
        with open(USERS_DB, 'r') as f:
            lines = f.readlines()
        
        with open(USERS_DB, 'w') as f:
            for line in lines:
                parts = line.strip().split(':')
                if parts[0] == username:
                    new_hash = hash_password(new_password)
                    f.write(f"{username}:{new_hash}:{parts[2]}:{parts[3]}:{parts[4]}\n")
                else:
                    f.write(line)
        return True, "Password changed successfully"
    except Exception as e:
        return False, str(e)

def get_system_status():
    status = {
        'connections': 0,
        'publicKey': 'Not available',
        'totalUsers': 0,
        'uptime': '0h',
        'slowdns_running': False,
        'edns_running': False,
        'dashboard_running': False
    }
    
    # Check services
    try:
        result = subprocess.run(['systemctl', 'is-active', 'server-sldns'], 
                              capture_output=True, text=True)
        status['slowdns_running'] = result.stdout.strip() == 'active'
    except:
        pass
    
    try:
        result = subprocess.run(['systemctl', 'is-active', 'edns-proxy'], 
                              capture_output=True, text=True)
        status['edns_running'] = result.stdout.strip() == 'active'
    except:
        pass
    
    # Get connections
    try:
        result = subprocess.run(['ss', '-tn'], capture_output=True, text=True)
        status['connections'] = len([l for l in result.stdout.split('\n') if ':22' in l or ':5300' in l])
    except:
        pass
    
    # Get public key
    try:
        with open('/etc/slowdns/server.pub', 'r') as f:
            status['publicKey'] = f.read().strip()
    except:
        pass
    
    # Get users count
    try:
        with open(USERS_DB, 'r') as f:
            status['totalUsers'] = len(f.readlines())
    except:
        pass
    
    # Get uptime
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
            hours = int(uptime_seconds // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            status['uptime'] = f"{hours}h {minutes}m"
    except:
        pass
    
    return status

def control_service(action, service):
    try:
        subprocess.run(['systemctl', action, service], check=True)
        return True, f"Service {service} {action}ed successfully"
    except Exception as e:
        return False, str(e)

def get_logs(service='slowdns'):
    try:
        if service == 'slowdns':
            result = subprocess.run(['journalctl', '-u', 'server-sldns', '--no-pager', '-n', '50'],
                                  capture_output=True, text=True, timeout=5)
        elif service == 'edns':
            result = subprocess.run(['journalctl', '-u', 'edns-proxy', '--no-pager', '-n', '50'],
                                  capture_output=True, text=True, timeout=5)
        else:
            result = subprocess.run(['tail', '-n', '50', LOG_FILE],
                                  capture_output=True, text=True, timeout=5)
        return result.stdout or 'No logs available'
    except:
        return 'Error fetching logs'

def parse_cookies(headers):
    cookies = {}
    if 'Cookie' in headers:
        for cookie in headers['Cookie'].split(';'):
            if '=' in cookie:
                key, value = cookie.strip().split('=', 1)
                cookies[key.strip()] = value.strip()
    return cookies

class SlowDNSAPI(http.server.BaseHTTPRequestHandler):
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        # Serve static files
        if path == '/' or path == '/dashboard':
            self.serve_file('/etc/slowdns/dashboard/index.html', 'text/html')
        elif path == '/login':
            self.serve_file('/etc/slowdns/dashboard/login.html', 'text/html')
        elif path == '/api/status':
            self.send_json_response(get_system_status())
        elif path == '/api/list-users':
            self.send_json_response({'users': list_users_from_db()})
        elif path == '/api/logs':
            service = parse_qs(parsed.query).get('service', ['slowdns'])[0]
            self.send_json_response({'logs': get_logs(service)})
        elif path == '/api/verify':
            cookies = parse_cookies(self.headers)
            if 'session' in cookies:
                self.send_json_response({'authenticated': True})
            else:
                self.send_json_response({'authenticated': False}, 401)
        else:
            self.send_error(404)
    
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        data = json.loads(post_data.decode() if post_data else '{}')
        
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/api/login':
            username = data.get('username', '')
            password = data.get('password', '')
            
            if verify_credentials(username, password):
                response = {
                    'status': 'success',
                    'session': 'active_session',
                    'username': username
                }
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Set-Cookie', 'session=active_session; Path=/; HttpOnly')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
            else:
                self.send_json_response({'status': 'error', 'message': 'Invalid credentials'}, 401)
        
        elif path == '/api/logout':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Set-Cookie', 'session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'success', 'message': 'Logged out'}).encode())
        
        elif path == '/api/add-user':
            username = data.get('username', '')
            password = data.get('password', '')
            role = data.get('role', 'user')
            
            success, message = add_user_to_db(username, password, role)
            self.send_json_response({'status': 'success' if success else 'error', 'message': message})
        
        elif path == '/api/remove-user':
            username = data.get('username', '')
            success, message = remove_user_from_db(username)
            self.send_json_response({'status': 'success' if success else 'error', 'message': message})
        
        elif path == '/api/change-password':
            username = data.get('username', '')
            password = data.get('password', '')
            
            success, message = change_user_password(username, password)
            self.send_json_response({'status': 'success' if success else 'error', 'message': message})
        
        elif path == '/api/service-control':
            action = data.get('action', '')
            service = data.get('service', '')
            
            success, message = control_service(action, service)
            self.send_json_response({'status': 'success' if success else 'error', 'message': message})
        
        else:
            self.send_error(404)
    
    def serve_file(self, filepath, content_type):
        try:
            with open(filepath, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.end_headers()
            self.wfile.write(content)
        except:
            self.send_error(404)
    
    def send_json_response(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8080), SlowDNSAPI)
    print("SlowDNS API Server running on port 8080")
    server.serve_forever()
APIEOF

    chmod +x /usr/local/bin/slowdns-api.py
    
    # Create dashboard service
    cat > /etc/systemd/system/slowdns-dashboard.service << EOF
[Unit]
Description=SlowDNS Dashboard API
After=network.target server-sldns.service edns-proxy.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/slowdns-api.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    print_success "Dashboard with login created successfully"
    print_step_end
}

# ============================================================================
# MAIN INSTALLATION FUNCTION
# ============================================================================
main_installation() {
    print_banner
    
    # Get nameserver
    echo -e "${WHITE}${BOLD}Configure Your Nameserver:${NC}"
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Example:${NC} dns.google.com, dns.cloudflare.com            ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    read -p "$(echo -e "${WHITE}${BOLD}Enter nameserver: ${NC}")" NAMESERVER
    NAMESERVER=${NAMESERVER:-dns.google.com}
    
    # Get server IP
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    check_requirements
    download_files
    configure_ssh
    compile_edns
    compile_auth_server
    init_users_db
    create_dashboard
    create_services
    configure_firewall
    start_services
    show_summary
}

# ============================================================================
# SHOW COMPLETION SUMMARY
# ============================================================================
show_summary() {
    print_header "🎉 INSTALLATION COMPLETE"
    
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}ELITE-X8 SLOWDNS SERVER INFORMATION${NC}                 ${CYAN}│${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Server IP:      ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SSH Port:       ${WHITE}$SSHD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} SlowDNS Port:   ${WHITE}$SLOWDNS_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} EDNS Port:      ${WHITE}53${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Dashboard:      ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Login Page:     ${WHITE}http://$SERVER_IP:$DASHBOARD_PORT/login${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Nameserver:     ${WHITE}$NAMESERVER${NC}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}${BOLD}LOGIN CREDENTIALS${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Username:       ${WHITE}elite-x${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}●${NC} Password:       ${WHITE}elite2026${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    
    # Show public key
    if [ -f /etc/slowdns/server.pub ]; then
        echo -e "\n${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}${BOLD}PUBLIC KEY${NC}                                           ${CYAN}│${NC}"
        echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}$(cat /etc/slowdns/server.pub)${NC}"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    fi
    
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}🎯 ELITE-X8 SLOWDNS WITH LOGIN SYSTEM INSTALLED!${NC}       ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}⚡ Dashboard: http://$SERVER_IP:$DASHBOARD_PORT${NC}             ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}    ${WHITE}🔐 Login: http://$SERVER_IP:$DASHBOARD_PORT/login${NC}          ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================================================
# ERROR HANDLING & EXECUTION
# ============================================================================
trap 'echo -e "\n${RED}✗ Installation interrupted!${NC}"; log_message "Installation interrupted"; exit 1' INT

# Initialize log
echo "=== SLOWDNS INSTALLATION STARTED $(date) ===" > "$LOG_FILE"

if main_installation; then
    echo "=== INSTALLATION COMPLETED SUCCESSFULLY $(date) ===" >> "$LOG_FILE"
    exit 0
else
    echo "=== INSTALLATION FAILED $(date) ===" >> "$LOG_FILE"
    echo -e "\n${RED}✗ Installation failed${NC}"
    exit 1
fi
