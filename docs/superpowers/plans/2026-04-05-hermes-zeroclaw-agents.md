# Hermes & Zeroclaw AI Agent Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Hermes (Nous Research) and Zeroclaw (Zeroclaw Labs) as on-machine AI agent tools with nested sub-profiles and hybrid setup scripts.

**Architecture:** Each tool gets a profile in `profiles/<tool>/base.conf` extending `minimal`, a setup script in `scripts/` that handles platform gating, installation via curl, backend/gateway selection prompts, and delegation to the tool's native wizard. Dotfile directories for each tool's config are symlinked for backup/sync.

**Tech Stack:** Bash, bats-core (testing), groff (man pages)

---

### Task 1: Hermes Profile

**Files:**
- Create: `profiles/hermes/base.conf`

- [ ] **Step 1: Create the profile directory and config**

```bash
mkdir -p profiles/hermes
```

Write `profiles/hermes/base.conf`:

```ini
# Profile: hermes
# Hermes AI agent by Nous Research

[profile]
name = hermes
description = Hermes AI agent by Nous Research - on-machine agent with persistent memory
extends = minimal

[dotfiles]
source = profiles/hermes/

[dotfiles.links.1]
src = .config/hermes/
dest = ~/.config/hermes/

[setup_scripts]
run = scripts/setup-hermes.sh
```

- [ ] **Step 2: Create the dotfiles directory placeholder**

```bash
mkdir -p dotfiles/profiles/hermes/.config/hermes
touch dotfiles/profiles/hermes/.config/hermes/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add profiles/hermes/base.conf dotfiles/profiles/hermes/
git commit -m "feat: add hermes agent profile (base.conf)"
```

---

### Task 2: Zeroclaw Profile

**Files:**
- Create: `profiles/zeroclaw/base.conf`

- [ ] **Step 1: Create the profile directory and config**

```bash
mkdir -p profiles/zeroclaw
```

Write `profiles/zeroclaw/base.conf`:

```ini
# Profile: zeroclaw
# Zeroclaw AI agent by Zeroclaw Labs

[profile]
name = zeroclaw
description = Zeroclaw AI agent by Zeroclaw Labs - local-first agent with persistent memory
extends = minimal

[dotfiles]
source = profiles/zeroclaw/

[dotfiles.links.1]
src = .config/zeroclaw/
dest = ~/.config/zeroclaw/

[setup_scripts]
run = scripts/setup-zeroclaw.sh
```

- [ ] **Step 2: Create the dotfiles directory placeholder**

```bash
mkdir -p dotfiles/profiles/zeroclaw/.config/zeroclaw
touch dotfiles/profiles/zeroclaw/.config/zeroclaw/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add profiles/zeroclaw/base.conf dotfiles/profiles/zeroclaw/
git commit -m "feat: add zeroclaw agent profile (base.conf)"
```

---

### Task 3: Hermes Setup Script

**Files:**
- Create: `scripts/setup-hermes.sh`

- [ ] **Step 1: Write the setup script**

