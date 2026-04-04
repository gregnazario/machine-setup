#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

gpg_import() {
    local keyfile="${1:-}"
    if [[ -z "$keyfile" || ! -f "$keyfile" ]]; then
        log_error "Usage: $0 import <keyfile.asc>"
        return 1
    fi

    log_info "Importing GPG key from: $keyfile"
    gpg --import "$keyfile" 2>&1

    local key_id
    key_id=$(gpg --show-keys --with-colons "$keyfile" 2>/dev/null | grep "^pub" | cut -d: -f5 | tail -1)

    if [[ -n "$key_id" ]]; then
        log_success "Imported key: $key_id"

        if command -v git-crypt &>/dev/null; then
            log_info "Adding key to git-crypt..."
            (cd "$REPO_DIR" && git-crypt add-gpg-user "$key_id") || {
                log_warn "Could not add to git-crypt (may already be added or repo not initialized)"
            }
        fi
    fi
}

gpg_export() {
    local output="${1:-}"
    local key_id
    key_id=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep "^sec" | head -1 | cut -d: -f5)

    if [[ -z "$key_id" ]]; then
        log_error "No secret GPG key found"
        return 1
    fi

    if [[ -n "$output" ]]; then
        gpg --armor --export "$key_id" > "$output"
        log_success "Public key exported to: $output"
    else
        gpg --armor --export "$key_id"
    fi
}

gpg_list() {
    log_info "GPG keys (secret keys available):"
    echo ""
    gpg --list-secret-keys --keyid-format long 2>/dev/null || {
        log_warn "No secret keys found"
    }

    if command -v git-crypt &>/dev/null && [[ -d "$REPO_DIR/.git" ]]; then
        echo ""
        log_info "git-crypt status:"
        (cd "$REPO_DIR" && git-crypt status -e 2>/dev/null | head -20) || {
            log_info "git-crypt not initialized in this repo"
        }
    fi
}

gpg_status() {
    echo ""
    echo "============================================"
    echo "  GPG Key Status"
    echo "============================================"
    echo ""

    # Check if gpg is available
    if ! command -v gpg &>/dev/null; then
        log_error "gpg not installed"
        return 1
    fi
    log_success "gpg: installed ($(gpg --version | head -1))"

    # Check for secret keys
    local secret_count
    secret_count=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep -c "^sec" || true)
    if [[ "$secret_count" -gt 0 ]]; then
        log_success "Secret keys: $secret_count found"

        # Show expiry of first key
        local expiry
        expiry=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep "^sec" | head -1 | cut -d: -f7)
        if [[ -n "$expiry" && "$expiry" != "0" ]]; then
            local expiry_date
            expiry_date=$(date -d "@$expiry" +%Y-%m-%d 2>/dev/null || date -r "$expiry" +%Y-%m-%d 2>/dev/null || echo "unknown")
            log_info "Primary key expires: $expiry_date"
        else
            log_info "Primary key: no expiry"
        fi
    else
        log_warn "No secret keys found"
    fi

    # Check git-crypt
    if command -v git-crypt &>/dev/null; then
        log_success "git-crypt: installed"
        if [[ -d "$REPO_DIR/.git-crypt" ]]; then
            log_success "git-crypt: initialized in repo"
        else
            log_warn "git-crypt: not initialized (run: git-crypt init)"
        fi
    else
        log_warn "git-crypt: not installed"
    fi

    echo ""
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        import)
            gpg_import "$@"
            ;;
        export)
            local output=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --output|-o) output="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            gpg_export "$output"
            ;;
        list)
            gpg_list
            ;;
        status)
            gpg_status
            ;;
        *)
            echo "Usage: $0 <import|export|list|status>"
            echo ""
            echo "Commands:"
            echo "  import <keyfile>           Import a GPG key and add to git-crypt"
            echo "  export [--output <file>]   Export public GPG key"
            echo "  list                       List GPG keys and git-crypt status"
            echo "  status                     Show GPG key status and expiry"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
