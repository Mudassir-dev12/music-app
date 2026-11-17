#!/usr/bin/env bash
# deploy/install.sh - Melodia VPS installation script
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/lib.sh
source "${SCRIPT_DIR}/lib.sh"

DOMAIN=""
EMAIL=""
PORT=8610
USER="melodia"
ROOT="/var/www/music-app"
CREATE_ENV=0
CREATE_VENV=0
APPLY=0
RENDER_ONLY=""

usage() {
    cat <<EOF
Usage: sudo bash deploy/install.sh --domain DOMAIN --email EMAIL [OPTIONS]

Options:
  --domain DOMAIN       Subdomain for Melodia API (e.g. music-api.example.com)
  --email EMAIL         Contact email for Let's Encrypt / TLS certificate
  --port PORT           Local backend port (default: 8610)
  --user USER           System user for the backend service (default: melodia)
  --root DIR            Repository root path (default: /var/www/music-app)
  --create-env          Generate production backend/.env if missing
  --create-venv         Create backend/.venv if missing
  --render-only DIR     Render all templates into DIR without modifying system
  --apply               Execute changes (default is dry-run)
  -h, --help            Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) DOMAIN="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --user) USER="$2"; shift 2 ;;
        --root) ROOT="$2"; shift 2 ;;
        --create-env) CREATE_ENV=1; shift ;;
        --create-venv) CREATE_VENV=1; shift ;;
        --render-only) RENDER_ONLY="$2"; shift 2 ;;
        --apply) APPLY=1; shift ;;
        -h|--help) usage ;;
        *) log_err "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "${DOMAIN}" && -z "${RENDER_ONLY}" ]]; then
    log_err "--domain is required (or use --render-only DIR)"
    exit 1
fi
if [[ -z "${EMAIL}" && -z "${RENDER_ONLY}" ]]; then
    log_err "--email is required (or use --render-only DIR)"
    exit 1
fi

if [[ -n "${RENDER_ONLY}" ]]; then
    MANIFEST_FILE="${RENDER_ONLY}/manifest"
    mkdir -p "${RENDER_ONLY}"
else
    MANIFEST_FILE="${ROOT}/deploy/.installed.manifest"
fi

# Track files created during this run for rollback if needed
CREATED_FILES=()

cleanup_on_failure() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 && "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
        log_warn "Installation failed. Cleaning up newly created files..."
        for f in "${CREATED_FILES[@]}"; do
            if [[ -f "${f}" || -L "${f}" ]]; then
                rm -f "${f}"
                log_info "Removed: ${f}"
            fi
        done
    fi
}
trap cleanup_on_failure EXIT

# ==========================================================
# 1. Checks (Read-only)
# ==========================================================
log_info "Step 1: Running pre-flight system checks..."