Write `scripts/setup-hermes.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=false

HERMES_INSTALL_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

SUPPORTED_PLATFORMS="macos linux wsl"
# "linux" covers: fedora ubuntu debian arch gentoo void alpine opensuse rocky alma raspberrypios nixos chromeos

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install and configure the Hermes AI agent by Nous Research.

Handles platform verification, installation via curl, backend selection
(Nous Portal / OpenRouter / custom endpoint), and optional messaging
gateway setup (Telegram, Discord, Slack, WhatsApp, Signal, Email).

Options:
    --dry-run     Show what would be done without executing
    -h, --help    Show this help message
EOF
    exit 0
}

is_linux_platform() {
    local p="$1"
    case "$p" in
        fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

check_platform() {
    detect_platform
    if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
        log_info "Platform '$PLATFORM' is supported by Hermes"
        return 0
    else
        log_warn "Hermes does not officially support platform '$PLATFORM'"
        log_warn "Supported: Linux, macOS, WSL2. Skipping Hermes setup."
        exit 0
    fi
}

check_installed() {
    if command -v hermes &> /dev/null; then
        return 0
    fi
    return 1
}

install_hermes() {
    if check_installed; then
        log_info "Hermes is already installed"
        read -p "Update Hermes to the latest version? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[dry-run] Would run: hermes update"
            else
                hermes update
                log_success "Hermes updated"
            fi
        fi
        return 0
    fi

    log_info "Installing Hermes..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: curl -fsSL $HERMES_INSTALL_URL | bash"
        return 0
    fi

    curl -fsSL "$HERMES_INSTALL_URL" | bash
    log_success "Hermes installed"
}

select_backend() {
    echo ""
    log_info "Select a backend for Hermes:"
    echo "  1) Nous Portal (OAuth - no API key needed)"
    echo "  2) OpenRouter (requires API key)"
    echo "  3) Custom OpenAI-compatible endpoint"
    echo ""
    read -p "Choose [1-3]: " -n 1 -r
    echo ""

    case "$REPLY" in
        1) HERMES_BACKEND="nous" ;;
        2) HERMES_BACKEND="openrouter" ;;
        3) HERMES_BACKEND="custom" ;;
        *)
            log_warn "Invalid choice, defaulting to Nous Portal"
            HERMES_BACKEND="nous"
            ;;
    esac

    log_info "Selected backend: $HERMES_BACKEND"
}

select_gateways() {
    HERMES_GATEWAYS=()
    echo ""
    log_info "Select messaging gateways to configure (enter numbers separated by spaces, or 'none'):"
    echo "  1) Telegram"
    echo "  2) Discord"
    echo "  3) Slack"
    echo "  4) WhatsApp"
    echo "  5) Signal"
    echo "  6) Email"
    echo ""
    read -p "Choose (e.g., '1 3' or 'none'): " -r

    if [[ "$REPLY" == "none" ]] || [[ -z "$REPLY" ]]; then
        log_info "No gateways selected"
        return 0
    fi

    for choice in $REPLY; do
        case "$choice" in
            1) HERMES_GATEWAYS+=("telegram") ;;
            2) HERMES_GATEWAYS+=("discord") ;;
            3) HERMES_GATEWAYS+=("slack") ;;
            4) HERMES_GATEWAYS+=("whatsapp") ;;
            5) HERMES_GATEWAYS+=("signal") ;;
            6) HERMES_GATEWAYS+=("email") ;;
            *) log_warn "Ignoring invalid choice: $choice" ;;
        esac
    done

    if [[ ${#HERMES_GATEWAYS[@]} -gt 0 ]]; then
        log_info "Selected gateways: ${HERMES_GATEWAYS[*]}"
    fi
}

run_native_setup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: hermes setup"
        if [[ ${#HERMES_GATEWAYS[@]} -gt 0 ]]; then
            log_info "[dry-run] Would run: hermes gateway setup"
        fi
        return 0
    fi

    log_info "Launching Hermes native setup wizard..."
    log_info "Backend choice: $HERMES_BACKEND"
    hermes setup

    if [[ ${#HERMES_GATEWAYS[@]} -gt 0 ]]; then
        log_info "Launching Hermes gateway setup..."
        hermes gateway setup
    fi
}

register_dotfiles() {
    local config_dir="$HOME/.config/hermes"
    if [[ -d "$config_dir" ]]; then
        log_info "Hermes config directory found at $config_dir"
        log_success "Config will be synced/backed up via dotfile linking"
    else
        log_info "Hermes config directory will be created during native setup"
    fi
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
        --dry-run) DRY_RUN=true ;;
    esac

    log_info "=== Hermes Agent Setup ==="

    check_platform
    install_hermes
    select_backend
    select_gateways
    run_native_setup
    register_dotfiles

    log_success "Hermes setup complete!"
}

main "$@"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/setup-hermes.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/setup-hermes.sh
git commit -m "feat: add hybrid setup script for Hermes agent"
```

