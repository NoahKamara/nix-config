{ pkgs, lib, userProfile, ... }:
let
  vaultCommand = pkgs.writeShellScriptBin "vault" ''
    set -euo pipefail

    image="$HOME/vault.img"
    mountpoint="$HOME/Vault"
    volume_name="Vault"

    usage() {
      echo "Usage: vault <open|close|status>" >&2
      exit 1
    }

    read_passphrase() {
      if [ ! -t 0 ]; then
        echo "Interactive terminal required for passphrase entry." >&2
        exit 1
      fi

      printf "Vault passphrase: " >&2
      stty -echo
      IFS= read -r passphrase
      stty echo
      printf "\n" >&2

      if [ -z "$passphrase" ]; then
        echo "Passphrase cannot be empty." >&2
        exit 1
      fi
    }

    is_mounted() {
      /sbin/mount | ${pkgs.gnugrep}/bin/grep -Fq " on $mountpoint "
    }

    open_vault() {
      if [ ! -e "$image" ]; then
        echo "Creating encrypted sparsebundle at $image (max 100G)..."
        read_passphrase
        printf "%s" "$passphrase" | /usr/bin/hdiutil create \
          -type SPARSEBUNDLE \
          -fs APFS \
          -volname "$volume_name" \
          -size 100g \
          -encryption AES-256 \
          -stdinpass \
          "$image"
      fi

      mkdir -p "$mountpoint"

      if is_mounted; then
        echo "Vault is already mounted at $mountpoint"
        return
      fi

      read_passphrase
      printf "%s" "$passphrase" | /usr/bin/hdiutil attach \
        -stdinpass \
        -mountpoint "$mountpoint" \
        "$image"

      echo "Vault mounted at $mountpoint"
    }

    close_vault() {
      if ! is_mounted; then
        echo "Vault is not mounted."
        return
      fi

      /usr/bin/hdiutil detach "$mountpoint"
      echo "Vault unmounted."
    }

    status_vault() {
      if is_mounted; then
        echo "mounted:$mountpoint"
      else
        echo "unmounted"
      fi
    }

    case "''${1:-}" in
      open)
        open_vault
        ;;
      close)
        close_vault
        ;;
      status)
        status_vault
        ;;
      *)
        usage
        ;;
    esac
  '';
in

{
  imports = [
    ./ghostty.nix
    ./hyprland.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    lazygit
    (writeShellScriptBin "use-nix" ''
      config_path="''${NIX_CONFIG_DIR:-$HOME/.nix-config}"
      shell_name="''${1:-default}"

      if [ "$shell_name" = "default" ]; then
        echo "use flake \"$config_path\"" > .envrc
      else
        echo "use flake \"$config_path#$shell_name\"" > .envrc
      fi

      direnv allow
    '')
    (import ../../pkgs/service-expose.nix { inherit pkgs; })
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    vaultCommand
  ] ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    wofi
    wl-clipboard
    grim
    slurp
    brightnessctl
    playerctl
    pavucontrol
  ]);

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      hide_env_diff = true;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = userProfile.fullName;
      user.email = userProfile.email;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        identityFile = [
          "~/.ssh/id_ed25519"
          "~/.ssh/id_rsa"
        ];
      };
    };
  };

  home.activation.generateSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
      mkdir -p "$HOME/.ssh"
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${userProfile.email}" -f "$HOME/.ssh/id_ed25519" -N ""
    fi
  '';

  programs.zoxide.enable = true;

  programs.zsh.enable = true;
  programs.fish.enable = true;

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    TERMINAL = "ghostty";
  };

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };
}
