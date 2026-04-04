{
  description = "Machine setup - development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # Minimal profile packages
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Shell
            nushell

            # Editors
            neovim

            # CLI essential
            ripgrep
            fd
            fzf

            # Git
            git
            git-crypt

            # Security
            gnupg
            openssh

            # Version manager
            mise

            # Sync
            syncthing
          ];

          shellHook = ''
            echo "machine-setup dev shell (minimal profile)"
            echo "Run 'nix develop .#full' for the full profile"
          '';
        };

        # Full profile packages (extends minimal)
        devShells.full = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Minimal profile
            nushell
            neovim
            ripgrep
            fd
            fzf
            git
            git-crypt
            gnupg
            openssh
            mise
            syncthing

            # Multiplexer
            zellij

            # CLI modern
            bat
            eza
            du-dust
            bottom
            procs

            # Utilities
            jq
            httpie
            doggo
            gping
            rsync
            yazi
            fastfetch

            # Security
            pass
            restic

            # Languages
            python3
            rustup

            # Git
            gh

            # DevOps
            docker
            kubectl
          ];

          shellHook = ''
            echo "machine-setup dev shell (full profile)"
          '';
        };
      }
    );
}