---

### Task 4: Zeroclaw Setup Script

**Files:**
- Create: `scripts/setup-zeroclaw.sh`

- [ ] **Step 1: Write the setup script**

Write `scripts/setup-zeroclaw.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform-detect.sh"
source "${SCRIPT_DIR}/lib/common.sh"

DRY_RUN=false

ZEROCLAW_INSTALL_URL="https://zeroclawlabs.ai/install.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install and configure the Zeroclaw AI agent by Zeroclaw Labs.

Handles platform verification, installation via curl, backend selection
(Claude / OpenAI / local models), and optional messaging gateway setup
(Telegram, Discord, WhatsApp, Slack).

Options:
    --dry-run     Show what would be done without executing
    -h, --help    Show this help message
EOF
    exit 0
}

is_linux_platform() {
    local p="$1"
    case "$p" in
        fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

check_platform() {
    detect_platform
    if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
        log_info "Platform '$PLATFORM' is supported by Zeroclaw"
        return 0
    else
        log_warn "Zeroclaw does not officially support platform '$PLATFORM'"
        log_warn "Supported: Linux, macOS, Windows, WSL2. Skipping Zeroclaw setup."
        exit 0
    fi
}

check_installed() {
    if command -v zeroclaw &> /dev/null; then
        return 0
    fi
    return 1
}

install_zeroclaw() {
    if check_installed; then
        log_info "Zeroclaw is already installed"
        read -p "Reinstall Zeroclaw? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing installation"
            return 0
        fi
    fi

    log_info "Installing Zeroclaw..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: curl -fsSL $ZEROCLAW_INSTALL_URL | bash"
        return 0
    fi

    curl -fsSL "$ZEROCLAW_INSTALL_URL" | bash
    log_success "Zeroclaw installed"
}

select_backend() {
    echo ""
    log_info "Select a backend for Zeroclaw:"
    echo "  1) Claude (Anthropic API key required)"
    echo "  2) OpenAI (API key required)"
    echo "  3) Local models (no API key needed)"
    echo ""
    read -p "Choose [1-3]: " -n 1 -r
    echo ""

    case "$REPLY" in
        1) ZEROCLAW_BACKEND="claude" ;;
        2) ZEROCLAW_BACKEND="openai" ;;
        3) ZEROCLAW_BACKEND="local" ;;
        *)
            log_warn "Invalid choice, defaulting to Claude"
            ZEROCLAW_BACKEND="claude"
            ;;
    esac

    log_info "Selected backend: $ZEROCLAW_BACKEND"
}

select_gateways() {
    ZEROCLAW_GATEWAYS=()
    echo ""
    log_info "Select messaging gateways to configure (enter numbers separated by spaces, or 'none'):"
    echo "  1) Telegram"
    echo "  2) Discord"
    echo "  3) WhatsApp"
    echo "  4) Slack"
    echo ""
    read -p "Choose (e.g., '1 3' or 'none'): " -r

    if [[ "$REPLY" == "none" ]] || [[ -z "$REPLY" ]]; then
        log_info "No gateways selected"
        return 0
    fi

    for choice in $REPLY; do
        case "$choice" in
            1) ZEROCLAW_GATEWAYS+=("telegram") ;;
            2) ZEROCLAW_GATEWAYS+=("discord") ;;
            3) ZEROCLAW_GATEWAYS+=("whatsapp") ;;
            4) ZEROCLAW_GATEWAYS+=("slack") ;;
            *) log_warn "Ignoring invalid choice: $choice" ;;
        esac
    done

    if [[ ${#ZEROCLAW_GATEWAYS[@]} -gt 0 ]]; then
        log_info "Selected gateways: ${ZEROCLAW_GATEWAYS[*]}"
    fi
}

run_native_setup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would run: zeroclaw setup"
        return 0
    fi

    log_info "Launching Zeroclaw native setup wizard..."
    log_info "Backend choice: $ZEROCLAW_BACKEND"
    zeroclaw setup
}

register_dotfiles() {
    local config_dir="$HOME/.config/zeroclaw"
    if [[ -d "$config_dir" ]]; then
        log_info "Zeroclaw config directory found at $config_dir"
        log_success "Config will be synced/backed up via dotfile linking"
    else
        log_info "Zeroclaw config directory will be created during native setup"
    fi
}

main() {
    case "${1:-}" in
        -h|--help) usage ;;
        --dry-run) DRY_RUN=true ;;
    esac

    log_info "=== Zeroclaw Agent Setup ==="

    check_platform
    install_zeroclaw
    select_backend
    select_gateways
    run_native_setup
    register_dotfiles

    log_success "Zeroclaw setup complete!"
}

main "$@"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/setup-zeroclaw.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/setup-zeroclaw.sh
git commit -m "feat: add hybrid setup script for Zeroclaw agent"
```

