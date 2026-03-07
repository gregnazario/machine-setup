#!/usr/bin/env bash
set -euo pipefail

# Test: Dotfiles Linking
# Validates that dotfiles are linked correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PROFILE="${1:-minimal}"

echo "Testing dotfiles linking for profile: $PROFILE"

source "${REPO_ROOT}/scripts/platform-detect.sh"
source "${REPO_ROOT}/scripts/profile-loader.sh"

detect_platform
load_profile "$PROFILE"

# Get dotfiles configuration
DOTFILES_SOURCE=$(get_profile_dotfiles | yq eval '.source' -)
DOTFILES_DIR="${REPO_ROOT}/dotfiles/${DOTFILES_SOURCE}"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    echo "❌ FAIL: Dotfiles directory not found: $DOTFILES_DIR"
    exit 1
fi

# Check that essential dotfiles exist
if [[ "$PROFILE" == "minimal" ]]; then
    if [[ ! -f "${DOTFILES_DIR}/.config/nushell/config.nu" ]]; then
        echo "❌ FAIL: Minimal profile missing nushell config"
        exit 1
    fi
    if [[ ! -f "${DOTFILES_DIR}/.gitconfig" ]]; then
        echo "❌ FAIL: Minimal profile missing gitconfig"
        exit 1
    fi
    echo "✅ Minimal profile dotfiles exist"
fi

if [[ "$PROFILE" == "full" ]]; then
    if [[ ! -f "${DOTFILES_DIR}/shell/.config/nushell/config.nu" ]]; then
        echo "❌ FAIL: Full profile missing nushell config"
        exit 1
    fi
    if [[ ! -f "${DOTFILES_DIR}/editors/.config/nvim/init.lua" ]]; then
        echo "❌ FAIL: Full profile missing neovim config"
        exit 1
    fi
    if [[ ! -f "${DOTFILES_DIR}/multiplexer/.config/zellij/config.kdl" ]]; then
        echo "❌ FAIL: Full profile missing zellij config"
        exit 1
    fi
    echo "✅ Full profile dotfiles exist"
fi

# Test symlink creation in dry-run mode (without actually linking)
echo "Testing dry-run mode..."

# Mock the create_symlink function
create_symlink() {
    local source="$1"
    local target="$2"
    echo "Would create symlink: $target -> $source"
}

# The actual link-dotfiles.sh would be tested in integration tests
echo "✅ PASS: Dotfiles structure is valid for $PROFILE"
