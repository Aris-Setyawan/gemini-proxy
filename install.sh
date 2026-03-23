#!/bin/bash
# ============================================================
# Google Gemini OpenAI-Compatible Proxy — Installer
# Repo: https://github.com/Aris-Setyawan/gemini-proxy
# ============================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROXY_PORT="${PROXY_PORT:-9998}"
INSTALL_DIR="${INSTALL_DIR:-/opt/gemini-proxy}"
SERVICE_NAME="gemini-proxy"
PROXY_FILE="$INSTALL_DIR/proxy.py"

print_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║     Google Gemini Proxy — Installer      ║"
    echo "  ║   OpenAI-Compatible · Auto-start · Fast  ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[✗] Jalankan sebagai root: sudo bash install.sh${NC}"
        exit 1
    fi
}

check_deps() {
    echo -e "${CYAN}[→] Cek dependencies...${NC}"
    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}[!] python3 tidak ditemukan, install...${NC}"
        apt-get update -qq && apt-get install -y python3
    fi
    echo -e "${GREEN}[✓] python3 $(python3 --version)${NC}"
}

get_api_key() {
    echo ""
    echo -e "${BOLD}Masukkan Google Gemini API Key:${NC}"
    echo -e "${YELLOW}  → Dapatkan di: https://aistudio.google.com/app/apikey${NC}"
    echo ""
    read -rsp "  API Key: " GEMINI_API_KEY
    echo ""

    if [ -z "$GEMINI_API_KEY" ]; then
        echo -e "${RED}[✗] API key tidak boleh kosong${NC}"
        exit 1
    fi
    echo -e "${GREEN}[✓] API key diterima${NC}"
}

install_proxy() {
    echo -e "${CYAN}[→] Install proxy ke $INSTALL_DIR...${NC}"
    mkdir -p "$INSTALL_DIR"
    cp "$(dirname "$0")/proxy.py" "$PROXY_FILE" 2>/dev/null || \
        curl -fsSL "https://raw.githubusercontent.com/Aris-Setyawan/gemini-proxy/main/proxy.py" -o "$PROXY_FILE"
    chmod +x "$PROXY_FILE"
    echo -e "${GREEN}[✓] proxy.py terinstall${NC}"
}

create_service() {
    echo -e "${CYAN}[→] Buat systemd service...${NC}"
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Google Gemini OpenAI-Compatible Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${PROXY_FILE}
Restart=always
RestartSec=3
Environment=PROXY_PORT=${PROXY_PORT}
Environment=PROXY_HOST=127.0.0.1
Environment=GEMINI_API_KEY=${GEMINI_API_KEY}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}[✓] Service berjalan${NC}"
    else
        echo -e "${RED}[✗] Service gagal start, cek: journalctl -u $SERVICE_NAME${NC}"
        exit 1
    fi
}

save_config() {
    cat > "$INSTALL_DIR/.env" << EOF
PROXY_PORT=${PROXY_PORT}
PROXY_HOST=127.0.0.1
GEMINI_API_KEY=${GEMINI_API_KEY}
INSTALL_DIR=${INSTALL_DIR}
EOF
    chmod 600 "$INSTALL_DIR/.env"
    echo -e "${GREEN}[✓] Config tersimpan di $INSTALL_DIR/.env${NC}"
}

test_proxy() {
    echo -e "${CYAN}[→] Test koneksi proxy...${NC}"
    sleep 1
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "http://127.0.0.1:${PROXY_PORT}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${GEMINI_API_KEY}" \
        -d '{"model":"gemini-2.0-flash","messages":[{"role":"user","content":"ping"}],"max_tokens":5}' \
        --max-time 15 2>/dev/null)

    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}[✓] Proxy OK — HTTP 200${NC}"
    else
        echo -e "${YELLOW}[!] Response: HTTP $RESPONSE (cek API key atau koneksi)${NC}"
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║           Instalasi Selesai! ✓           ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Proxy URL:${NC}    http://127.0.0.1:${PROXY_PORT}"
    echo -e "  ${BOLD}Service:${NC}      systemctl {start|stop|status} ${SERVICE_NAME}"
    echo -e "  ${BOLD}Log:${NC}          journalctl -u ${SERVICE_NAME} -f"
    echo -e "  ${BOLD}Config:${NC}       ${INSTALL_DIR}/.env"
    echo ""
    echo -e "  ${BOLD}Contoh penggunaan (OpenAI SDK):${NC}"
    echo -e "  ${CYAN}  base_url = \"http://127.0.0.1:${PROXY_PORT}\""
    echo -e "  api_key  = \"YOUR_GEMINI_API_KEY\"${NC}"
    echo ""
    echo -e "  ${BOLD}Model yang didukung:${NC}"
    echo -e "  ${CYAN}  gemini-2.5-flash  gemini-2.0-flash  gemini-2.5-pro${NC}"
    echo ""
}

