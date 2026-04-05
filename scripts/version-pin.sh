#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Parse a package spec like "docker=24.0.*" into name and version
# Returns: sets PKG_NAME and PKG_VERSION variables
parse_package_spec() {
    local spec="$1"
    PKG_NAME=""
    PKG_VERSION=""
    PKG_CONSTRAINT=""

    if [[ "$spec" =~ ^([a-zA-Z0-9._/-]+)(>=|<=|=)(.+)$ ]]; then
        PKG_NAME="${BASH_REMATCH[1]}"
        PKG_CONSTRAINT="${BASH_REMATCH[2]}"
        PKG_VERSION="${BASH_REMATCH[3]}"
    else
        PKG_NAME="$spec"
    fi
}

# Format a versioned package spec for a specific package manager
# Args: package_name version_constraint version package_manager
# Returns: the formatted install string for that package manager
format_versioned_package() {
    local name="$1"
    local constraint="${2:-}"
    local version="${3:-}"
    local pkg_mgr="${4:-}"

    if [[ -z "$version" ]]; then
        echo "$name"
        return
    fi

    case "$pkg_mgr" in
        apt)
            # apt uses = for exact version
            echo "${name}=${version}"
            ;;
        dnf)
            # dnf supports name-version
            echo "${name}-${version}"
            ;;
        homebrew)
            # Homebrew doesn't support version pinning in install
            # Log a warning and install without version
            log_warn "Homebrew does not support version pinning for '$name' (requested $constraint$version)"
            echo "$name"
            ;;
        pacman)
            # pacman uses = for exact
            if [[ "$constraint" == "=" ]]; then
                echo "${name}=${version}"
            else
                echo "$name"
            fi
            ;;
        apk)
            # apk uses = for exact
            echo "${name}=${version}"
            ;;
        nix)
            # nix doesn't support version pinning in nix-env -i
            log_warn "Nix version pinning not supported for '$name' (requested $constraint$version)"
            echo "$name"
            ;;
        *)
            # Default: strip version, install latest
            echo "$name"
            ;;
    esac
}

# Process a list of package specs, applying version pinning
# Args: packages_string package_manager
# Returns: processed package list with versions applied
process_versioned_packages() {
    local packages="$1"
    local pkg_mgr="$2"
    local result=""

    for spec in $packages; do
        parse_package_spec "$spec"
        local formatted
        formatted=$(format_versioned_package "$PKG_NAME" "$PKG_CONSTRAINT" "$PKG_VERSION" "$pkg_mgr")
        result="$result $formatted"
    done

    echo "$result" | sed 's/^ //'
}

usage() {
    cat <<EOF
Usage: source $(basename "$0")

Version pinning utility for package installation. This script is
intended to be sourced by other scripts, not run directly.

Functions:
    parse_package_spec <spec>                    Parse "pkg=version" into components
    process_versioned_packages <pkgs> <manager>  Apply version pins for a package manager

Options:
    -h, --help    Show this help message

Examples:
    source $(basename "$0")
    parse_package_spec 'docker=24.0.*'
    echo "Name: \$PKG_NAME, Version: \$PKG_VERSION"
EOF
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help) usage ;;
    esac
    echo "Version pin utility"
    echo "Usage: source this file, then call parse_package_spec or process_versioned_packages"
    echo ""
    echo "Example:"
    echo "  parse_package_spec 'docker=24.0.*'"
    echo "  echo \"Name: \$PKG_NAME, Version: \$PKG_VERSION\""
fi