if [[ "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
    if [[ "${EUID}" -ne 0 ]]; then
        log_err "install.sh with --apply must be run as root (or via sudo)."
        exit 1
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        log_err "systemd is required but systemctl was not found."
        exit 1
    fi
fi

VENV_PYTHON="${ROOT}/backend/.venv/bin/python"
if [[ ! -x "${VENV_PYTHON}" && -x "${ROOT}/backend/.venv/Scripts/python.exe" ]]; then
    VENV_PYTHON="${ROOT}/backend/.venv/Scripts/python.exe"
fi

if [[ ! -x "${VENV_PYTHON}" && -z "${RENDER_ONLY}" ]]; then
    if [[ "${CREATE_VENV}" -eq 1 && "${APPLY}" -eq 1 ]]; then
        log_info "Creating virtual environment at ${ROOT}/backend/.venv..."
        python3 -m venv "${ROOT}/backend/.venv"
        "${ROOT}/backend/.venv/bin/pip" install -U pip
        "${ROOT}/backend/.venv/bin/pip" install -r "${ROOT}/backend/requirements.txt"
    else
        log_err "Virtualenv python not found at ${VENV_PYTHON}."
        echo "Please create it first by running:" >&2
        echo "  cd ${ROOT}/backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
        echo "Or pass --create-venv to install.sh." >&2
        exit 1
    fi
fi

# Port check
if is_port_in_use "${PORT}"; then
    NEW_PORT=$(find_free_port "$((PORT + 1))")
    log_warn "Port ${PORT} is currently in use. Selecting free port: ${NEW_PORT}"
    PORT="${NEW_PORT}"
else
    log_info "Port ${PORT} is free."
fi

# Domain DNS resolution
if [[ -n "${DOMAIN}" ]]; then
    RESOLVED_IP=$(check_domain_resolves "${DOMAIN}")
    if [[ -n "${RESOLVED_IP}" ]]; then
        log_info "Domain ${DOMAIN} resolves to: ${RESOLVED_IP}"
    else
        log_warn "Domain ${DOMAIN} does not yet resolve to an IP via DNS."
        log_warn "Ensure your DNS A/AAAA record is configured before running Certbot."
    fi
fi

# ==========================================================
# 2. Discovery
# ==========================================================
log_info "Step 2: Detecting environment and services..."
WEB_SERVER=$(detect_web_server)
log_info "Detected web server: ${WEB_SERVER}"

HAVE_CERTBOT=0
if command -v certbot >/dev/null 2>&1; then
    HAVE_CERTBOT=1
    log_info "Certbot detected: $(command -v certbot)"
else
    log_warn "Certbot not found. Let's Encrypt TLS setup will be skipped until certbot is installed."
fi

NODE_DIR=$(detect_js_runtime)
if [[ -n "${NODE_DIR}" ]]; then
    log_info "JavaScript runtime detected in: ${NODE_DIR}"
else
    log_info "No separate Node/Deno/Bun runtime detected in PATH (yt-dlp will use default python environment)."
fi

# ==========================================================
# 3. System User
# ==========================================================
log_info "Step 3: Ensuring system user '${USER}'..."
if [[ "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
    if ! id -u "${USER}" >/dev/null 2>&1; then
        log_info "Creating system user '${USER}'..."
        useradd --system --no-create-home --shell /usr/sbin/nologin "${USER}" 2>/dev/null || \
        useradd --system --no-create-home --shell /bin/false "${USER}"
    else
        log_info "System user '${USER}' already exists."
    fi
else
    log_plan "Would ensure system user '${USER}' exists (nologin, system account)"
fi

# ==========================================================
# 4. Project Directory Ownership & Permissions
# ==========================================================
log_info "Step 4: Setting up runtime directories and permissions..."
DIRS_TO_PREPARE=(
    "${ROOT}/data"
    "${ROOT}/backups"
    "${ROOT}/.tmp"
    "${ROOT}/.home"
    "${ROOT}/.cache"
)

for d in "${DIRS_TO_PREPARE[@]}"; do
    if [[ -n "${RENDER_ONLY}" ]]; then
        mkdir -p "${RENDER_ONLY}${d}"
    elif [[ "${APPLY}" -eq 1 ]]; then
        mkdir -p "${d}"
        chown -R "${USER}:${USER}" "${d}"
        chmod 700 "${d}"
        log_info "Configured directory: ${d} (owner: ${USER}, mode: 700)"
    else
        log_plan "Would create and set permissions for: ${d} (owner: ${USER}, mode: 700)"
    fi
done

# ==========================================================
# 5. Production Environment Configuration (.env)
# ==========================================================
log_info "Step 5: Configuring backend/.env..."
ENV_FILE="${ROOT}/backend/.env"
ENV_TMPL="${SCRIPT_DIR}/templates/env.production.tmpl"

if [[ -n "${RENDER_ONLY}" ]]; then
    render_template "${ENV_TMPL}" "${RENDER_ONLY}/backend/.env" \
        "PORT=${PORT}" \
        "ROOT=${ROOT}" \
        "APP_JWT_SECRET=GENERATED_SECRET_PLACEHOLDER_32_CHARS"
elif [[ ! -f "${ENV_FILE}" ]]; then
    if [[ "${CREATE_ENV}" -eq 1 ]]; then
        if [[ "${APPLY}" -eq 1 ]]; then
            RANDOM_SECRET=$("${VENV_PYTHON}" -c "import secrets; print(secrets.token_urlsafe(48))" 2>/dev/null || python3 -c "import secrets; print(secrets.token_urlsafe(48))")
            render_template "${ENV_TMPL}" "${ENV_FILE}" \
                "PORT=${PORT}" \
                "ROOT=${ROOT}" \
                "APP_JWT_SECRET=${RANDOM_SECRET}"
            chown "root:${USER}" "${ENV_FILE}"
            chmod 640 "${ENV_FILE}"
            log_info "Created ${ENV_FILE} with generated APP_JWT_SECRET (mode 640, root:${USER})"
        else
            log_plan "Would generate ${ENV_FILE} from template with strong APP_JWT_SECRET"
        fi
    else
        log_warn "${ENV_FILE} does not exist. Run with --create-env to generate it, or create it manually."
    fi
else
    log_info "${ENV_FILE} already exists. Leaving intact."
fi

# ==========================================================
# 6. Render & Install Systemd Units
# ==========================================================
log_info "Step 6: Configuring systemd service and timer..."
SYSTEMD_DEST="/etc/systemd/system"
if [[ -n "${RENDER_ONLY}" ]]; then
    SYSTEMD_DEST="${RENDER_ONLY}/etc/systemd/system"
fi

render_template "${SCRIPT_DIR}/templates/melodia-backend.service.tmpl" \
    "${SYSTEMD_DEST}/melodia-backend.service" \
    "ROOT=${ROOT}" \
    "USER=${USER}" \
    "PORT=${PORT}" \
    "NODE_DIR=${NODE_DIR}"
CREATED_FILES+=("${SYSTEMD_DEST}/melodia-backend.service")

render_template "${SCRIPT_DIR}/templates/melodia-health.service.tmpl" \
    "${SYSTEMD_DEST}/melodia-health.service" \
    "ROOT=${ROOT}" \
    "PORT=${PORT}"
CREATED_FILES+=("${SYSTEMD_DEST}/melodia-health.service")

render_template "${SCRIPT_DIR}/templates/melodia-health.timer.tmpl" \
    "${SYSTEMD_DEST}/melodia-health.timer"
CREATED_FILES+=("${SYSTEMD_DEST}/melodia-health.timer")

if [[ "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
    systemctl daemon-reload
    systemctl enable --now melodia-backend
    systemctl enable --now melodia-health.timer
    log_info "Enabled and started melodia-backend.service and melodia-health.timer"

    # Wait up to 30s for /health to respond
    log_info "Waiting for backend /health endpoint on 127.0.0.1:${PORT}..."
    HEALTH_OK=0
    for i in {1..30}; do
        if curl -fsS -m 2 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
            HEALTH_OK=1
            break
        fi
        sleep 1
    done

    if [[ "${HEALTH_OK}" -eq 1 ]]; then
        log_info "Backend service is healthy!"
    else
        log_err "Backend service failed to become healthy within 30 seconds."
        echo "Recent journal entries for melodia-backend:" >&2
        journalctl -u melodia-backend -n 40 --no-pager >&2
        exit 1
    fi
fi

# ==========================================================
# 7. Web Server Configuration (Nginx)
# ==========================================================
log_info "Step 7: Configuring web server..."

if [[ "${WEB_SERVER}" == "nginx" || -n "${RENDER_ONLY}" ]]; then
    NGINX_CONF_D="/etc/nginx/conf.d"
    NGINX_SITES_AVAIL="/etc/nginx/sites-available"
    NGINX_SITES_ENAB="/etc/nginx/sites-enabled"

    if [[ -n "${RENDER_ONLY}" ]]; then
        NGINX_CONF_D="${RENDER_ONLY}/etc/nginx/conf.d"
        NGINX_SITES_AVAIL="${RENDER_ONLY}/etc/nginx/sites-available"
        NGINX_SITES_ENAB="${RENDER_ONLY}/etc/nginx/sites-enabled"
        mkdir -p "${NGINX_CONF_D}" "${NGINX_SITES_AVAIL}" "${NGINX_SITES_ENAB}"
    fi

    # 1. Limits file in conf.d
    render_template "${SCRIPT_DIR}/templates/nginx-limits.conf.tmpl" \
        "${NGINX_CONF_D}/melodia-limits.conf"
    CREATED_FILES+=("${NGINX_CONF_D}/melodia-limits.conf")

    # 2. Site configuration
    SITE_CONF_FILE="${NGINX_SITES_AVAIL}/music-api.conf"
    if [[ ! -d "${NGINX_SITES_AVAIL}" && -d "${NGINX_CONF_D}" ]]; then
        # On CentOS / Fedora / some Nginx layouts without sites-available
        SITE_CONF_FILE="${NGINX_CONF_D}/music-api.conf"
    fi

    render_template "${SCRIPT_DIR}/templates/nginx-site.conf.tmpl" \
        "${SITE_CONF_FILE}" \
        "DOMAIN=${DOMAIN}" \
        "PORT=${PORT}"
    CREATED_FILES+=("${SITE_CONF_FILE}")

    # Symlink into sites-enabled if using Debian/Ubuntu layout
    if [[ -d "${NGINX_SITES_ENAB}" || -n "${RENDER_ONLY}" ]]; then
        safe_symlink "${SITE_CONF_FILE}" "${NGINX_SITES_ENAB}/music-api.conf"
        CREATED_FILES+=("${NGINX_SITES_ENAB}/music-api.conf")
    fi

    # Test Nginx configuration before reloading
    if [[ "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
        log_info "Testing Nginx configuration (nginx -t)..."
        if nginx -t; then
            log_info "Nginx test passed. Reloading Nginx (reload only, never restart)..."
            systemctl reload nginx
        else
            log_err "Nginx configuration test failed! Rolling back added files..."
            rm -f "${NGINX_CONF_D}/melodia-limits.conf"
            rm -f "${SITE_CONF_FILE}"
            rm -f "${NGINX_SITES_ENAB}/music-api.conf"
            exit 1
        fi
    fi
else
    log_warn "Nginx was not detected. Web server setup skipped."
    echo "Ready-to-use reverse proxy configuration for your web server:"
    echo "  Forward traffic for ${DOMAIN} to http://127.0.0.1:${PORT}"
    echo "  Ensure response buffering and request buffering are disabled for audio streaming."
fi

# ==========================================================
# 8. TLS Configuration (Certbot)
# ==========================================================
if [[ "${HAVE_CERTBOT}" -eq 1 && "${WEB_SERVER}" == "nginx" && "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
    log_info "Step 8: Obtaining TLS certificate via Certbot..."
    if certbot --nginx -d "${DOMAIN}" -m "${EMAIL}" --agree-tos --no-eff-email --redirect --non-interactive; then
        log_info "TLS certificate successfully obtained for ${DOMAIN}!"
    else
        log_warn "Certbot automated setup failed. Plain HTTP site remains active."
        log_warn "You can run Certbot manually once DNS propagates:"
        log_warn "  sudo certbot --nginx -d ${DOMAIN} -m ${EMAIL}"
    fi
elif [[ -z "${RENDER_ONLY}" ]]; then
    log_plan "Would configure TLS via certbot for ${DOMAIN} (${EMAIL})"
fi

# ==========================================================
# 9. Write Manifest
# ==========================================================
if [[ -n "${RENDER_ONLY}" || "${APPLY}" -eq 1 ]]; then
    log_info "Step 9: Writing installation manifest to ${MANIFEST_FILE}..."
    mkdir -p "$(dirname "${MANIFEST_FILE}")"
    for f in "${CREATED_FILES[@]}"; do
        echo "${f}" >> "${MANIFEST_FILE}"
    done
    # Sort and deduplicate
    sort -u "${MANIFEST_FILE}" -o "${MANIFEST_FILE}"
fi

# ==========================================================
# 10. Final Report
# ==========================================================
echo ""
echo "============================================================"
echo "          Melodia Backend Installation Plan/Report"
echo "============================================================"
echo "Service:             melodia-backend.service"
echo "Timer:               melodia-health.timer"
echo "Internal Port:       127.0.0.1:${PORT}"
echo "Public Domain:       https://${DOMAIN}"
echo "Health Endpoint:     https://${DOMAIN}/health"
echo "Ready Endpoint:      https://${DOMAIN}/ready"
echo ""
echo "Next Steps:"
echo "1. Create owner account:"
echo "   cd ${ROOT}/backend && sudo -u ${USER} ${VENV_PYTHON} -m app.tools.create_user --email you@example.com"
echo ""
echo "2. View logs in real-time:"
echo "   sudo journalctl -u melodia-backend -f"
echo ""
echo "3. Uninstall if needed:"
echo "   sudo bash ${ROOT}/deploy/uninstall.sh --apply"
echo "============================================================"
