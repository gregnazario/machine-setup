---
title: Add Hermes and Zeroclaw AI Agent Tools
date: 2026-04-05
status: approved
---

# Add Hermes and Zeroclaw AI Agent Tools

## Overview

Add two on-machine AI agent tools — Hermes (Nous Research) and Zeroclaw (Zeroclaw Labs) — to the machine-setup system. Each gets nested sub-profile configurations and a dedicated hybrid setup script that handles high-level choices (backend, gateways) before delegating to the tool's native wizard.

Both are alternatives to OpenClaw and provide persistent memory, multi-agent support, and messaging platform integrations.

## Tools

### Hermes (Nous Research)

- **Site:** https://hermes-agent.nousresearch.com/
- **Install:** `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash`
- **CLI:** `hermes` command (interactive terminal agent)
- **Gateway:** `hermes gateway` for messaging platform integrations
- **Backends:** Nous Portal (OAuth), OpenRouter (API key), custom OpenAI-compatible endpoints
- **Gateways:** Telegram, Discord, Slack, WhatsApp, Signal, Email
- **Platforms:** Linux, macOS, WSL2 (Windows is experimental/unsupported)
- **Update:** `hermes update`

### Zeroclaw (Zeroclaw Labs)

- **Site:** https://www.zeroclawlabs.ai/
- **Install:** `curl -fsSL https://zeroclawlabs.ai/install.sh | bash`
- **100% local processing** — no cloud required
- **Multi-agent support** with persistent memory
- **Backends:** Claude, OpenAI, local models
- **Gateways:** Telegram, Discord, WhatsApp, Slack
- **Platforms:** macOS, Linux, Windows

## File Structure

```
profiles/
  hermes/
    base.conf              # Core Hermes install, extends minimal
  zeroclaw/
    base.conf              # Core Zeroclaw install, extends minimal

dotfiles/
  profiles/
    hermes/
      .config/hermes/      # Hermes config (synced/backed up)
    zeroclaw/
      .config/zeroclaw/    # Zeroclaw config (synced/backed up)

scripts/
  setup-hermes.sh          # Hybrid wizard for Hermes
  setup-zeroclaw.sh        # Hybrid wizard for Zeroclaw

tests/bats/
  setup-hermes.bats        # Tests for Hermes setup script
  setup-zeroclaw.bats      # Tests for Zeroclaw setup script

docs/
  setup-hermes.1           # Man page
  setup-zeroclaw.1         # Man page
```

## Profile Configs

### profiles/hermes/base.conf

```ini
[profile]
name = hermes
description = Hermes AI agent by Nous Research
extends = minimal

[dotfiles]
source = profiles/hermes/

[dotfiles.links.1]
src = .config/hermes/
dest = ~/.config/hermes/

[setup_scripts]
run = scripts/setup-hermes.sh
```

### profiles/zeroclaw/base.conf

```ini
[profile]
name = zeroclaw
description = Zeroclaw AI agent by Zeroclaw Labs
extends = minimal

[dotfiles]
source = profiles/zeroclaw/

[dotfiles.links.1]
src = .config/zeroclaw/
dest = ~/.config/zeroclaw/

[setup_scripts]
run = scripts/setup-zeroclaw.sh
```

No `[packages]` section — both tools install via curl, not system package managers. The setup scripts handle installation directly.

Usage: `./setup.sh --profile hermes/base` or `./setup.sh --profile zeroclaw/base`.

## Setup Script Flow

Both `setup-hermes.sh` and `setup-zeroclaw.sh` follow the same six-step pattern:

### 1. Platform Gate

- Source `scripts/platform-detect.sh`, check against supported platforms
- Hermes: allow linux, macos, wsl. Log warning and exit on others.
- Zeroclaw: allow linux, macos, windows. Log warning and exit on others.

### 2. Installation

- Check if the tool is already installed (check for `hermes` / `zeroclaw` in PATH)
- If missing, run the curl installer
- If present, offer to update

### 3. Backend Selection (Our Prompts)

- Hermes: Nous Portal (OAuth) / OpenRouter (API key) / Custom endpoint
- Zeroclaw: Claude / OpenAI / Local models
- Store the choice for delegation in step 5

### 4. Gateway Selection (Our Prompts)

- Present a menu of available messaging integrations
- Hermes: Telegram, Discord, Slack, WhatsApp, Signal, Email
- Zeroclaw: Telegram, Discord, WhatsApp, Slack
- User picks zero or more gateways to configure

### 5. Delegate to Native Wizard

- Pass selected backend/gateway choices to the tool's own setup command
- Hermes: `hermes setup` for backend, `hermes gateway setup` for gateways
- Zeroclaw: delegate to zeroclaw's equivalent setup commands
- If the native wizard needs interactive input beyond what we can pre-seed, let it take over the terminal

### 6. Dotfile Registration

- Symlink the tool's config directory into the dotfiles tree
- Hermes: `~/.config/hermes/`
- Zeroclaw: `~/.config/zeroclaw/`
- Ensures config is backed up and synced across machines

### Script Conventions

- Source `scripts/lib/common.sh` for logging (log_info, log_warn, log_error, log_success)
- Support `--help` / `-h` flag with usage information
- Support `--dry-run` flag (show what would be done without executing)
- Follow existing script patterns in the repository

## Testing

- Add bats tests for each setup script in `tests/bats/`
- Mock the curl installer and native wizard calls (no real installs in tests)
- Test platform gating: verify skip + warning on unsupported platforms
- Test the "already installed" detection path
- Follow existing mock patterns from other setup script tests

## Documentation

- Add Hermes and Zeroclaw to the GitHub Pages website (configuration page, mention on landing page)
- Add a section to `README.md` under profiles listing the agent profiles
- Each setup script supports `--help` with usage details
- Man pages for both setup scripts in `docs/` (setup-hermes.1, setup-zeroclaw.1)

## Out of Scope

- No changes to the profile loader or INI parser
- No multi-profile composition system — each agent profile is self-contained via `extends = minimal`
- No systemd/launchd service management for gateways — the native tools handle that themselves
- No custom configuration UI beyond the backend/gateway selection prompts
