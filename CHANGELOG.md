# Changelog

All notable changes to this project are documented in this file.

Generated from conventional commits on 2026-04-04.

## Features

- feat: auto-install shell completions during setup (`05ea269`)
- feat: add --status dashboard showing full setup state (`894f29e`)
- feat: add --interactive wizard for guided setup (`9bc5e55`)
- feat: add bash/zsh/fish shell completions for setup.sh (`71c3b90`)
- feat: add ChromeOS/Crostini platform support (`88e0e54`)
- feat: add package version pinning support (`533dc51`)
- feat: add plugin/extension system via custom/ directory (`63a8cac`)
- feat: add --update command to pull latest and re-run setup (`b1ea7c7`)
- feat: add --create-profile to scaffold new profiles (`0a4256c`)
- feat: add colored dry-run diff showing current vs desired state (`f867674`)
- feat: add --check health command to verify setup state (`93a128d`)
- feat: use Brewfile for Homebrew package installation (`04ab226`)
- feat: add Nix flake with minimal and full dev shells (`02602c1`)
- feat: add --validate-profile command to verify profile config (`46ab255`)
- feat: add --unlink command to remove managed dotfile symlinks (`0631fcd`)
- feat: add bats-core test framework with migrated test suite (`118e8c4`)
- feat: add NixOS platform test and config files (`5af2a68`)
- feat: add Android/Termux platform support (`3cbe9f8`)
- feat: add idempotency tests and fix symlink re-linking (`ab241fd`)
- feat: detect WSL2 as its own platform using apt instead of winget (`79dc813`)
- feat: add inline comment support to INI parser (`662e0ad`)
- feat: add self-hosted server profile with Docker Compose stack (`7b4bd31`)
- feat: remove YAML parser and complete migration to INI (`a2e6437`)
- feat: complete migration from YAML to INI format (`0ca5c14`)
- feat: replace YAML with INI format (`5f9d63b`)

## Bug Fixes

- fix: address all PR review comments (`a2ccda8`)
- fix: install sed/grep/coreutils in NixOS Docker CI job (`67a5c64`)
- fix: resolve CI failures in platform-package-defs and NixOS Docker jobs (`cc336d7`)
- fix: remove backup script generator that would overwrite hand-written version (`c6d3dae`)
- fix: resolve 2 pre-existing test failures (`2a64c0b`)
- fix: resolve shellcheck warnings in selfhosted scripts (`a425d7f`)
- fix: resolve Gentoo and Void CI failures (`a52d20b`)
- fix: resolve CI failures on Windows, Gentoo, and Void Linux (`32920ae`)
- fix: resolve all shellcheck warnings across codebase (`8a7f280`)
- fix: comprehensive repo fixes, standalone bootstrap, and full CI matrix (`a8b5048`)
- fix: correct INI parser and test issues (`44e9eda`)
- fix: resolve all remaining CI failures (`a63bfbb`)
- fix: resolve CI failures (`176ba84`)
- fix: remove yq dependency from CI and tests (`3d02482`)

## Security

- security: add GPG fingerprint verification for Docker repo key (`f5a6049`)

## Performance

- perf: fast-path --help before sourcing scripts (`345835a`)
- perf: improve Homebrew install with batch-then-fallback strategy (`46d4919`)

## Refactoring

- refactor: remove legacy tests, consolidate on bats-core (`990c924`)
- refactor: add .shellcheckrc for project-wide shellcheck config (`4b0eaed`)
- refactor: extract shared log functions into scripts/lib/common.sh (`8d2a9d6`)
- refactor: convert backup configs to INI format (`96e480e`)

## Documentation

- docs: rewrite AGENTS.md to reflect current codebase state (`04f6b8d`)
- docs: update README with new features and platforms (`5a81c00`)
- docs: update documentation to reference INI instead of YAML (`e1ffcf9`)

## CI/CD

- ci: pin GitHub Actions to commit SHAs for supply-chain hardening (`4e99d9c`)
- ci: upgrade GitHub Actions to latest Node.js 24 versions (`7431d6d`)
- ci: add Homebrew and apt caching to speed up CI (`e8be674`)

## Other

- make mroe updates (`a5ee06a`)
- Initial setup (`471be18`)

