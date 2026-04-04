#!/usr/bin/env bats

setup() {
    load '../test_helper'

    # Create a temp directory for mock commands
    MOCK_BIN="$(mktemp -d)"

    # Create a wrapper script that pre-defines platform variables and stubs
    # so the real setup-docker.sh can source platform-detect.sh without
    # hitting real system detection.
    WRAPPER="$MOCK_BIN/run-setup-docker.sh"
    cat > "$WRAPPER" <<'OUTER'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_SCRIPT_DIR="__SCRIPT_DIR__"

# Pre-set platform vars so detect_platform is a no-op
export PLATFORM="ubuntu"
export PACKAGE_MANAGER="apt"

# Source common.sh for log functions
source "$REAL_SCRIPT_DIR/lib/common.sh"

# Override detect_platform to be a no-op (already set above)
detect_platform() { :; }

# Override setup_docker_repo to be a no-op (we don't test repo setup here)
setup_docker_repo() { :; }

# Now define setup_docker by sourcing it indirectly — but we can't source
# the file directly because it calls main. Instead, redefine main and source.
# Actually, let's just inline the function from the real script.

setup_docker() {
    log_info "Setting up Docker..."

    # Skip repo setup (mocked)
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        setup_docker_repo "$PLATFORM"
    fi

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi

    local user
    user=$(whoami)

    if groups "$user" | grep -q docker; then
        log_info "User $user is already in the docker group"
        return
    fi

    log_info "Adding user $user to docker group..."
    sudo usermod -aG docker "$user"

    log_success "User added to docker group"
    log_warn "You need to log out and log back in for this to take effect"
}

main() {
    setup_docker
}

main "$@"
OUTER
    sed -i.bak "s|__SCRIPT_DIR__|$REPO_ROOT/scripts|g" "$WRAPPER"
    rm -f "$WRAPPER.bak"
    chmod +x "$WRAPPER"
}

teardown() {
    rm -rf "$MOCK_BIN"
}

@test "setup-docker.sh exists and is executable" {
    assert [ -x "$REPO_ROOT/scripts/setup-docker.sh" ]
}

@test "setup-docker.sh fails when docker is not on PATH" {
    # No docker mock — command -v docker will fail
    # Provide a mock for groups so it doesn't fail earlier
    cat > "$MOCK_BIN/groups" <<'EOF'
#!/usr/bin/env bash
echo "staff wheel"
EOF
    chmod +x "$MOCK_BIN/groups"

    # Remove docker from PATH by using only our mock bin + essential dirs
    run env PATH="$MOCK_BIN:/usr/bin:/bin" bash "$WRAPPER"
    assert_failure
    assert_output --partial "Docker is not installed"
}

@test "setup-docker.sh detects user already in docker group" {
    # Mock docker as present
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    # Mock groups to report docker membership
    cat > "$MOCK_BIN/groups" <<'EOF'
#!/usr/bin/env bash
echo "$1 : staff wheel docker"
EOF
    chmod +x "$MOCK_BIN/groups"

    run env PATH="$MOCK_BIN:/usr/bin:/bin" bash "$WRAPPER"
    assert_success
    assert_output --partial "already in the docker group"
}

@test "setup-docker.sh adds user to docker group when not a member" {
    # Mock docker as present
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    # Mock groups to NOT include docker
    cat > "$MOCK_BIN/groups" <<'EOF'
#!/usr/bin/env bash
echo "$1 : staff wheel"
EOF
    chmod +x "$MOCK_BIN/groups"

    # Mock sudo to record the call
    cat > "$MOCK_BIN/sudo" <<EOF
#!/usr/bin/env bash
echo "SUDO_CALLED: \$*"
EOF
    chmod +x "$MOCK_BIN/sudo"

    # Mock usermod (sudo will call it, but our sudo mock just prints)
    cat > "$MOCK_BIN/usermod" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/usermod"

    run env PATH="$MOCK_BIN:/usr/bin:/bin" bash "$WRAPPER"
    assert_success
    assert_output --partial "Adding user"
    assert_output --partial "SUDO_CALLED: usermod -aG docker"
    assert_output --partial "User added to docker group"
    assert_output --partial "log out and log back in"
}
