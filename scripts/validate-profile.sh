#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/ini-parser.sh"

# Validate a profile's configuration
# Usage: validate-profile.sh --profile <name>

PROFILE_NAME=""

# Validate profile name to prevent path traversal
validate_name() {
    local name="$1"
    if [[ "$name" =~ [/\\] || "$name" == *..* || ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid profile name: '$name' (only alphanumeric, hyphens, underscores allowed)"
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                if [[ $# -lt 2 ]]; then
                    log_error "Missing value for --profile"
                    echo "Usage: $0 --profile <name>"
                    exit 1
                fi
                PROFILE_NAME="$2"
                validate_name "$PROFILE_NAME"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 --profile <name>"
                exit 1
                ;;
        esac
    done

    if [[ -z "$PROFILE_NAME" ]]; then
        log_error "No profile specified. Usage: $0 --profile <name>"
        exit 1
    fi
}

validate_profile() {
    local profile_name="$1"
    local profile_file="${SCRIPT_DIR}/../profiles/${profile_name}.conf"
    local errors=0
    local warnings=0

    log_info "Validating profile: ${profile_name}"

    # Check profile file exists
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: profiles/${profile_name}.conf"
        exit 1
    fi

    log_success "Profile file exists: profiles/${profile_name}.conf"

    # Check required fields: name
    local name
    name=$(ini_get "$profile_file" "profile" "name" "")
    if [[ -z "$name" ]]; then
        log_error "Required field missing: [profile] name"
        errors=$((errors + 1))
    else
        log_success "Required field present: name = ${name}"
    fi

    # Check required fields: description
    local description
    description=$(ini_get "$profile_file" "profile" "description" "")
    if [[ -z "$description" ]]; then
        log_error "Required field missing: [profile] description"
        errors=$((errors + 1))
    else
        log_success "Required field present: description = ${description}"
    fi

    # Check packages section is non-empty
    local has_packages=false
    local in_packages=false
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue
        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "packages" ]]; then
                in_packages=true
            elif [[ "$in_packages" == true ]]; then
                break
            fi
            continue
        fi
        if [[ "$in_packages" == true && "$line" =~ ^[^=]+=.+$ ]]; then
            has_packages=true
            break
        fi
    done < "$profile_file"

    # Also check parent profile if extends is set
    local extends
    extends=$(ini_get "$profile_file" "profile" "extends" "false")
    if [[ "$has_packages" == false && "$extends" != "false" && -n "$extends" ]]; then
        local base_file="${SCRIPT_DIR}/../profiles/${extends}.conf"
        if [[ -f "$base_file" ]]; then
            local base_in_packages=false
            while IFS= read -r line; do
                [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue
                if [[ "$line" =~ ^\[([^]]+)\] ]]; then
                    if [[ "${BASH_REMATCH[1]}" == "packages" ]]; then
                        base_in_packages=true
                    elif [[ "$base_in_packages" == true ]]; then
                        break
                    fi
                    continue
                fi
                if [[ "$base_in_packages" == true && "$line" =~ ^[^=]+=.+$ ]]; then
                    has_packages=true
                    break
                fi
            done < "$base_file"
        fi
    fi

    if [[ "$has_packages" == false ]]; then
        log_error "No packages defined in [packages] section"
        errors=$((errors + 1))
    else
        log_success "Packages section is non-empty"
    fi

    # Check dotfiles source directory exists
    local dotfiles_source
    dotfiles_source=$(ini_get "$profile_file" "dotfiles" "source" "")
    if [[ -n "$dotfiles_source" ]]; then
        local dotfiles_dir="${SCRIPT_DIR}/../dotfiles/${dotfiles_source}"
        if [[ -d "$dotfiles_dir" ]]; then
            log_success "Dotfiles source directory exists: ${dotfiles_source}"
        else
            log_warn "Dotfiles source directory not found: ${dotfiles_source}"
            warnings=$((warnings + 1))
        fi
    else
        log_warn "No dotfiles source directory configured"
        warnings=$((warnings + 1))
    fi

    # Check dotfile link sources exist
    local link_index=1
    while true; do
        local src
        local dest
        src=$(ini_get "$profile_file" "dotfiles.links.${link_index}" "src" "")
        dest=$(ini_get "$profile_file" "dotfiles.links.${link_index}" "dest" "")

        if [[ -z "$src" || -z "$dest" ]]; then
            break
        fi

        local full_src="${SCRIPT_DIR}/../dotfiles/${dotfiles_source}${src}"
        if [[ -e "$full_src" ]]; then
            log_success "Dotfile link source exists: dotfiles/${dotfiles_source}${src}"
        else
            log_warn "Dotfile link source not found: dotfiles/${dotfiles_source}${src}"
            warnings=$((warnings + 1))
        fi

        link_index=$((link_index + 1))
    done

    # Check platform config directory exists (platform-specific package files)
    local platform_dir="${SCRIPT_DIR}/../packages/platforms"
    if [[ -d "$platform_dir" ]]; then
        log_success "Platform config directory exists: packages/platforms"
    else
        log_warn "Platform config directory not found: packages/platforms"
        warnings=$((warnings + 1))
    fi

    # Summary
    echo ""
    if [[ "$errors" -gt 0 ]]; then
        log_error "Validation failed: ${errors} error(s), ${warnings} warning(s)"
        return 1
    else
        if [[ "$warnings" -gt 0 ]]; then
            log_warn "Validation passed with ${warnings} warning(s)"
        fi
        log_success "Profile '${profile_name}' is valid"
        return 0
    fi
}

parse_args "$@"
validate_profile "$PROFILE_NAME"