uninstall() {
    echo -e "${YELLOW}[!] Uninstall gemini-proxy...${NC}"
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -rf "$INSTALL_DIR"
    systemctl daemon-reload
    echo -e "${GREEN}[✓] Uninstall selesai${NC}"
}

update_key() {
    # Ambil key baru dari arg, stdin (pipe), atau interactive
    if [ -n "${2:-}" ]; then
        NEW_KEY="$2"
    elif [ ! -t 0 ]; then
        read -r NEW_KEY
    else
        echo -e "${BOLD}Masukkan Google Gemini API Key baru:${NC}"
        echo -e "${YELLOW}  → Dapatkan di: https://aistudio.google.com/app/apikey${NC}"
        echo ""
        read -rsp "  API Key baru: " NEW_KEY
        echo ""
    fi

    if [ -z "$NEW_KEY" ]; then
        echo -e "${RED}[✗] API key tidak boleh kosong${NC}"
        exit 1
    fi

    echo -e "${CYAN}[→] Update API key...${NC}"

    # 1. Update .env
    if [ -f "$INSTALL_DIR/.env" ]; then
        sed -i "s|^GEMINI_API_KEY=.*|GEMINI_API_KEY=${NEW_KEY}|" "$INSTALL_DIR/.env"
        echo -e "${GREEN}[✓] $INSTALL_DIR/.env${NC}"
    fi

    # 2. Update systemd service Environment
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    if [ -f "$SERVICE_FILE" ]; then
        sed -i "s|Environment=GEMINI_API_KEY=.*|Environment=GEMINI_API_KEY=${NEW_KEY}|" "$SERVICE_FILE"
        systemctl daemon-reload
        systemctl restart "$SERVICE_NAME"
        echo -e "${GREEN}[✓] systemd service restarted${NC}"
    fi

    # 3. Update openclaw.json (semua user yang punya file ini)
    for OC_JSON in /root/.openclaw/openclaw.json /home/*/.openclaw/openclaw.json; do
        [ -f "$OC_JSON" ] || continue
        python3 -c "
import json, sys
path = '$OC_JSON'
d = json.load(open(path))
providers = d.get('models', {}).get('providers', {})
changed = False
for pname, pconf in providers.items():
    if 'gemini' in pname.lower() or '9998' in str(pconf.get('baseUrl','')):
        if pconf.get('apiKey','').startswith('AIzaSy'):
            pconf['apiKey'] = '$NEW_KEY'
            changed = True
if changed:
    json.dump(d, open(path, 'w'), indent=2)
    print('  updated: ' + path)
" 2>/dev/null && echo -e "${GREEN}[✓] $OC_JSON${NC}"
    done

    # 4. Update auth-profiles.json (semua agent)
    for AUTH in /root/.openclaw/agents/*/agent/auth-profiles.json /home/*/.openclaw/agents/*/agent/auth-profiles.json; do
        [ -f "$AUTH" ] || continue
        python3 -c "
import json
path = '$AUTH'
d = json.load(open(path))
changed = False
for k, v in d.get('profiles', {}).items():
    if v.get('provider') == 'google' or 'google' in k:
        if v.get('key','').startswith('AIzaSy') or v.get('Authorization','').startswith('Bearer AIzaSy'):
            v['key'] = '$NEW_KEY'
            if 'Authorization' in v:
                v['Authorization'] = 'Bearer $NEW_KEY'
            changed = True
if changed:
    json.dump(d, open(path, 'w'), indent=2)
    print('  updated: ' + path)
" 2>/dev/null && echo -e "${GREEN}[✓] $AUTH${NC}"
    done

    echo ""
    echo -e "${GREEN}${BOLD}[✓] API key berhasil diupdate!${NC}"
    echo -e "  Key baru: ${CYAN}${NEW_KEY:0:12}...${NC}"
    echo -e "  Proxy   : systemctl status $SERVICE_NAME"
}

# Main
case "${1:-}" in
    uninstall) check_root; uninstall ;;
    update-key) check_root; update_key "$@" ;;
    *)
        print_banner
        check_root
        check_deps
        get_api_key
        install_proxy
        create_service
        save_config
        test_proxy
        print_summary
        ;;
esac
