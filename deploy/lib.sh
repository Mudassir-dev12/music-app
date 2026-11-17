#!/usr/bin/env bash
# deploy/lib.sh - Shared helpers for Melodia deploy kit
set -Eeuo pipefail

# ANSI colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APPLY=0
RENDER_ONLY=""
MANIFEST_FILE=""

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_plan() {
    echo -e "${BLUE}[PLAN]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_err() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Run a command only if APPLY=1, else print dry-run notice
run_cmd() {
    if [[ "${APPLY}" -eq 1 ]]; then
        "$@"
    else
        log_plan "Would execute: $*"
    fi
}

# Record an installed path into the manifest file
record_manifest() {
    local target="$1"
    if [[ -n "${MANIFEST_FILE}" ]]; then
        mkdir -p "$(dirname "${MANIFEST_FILE}")"
        echo "${target}" >> "${MANIFEST_FILE}"
    fi
}

# Pure-Bash template renderer
# Usage: render_template "path/to/tmpl" "path/to/dest" "KEY1=VAL1" "KEY2=VAL2" ...
render_template() {
    local tmpl="$1"
    local dest="$2"
    shift 2

    if [[ ! -f "${tmpl}" ]]; then
        log_err "Template file not found: ${tmpl}"
        return 1
    fi

    local content
    content=$(<"${tmpl}")

    for pair in "$@"; do
        local key="${pair%%=*}"
        local val="${pair#*=}"
        content="${content//\{\{${key}\}\}/$val}"
    done

    # Check for unreplaced template variables
    if [[ "${content}" =~ \{\{([a-zA-Z0-9_]+)\}\} ]]; then
        log_err "Unreplaced template variable in ${tmpl}: \${BASH_REMATCH[0]}"
        return 1
    fi

    if [[ -n "${RENDER_ONLY}" ]] || [[ "${APPLY}" -eq 1 ]]; then
        mkdir -p "$(dirname "${dest}")"
        printf '%s\n' "${content}" > "${dest}"
        record_manifest "${dest}"
    else
        log_plan "Would render template ${tmpl} -> ${dest}"
    fi
}

# Create a symlink safely and record in manifest
safe_symlink() {
    local src="$1"
    local dest="$2"

    if [[ -n "${RENDER_ONLY}" ]] || [[ "${APPLY}" -eq 1 ]]; then
        mkdir -p "$(dirname "${dest}")"
        ln -sf "${src}" "${dest}"
        record_manifest "${dest}"
    else
        log_plan "Would symlink ${src} -> ${dest}"
    fi
}

# Detect installed web server
detect_web_server() {
    if [[ -f "/etc/nginx/nginx.conf" ]] || command -v nginx >/dev/null 2>&1; then
        echo "nginx"
    elif command -v caddy >/dev/null 2>&1; then
        echo "caddy"
    elif command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
        echo "apache"
    elif command -v traefik >/dev/null 2>&1; then
        echo "traefik"
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"
    else
        echo "unknown"
    fi
}

# Detect JavaScript runtime for yt-dlp
detect_js_runtime() {
    local binary=""
    for bin in node deno bun; do
        if command -v "${bin}" >/dev/null 2>&1; then
            binary=$(command -v "${bin}")
            dirname "${binary}"
            return 0
        fi
    done
    echo ""
}

# Check if a port is in use
is_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep -q ":${port} " && return 0 || return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | grep -q ":${port} " && return 0 || return 1
    else
        # Python socket check fallback
        python3 -c "import socket; s = socket.socket(); s.connect(('127.0.0.1', ${port}))" 2>/dev/null && return 0 || return 1
    fi
}

# Find next free port starting from $1
find_free_port() {
    local port="$1"
    while is_port_in_use "${port}"; do
        port=$((port + 1))
    done
    echo "${port}"
}

# Check if domain resolves via DNS
check_domain_resolves() {
    local domain="$1"
    if command -v getent >/dev/null 2>&1; then
        getent hosts "${domain}" | awk '{print $1}' | head -n1
    elif command -v host >/dev/null 2>&1; then
        host "${domain}" | awk '/has address/ {print $4}' | head -n1
    elif command -v nslookup >/dev/null 2>&1; then
        nslookup "${domain}" 2>/dev/null | awk '/^Address: / {print $2}' | tail -n1
    else
        python3 -c "import socket; print(socket.gethostbyname('${domain}'))" 2>/dev/null || true
    fi
}