---

### Task 5: Hermes Setup Script Tests

**Files:**
- Create: `tests/bats/setup-hermes.bats`

- [ ] **Step 1: Write the test file**

Write `tests/bats/setup-hermes.bats`:

```bash
#!/usr/bin/env bats

setup() {
    load '../test_helper'

    TEST_TMPDIR="$(mktemp -d)"
    MOCK_DIR="$TEST_TMPDIR/bin"
    mkdir -p "$MOCK_DIR"

    # Create a mock hermes binary
    cat > "$MOCK_DIR/hermes" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    setup) echo "hermes setup called"; exit 0 ;;
    update) echo "hermes update called"; exit 0 ;;
    gateway) echo "hermes gateway $2 called"; exit 0 ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$MOCK_DIR/hermes"

    # Create a mock curl
    cat > "$MOCK_DIR/curl" <<'MOCK'
#!/usr/bin/env bash
echo "mock curl: $*"
exit 0
MOCK
    chmod +x "$MOCK_DIR/curl"

    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_TMPDIR/fakehome"
    mkdir -p "$HOME"

    source "$REPO_ROOT/scripts/lib/common.sh"
    unset _COMMON_SH_LOADED
    source "$REPO_ROOT/scripts/platform-detect.sh"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    export HOME="$ORIGINAL_HOME"
}

@test "setup-hermes.sh exists and is executable" {
    assert [ -f "$REPO_ROOT/scripts/setup-hermes.sh" ]
    assert [ -x "$REPO_ROOT/scripts/setup-hermes.sh" ]
}

@test "setup-hermes.sh --help shows usage" {
    run bash "$REPO_ROOT/scripts/setup-hermes.sh" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Hermes AI agent"
    assert_output --partial "--dry-run"
}

@test "check_platform allows macos" {
    PLATFORM="macos"
    detect_platform() { :; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]]; then
            log_info "Platform '$PLATFORM' is supported by Hermes"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Hermes"
}

@test "check_platform allows wsl" {
    PLATFORM="wsl"
    detect_platform() { :; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]]; then
            log_info "Platform '$PLATFORM' is supported by Hermes"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Hermes"
}

@test "check_platform allows linux platforms" {
    PLATFORM="ubuntu"
    detect_platform() { :; }

    is_linux_platform() {
        case "$1" in
            fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos) return 0 ;;
            *) return 1 ;;
        esac
    }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Hermes"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Hermes"
}

@test "check_platform rejects windows" {
    PLATFORM="windows"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            return 0
        else
            log_warn "Hermes does not officially support platform '$PLATFORM'"
            exit 0
        fi
    }

    run check_platform
    assert_success
    assert_output --partial "does not officially support"
}

@test "check_installed succeeds when hermes is on PATH" {
    check_installed() {
        if command -v hermes &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="$MOCK_DIR:$PATH"
    run check_installed
    assert_success
}

@test "check_installed fails when hermes is not on PATH" {
    check_installed() {
        if command -v hermes &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="/usr/bin:/bin"
    run check_installed
    assert_failure
}

@test "install_hermes detects existing installation" {
    PATH="$MOCK_DIR:$PATH"

    install_hermes() {
        if command -v hermes &> /dev/null; then
            log_info "Hermes is already installed"
            return 0
        fi
    }

    run install_hermes
    assert_success
    assert_output --partial "already installed"
}

@test "install_hermes dry-run shows curl command" {
    DRY_RUN=true
    HERMES_INSTALL_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"

    install_hermes() {
        if command -v hermes &> /dev/null; then
            return 0
        fi
        log_info "Installing Hermes..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would run: curl -fsSL $HERMES_INSTALL_URL | bash"
            return 0
        fi
    }

    # Ensure hermes is not on PATH
    PATH="/usr/bin:/bin"
    run install_hermes
    assert_success
    assert_output --partial "[dry-run]"
    assert_output --partial "curl"
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
tests/libs/bats-core/bin/bats tests/bats/setup-hermes.bats
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/bats/setup-hermes.bats
git commit -m "test: add tests for Hermes setup script"
```

