#!/usr/bin/env bash
# ============================================================
#  SHANUTECHX — Automated Install Script
#  Version: 1.0.0
#
#  Installs and configures:
#    • SHANUTECHX panel (3x-ui engine, rebranded)
#    • Nginx (stream SNI router + HTTPS reverse proxy)
#    • REALITY + normal VLESS+TLS inbounds (seeded)
#    • Let's Encrypt certificates via Certbot
#    • Custom glassmorphism subscription page template
#    • Firewall (ufw) + systemd + cron jobs
#
#  Supported OS: Ubuntu 20.04 / 22.04 / 24.04 · Debian 11 / 12
#
#  Usage:
#    bash shanutechx-install.sh [flags]
#
#  Flags:
#    -install y           Run the full install
#    -panel_domain <d>    Panel domain (HTTPS + subs)
#    -reality_domain <d>  REALITY inbound serverName / SNI
#    -vless_sni <d>       Normal VLESS+TLS camouflage SNI
#    -uninstall y         Cleanly remove everything
#
#  !! PLACEHOLDERS !!
#    PANEL_BINARY_URL and PANEL_TARBALL_NAME must be updated
#    to point at YOUR OWN GitHub fork after you push the
#    rebranded source tree.  Never silently point at a
#    third-party repository.
#
# ============================================================
set -euo pipefail

# ── Placeholder: update before use ──────────────────────────
PANEL_BINARY_URL="https://github.com/YOUR_GITHUB_USER/shanutechx/releases/latest/download/shanutechx-linux-amd64.tar.gz"
PANEL_TARBALL_NAME="shanutechx-linux-amd64.tar.gz"
# ────────────────────────────────────────────────────────────

INSTALL_DIR="/usr/local/x-ui"
DB_DIR="/etc/x-ui"
DB_FILE="${DB_DIR}/x-ui.db"
SUB_TEMPLATE_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sub_templates/shanutechx"
SUB_TEMPLATE_DEST="/opt/shanutechx/sub_templates/shanutechx"
FAVICON_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_STREAM_DIR="/etc/nginx/stream-enabled"
NGINX_CONF_DIR="/etc/nginx/sites-enabled"
NGINX_AVAIL_DIR="/etc/nginx/sites-available"
CERT_DIR="/etc/letsencrypt/live"
WEBROOT="/var/www/html"
SERVICE_FILE="/etc/systemd/system/x-ui.service"

# ── Brand terminal colors ────────────────────────────────────
VIOLET='\033[38;2;122;67;215m'
CYAN='\033[38;2;35;182;211m'
WHITE='\033[1;37m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
DIM='\033[2m'
RESET='\033[0m'
BOLD='\033[1m'

msg_ok()  { echo -e "${CYAN}  ✓  ${RESET}${WHITE}${*}${RESET}"; }
msg_err() { echo -e "${RED}  ✗  ${RESET}${WHITE}${*}${RESET}" >&2; }
msg_inf() { echo -e "${VIOLET}  →  ${RESET}${*}"; }
msg_warn(){ echo -e "${YELLOW}  ⚠  ${RESET}${*}"; }
die()     { msg_err "$*"; exit 1; }

banner() {
  echo ""
  echo -e "${VIOLET}${BOLD}"
  echo '   ╔═══════════════════════════════════════════╗'
  echo '   ║                                           ║'
  echo '   ║   ███████╗██╗  ██╗ █████╗ ███╗   ██╗    ║'
  echo '   ║   ██╔════╝██║  ██║██╔══██╗████╗  ██║    ║'
  echo '   ║   ███████╗███████║███████║██╔██╗ ██║    ║'
  echo '   ║   ╚════██║██╔══██║██╔══██║██║╚██╗██║    ║'
  echo '   ║   ███████║██║  ██║██║  ██║██║ ╚████║    ║'
  echo '   ║   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝    ║'
  echo '   ║                                           ║'
  echo -e "   ║   ${CYAN}TECHX${VIOLET} VPN Management Panel            ║"
  echo '   ║   Automated Install  v1.0.0              ║'
  echo '   ╚═══════════════════════════════════════════╝'
  echo -e "${RESET}"
  echo -e "${DIM}  Supported: Ubuntu 20/22/24 LTS · Debian 11/12${RESET}"
  echo ""
}

# ── Runtime variables (populated during install) ─────────────
ARG_INSTALL=""
ARG_UNINSTALL=""
ARG_PANEL_DOMAIN=""
ARG_REALITY_DOMAIN=""
ARG_VLESS_SNI=""

PANEL_DOMAIN=""
REALITY_DOMAIN=""
VLESS_SNI=""
PANEL_PORT=""
PANEL_PATH=""
SUB_PORT=""
SUB_PATH=""
SUB_JSON_PATH=""
REALITY_PORT=8443
VLESS_TLS_PORT=""
NGINX_INTERNAL_PORT=7443
PANEL_USER=""
PANEL_PASS=""
PANEL_API_TOKEN=""
VLESS_SNI_OWN=""   # "y" if user owns the VLESS_TLS_SNI domain
REALITY_PRIV_KEY=""
REALITY_PUB_KEY=""
SHORT_IDS=""
EMOJI_FLAG=""

