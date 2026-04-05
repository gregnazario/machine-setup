#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

_BUILD_IMAGE_TMPFILE=""
cleanup_build_image() {
    if [[ -n "$_BUILD_IMAGE_TMPFILE" ]]; then
        rm -f "$_BUILD_IMAGE_TMPFILE"
    fi
}
trap cleanup_build_image EXIT

main() {
    local profile=""
    local tag=""
    local base_image="ubuntu:latest"
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                cat <<EOF
Usage: $(basename "$0") <profile> [OPTIONS]

Build a Docker image with the given profile pre-installed.

Options:
    --profile, -p <name>  Profile to install (required)
    --tag, -t <name>      Image tag (default: machine-setup-<profile>)
    --base <image>        Base image (default: ubuntu:latest)
    --dry-run             Show Dockerfile without building
    -h, --help            Show this help message

Examples:
    $(basename "$0") minimal
    $(basename "$0") full --tag my-dev --base debian:bookworm
    $(basename "$0") --profile full --dry-run
EOF
                exit 0
                ;;
            --profile|-p) profile="$2"; shift 2 ;;
            --tag|-t) tag="$2"; shift 2 ;;
            --base) base_image="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            *)
                if [[ -z "$profile" ]]; then
                    profile="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$profile" ]]; then
        echo "Usage: $0 <profile> [--tag <name>] [--base <image>] [--dry-run]"
        echo ""
        echo "Builds a Docker image with the given profile pre-installed."
        echo ""
        echo "Options:"
        echo "  --profile, -p <name>  Profile to install (required)"
        echo "  --tag, -t <name>      Image tag (default: machine-setup-<profile>)"
        echo "  --base <image>        Base image (default: ubuntu:latest)"
        echo "  --dry-run             Show Dockerfile without building"
        exit 1
    fi

    if [[ -z "$tag" ]]; then
        tag="machine-setup-${profile}"
    fi

    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Generate Dockerfile
    local dockerfile
    dockerfile="$(mktemp)"
    _BUILD_IMAGE_TMPFILE="$dockerfile"

    cat > "$dockerfile" <<DOCKERFILE
FROM ${base_image}

# Install prerequisites
RUN apt-get update && apt-get install -y \\
    bash git curl gnupg \\
    && rm -rf /var/lib/apt/lists/*

# Copy machine-setup repo
COPY . /opt/machine-setup
WORKDIR /opt/machine-setup

# Run setup with the specified profile (packages only, skip interactive steps)
RUN bash setup.sh --profile ${profile} --no-syncthing --no-backup --no-dotfiles \\
    || true

# Set up dotfiles
RUN bash scripts/link-dotfiles.sh --profile ${profile} --force \\
    || true

# Default to nushell if available, else bash
RUN command -v nu && echo '/usr/bin/env nu' >> /etc/shells || true
CMD ["bash"]

LABEL org.opencontainers.image.title="machine-setup-${profile}"
LABEL org.opencontainers.image.description="Machine setup with ${profile} profile"
LABEL org.opencontainers.image.source="https://github.com/yourusername/machine-setup"
DOCKERFILE

    if [[ "$dry_run" == true ]]; then
        log_info "Generated Dockerfile for profile: $profile"
        echo "---"
        cat "$dockerfile"
        echo "---"
        log_info "Would build: docker build -t $tag ."
        return 0
    fi

    log_info "Building Docker image: $tag (profile: $profile, base: $base_image)"

    docker build -t "$tag" -f "$dockerfile" "$REPO_DIR"

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "Image built: $tag"
        log_info "Run with: docker run -it $tag"
    else
        log_error "Image build failed"
        return $exit_code
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