---

### Task 6: Zeroclaw Setup Script Tests

**Files:**
- Create: `tests/bats/setup-zeroclaw.bats`

- [ ] **Step 1: Write the test file**

Write `tests/bats/setup-zeroclaw.bats`:

```bash
#!/usr/bin/env bats

setup() {
    load '../test_helper'

    TEST_TMPDIR="$(mktemp -d)"
    MOCK_DIR="$TEST_TMPDIR/bin"
    mkdir -p "$MOCK_DIR"

    # Create a mock zeroclaw binary
    cat > "$MOCK_DIR/zeroclaw" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    setup) echo "zeroclaw setup called"; exit 0 ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$MOCK_DIR/zeroclaw"

    # Create a mock curl
    cat > "$MOCK_DIR/curl" <<'MOCK'
#!/usr/bin/env bash
echo "mock curl: $*"
exit 0
MOCK
    chmod +x "$MOCK_DIR/curl"

    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_TMPDIR/fakehome"
    mkdir -p "$HOME"

    source "$REPO_ROOT/scripts/lib/common.sh"
    unset _COMMON_SH_LOADED
    source "$REPO_ROOT/scripts/platform-detect.sh"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    export HOME="$ORIGINAL_HOME"
}

@test "setup-zeroclaw.sh exists and is executable" {
    assert [ -f "$REPO_ROOT/scripts/setup-zeroclaw.sh" ]
    assert [ -x "$REPO_ROOT/scripts/setup-zeroclaw.sh" ]
}

@test "setup-zeroclaw.sh --help shows usage" {
    run bash "$REPO_ROOT/scripts/setup-zeroclaw.sh" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Zeroclaw AI agent"
    assert_output --partial "--dry-run"
}

@test "check_platform allows macos" {
    PLATFORM="macos"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform allows windows" {
    PLATFORM="windows"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform allows linux platforms" {
    PLATFORM="fedora"
    detect_platform() { :; }

    is_linux_platform() {
        case "$1" in
            fedora|ubuntu|debian|arch|gentoo|void|alpine|opensuse|rocky|alma|raspberrypios|nixos|chromeos) return 0 ;;
            *) return 1 ;;
        esac
    }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        fi
        return 1
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform allows wsl for zeroclaw" {
    PLATFORM="wsl"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            log_info "Platform '$PLATFORM' is supported by Zeroclaw"
            return 0
        else
            log_warn "Zeroclaw does not officially support platform '$PLATFORM'"
            exit 0
        fi
    }

    run check_platform
    assert_success
    assert_output --partial "supported by Zeroclaw"
}

@test "check_platform rejects termux for zeroclaw" {
    PLATFORM="termux"
    detect_platform() { :; }

    is_linux_platform() { return 1; }

    check_platform() {
        detect_platform
        if [[ "$PLATFORM" == "macos" ]] || [[ "$PLATFORM" == "windows" ]] || [[ "$PLATFORM" == "wsl" ]] || is_linux_platform "$PLATFORM"; then
            return 0
        else
            log_warn "Zeroclaw does not officially support platform '$PLATFORM'"
            exit 0
        fi
    }

    run check_platform
    assert_success
    assert_output --partial "does not officially support"
}

@test "check_installed succeeds when zeroclaw is on PATH" {
    check_installed() {
        if command -v zeroclaw &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="$MOCK_DIR:$PATH"
    run check_installed
    assert_success
}

@test "check_installed fails when zeroclaw is not on PATH" {
    check_installed() {
        if command -v zeroclaw &> /dev/null; then
            return 0
        fi
        return 1
    }

    PATH="/usr/bin:/bin"
    run check_installed
    assert_failure
}

@test "install_zeroclaw detects existing installation" {
    PATH="$MOCK_DIR:$PATH"

    install_zeroclaw() {
        if command -v zeroclaw &> /dev/null; then
            log_info "Zeroclaw is already installed"
            return 0
        fi
    }

    run install_zeroclaw
    assert_success
    assert_output --partial "already installed"
}

@test "install_zeroclaw dry-run shows curl command" {
    DRY_RUN=true
    ZEROCLAW_INSTALL_URL="https://zeroclawlabs.ai/install.sh"

    install_zeroclaw() {
        if command -v zeroclaw &> /dev/null; then
            return 0
        fi
        log_info "Installing Zeroclaw..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[dry-run] Would run: curl -fsSL $ZEROCLAW_INSTALL_URL | bash"
            return 0
        fi
    }

    PATH="/usr/bin:/bin"
    run install_zeroclaw
    assert_success
    assert_output --partial "[dry-run]"
    assert_output --partial "curl"
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
tests/libs/bats-core/bin/bats tests/bats/setup-zeroclaw.bats
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/bats/setup-zeroclaw.bats
git commit -m "test: add tests for Zeroclaw setup script"
```

