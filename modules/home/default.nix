{ pkgs, lib, inputs, userProfile, ... }:
let
  vaultDiskoConfig = pkgs.writeText "vault-disko.nix" ''
    { imagePath, mountPoint, mapperName ? "vaultimg", ... }:
    {
      disko.devices = {
        disk.vault = {
          type = "disk";
          device = imagePath;
          content = {
            type = "luks";
            name = mapperName;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = mountPoint;
              mountOptions = [ "defaults" "noatime" ];
            };
          };
        };
      };
    }
  '';

  vaultCommand = pkgs.writeShellScriptBin "vault" ''
    set -euo pipefail

    image="$HOME/vault.img"
    mountpoint="$HOME/Vault"
    mapper_name="vaultimg"

    usage() {
      echo "Usage: vault <open|close|status>" >&2
      exit 1
    }

    is_mounted() {
      ${pkgs.util-linux}/bin/findmnt "$mountpoint" >/dev/null 2>&1
    }

    open_vault() {
      if [ ! -e "$image" ]; then
        echo "Creating sparse image at $image (100G max)..."
        ${pkgs.coreutils}/bin/truncate -s 100G "$image"
      fi

      if is_mounted; then
        echo "Vault is already mounted at $mountpoint"
        return
      fi

      ${pkgs.coreutils}/bin/mkdir -p "$mountpoint"
      sudo ${inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/disko \
        --mode format,mount \
        --argstr imagePath "$image" \
        --argstr mountPoint "$mountpoint" \
        --argstr mapperName "$mapper_name" \
        ${vaultDiskoConfig}

      echo "Vault mounted at $mountpoint"
    }

    close_vault() {
      if is_mounted; then
        sudo ${pkgs.util-linux}/bin/umount "$mountpoint"
      fi

      if sudo ${pkgs.cryptsetup}/bin/cryptsetup status "$mapper_name" >/dev/null 2>&1; then
        sudo ${pkgs.cryptsetup}/bin/cryptsetup close "$mapper_name"
      fi

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
  ] ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    wofi
    wl-clipboard
    grim
    slurp
    brightnessctl
    playerctl
    pavucontrol
    vaultCommand
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