PKG_MGR=""      # apt / yum / dnf
OS_ID=""
OS_VER=""

# ============================================================
#  Argument parsing
# ============================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -install)       ARG_INSTALL="${2:-}";       shift 2;;
      -uninstall)     ARG_UNINSTALL="${2:-}";     shift 2;;
      -panel_domain)  ARG_PANEL_DOMAIN="${2:-}";  shift 2;;
      -reality_domain)ARG_REALITY_DOMAIN="${2:-}";shift 2;;
      -vless_sni)     ARG_VLESS_SNI="${2:-}";     shift 2;;
      *) shift;;
    esac
  done
}

# ============================================================
#  OS detection
# ============================================================
detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    die "Cannot detect OS — /etc/os-release not found."
  fi
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VER="${VERSION_ID:-0}"

  case "$OS_ID" in
    ubuntu)
      case "$OS_VER" in
        20.04|22.04|24.04) ;;
        *) msg_warn "Ubuntu $OS_VER is untested. Proceeding anyway.";;
      esac
      PKG_MGR="apt"
      ;;
    debian)
      case "$OS_VER" in
        11|12) ;;
        *) msg_warn "Debian $OS_VER is untested. Proceeding anyway.";;
      esac
      PKG_MGR="apt"
      ;;
    centos|rhel|rocky|almalinux)
      PKG_MGR="yum"
      ;;
    fedora)
      PKG_MGR="dnf"
      ;;
    *)
      die "Unsupported OS: $OS_ID. This script targets Ubuntu 20/22/24 and Debian 11/12."
      ;;
  esac
  msg_ok "Detected OS: ${OS_ID} ${OS_VER} (package manager: ${PKG_MGR})"
}

# ============================================================
#  Root check
# ============================================================
check_root() {
  [[ $EUID -eq 0 ]] || die "This script must be run as root (sudo -i first)."
  msg_ok "Running as root"
}

# ============================================================
#  Public IP helpers
# ============================================================
get_public_ip() {
  curl -4 -fsSL --max-time 10 https://api.ipify.org 2>/dev/null \
    || curl -4 -fsSL --max-time 10 https://icanhazip.com 2>/dev/null \
    || echo ""
}

resolve_to_ip() {
  local domain="$1"
  dig +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' | head -1 || \
    getent hosts "$domain" 2>/dev/null | awk '{print $1}' || echo ""
}

validate_dns() {
  local domain="$1"
  local label="$2"
  local srv_ip
  srv_ip="$(get_public_ip)"
  local dns_ip
  dns_ip="$(resolve_to_ip "$domain")"

  if [[ -z "$dns_ip" ]]; then
    die "DNS check failed: $label ($domain) does not resolve to any IP.\n   Point an A record at this server's IP (${srv_ip}) and retry."
  fi
  if [[ "$dns_ip" != "$srv_ip" ]]; then
    die "DNS check failed: $label ($domain) resolves to ${dns_ip}, but this server is ${srv_ip}.\n   Update the A record and retry."
  fi
  msg_ok "DNS OK: $domain → $dns_ip"
}