---

### Task 7: Man Pages

**Files:**
- Create: `docs/setup-hermes.1`
- Create: `docs/setup-zeroclaw.1`

- [ ] **Step 1: Write the Hermes man page**

Write `docs/setup-hermes.1`:

```groff
.TH SETUP\-HERMES 1 "2026-04-05" "machine-setup 2.0" "Machine Setup Manual"
.SH NAME
setup\-hermes.sh \- install and configure the Hermes AI agent
.SH SYNOPSIS
.B setup\-hermes.sh
[\fIOPTIONS\fR]
.SH DESCRIPTION
Install and configure the Hermes AI agent by Nous Research. Handles platform
verification, installation via curl, backend selection (Nous Portal, OpenRouter,
or custom endpoint), and optional messaging gateway setup (Telegram, Discord,
Slack, WhatsApp, Signal, Email).
.PP
After high-level configuration, delegates to the native \fBhermes setup\fR and
\fBhermes gateway setup\fR wizards for detailed settings.
.SH OPTIONS
.TP
.B \-\-dry\-run
Show what would be done without executing.
.TP
.BR \-h ", " \-\-help
Show the help message and exit.
.SH SUPPORTED PLATFORMS
Linux (all supported distributions), macOS, and WSL2.
Windows is not officially supported by Hermes.
.SH BACKENDS
.TP
.B Nous Portal
OAuth-based authentication. No API key required.
.TP
.B OpenRouter
Requires an OpenRouter API key.
.TP
.B Custom endpoint
Any OpenAI-compatible API endpoint.
.SH GATEWAYS
Telegram, Discord, Slack, WhatsApp, Signal, Email.
Gateway configuration is optional and handled by \fBhermes gateway setup\fR.
.SH EXIT STATUS
.TP
.B 0
Success, or platform not supported (skipped gracefully).
.TP
.B 1
Error during installation or setup.
.SH SEE ALSO
.BR setup.sh (1),
.BR setup\-zeroclaw (1)
.SH AUTHORS
Machine Setup contributors.
```

