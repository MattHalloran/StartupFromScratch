#!/usr/bin/env bash
# Utilities for managing the Caddy reverse proxy service.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${HERE}/logging.sh"
# shellcheck disable=SC1091
source "${HERE}/flow.sh"
# shellcheck disable=SC1091
source "${HERE}/system.sh"

CADDY_CONFIG_DIR="/etc/caddy"
CADDY_MAIN_CONFIG_FILE="${CADDY_CONFIG_DIR}/Caddyfile"
CADDY_SNIPPETS_DIR="${CADDY_CONFIG_DIR}/conf.d"
APP_CADDY_SNIPPET="${CADDY_SNIPPETS_DIR}/vrooli.caddy"

# Ensures the main Caddyfile imports snippets from conf.d
ensure_caddy_import_configured() {
    # Ensure the snippets directory exists so import works
    maybe_run_sudo mkdir -p "$CADDY_SNIPPETS_DIR"
    if [ ! -f "$CADDY_MAIN_CONFIG_FILE" ]; then
        info "Main Caddyfile ($CADDY_MAIN_CONFIG_FILE) does not exist. Creating with import directive."
        echo -e "import ${CADDY_SNIPPETS_DIR}/*.caddy" | maybe_run_sudo tee "$CADDY_MAIN_CONFIG_FILE" > /dev/null
        return
    fi

    if ! maybe_run_sudo grep -q "import ${CADDY_SNIPPETS_DIR}/\*.caddy" "$CADDY_MAIN_CONFIG_FILE"; then
        info "Adding import directive to $CADDY_MAIN_CONFIG_FILE"
        echo -e "\nimport ${CADDY_SNIPPETS_DIR}/*.caddy" | maybe_run_sudo tee -a "$CADDY_MAIN_CONFIG_FILE" > /dev/null
    else
        info "Caddyfile import directive already present."
    fi
}

# Generates a Caddyfile snippet for the application
# Usage: generate_caddy_snippet <domain> <target_port>
generate_caddy_snippet() {
    local domain="${1:?Domain argument required}"
    local target_port="${2:?Target port argument required}"

    # Ensure the snippets directory exists
    maybe_run_sudo mkdir -p "$CADDY_SNIPPETS_DIR"

    info "Generating Caddy snippet for ${domain} -> localhost:${target_port}"
    local snippet_content
    snippet_content=$(cat <<EOF
${domain} {
    reverse_proxy localhost:${target_port}
    # Optional: Add more directives here, like logging, headers, etc.
    # log {
    #   output file /var/log/caddy/${domain}.log
    # }
}
EOF
)

    echo "$snippet_content" | maybe_run_sudo tee "$APP_CADDY_SNIPPET" > /dev/null
    success "Generated Caddy snippet: $APP_CADDY_SNIPPET"
}

# Starts or reloads the Caddy service
start_or_reload_caddy() {
    ensure_caddy_import_configured

    info "Attempting to start/reload Caddy service..."
    if systemctl is-active --quiet caddy; then
        info "Caddy is active, attempting reload."
        # Validate config before reloading
        if maybe_run_sudo caddy validate --config "$CADDY_MAIN_CONFIG_FILE" --adapter caddyfile; then
            maybe_run_sudo systemctl reload caddy
            success "Caddy reloaded successfully."
        else
            exit_with_error "Caddy configuration validation failed. Check $APP_CADDY_SNIPPET and $CADDY_MAIN_CONFIG_FILE." "$ERROR_CONFIGURATION"
        fi
    else
        info "Caddy is not active, attempting start."
        maybe_run_sudo systemctl start caddy
        if systemctl is-active --quiet caddy; then
            success "Caddy started successfully."
        else
            exit_with_error "Failed to start Caddy service." "$ERROR_SERVICE_START_FAILED"
        fi
    fi
}

# Stops the Caddy service
stop_caddy_proxy() {
    info "Stopping Caddy service..."
    if systemctl is-active --quiet caddy; then
        maybe_run_sudo systemctl stop caddy
        success "Caddy stopped."
    else
        info "Caddy service was not running."
    fi
}

# Checks the status of the Caddy service
check_caddy_status() {
    if systemctl is-active --quiet caddy; then
        info "Caddy service is active."
        return 0
    else
        info "Caddy service is inactive."
        return 1
    fi
}

start_reverse_proxy() {
    local domain="${1:-}"
    local port="${2:-}"

    if [[ -z "$domain" ]]; then
        exit_with_error "Domain is required" "$ERROR_USAGE"
    fi
    if [[ -z "$port" ]]; then
        exit_with_error "Port is required" "$ERROR_USAGE"
    fi

    header "Starting reverse proxy for $domain:$port"
    ensure_caddy_import_configured
    generate_caddy_snippet "$domain" "$port"
    start_or_reload_caddy
    success "Reverse proxy started for $domain:$port"
}

stop_reverse_proxy() {
    header "Stopping reverse proxy"
    stop_caddy_proxy
    success "Reverse proxy stopped"
}

check_reverse_proxy_status() {
    check_caddy_status
}