# ============================================================
#  Package installation
# ============================================================
install_packages() {
  msg_inf "Installing system packages…"
  if [[ "$PKG_MGR" == "apt" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq \
      curl wget jq sqlite3 ufw \
      nginx-full \
      certbot python3-certbot-nginx \
      dnsutils uuid-runtime cron
  elif [[ "$PKG_MGR" == "yum" ]]; then
    yum install -y -q \
      curl wget jq sqlite ufw \
      nginx certbot python3-certbot-nginx \
      bind-utils util-linux cronie
  elif [[ "$PKG_MGR" == "dnf" ]]; then
    dnf install -y -q \
      curl wget jq sqlite ufw \
      nginx certbot python3-certbot-nginx \
      bind-utils util-linux cronie
  fi
  systemctl enable --now nginx
  msg_ok "Packages installed"
}

# ============================================================
#  Interactive prompts (fallback when flags not provided)
# ============================================================
prompt_domains() {
  # Panel domain
  if [[ -z "$PANEL_DOMAIN" ]]; then
    while true; do
      echo ""
      echo -e "${CYAN}Panel domain${RESET} (e.g. panel.yourdomain.com)"
      echo -e "  This domain will serve the SHANUTECHX UI, subscription page,"
      echo -e "  and CDN-friendly transports. It needs a valid A record."
      read -rp "  → Panel domain: " PANEL_DOMAIN
      [[ -n "$PANEL_DOMAIN" ]] && break
      msg_err "Domain cannot be empty."
    done
  fi

  # REALITY domain
  if [[ -z "$REALITY_DOMAIN" ]]; then
    while true; do
      echo ""
      echo -e "${CYAN}REALITY domain / SNI${RESET} (e.g. reality.yourdomain.com or a third-party domain)"
      echo -e "  This is the SNI that REALITY clients present. It does NOT need"
      echo -e "  to point at this server — it can be any TLS-enabled site."
      echo -e "  However, it must resolve to somewhere real for the SNI check."
      read -rp "  → REALITY SNI: " REALITY_DOMAIN
      [[ -n "$REALITY_DOMAIN" ]] && break
      msg_err "Domain cannot be empty."
    done
  fi

  # VLESS+TLS SNI
  if [[ -z "$VLESS_SNI" ]]; then
    while true; do
      echo ""
      echo -e "${CYAN}VLESS+TLS camouflage SNI${RESET}"
      echo -e "  This is the SNI used by the normal VLESS+TLS inbound."
      echo -e "  ${YELLOW}IMPORTANT — trust trade-off:${RESET}"
      echo -e "    A) You OWN this domain → Certbot will issue a real cert. Best security."
      echo -e "    B) You do NOT own it  → The connection uses a self-signed cert."
      echo -e "       Clients must set allowInsecure=true. Detectable by TLS inspection."
      read -rp "  → VLESS+TLS SNI [default: www.cloudflare.com]: " VLESS_SNI
      VLESS_SNI="${VLESS_SNI:-www.cloudflare.com}"
      [[ -n "$VLESS_SNI" ]] && break
    done
  fi

  echo ""
  echo -e "${YELLOW}Do you OWN the VLESS+TLS SNI domain (${VLESS_SNI})?${RESET}"
  echo -e "  Owning it = Certbot can issue a real cert (recommended)."
  echo -e "  Not owning = self-signed cert used, clients need allowInsecure=true."
  read -rp "  → Do you own '${VLESS_SNI}'? [y/N]: " VLESS_SNI_OWN
  VLESS_SNI_OWN="${VLESS_SNI_OWN,,}"
}

prompt_credentials() {
  echo ""
  echo -e "${CYAN}━━━ Panel credentials ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  Choose a username and strong password for the SHANUTECHX panel."
  echo -e "  These are shown ONCE at the end of installation. Store them safely."
  echo ""

  while true; do
    read -rp "  → Panel username: " PANEL_USER
    [[ ${#PANEL_USER} -ge 3 ]] && break
    msg_err "Username must be at least 3 characters."
  done

  while true; do
    read -rsp "  → Panel password: " PANEL_PASS
    echo ""
    [[ ${#PANEL_PASS} -ge 8 ]] && break
    msg_err "Password must be at least 8 characters."
  done

  while true; do
    read -rsp "  → Confirm password: " PASS2
    echo ""
    [[ "$PANEL_PASS" == "$PASS2" ]] && break
    msg_err "Passwords do not match. Try again."
  done

  msg_ok "Credentials accepted"
}

# ============================================================
#  Certificate issuance
# ============================================================
issue_cert() {
  local domain="$1"
  local cert_path="${CERT_DIR}/${domain}/fullchain.pem"

  if [[ -f "$cert_path" ]]; then
    msg_ok "Certificate already exists for ${domain} — skipping."
    return
  fi

  msg_inf "Requesting Let's Encrypt cert for ${domain}…"
  # Stop nginx temporarily so certbot can use port 80
  systemctl stop nginx 2>/dev/null || true
  certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    -d "$domain" \
    || die "Certbot failed for ${domain}. Check DNS propagation and try again."
  systemctl start nginx 2>/dev/null || true
  msg_ok "Certificate issued for ${domain}"
}

# ============================================================
#  Nginx configuration
# ============================================================
write_nginx_stream() {
  msg_inf "Writing Nginx stream SNI router…"
  mkdir -p "$NGINX_STREAM_DIR"

  # Ensure stream module is loaded in main nginx.conf
  if ! grep -q "stream_enabled" /etc/nginx/nginx.conf; then
    # Append stream include at end of nginx.conf (before last closing brace)
    sed -i '/^}/{ s/^}/\nstream { include \/etc\/nginx\/stream-enabled\/*.conf; }\n}/; b; }' \
      /etc/nginx/nginx.conf 2>/dev/null || true

    # Fallback: append to end of file
    if ! grep -q "stream_enabled" /etc/nginx/nginx.conf; then
      cat >> /etc/nginx/nginx.conf << NGINXEOF

stream {
    include /etc/nginx/stream-enabled/*.conf;
}
NGINXEOF
    fi
  fi

  cat > "${NGINX_STREAM_DIR}/stream.conf" << STREAMEOF
# ── SHANUTECHX SNI routing ──────────────────────────────────
# DO NOT EDIT — managed by shanutechx-install.sh

upstream xray_reality {
    server 127.0.0.1:${REALITY_PORT};
}

upstream xray_vless_tls {
    server 127.0.0.1:${VLESS_TLS_PORT};
}

upstream nginx_https {
    server 127.0.0.1:${NGINX_INTERNAL_PORT};
}

map \$ssl_preread_server_name \$sni_upstream {
    ${REALITY_DOMAIN}   xray_reality;
    ${VLESS_SNI}        xray_vless_tls;
    ${PANEL_DOMAIN}     nginx_https;
    default             xray_reality;
}

server {
    listen 443;
    ssl_preread on;
    proxy_pass \$sni_upstream;
    proxy_protocol off;
    proxy_connect_timeout 10s;
    proxy_timeout 300s;
}
STREAMEOF

  msg_ok "Nginx stream config written"
}

write_nginx_http() {
  msg_inf "Writing Nginx HTTP server blocks…"

  # HTTP → HTTPS redirect (both domains)
  cat > "${NGINX_AVAIL_DIR}/shanutechx-redirect.conf" << RCONF
# SHANUTECHX — HTTP→HTTPS redirect
server {
    listen 80;
    server_name ${PANEL_DOMAIN} ${REALITY_DOMAIN} ${VLESS_SNI};
    return 301 https://\$host\$request_uri;
}
RCONF
  ln -sf "${NGINX_AVAIL_DIR}/shanutechx-redirect.conf" \
         "${NGINX_CONF_DIR}/shanutechx-redirect.conf" 2>/dev/null || true

  # Panel HTTPS block (internal port — TLS terminated here)
  cat > "${NGINX_AVAIL_DIR}/shanutechx-panel.conf" << PANELCONF
# SHANUTECHX — Panel HTTPS reverse proxy
# Listens on internal port ${NGINX_INTERNAL_PORT}; fronted by the stream SNI map.

server {
    listen ${NGINX_INTERNAL_PORT} ssl;
    server_name ${PANEL_DOMAIN};

    ssl_certificate     ${CERT_DIR}/${PANEL_DOMAIN}/fullchain.pem;
    ssl_certificate_key ${CERT_DIR}/${PANEL_DOMAIN}/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    # ── Favicons (served directly, long cache) ──────────────
    location = /favicon.svg {
        root  ${WEBROOT};
        expires 365d;
        add_header Cache-Control "public, immutable";
    }
    location = /favicon.ico {
        root  ${WEBROOT};
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    # ── Panel UI ────────────────────────────────────────────
    location ${PANEL_PATH}/ {
        proxy_pass         http://127.0.0.1:${PANEL_PORT}${PANEL_PATH}/;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    # ── Subscription page ───────────────────────────────────
    location ${SUB_PATH}/ {
        proxy_pass         http://127.0.0.1:${SUB_PORT}${SUB_PATH}/;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ${SUB_JSON_PATH}/ {
        proxy_pass         http://127.0.0.1:${SUB_PORT}${SUB_JSON_PATH}/;
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
    }

    # ── Dynamic port forwarding for WS/gRPC/XHTTP transports
    #    URL pattern: /<inbound_port>/<path>
    location ~ ^/(?<fwdport>[0-9]{4,5})/(?<fwdpath>.*)\$ {
        resolver 127.0.0.1;
        proxy_pass         http://127.0.0.1:\$fwdport/\$fwdpath\$is_args\$args;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_read_timeout 300s;
    }

    # ── Deny everything else ────────────────────────────────
    location / {
        return 404;
    }
}
PANELCONF

  ln -sf "${NGINX_AVAIL_DIR}/shanutechx-panel.conf" \
         "${NGINX_CONF_DIR}/shanutechx-panel.conf" 2>/dev/null || true

  msg_ok "Nginx HTTP config written"
}

test_nginx() {
  msg_inf "Testing Nginx configuration…"
  if ! nginx -t 2>&1; then
    msg_err "Nginx config test FAILED. Output above. Aborting."
    exit 1
  fi
  systemctl reload nginx
  msg_ok "Nginx reloaded"
}

# ============================================================
#  Panel binary + frontend installation
# ============================================================
install_panel() {
  msg_inf "Downloading SHANUTECHX panel binary…"

  if [[ "$PANEL_BINARY_URL" == *"YOUR_GITHUB_USER"* ]]; then
    die "PANEL_BINARY_URL is still a placeholder!\n   Edit the top of shanutechx-install.sh with your own GitHub release URL."
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  cd "$tmp_dir"

  wget -q --show-progress -O "$PANEL_TARBALL_NAME" "$PANEL_BINARY_URL" \
    || die "Download failed. Check PANEL_BINARY_URL in the script."

  tar -xzf "$PANEL_TARBALL_NAME"

  mkdir -p "$INSTALL_DIR"
  # Assume tarball extracts to a directory named 'x-ui' containing the binary:
  if [[ -d "$tmp_dir/x-ui" ]]; then
    cp -r "$tmp_dir/x-ui/"* "$INSTALL_DIR/"
  else
    cp -r "$tmp_dir/"* "$INSTALL_DIR/"
  fi

  chmod +x "${INSTALL_DIR}/x-ui"
  cd /
  rm -rf "$tmp_dir"
  msg_ok "Panel binary installed to ${INSTALL_DIR}"
}

# ============================================================
#  systemd service
# ============================================================
install_service() {
  msg_inf "Installing SHANUTECHX systemd service…"
  cat > "$SERVICE_FILE" << 'SVCEOF'
[Unit]
Description=SHANUTECHX Panel Service
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

  systemctl daemon-reload
  systemctl enable x-ui
  systemctl start x-ui
  sleep 2

  if systemctl is-active --quiet x-ui; then
    msg_ok "x-ui service started"
  else
    msg_warn "x-ui service may not have started yet. Check: journalctl -u x-ui -n 30"
  fi
}

# ============================================================
#  Generate random tokens / ports
# ============================================================
gen_random_path() {
  # Generates a random 8-char alphanumeric path segment
  tr -dc 'a-z0-9' </dev/urandom | head -c 8
}

gen_random_port() {
  # Generates a random high port (20000–59999)
  shuf -i 20000-59999 -n 1
}

gen_random_api_token() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48
}

gen_uuid() {
  uuidgen | tr '[:upper:]' '[:lower:]'
}

gen_short_ids() {
  # Generates 6 random hex shortIds (8–16 chars each)
  local ids=()
  for _ in {1..6}; do
    ids+=( "$(tr -dc '0-9a-f' </dev/urandom | head -c 16)" )
  done
  # JSON array
  printf '"%s"' "${ids[@]}" | sed 's/""/"","/g' | sed 's/^/[/' | sed 's/$/]/'
}

random_emoji_flag() {
  local flags=('🇺🇸' '🇬🇧' '🇩🇪' '🇫🇷' '🇯🇵' '🇸🇬' '🇳🇱' '🇨🇦' '🇦🇺' '🇸🇪')
  echo "${flags[$((RANDOM % ${#flags[@]}))]}"
}


# ============================================================
#  REALITY keypair generation
# ============================================================
gen_reality_keys() {
  msg_inf "Generating REALITY x25519 keypair…"

  local xray_bin="${INSTALL_DIR}/xray"
  [[ ! -f "$xray_bin" ]] && xray_bin="${INSTALL_DIR}/xray-linux-amd64"
  [[ ! -f "$xray_bin" ]] && die "Cannot find xray binary in ${INSTALL_DIR}. Install panel first."

  local out
  out="$("$xray_bin" x25519 2>&1)"
  REALITY_PRIV_KEY=$(echo "$out" | grep -i 'private key' | awk '{print $NF}')
  REALITY_PUB_KEY=$(echo  "$out" | grep -i 'public key'  | awk '{print $NF}')

  [[ -z "$REALITY_PRIV_KEY" || -z "$REALITY_PUB_KEY" ]] && \
    die "Could not parse x25519 output:\n${out}"

  msg_ok "REALITY keys generated"
}

# ============================================================
#  Database seeding
# ============================================================
seed_database() {
  msg_inf "Seeding SHANUTECHX database…"

  mkdir -p "$DB_DIR"

  # If DB doesn't exist yet, initialise it by starting then stopping x-ui once
  if [[ ! -f "$DB_FILE" ]]; then
    msg_inf "Waiting for x-ui to create database…"
    systemctl start x-ui 2>/dev/null || true
    local waited=0
    while [[ ! -f "$DB_FILE" && $waited -lt 20 ]]; do
      sleep 1; ((waited++))
    done
    systemctl stop x-ui 2>/dev/null || true
    [[ -f "$DB_FILE" ]] || die "x-ui did not create database at ${DB_FILE}."
  fi

  EMOJI_FLAG="$(random_emoji_flag)"

  # ── Panel settings ────────────────────────────────────────
  # Hash the password (x-ui uses SHA256 hex)
  local pass_hash
  pass_hash="$(echo -n "${PANEL_PASS}" | sha256sum | awk '{print $1}')"

  # Subscription port = panel port + 1
  SUB_PORT=$(( PANEL_PORT + 1 ))

  PANEL_API_TOKEN="$(gen_random_api_token)"

  # Sub template absolute path
  local sub_theme_dir="${SUB_TEMPLATE_DEST}"

  sqlite3 "$DB_FILE" << SQLEOF
-- Panel settings
INSERT OR REPLACE INTO settings(key, value) VALUES
  ('webPort',       '${PANEL_PORT}'),
  ('webBasePath',   '${PANEL_PATH}'),
  ('subEnable',     'true'),
  ('subPort',       '${SUB_PORT}'),
  ('subPath',       '${SUB_PATH}'),
  ('subURI',        'https://${PANEL_DOMAIN}${SUB_PATH}/'),
  ('subJsonPath',   '${SUB_JSON_PATH}'),
  ('subJsonURI',    'https://${PANEL_DOMAIN}${SUB_JSON_PATH}/'),
  ('subThemeDir',   '${sub_theme_dir}'),
  ('apiToken',      '${PANEL_API_TOKEN}'),
  ('username',      '${PANEL_USER}'),
  ('password',      '${pass_hash}');
SQLEOF

  msg_ok "Panel settings seeded"

  # ── Inbound 1: VLESS + REALITY ────────────────────────────
  local reality_uuid
  reality_uuid="$(gen_uuid)"

  local reality_inbound_json
  reality_inbound_json=$(cat << RJSON
{
  "listen": "0.0.0.0",
  "port": ${REALITY_PORT},
  "protocol": "vless",
  "settings": {
    "clients": [{
      "id": "${reality_uuid}",
      "flow": "xtls-rprx-vision",
      "email": "${EMOJI_FLAG}-reality",
      "enable": true
    }],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "show": false,
      "dest": "127.0.0.1:${NGINX_INTERNAL_PORT}",
      "serverNames": ["${REALITY_DOMAIN}"],
      "privateKey": "${REALITY_PRIV_KEY}",
      "publicKey":  "${REALITY_PUB_KEY}",
      "shortIds": ${SHORT_IDS},
      "fingerprint": "chrome"
    }
  },
  "sniffing": {"enabled": true, "destOverride": ["http","tls","quic"]}
}
RJSON
)

  sqlite3 "$DB_FILE" << SQLEOF2
INSERT OR REPLACE INTO inbounds(
  user_id, up, down, total, remark, enable,
  expiry_time, listen, port, protocol,
  settings, stream_settings, tag, sniffing
) VALUES (
  1, 0, 0, 0,
  '${EMOJI_FLAG} REALITY',
  1, 0, '0.0.0.0', ${REALITY_PORT}, 'vless',
  '$(echo "$reality_inbound_json" | jq -c '.settings'      | sed "s/'/''/g")',
  '$(echo "$reality_inbound_json" | jq -c '.streamSettings'| sed "s/'/''/g")',
  'inbound-${REALITY_PORT}',
  '{"enabled":true,"destOverride":["http","tls","quic"]}'
);
SQLEOF2

  msg_ok "REALITY inbound seeded (port ${REALITY_PORT})"

  # ── Inbound 2: VLESS + TLS (normal with SNI) ──────────────
  local vless_uuid
  vless_uuid="$(gen_uuid)"
  local vless_tag="inbound-${VLESS_TLS_PORT}"

  local tls_settings
  if [[ "${VLESS_SNI_OWN,,}" == "y" ]]; then
    # Real cert — issued by certbot
    tls_settings=$(cat << TLSJ
{
  "certificates": [{
    "certificateFile": "${CERT_DIR}/${VLESS_SNI}/fullchain.pem",
    "keyFile":         "${CERT_DIR}/${VLESS_SNI}/privkey.pem"
  }],
  "alpn": ["h2", "http/1.1"]
}
TLSJ
)
  else
    # Self-signed / allowInsecure mode
    tls_settings=$(cat << TLSJ
{
  "certificates": [{
    "certificate": [],
    "key": []
  }],
  "alpn": ["http/1.1"],
  "allowInsecure": true
}
TLSJ
)
  fi

  local vless_stream
  vless_stream=$(cat << VSJS
{
  "network": "tcp",
  "security": "tls",
  "tlsSettings": $(echo "$tls_settings" | jq -c .)
}
VSJS
)

  sqlite3 "$DB_FILE" << SQLEOF3
INSERT OR REPLACE INTO inbounds(
  user_id, up, down, total, remark, enable,
  expiry_time, listen, port, protocol,
  settings, stream_settings, tag, sniffing
) VALUES (
  1, 0, 0, 0,
  '${EMOJI_FLAG} VLESS-TLS',
  1, 0, '0.0.0.0', ${VLESS_TLS_PORT}, 'vless',
  '{"clients":[{"id":"${vless_uuid}","email":"${EMOJI_FLAG}-vless-tls","enable":true}],"decryption":"none"}',
  '$(echo "$vless_stream" | jq -c . | sed "s/'/''/g")',
  '${vless_tag}',
  '{"enabled":true,"destOverride":["http","tls","quic"]}'
);
SQLEOF3

  msg_ok "VLESS+TLS inbound seeded (port ${VLESS_TLS_PORT})"
}

# ============================================================
#  Copy subscription template + favicons
# ============================================================
deploy_assets() {
  msg_inf "Deploying subscription template and favicons…"

  mkdir -p "$SUB_TEMPLATE_DEST"
  if [[ -d "$SUB_TEMPLATE_SRC" ]]; then
    cp -r "${SUB_TEMPLATE_SRC}/"* "${SUB_TEMPLATE_DEST}/"
    msg_ok "Subscription template deployed to ${SUB_TEMPLATE_DEST}"
  else
    msg_warn "sub_templates/shanutechx not found next to install script — skipping template deploy."
    msg_warn "Place the subscription template at: ${SUB_TEMPLATE_DEST}/index.html"
  fi

  # Favicons to webroot (for nginx to serve)
  mkdir -p "$WEBROOT"
  local fav_svg="${FAVICON_SRC}/favicon.svg"
  local fav_ico="${FAVICON_SRC}/favicon__1_.ico"
  [[ -f "$fav_svg" ]] && cp "$fav_svg" "${WEBROOT}/favicon.svg"
  [[ -f "$fav_ico" ]] && cp "$fav_ico" "${WEBROOT}/favicon.ico"

  # Also copy to panel public dir (if built frontend exists)
  local pub_dir="${INSTALL_DIR}/html/public"
  if [[ -d "$pub_dir" ]]; then
    [[ -f "$fav_svg" ]] && cp "$fav_svg" "${pub_dir}/favicon.svg"
    [[ -f "$fav_ico" ]] && cp "$fav_ico" "${pub_dir}/favicon.ico"
    msg_ok "Favicons deployed to ${pub_dir}"
  fi
  msg_ok "Favicons deployed to ${WEBROOT}"
}

# ============================================================
#  Firewall
# ============================================================
configure_firewall() {
  msg_inf "Configuring ufw firewall…"
  ufw --force reset >/dev/null 2>&1 || true
  ufw default deny incoming  >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  ufw allow 22/tcp   comment "SSH"
  ufw allow 80/tcp   comment "HTTP (redirect)"
  ufw allow 443/tcp  comment "HTTPS / Nginx stream"
  ufw allow 443/udp  comment "QUIC"
  echo "y" | ufw enable >/dev/null 2>&1
  msg_ok "Firewall configured (22,80,443/tcp + 443/udp)"
}

# ============================================================
#  Cron jobs
# ============================================================
setup_cron() {
  msg_inf "Setting up cron jobs…"
  # Remove old SHANUTECHX cron entries first
  crontab -l 2>/dev/null | grep -v 'shanutechx' > /tmp/crontab_clean || true

  cat >> /tmp/crontab_clean << 'CRONEOF'
# SHANUTECHX — daily service health cycle at 04:00
0 4 * * * systemctl restart x-ui && nginx -s reload >> /var/log/shanutechx-cron.log 2>&1
# SHANUTECHX — monthly cert renewal
0 3 1 * * certbot renew --quiet --post-hook "systemctl reload nginx" >> /var/log/shanutechx-cron.log 2>&1
CRONEOF

  crontab /tmp/crontab_clean
  rm -f /tmp/crontab_clean
  msg_ok "Cron jobs installed"
}

# ============================================================
#  Health checks
# ============================================================
final_health_check() {
  msg_inf "Running final health checks…"

  local ok=1

  # Nginx config
  if ! nginx -t 2>/dev/null; then
    msg_err "Nginx config test FAILED"
    ok=0
  else
    msg_ok "Nginx config: OK"
  fi

  # Nginx running
  if systemctl is-active --quiet nginx; then
    msg_ok "Nginx service: running"
  else
    msg_err "Nginx service: NOT running"
    ok=0
  fi

  # x-ui running
  systemctl restart x-ui 2>/dev/null || true
  sleep 3
  if systemctl is-active --quiet x-ui; then
    msg_ok "x-ui service: running"
  else
    msg_err "x-ui service: NOT running"
    journalctl -u x-ui -n 30 --no-pager
    ok=0
  fi

  [[ $ok -eq 0 ]] && die "One or more health checks failed. See output above."
}

# ============================================================
#  Final summary banner
# ============================================================
print_summary() {
  local srv_ipv4
  srv_ipv4="$(get_public_ip)"
  local srv_ipv6
  srv_ipv6="$(curl -6 -fsSL --max-time 5 https://api6.ipify.org 2>/dev/null || echo 'n/a')"

  local vless_tls_mode
  if [[ "${VLESS_SNI_OWN,,}" == "y" ]]; then
    vless_tls_mode="Real cert (Let's Encrypt) ✓"
  else
    vless_tls_mode="Self-signed — clients need allowInsecure=true ⚠"
  fi

  echo ""
  echo -e "${VIOLET}${BOLD}╔══════════════════════════════════════════════════════════╗"
  echo    "║               SHANUTECHX — Install Complete              ║"
  echo -e "╠══════════════════════════════════════════════════════════╣${RESET}"
  echo ""
  echo -e "  ${CYAN}Server${RESET}"
  echo    "    IPv4 : ${srv_ipv4}"
  echo    "    IPv6 : ${srv_ipv6}"
  echo ""
  echo -e "  ${CYAN}Panel${RESET}"
  echo    "    URL  : https://${PANEL_DOMAIN}${PANEL_PATH}/"
  echo    "    User : ${PANEL_USER}"
  echo    "    Pass : ${PANEL_PASS}"
  echo    "    API  : https://${PANEL_DOMAIN}${PANEL_PATH}/api-docs"
  echo    "    Token: ${PANEL_API_TOKEN}"
  echo ""
  echo -e "  ${CYAN}Subscription URLs${RESET}"
  echo    "    Base64 : https://${PANEL_DOMAIN}${SUB_PATH}/<subId>"
  echo    "    JSON   : https://${PANEL_DOMAIN}${SUB_JSON_PATH}/<subId>"
  echo    "    Clash  : https://${PANEL_DOMAIN}${SUB_PATH}/<subId>/clash"
  echo ""
  echo -e "  ${CYAN}Protocol Table${RESET}"
  printf  "    %-18s %-10s %-20s %s\n" "Protocol" "Port" "SNI / Target" "Notes"
  printf  "    %-18s %-10s %-20s %s\n" "────────────────" "────────" "──────────────────" "─────────────────"
  printf  "    %-18s %-10s %-20s %s\n" "VLESS+REALITY"   "${REALITY_PORT}" "${REALITY_DOMAIN}" "SNI → Xray REALITY"
  printf  "    %-18s %-10s %-20s %s\n" "VLESS+TLS"       "${VLESS_TLS_PORT}" "${VLESS_SNI}" "${vless_tls_mode}"
  printf  "    %-18s %-10s %-20s %s\n" "Panel (Nginx)"   "${NGINX_INTERNAL_PORT}" "${PANEL_DOMAIN}" "Internal only (SNI-routed)"
  echo ""
  echo -e "  ${CYAN}REALITY Keys${RESET}"
  echo    "    Public Key : ${REALITY_PUB_KEY}"
  echo    "    Private Key: stored in DB (never share)"
  echo ""
  echo -e "  ${YELLOW}⚠  Credentials shown ONCE. Store them in a password manager.${RESET}"
  echo -e "  ${YELLOW}⚠  VLESS+TLS mode: ${vless_tls_mode}${RESET}"
  echo ""
  echo -e "${VIOLET}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ============================================================
#  Uninstall
# ============================================================
do_uninstall() {
  echo ""
  msg_warn "This will PERMANENTLY remove SHANUTECHX, Nginx, and Certbot."
  read -rp "  → Type 'yes' to confirm: " confirm
  [[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }

  msg_inf "Stopping services…"
  systemctl stop  x-ui  2>/dev/null || true
  systemctl disable x-ui 2>/dev/null || true
  systemctl stop  nginx 2>/dev/null || true

  msg_inf "Removing panel files…"
  rm -rf "$INSTALL_DIR" "$DB_DIR" "$SERVICE_FILE"

  msg_inf "Removing Nginx config…"
  rm -f  "${NGINX_CONF_DIR}/shanutechx-panel.conf"
  rm -f  "${NGINX_CONF_DIR}/shanutechx-redirect.conf"
  rm -f  "${NGINX_AVAIL_DIR}/shanutechx-panel.conf"
  rm -f  "${NGINX_AVAIL_DIR}/shanutechx-redirect.conf"
  rm -f  "${NGINX_STREAM_DIR}/stream.conf"
  rm -rf "$SUB_TEMPLATE_DEST"
  rm -f  "${WEBROOT}/favicon.svg" "${WEBROOT}/favicon.ico"

  msg_inf "Removing cron jobs…"
  crontab -l 2>/dev/null | grep -v 'shanutechx' | crontab - 2>/dev/null || true

  if [[ "$PKG_MGR" == "apt" ]]; then
    msg_inf "Purging packages…"
    apt-get purge -y -qq nginx-full certbot python3-certbot-nginx ufw 2>/dev/null || true
    apt-get autoremove -y -qq 2>/dev/null || true
  fi

  msg_inf "Restoring firewall…"
  ufw --force disable 2>/dev/null || true

  systemctl daemon-reload
  msg_ok "SHANUTECHX uninstalled cleanly."
}

# ============================================================
#  Main install flow
# ============================================================
do_install() {
  banner
  check_root
  detect_os

  # Populate from flags or prompts
  PANEL_DOMAIN="${ARG_PANEL_DOMAIN}"
  REALITY_DOMAIN="${ARG_REALITY_DOMAIN}"
  VLESS_SNI="${ARG_VLESS_SNI}"

  prompt_domains     # fills any still-empty values interactively
  prompt_credentials

  # Idempotency check
  if [[ -f "$DB_FILE" ]]; then
    msg_warn "Existing installation detected (${DB_FILE} exists)."
    msg_warn "Re-running will update config but NOT reset your existing clients."
    read -rp "  → Continue? [y/N]: " cont
    [[ "${cont,,}" == "y" ]] || { echo "Aborted."; exit 0; }
  fi

  # Validate DNS before requesting certs
  validate_dns "$PANEL_DOMAIN"  "Panel domain"

  # Install packages
  install_packages

  # Generate random ports + paths
  PANEL_PORT="$(gen_random_port)"
  PANEL_PATH="/$(gen_random_path)"
  SUB_PORT="$(( PANEL_PORT + 1 ))"
  SUB_PATH="/$(gen_random_path)"
  SUB_JSON_PATH="/$(gen_random_path)"
  VLESS_TLS_PORT="$(gen_random_port)"
  SHORT_IDS="$(gen_short_ids)"

  # Certificates
  issue_cert "$PANEL_DOMAIN"
  if [[ "${VLESS_SNI_OWN,,}" == "y" ]]; then
    validate_dns "$VLESS_SNI" "VLESS+TLS SNI"
    issue_cert "$VLESS_SNI"
  fi

  # Nginx
  write_nginx_stream
  write_nginx_http
  test_nginx

  # Panel binary
  install_panel

  # systemd service (starts x-ui)
  install_service

  # REALITY keys (needs xray binary)
  gen_reality_keys

  # Database seeding
  seed_database

  # Restart x-ui with final config
  systemctl restart x-ui

  # Assets
  deploy_assets

  # Firewall
  configure_firewall

  # Cron
  setup_cron

  # Health checks
  final_health_check

  # Summary
  print_summary
}

# ============================================================
#  Entry point
# ============================================================
parse_args "$@"

if [[ "${ARG_UNINSTALL,,}" == "y" ]]; then
  check_root
  do_uninstall
elif [[ "${ARG_INSTALL,,}" == "y" ]] || [[ $# -eq 0 ]]; then
  do_install
else
  echo ""
  echo -e "Usage: bash shanutechx-install.sh [options]"
  echo ""
  echo "  -install y                  Run full installation"
  echo "  -panel_domain <domain>      Panel / subscription domain"
  echo "  -reality_domain <domain>    REALITY inbound SNI"
  echo "  -vless_sni <domain>         Normal VLESS+TLS camouflage SNI"
  echo "  -uninstall y                Remove everything cleanly"
  echo ""
  exit 0
fi