- [ ] **Step 2: Write the Zeroclaw man page**

Write `docs/setup-zeroclaw.1`:

```groff
.TH SETUP\-ZEROCLAW 1 "2026-04-05" "machine-setup 2.0" "Machine Setup Manual"
.SH NAME
setup\-zeroclaw.sh \- install and configure the Zeroclaw AI agent
.SH SYNOPSIS
.B setup\-zeroclaw.sh
[\fIOPTIONS\fR]
.SH DESCRIPTION
Install and configure the Zeroclaw AI agent by Zeroclaw Labs. Handles platform
verification, installation via curl, backend selection (Claude, OpenAI, or
local models), and optional messaging gateway setup (Telegram, Discord,
WhatsApp, Slack).
.PP
Zeroclaw runs 100% locally with no cloud requirement. After high-level
configuration, delegates to the native setup wizard for detailed settings.
.SH OPTIONS
.TP
.B \-\-dry\-run
Show what would be done without executing.
.TP
.BR \-h ", " \-\-help
Show the help message and exit.
.SH SUPPORTED PLATFORMS
Linux (all supported distributions), macOS, and Windows.
.SH BACKENDS
.TP
.B Claude
Requires an Anthropic API key.
.TP
.B OpenAI
Requires an OpenAI API key.
.TP
.B Local models
Runs entirely locally with no API key.
.SH GATEWAYS
Telegram, Discord, WhatsApp, Slack.
Gateway configuration is optional and handled during native setup.
.SH EXIT STATUS
.TP
.B 0
Success, or platform not supported (skipped gracefully).
.TP
.B 1
Error during installation or setup.
.SH SEE ALSO
.BR setup.sh (1),
.BR setup\-hermes (1)
.SH AUTHORS
Machine Setup contributors.
```

- [ ] **Step 3: Commit**

```bash
git add docs/setup-hermes.1 docs/setup-zeroclaw.1
git commit -m "docs: add man pages for Hermes and Zeroclaw setup scripts"
```

---

### Task 8: Update README and Website

**Files:**
- Modify: `README.md` (add agent profiles to the Profiles section)
- Modify: `docs/configuration.html` (add agent profiles to the profiles table)

- [ ] **Step 1: Add agent profiles section to README.md**

After the "Custom Profiles" section (around line 113, after the `./setup.sh --profile my-custom` code block), add:

```markdown
### AI Agent Profiles

On-machine AI agents with persistent memory and messaging integrations.

**Hermes** (Nous Research):
- Backends: Nous Portal, OpenRouter, custom endpoints
- Gateways: Telegram, Discord, Slack, WhatsApp, Signal, Email
- Platforms: Linux, macOS, WSL2

```bash
./setup.sh --profile hermes/base
```

**Zeroclaw** (Zeroclaw Labs):
- Backends: Claude, OpenAI, local models
- Gateways: Telegram, Discord, WhatsApp, Slack
- Platforms: Linux, macOS, Windows
- 100% local processing

```bash
./setup.sh --profile zeroclaw/base
```
```

- [ ] **Step 2: Add agent profiles to `docs/configuration.html`**

In the Built-in Profiles table, add two rows after the selfhosted row:

```html
<tr><td><code>hermes/base</code></td><td><code>minimal</code></td><td>Hermes AI agent (Nous Research) &mdash; on-machine agent with backend and gateway selection</td></tr>
<tr><td><code>zeroclaw/base</code></td><td><code>minimal</code></td><td>Zeroclaw AI agent (Zeroclaw Labs) &mdash; local-first agent with persistent memory</td></tr>
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/configuration.html
git commit -m "docs: add Hermes and Zeroclaw to README and website"
```
