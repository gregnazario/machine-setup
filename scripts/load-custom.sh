#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

CUSTOM_DIR="${MACHINE_SETUP_CUSTOM:-${REPO_DIR:-$HOME/.machine-setup}/custom}"

discover_custom_profiles() {
    local custom_profiles_dir="${CUSTOM_DIR}/profiles"
    if [[ ! -d "$custom_profiles_dir" ]]; then
        return 0
    fi

    local count=0
    for conf in "$custom_profiles_dir"/*.conf; do
        [[ -f "$conf" ]] || continue
        local name
        name=$(basename "$conf" .conf)
        log_info "  Found custom profile: $name"
        count=$((count + 1))
    done

    if [[ $count -gt 0 ]]; then
        log_success "Discovered $count custom profile(s)"
    fi
}

load_custom_packages() {
    local existing_packages="${1:-}"
    local custom_packages_dir="${CUSTOM_DIR}/packages"

    if [[ ! -d "$custom_packages_dir" ]]; then
        echo "$existing_packages"
        return 0
    fi

    local extra=""
    for conf in "$custom_packages_dir"/*.conf; do
        [[ -f "$conf" ]] || continue
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue
            [[ "$line" =~ ^\[ ]] && continue
            if [[ "$line" =~ ^[^=]+=(.*)$ ]]; then
                extra="$extra ${BASH_REMATCH[1]}"
            fi
        done < "$conf"
    done

    echo "$existing_packages $extra" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

run_custom_scripts() {
    local custom_scripts_dir="${CUSTOM_DIR}/scripts"

    if [[ ! -d "$custom_scripts_dir" ]]; then
        return 0
    fi

    for script in "$custom_scripts_dir"/*.sh; do
        [[ -f "$script" ]] || continue
        [[ -x "$script" ]] || continue
        local name
        name=$(basename "$script")
        if [[ "${DRY_RUN:-false}" == true ]]; then
            log_info "Would run custom script: $name"
        else
            log_info "Running custom script: $name"
            bash "$script"
        fi
    done
}

link_custom_dotfiles() {
    local custom_dotfiles_dir="${CUSTOM_DIR}/dotfiles"

    if [[ ! -d "$custom_dotfiles_dir" ]]; then
        return 0
    fi

    log_info "Linking custom dotfiles from: $custom_dotfiles_dir"

    # Mirror directory structure from custom/dotfiles/ to $HOME
    while IFS= read -r -d '' file; do
        local relative="${file#"$custom_dotfiles_dir"/}"
        local target="$HOME/$relative"
        local target_dir
        target_dir=$(dirname "$target")

        if [[ "${DRY_RUN:-false}" == true ]]; then
            echo "  Would link: $target -> $file"
            continue
        fi

        # Skip if already correctly linked
        if [[ -L "$target" && "$(readlink "$target")" == "$file" ]]; then
            log_info "  Already linked: $target"
            continue
        fi

        mkdir -p "$target_dir"

        # Backup existing non-symlink files
        if [[ -e "$target" && ! -L "$target" ]]; then
            local backup
            backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
            log_warn "  Backing up: $target -> $backup"
            mv "$target" "$backup"
        elif [[ -L "$target" ]]; then
            rm "$target"
        fi

        ln -s "$file" "$target"
        log_success "  Linked: $target -> $file"
    done < <(find "$custom_dotfiles_dir" -type f -print0)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Custom extension loader"
    echo "Custom dir: $CUSTOM_DIR"
    discover_custom_profiles
    echo ""
    echo "Custom packages that would be added:"
    load_custom_packages ""
fi
