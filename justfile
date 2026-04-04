# Machine Setup - Task Runner
# Run `just` to see all available commands

# Default: show help
default:
    @just --list

# === Setup ===

# Run full setup with auto-detected profile
setup *ARGS:
    bash setup.sh {{ARGS}}

# Run setup with a specific profile
setup-profile profile *ARGS:
    bash setup.sh --profile {{profile}} {{ARGS}}

# Run interactive setup wizard
interactive:
    bash setup.sh --interactive

# Preview what setup would do (colored diff)
dry-run profile="auto":
    bash setup.sh --dry-run --profile {{profile}} --no-syncthing --no-backup

# Update to latest version and re-run
update *ARGS:
    bash setup.sh --update {{ARGS}}

# === Profiles ===

# List available profiles
profiles:
    bash setup.sh --list-profiles

# Show profile details
show-profile profile:
    bash setup.sh --show-profile {{profile}}

# Validate a profile configuration
validate profile:
    bash setup.sh --validate-profile {{profile}}

# Create a new profile from template
create-profile name:
    bash setup.sh --create-profile {{name}}

# === Dotfiles ===

# Link dotfiles for a profile
link profile="auto":
    bash scripts/link-dotfiles.sh --profile {{profile}}

# Unlink dotfiles for a profile
unlink profile="auto":
    bash setup.sh --unlink --profile {{profile}}

# === Secrets ===

# Pull secrets from password manager
secrets-pull:
    bash setup.sh --secrets pull

# Push local secrets to password manager
secrets-push:
    bash setup.sh --secrets push

# List configured secret mappings
secrets-list:
    bash setup.sh --secrets list

# Show secret sync status
secrets-status:
    bash setup.sh --secrets status

# Initialize secrets.conf from template
secrets-init:
    bash setup.sh --secrets init

# Configure secrets provider
secrets-set-provider:
    bash setup.sh --secrets set-provider

# === Health & Status ===

# Show full status dashboard
status profile="auto":
    bash setup.sh --status --profile {{profile}}

# Run health check
check profile="auto":
    bash setup.sh --check --profile {{profile}}

# === Testing ===

# Run all tests (bats + integration + e2e)
test:
    bash tests/run-tests.sh

# Run only bats unit tests
test-bats:
    tests/libs/bats-core/bin/bats tests/bats/*.bats

# Run a specific bats test file
test-file file:
    tests/libs/bats-core/bin/bats tests/bats/{{file}}.bats

# Initialize test dependencies (bats submodules)
test-init:
    git submodule update --init --recursive tests/libs/

# === Linting ===

# Run shellcheck on all scripts
lint:
    shellcheck -x -S warning setup.sh
    find scripts/ -name "*.sh" -exec shellcheck -x -S warning {} +
    find tests/ -name "*.sh" -exec shellcheck -x -S warning {} +
    find backup/ -name "*.sh" -exec shellcheck -x -S warning {} +

# Validate all INI config files
lint-ini:
    #!/usr/bin/env bash
    status=0
    for file in packages/*.conf packages/platforms/*.conf profiles/*.conf backup/*.conf; do
        if [[ -f "$file" ]]; then
            if ! grep -qE "^\[" "$file"; then
                echo "No sections found in $file"
                status=1
            fi
        fi
    done
    exit $status

# Check all scripts are executable
lint-exec:
    #!/usr/bin/env bash
    for f in setup.sh scripts/*.sh; do
        test -x "$f" || { echo "Not executable: $f"; exit 1; }
    done
    echo "All scripts are executable"

# Run all lints
lint-all: lint lint-ini lint-exec

# === Documentation ===

# Generate changelog from git history
changelog:
    bash scripts/generate-changelog.sh

# View the man page
man:
    man ./docs/setup.sh.1

# === Backup ===

# Run backup (dry-run)
backup-dry-run:
    bash backup/backup.sh --dry-run

# Run backup
backup:
    bash backup/backup.sh

# List backup snapshots
backup-list:
    bash backup/backup.sh --list

# === Completions ===

# Install shell completions for current shell
install-completions:
    bash scripts/install-completions.sh

# Install completions for all shells
install-completions-all:
    bash scripts/install-completions.sh --all

# === NixOS ===

# Enter minimal dev shell (NixOS)
nix-minimal:
    nix develop

# Enter full dev shell (NixOS)
nix-full:
    nix develop .#full

# === CI ===

# Run the full CI pipeline locally
ci: lint-all test
    @echo "CI pipeline passed"
