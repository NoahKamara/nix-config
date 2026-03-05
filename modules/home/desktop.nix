{
  pkgs,
  lib,
  inputs,
  ...
}:
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

  settings = {
    text = builtins.toJSON {
      auto_update = false;
      vim_mode = true;
      vim = {
        toggle_relative_line_numbers = true;
      };
      autosave = "on_focus_change";
      auto_install_extensions = {
        "docker-compose" = true;
        "html" = true;
        "nix" = true;
        "dockerfile" = true;
        "toml" = true;
      };
    };
  };
in
{
  imports = [
    ./ghostty.nix
    ./hyprland.nix
    ./wayvnc.nix
  ];

  home.packages =
    (with pkgs; [ zed-editor ])
    ++ lib.optionals pkgs.stdenv.isLinux (
      with pkgs;
      [
        wofi
        wl-clipboard
        grim
        slurp
        brightnessctl
        playerctl
        pavucontrol
        vaultCommand
        firefox
      ]
    );

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    TERMINAL = "ghostty";
  };

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };

  # Zed
  xdg.configFile."zed/settings.json" = lib.mkIf pkgs.stdenv.isLinux settings;
  home.file."Library/Application Support/Zed/settings.json" = lib.mkIf pkgs.stdenv.isDarwin settings;
}
