#!/usr/bin/env bats

setup() {
    load '../test_helper'

    # Source common.sh for log helpers
    _COMMON_SH_LOADED=
    source "$REPO_ROOT/scripts/lib/common.sh"

    # Create isolated temp directories
    TEST_TMPDIR="$(mktemp -d)"
    export HOME="$TEST_TMPDIR/home"
    mkdir -p "$HOME"

    export SELFHOSTED_DIR="$TEST_TMPDIR/selfhosted"
    mkdir -p "$SELFHOSTED_DIR"

    # Create mock bin directory and add to PATH
    MOCK_BIN="$TEST_TMPDIR/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Mock sudo to just run the command
    cat > "$MOCK_BIN/sudo" <<'SCRIPT'
#!/usr/bin/env bash
"$@"
SCRIPT
    chmod +x "$MOCK_BIN/sudo"

    # Define functions under test inline (script has no main guard)
    # These mirror the functions in setup-selfhosted.sh, using SELFHOSTED_DIR env var.

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
    export -f setup_env_file

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
    export -f setup_element_config

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
    export -f setup_tailscale

    create_data_dirs() {
        local env_file="${SELFHOSTED_DIR}/.env"
        local dirs=()
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
    export -f create_data_dirs

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
    export -f validate_env
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ── Script existence ──

@test "setup-selfhosted.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/setup-selfhosted.sh" ]
}

# ── setup_env_file ──

@test "setup_env_file creates .env from .env.example" {
    cat > "$SELFHOSTED_DIR/.env.example" <<'EOF'
DOMAIN=example.com
SECRET=CHANGE_ME
EOF

    run setup_env_file
    assert_success
    assert_output --partial ".env created from template"
    assert [ -f "$SELFHOSTED_DIR/.env" ]
    # Content should match the template
    run diff "$SELFHOSTED_DIR/.env.example" "$SELFHOSTED_DIR/.env"
    assert_success
}

@test "setup_env_file skips if .env already exists" {
    echo "DOMAIN=mine.example.com" > "$SELFHOSTED_DIR/.env"

    run setup_env_file
    assert_success
    assert_output --partial ".env already exists, skipping"
}

# ── setup_element_config ──

@test "setup_element_config replaces DOMAIN_PLACEHOLDER with domain from .env" {
    echo 'DOMAIN=myhost.net' > "$SELFHOSTED_DIR/.env"
    cat > "$SELFHOSTED_DIR/element-config.json" <<'EOF'
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://DOMAIN_PLACEHOLDER"
        }
    }
}
EOF

    run setup_element_config
    assert_success
    assert_output --partial "Element config updated with domain: myhost.net"

    run cat "$SELFHOSTED_DIR/element-config.json"
    assert_output --partial "https://myhost.net"
    refute_output --partial "DOMAIN_PLACEHOLDER"
}

@test "setup_element_config warns if domain is example.com" {
    echo 'DOMAIN=example.com' > "$SELFHOSTED_DIR/.env"
    cat > "$SELFHOSTED_DIR/element-config.json" <<'EOF'
{ "url": "https://DOMAIN_PLACEHOLDER" }
EOF

    run setup_element_config
    assert_success
    assert_output --partial "Set DOMAIN in .env"
}

# ── validate_env ──

@test "validate_env fails when values contain CHANGE_ME" {
    cat > "$SELFHOSTED_DIR/.env" <<'EOF'
DOMAIN=real.example.net
DB_PASSWORD=CHANGE_ME
SECRET_KEY=CHANGE_ME_NOW
EOF

    run validate_env
    assert_failure
    assert_output --partial "DB_PASSWORD needs to be configured"
    assert_output --partial "SECRET_KEY needs to be configured"
}

@test "validate_env passes with real-looking values" {
    cat > "$SELFHOSTED_DIR/.env" <<'EOF'
DOMAIN=myhost.net
DB_PASSWORD=supersecret123
SECRET_KEY=abc123xyz
EOF

    run validate_env
    assert_success
    assert_output --partial "Environment configuration looks good"
}

# ── setup_tailscale ──

@test "setup_tailscale warns when tailscale not installed" {
    # Ensure tailscale is not on PATH (mock bin has no tailscale)
    run setup_tailscale
    assert_success
    assert_output --partial "Tailscale not found"
}

# ── create_data_dirs ──

@test "create_data_dirs creates directories from .env paths" {
    local data_root="$TEST_TMPDIR/data"
    cat > "$SELFHOSTED_DIR/.env" <<EOF
IMMICH_UPLOAD_PATH=${data_root}/immich/uploads
PAPERLESS_CONSUME_PATH=${data_root}/paperless/consume
NEXTCLOUD_DATA_PATH=${data_root}/nextcloud
EOF

    run create_data_dirs
    assert_success
    assert [ -d "${data_root}/immich/uploads" ]
    assert [ -d "${data_root}/paperless/consume" ]
    assert [ -d "${data_root}/nextcloud" ]
}
