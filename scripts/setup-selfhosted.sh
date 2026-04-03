#!/usr/bin/env bash
set -euo pipefail

SELFHOSTED_DIR="${HOME}/selfhosted"

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

setup_env_file() {
    if [[ ! -f "${SELFHOSTED_DIR}/.env" ]]; then
        if [[ -f "${SELFHOSTED_DIR}/.env.example" ]]; then
            cp "${SELFHOSTED_DIR}/.env.example" "${SELFHOSTED_DIR}/.env"
            log_warn ".env created from template — edit ${SELFHOSTED_DIR}/.env before starting services"
        else
            log_warn "No .env.example found — create ${SELFHOSTED_DIR}/.env manually"
        fi
    else
        log_info ".env already exists, skipping"
    fi
}

setup_element_config() {
    local config_file="${SELFHOSTED_DIR}/element-config.json"
    if [[ -f "$config_file" ]] && grep -q "DOMAIN_PLACEHOLDER" "$config_file"; then
        if [[ -f "${SELFHOSTED_DIR}/.env" ]]; then
            local domain
            domain=$(grep '^DOMAIN=' "${SELFHOSTED_DIR}/.env" | cut -d= -f2)
            if [[ -n "$domain" && "$domain" != "example.com" ]]; then
                sed -i.bak "s/DOMAIN_PLACEHOLDER/${domain}/g" "$config_file"
                rm -f "${config_file}.bak"
                log_info "Element config updated with domain: $domain"
            else
                log_warn "Set DOMAIN in .env, then re-run to configure Element"
            fi
        fi
    fi
}

setup_tailscale() {
    if command -v tailscale &>/dev/null; then
        if ! tailscale status &>/dev/null 2>&1; then
            log_info "Tailscale installed but not connected"
            log_warn "Run 'sudo tailscale up' to connect to your tailnet"
        else
            log_success "Tailscale is connected"
        fi
    else
        log_warn "Tailscale not found — install it via the profile packages"
    fi
}

disable_systemd_resolved() {
    # AdGuard Home needs port 53, which conflicts with systemd-resolved
    if ! command -v systemctl &>/dev/null; then
        return
    fi

    if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        log_info "systemd-resolved not running, no DNS conflict"
        return
    fi

    log_info "Disabling systemd-resolved stub listener for AdGuard Home..."

    # Disable the stub listener but keep resolved for fallback
    local resolved_conf="/etc/systemd/resolved.conf"
    if ! grep -q "^DNSStubListener=no" "$resolved_conf" 2>/dev/null; then
        sudo sed -i.bak 's/^#\?DNSStubListener=.*/DNSStubListener=no/' "$resolved_conf"
        # If the line didn't exist, append it
        if ! grep -q "^DNSStubListener=no" "$resolved_conf"; then
            echo "DNSStubListener=no" | sudo tee -a "$resolved_conf" >/dev/null
        fi
    fi

    sudo systemctl restart systemd-resolved

    # Point resolv.conf to a real upstream (AdGuard will take over once running)
    if [[ -L /etc/resolv.conf ]]; then
        sudo rm /etc/resolv.conf
        echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf >/dev/null
        echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf >/dev/null
    fi

    log_success "systemd-resolved stub listener disabled"
}

create_data_dirs() {
    local env_file="${SELFHOSTED_DIR}/.env"
    local dirs=()

    # Read data paths from .env, with defaults
    local immich_path
    immich_path=$(grep '^IMMICH_UPLOAD_PATH=' "$env_file" 2>/dev/null | cut -d= -f2)
    dirs+=("${immich_path:-/data/immich/uploads}")

    local paperless_path
    paperless_path=$(grep '^PAPERLESS_CONSUME_PATH=' "$env_file" 2>/dev/null | cut -d= -f2)
    dirs+=("${paperless_path:-/data/paperless/consume}")

    local nextcloud_path
    nextcloud_path=$(grep '^NEXTCLOUD_DATA_PATH=' "$env_file" 2>/dev/null | cut -d= -f2)
    dirs+=("${nextcloud_path:-/data/nextcloud}")

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating data directory: $dir"
            sudo mkdir -p "$dir"
            sudo chown "$(id -u):$(id -g)" "$dir"
        fi
    done
}

validate_env() {
    local env_file="${SELFHOSTED_DIR}/.env"
    local has_errors=false

    if [[ ! -f "$env_file" ]]; then
        log_warn "No .env file found — run setup first"
        return 1
    fi

    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        if [[ "$value" == "CHANGE_ME"* || "$value" == "example.com" ]]; then
            log_warn "  $key needs to be configured"
            has_errors=true
        fi
    done < "$env_file"

    if [[ "$has_errors" == true ]]; then
        log_warn "Edit ${env_file} before starting services"
        return 1
    fi

    log_success "Environment configuration looks good"
    return 0
}

main() {
    log_info "Setting up self-hosted services..."

    setup_env_file
    setup_element_config
    setup_tailscale
    disable_systemd_resolved
    create_data_dirs

    if validate_env; then
        log_info "Ready to start services:"
        log_info "  cd ${SELFHOSTED_DIR} && docker compose up -d"
    else
        log_info "After configuring .env:"
        log_info "  cd ${SELFHOSTED_DIR} && docker compose up -d"
    fi

    log_success "Self-hosted setup complete"
}

main "$@"
