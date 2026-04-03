#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"

source "${SCRIPT_DIR}/lib/common.sh"

check_syncthing_installed() {
    if ! command -v syncthing &> /dev/null; then
        log_error "Syncthing is not installed. Please install it first."
        exit 1
    fi
}

generate_syncthing_config() {
    local config_dir="$HOME/.config/syncthing"
    local config_file="$config_dir/config.xml"
    
    if [[ -f "$config_file" ]]; then
        log_warn "Syncthing config already exists at $config_file"
        read -p "Overwrite existing config? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing config"
            return
        fi
    fi
    
    mkdir -p "$config_dir"
    
    log_info "Generating Syncthing configuration..."
    syncthing --generate="$config_dir"
    
    log_success "Syncthing config generated at $config_file"
}

setup_syncthing_folders() {
    local dotfiles_dir="$HOME/dotfiles"
    
    log_info "Configuring Syncthing folder: $dotfiles_dir"
    
    cat <<EOF
Syncthing Setup Instructions:

1. Start Syncthing:
   $ syncthing

2. Open the web UI: http://localhost:8384

3. Set a GUI username and password when prompted

4. Add this folder for syncing:
   - Folder ID: dotfiles
   - Folder Path: $dotfiles_dir
   
5. On other devices:
   - Install Syncthing
   - Add this device using the Device ID
   - Share the "dotfiles" folder

6. Configure versioning (recommended):
   - File Versioning: Staggered Versioning
   - Maximum Age: 30 days

7. Enable folder encryption (optional but recommended)

For more information: https://docs.syncthing.net/
EOF
}

enable_syncthing_service() {
    detect_platform
    
    log_info "Enabling Syncthing service..."
    
    case "$PLATFORM" in
        ubuntu|debian|fedora|raspberrypios|arch|opensuse|rocky|alma)
            systemctl --user enable syncthing
            systemctl --user start syncthing
            ;;
        void)
            sudo ln -s /etc/sv/syncthing /var/service/
            ;;
        gentoo)
            sudo rc-update add syncthing default
            sudo rc-service syncthing start
            ;;
        alpine)
            sudo rc-update add syncthing default
            sudo rc-service syncthing start
            ;;
        freebsd)
            sysrc syncthing_enable=YES
            service syncthing start
            ;;
        macos)
            log_info "On macOS, Syncthing can be started via the application or: brew services start syncthing"
            ;;
        *)
            log_warn "Unknown platform for service setup. Please enable Syncthing manually."
            ;;
    esac
    
    log_success "Syncthing service enabled"
}

main() {
    detect_platform
    log_info "Setting up Syncthing for platform: $PLATFORM"
    
    check_syncthing_installed
    generate_syncthing_config
    setup_syncthing_folders
    
    read -p "Enable Syncthing as a system service? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        enable_syncthing_service
    fi
    
    log_success "Syncthing setup complete!"
    log_info "Next step: Configure devices and folders via the web UI at http://localhost:8384"
}

main "$@"
