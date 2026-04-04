#!/usr/bin/env bash
# Secrets orchestrator — pulls/pushes secrets between a password manager and
# local destinations defined in secrets.conf.
#
# Usage: secrets-manager.sh <action> [options]
#   Actions: pull, push, list, status, init, set-provider
#   Options:
#     --conf <path>   Path to secrets.conf (default: $REPO_DIR/secrets.conf)
#     --dry-run       Show what would happen without making changes

set -euo pipefail

# Resolve paths relative to this script
_SM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SM_REPO_DIR="${REPO_DIR:-$(cd "$_SM_SCRIPT_DIR/../.." && pwd)}"

# Source dependencies
# shellcheck source=../lib/common.sh
source "${_SM_REPO_DIR}/scripts/lib/common.sh"
# shellcheck source=../ini-parser.sh
source "${_SM_REPO_DIR}/scripts/ini-parser.sh"
# shellcheck source=secret-routing.sh
source "${_SM_SCRIPT_DIR}/secret-routing.sh"

# Provider scripts directory
PROVIDERS_DIR="${_SM_SCRIPT_DIR}/providers"

# Provider auto-detection order
PROVIDER_ORDER=("1password" "bitwarden" "keeper" "apple-keychain" "linux-keyring" "windows-credential")

###############################################################################
# detect_provider <conf_path>
#
# Reads [provider] name from conf, tries to source and check provider_available.
# If not configured, auto-detects by iterating PROVIDER_ORDER.
# Prints the provider name to stdout, or empty string if none found.
###############################################################################
detect_provider() {
    local conf_path="$1"

    # Check if provider is explicitly configured
    local configured_name=""
    if [[ -f "$conf_path" ]]; then
        configured_name="$(ini_get "$conf_path" "provider" "name" "")"
    fi

    if [[ -n "$configured_name" ]]; then
        local provider_script="${PROVIDERS_DIR}/${configured_name}.sh"
        if [[ -f "$provider_script" ]]; then
            # shellcheck disable=SC1090
            source "$provider_script"
            if type provider_available &>/dev/null && provider_available; then
                printf '%s' "$configured_name"
                return 0
            fi
        fi
        # Configured provider not available — fall through to empty
        printf ''
        return 0
    fi

    # Auto-detect: iterate providers in order
    for provider_name in "${PROVIDER_ORDER[@]}"; do
        local provider_script="${PROVIDERS_DIR}/${provider_name}.sh"
        [[ -f "$provider_script" ]] || continue
        # shellcheck disable=SC1090
        source "$provider_script"
        if type provider_available &>/dev/null && provider_available; then
            printf '%s' "$provider_name"
            return 0
        fi
    done

    # Nothing found
    printf ''
    return 0
}

###############################################################################
# load_secret_mappings <conf_path>
#
# Reads all [secret.*] section names from the conf file.
# Populates the SECRET_NAMES array.
###############################################################################
load_secret_mappings() {
    local conf_path="$1"
    SECRET_NAMES=()

    local sections
    sections="$(ini_get_sections "$conf_path")"

    while IFS= read -r section; do
        if [[ "$section" =~ ^secret\. ]]; then
            local name="${section#secret.}"
            SECRET_NAMES+=("$name")
        fi
    done <<< "$sections"
}

###############################################################################
# get_secret_config <conf_path> <name>
#
# Reads a [secret.<name>] section and sets global variables:
#   SECRET_PROVIDER_KEY, SECRET_DEST, SECRET_DEST_FILE, SECRET_DEST_SECTION,
#   SECRET_DEST_KEY, SECRET_DEST_VAR, SECRET_DEST_MODE
###############################################################################
get_secret_config() {
    local conf_path="$1"
    local name="$2"
    local section="secret.${name}"

    SECRET_PROVIDER_KEY="$(ini_get "$conf_path" "$section" "provider_key" "")"
    SECRET_DEST="$(ini_get "$conf_path" "$section" "dest" "")"
    SECRET_DEST_FILE="$(ini_get "$conf_path" "$section" "dest_file" "")"
    SECRET_DEST_SECTION="$(ini_get "$conf_path" "$section" "dest_section" "")"
    SECRET_DEST_KEY="$(ini_get "$conf_path" "$section" "dest_key" "")"
    SECRET_DEST_VAR="$(ini_get "$conf_path" "$section" "dest_var" "")"
    SECRET_DEST_MODE="$(ini_get "$conf_path" "$section" "dest_mode" "0600")"
}

