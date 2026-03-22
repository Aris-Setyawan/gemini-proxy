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

# Main
case "${1:-}" in
    uninstall) check_root; uninstall ;;
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
