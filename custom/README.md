# Custom Extensions

Place your customizations here. This directory is gitignored by default.

## Structure

```
custom/
├── profiles/     # Custom profile .conf files (auto-discovered)
├── packages/     # Extra package .conf files (merged with profile packages)
├── scripts/      # Extra setup scripts (run after main setup, alphabetical order)
└── dotfiles/     # Extra dotfiles (mirrored to $HOME)
```

## Usage

Custom profiles appear in `./setup.sh --list-profiles`.
Custom packages are automatically merged during installation.
Custom scripts must be executable (`chmod +x`).
Custom dotfiles mirror the directory structure to `$HOME`.

## Environment Variable

Set `MACHINE_SETUP_CUSTOM` to use a custom extensions directory
instead of the default `custom/` in the repo.