###############################################################################
# _resolve_dest_file <dest_file>
#
# Resolves relative dest_file paths against REPO_DIR.
###############################################################################
_resolve_dest_file() {
    local dest_file="$1"
    if [[ -z "$dest_file" ]]; then
        printf ''
        return
    fi
    # Expand leading tilde to $HOME
    local tilde="~"
    if [[ "$dest_file" == "${tilde}/"* ]]; then
        dest_file="${HOME}/${dest_file:2}"
    fi
    # Resolve relative paths against repo dir
    if [[ "$dest_file" != /* ]]; then
        dest_file="${_SM_REPO_DIR}/${dest_file}"
    fi
    printf '%s' "$dest_file"
}

###############################################################################
# _read_local_value <dest_type> <dest_file> <dest_section> <dest_key>
#
# Reads the current local value for a secret. Used by push and status.
# Prints the value to stdout. Returns 1 if not readable.
###############################################################################
_read_local_value() {
    local dest_type="$1"
    local dest_file="$2"
    local dest_section="$3"
    local dest_key="$4"

    case "$dest_type" in
        ini)
            local resolved
            resolved="$(_resolve_dest_file "$dest_file")"
            if [[ -f "$resolved" ]]; then
                ini_get "$resolved" "$dest_section" "$dest_key" ""
            else
                return 1
            fi
            ;;
        file)
            local resolved
            resolved="$(_resolve_dest_file "$dest_file")"
            if [[ -f "$resolved" ]]; then
                cat "$resolved"
            else
                return 1
            fi
            ;;
        env)
            # env destinations cannot be read back for push
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

###############################################################################
# pull_secrets <conf_path> [dry_run]
#
# Iterates mappings, calls provider_get_secret then route_secret for each.
# Tracks succeeded/failed/skipped counts. Prints summary. Returns 0 if no
# failures.
###############################################################################
pull_secrets() {
    local conf_path="$1"
    local dry_run="${2:-false}"

    load_secret_mappings "$conf_path"

    local succeeded=0
    local failed=0
    local skipped=0

    for name in "${SECRET_NAMES[@]}"; do
        get_secret_config "$conf_path" "$name"

        if [[ -z "$SECRET_PROVIDER_KEY" ]]; then
            log_warn "Secret '$name': no provider_key configured, skipping"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ -z "$SECRET_DEST" ]]; then
            log_warn "Secret '$name': no dest configured, skipping"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would pull '$name' (key='${SECRET_PROVIDER_KEY}') -> ${SECRET_DEST}"
            skipped=$((skipped + 1))
            continue
        fi

        # Fetch from provider
        local secret_value=""
        if ! secret_value="$(provider_get_secret "$SECRET_PROVIDER_KEY" 2>/dev/null)"; then
            log_error "Secret '$name': failed to fetch from provider"
            failed=$((failed + 1))
            continue
        fi

        # Route to destination
        if route_secret "$secret_value" "$SECRET_DEST" "$SECRET_DEST_FILE" \
            "$SECRET_DEST_SECTION" "$SECRET_DEST_KEY" "$SECRET_DEST_VAR" "$SECRET_DEST_MODE"; then
            log_success "Secret '$name': pulled successfully"
            succeeded=$((succeeded + 1))
        else
            log_error "Secret '$name': routing failed"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo "Pull complete: ${succeeded} succeeded, ${failed} failed, ${skipped} skipped"
    [[ "$failed" -eq 0 ]]
}

###############################################################################
# push_secrets <conf_path> [dry_run]
#
# Reverse: reads local values from dest files and pushes to provider.
# Only works for ini and file destinations.
###############################################################################
push_secrets() {
    local conf_path="$1"
    local dry_run="${2:-false}"

    load_secret_mappings "$conf_path"

    local succeeded=0
    local failed=0
    local skipped=0

    for name in "${SECRET_NAMES[@]}"; do
        get_secret_config "$conf_path" "$name"

        if [[ -z "$SECRET_PROVIDER_KEY" ]]; then
            log_warn "Secret '$name': no provider_key configured, skipping"
            skipped=$((skipped + 1))
            continue
        fi

        # env destinations cannot be pushed
        if [[ "$SECRET_DEST" == "env" ]]; then
            log_warn "Secret '$name': env destinations cannot be pushed, skipping"
            skipped=$((skipped + 1))
            continue
        fi

        # Read local value
        local local_value=""
        if ! local_value="$(_read_local_value "$SECRET_DEST" "$SECRET_DEST_FILE" \
            "$SECRET_DEST_SECTION" "$SECRET_DEST_KEY")"; then
            log_warn "Secret '$name': local value not readable, skipping"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ -z "$local_value" ]]; then
            log_warn "Secret '$name': local value is empty, skipping"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would push '$name' (key='${SECRET_PROVIDER_KEY}') from ${SECRET_DEST}"
            skipped=$((skipped + 1))
            continue
        fi

        # Push to provider
        if provider_store_secret "$SECRET_PROVIDER_KEY" "$local_value" 2>/dev/null; then
            log_success "Secret '$name': pushed successfully"
            succeeded=$((succeeded + 1))
        else
            log_error "Secret '$name': failed to push to provider"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo "Push complete: ${succeeded} succeeded, ${failed} failed, ${skipped} skipped"
    [[ "$failed" -eq 0 ]]
}

###############################################################################
# list_secrets <conf_path>
#
# Prints table of secret name, dest type, provider key.
###############################################################################
list_secrets() {
    local conf_path="$1"

    load_secret_mappings "$conf_path"

    printf '%-25s %-8s %s\n' "NAME" "DEST" "PROVIDER KEY"
    printf '%-25s %-8s %s\n' "----" "----" "------------"

    for name in "${SECRET_NAMES[@]}"; do
        get_secret_config "$conf_path" "$name"
        printf '%-25s %-8s %s\n' "$name" "$SECRET_DEST" "$SECRET_PROVIDER_KEY"
    done
}

###############################################################################
# secrets_status <conf_path>
#
# Prints table showing if each secret exists in provider and locally.
###############################################################################
secrets_status() {
    local conf_path="$1"

    load_secret_mappings "$conf_path"

    printf '%-25s %-10s %-10s %s\n' "NAME" "PROVIDER" "LOCAL" "DEST"
    printf '%-25s %-10s %-10s %s\n' "----" "--------" "-----" "----"

    for name in "${SECRET_NAMES[@]}"; do
        get_secret_config "$conf_path" "$name"

        # Check provider
        local provider_status="unknown"
        if type provider_get_secret &>/dev/null; then
            if provider_get_secret "$SECRET_PROVIDER_KEY" &>/dev/null; then
                provider_status="yes"
            else
                provider_status="no"
            fi
        fi

        # Check local
        local local_status="no"
        case "$SECRET_DEST" in
            ini|file)
                local resolved
                resolved="$(_resolve_dest_file "$SECRET_DEST_FILE")"
                if [[ -f "$resolved" ]]; then
                    local_status="yes"
                fi
                ;;
            env)
                local var_name="$SECRET_DEST_VAR"
                if [[ -n "${!var_name:-}" ]]; then
                    local_status="yes"
                fi
                ;;
        esac

        printf '%-25s %-10s %-10s %s\n' "$name" "$provider_status" "$local_status" "$SECRET_DEST"
    done
}

###############################################################################
# _usage
#
# Print usage information.
###############################################################################
_usage() {
    cat <<'USAGE'
Usage: secrets-manager.sh <action> [options]

Actions:
  pull           Fetch secrets from password manager to local destinations
  push           Push local secret values back to password manager
  list           List all configured secret mappings
  status         Show which secrets exist in provider and locally
  init           Create a secrets.conf from the example template
  set-provider   Set the provider in secrets.conf

Options:
  --conf <path>  Path to secrets.conf (default: $REPO_DIR/secrets.conf)
  --dry-run      Show what would happen without making changes
  --help, -h     Show this help message
USAGE
}

###############################################################################
# main <action> [...]
#
# CLI handler for pull/push/list/status/init/set-provider actions.
###############################################################################
main() {
    local action=""
    local conf_path="${_SM_REPO_DIR}/secrets.conf"
    local dry_run="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            pull|push|list|status|init|set-provider)
                action="$1"
                shift
                ;;
            --conf)
                conf_path="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                _usage
                return 0
                ;;
            *)
                # For set-provider, the next arg is the provider name
                if [[ "$action" == "set-provider" ]]; then
                    local provider_name="$1"
                    shift
                else
                    log_error "Unknown argument: $1"
                    _usage
                    return 1
                fi
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        _usage
        return 1
    fi

    case "$action" in
        pull)
            if [[ ! -f "$conf_path" ]]; then
                log_error "Config not found: ${conf_path}"
                log_info "Run 'secrets-manager.sh init' to create one from the template."
                return 1
            fi
            local provider
            provider="$(detect_provider "$conf_path")"
            if [[ -z "$provider" ]]; then
                log_error "No password manager provider available."
                return 1
            fi
            log_info "Using provider: ${provider}"
            if ! provider_authenticated; then
                provider_authenticate || { log_error "Authentication failed."; return 1; }
            fi
            pull_secrets "$conf_path" "$dry_run"
            ;;
        push)
            if [[ ! -f "$conf_path" ]]; then
                log_error "Config not found: ${conf_path}"
                return 1
            fi
            local provider
            provider="$(detect_provider "$conf_path")"
            if [[ -z "$provider" ]]; then
                log_error "No password manager provider available."
                return 1
            fi
            log_info "Using provider: ${provider}"
            if ! provider_authenticated; then
                provider_authenticate || { log_error "Authentication failed."; return 1; }
            fi
            push_secrets "$conf_path" "$dry_run"
            ;;
        list)
            if [[ ! -f "$conf_path" ]]; then
                log_error "Config not found: ${conf_path}"
                return 1
            fi
            list_secrets "$conf_path"
            ;;
        status)
            if [[ ! -f "$conf_path" ]]; then
                log_error "Config not found: ${conf_path}"
                return 1
            fi
            local provider
            provider="$(detect_provider "$conf_path")"
            if [[ -z "$provider" ]]; then
                log_error "No password manager provider available."
                return 1
            fi
            log_info "Using provider: ${provider}"
            if ! provider_authenticated; then
                provider_authenticate || { log_error "Authentication failed."; return 1; }
            fi
            secrets_status "$conf_path"
            ;;
        init)
            local example="${_SM_REPO_DIR}/secrets.conf.example"
            if [[ ! -f "$example" ]]; then
                log_error "Example config not found: ${example}"
                return 1
            fi
            if [[ -f "$conf_path" ]]; then
                log_warn "Config already exists: ${conf_path}"
                return 0
            fi
            cp "$example" "$conf_path"
            log_success "Created ${conf_path} from template. Edit it to configure your secrets."
            ;;
        set-provider)
            if [[ ! -f "$conf_path" ]]; then
                log_error "Config not found: ${conf_path}"
                return 1
            fi
            if [[ -z "${provider_name:-}" ]]; then
                log_error "Usage: secrets-manager.sh set-provider <name>"
                return 1
            fi
            # Validate provider name against known providers
            local valid_provider=false
            for p in "${PROVIDER_ORDER[@]}"; do
                if [[ "$p" == "$provider_name" ]]; then
                    valid_provider=true
                    break
                fi
            done
            if [[ "$valid_provider" != "true" ]]; then
                log_error "Unknown provider: ${provider_name}"
                log_info "Supported providers: ${PROVIDER_ORDER[*]}"
                return 1
            fi
            # Update or add [provider] section with the name
            if grep -q '^\[provider\]' "$conf_path"; then
                # Section exists — update or add the name key
                local current
                current="$(ini_get "$conf_path" "provider" "name" "")"
                if [[ -n "$current" ]]; then
                    sed -i.bak "/^\[provider\]/,/^\[/ s/^name = .*/name = ${provider_name}/" "$conf_path"
                    rm -f "${conf_path}.bak"
                else
                    sed -i.bak "/^\[provider\]/a\\
name = ${provider_name}" "$conf_path"
                    rm -f "${conf_path}.bak"
                fi
            else
                printf '\n[provider]\nname = %s\n' "$provider_name" >> "$conf_path"
            fi
            log_success "Provider set to: ${provider_name}"
            ;;
        *)
            log_error "Unknown action: $action"
            _usage
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
