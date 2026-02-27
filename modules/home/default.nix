{ pkgs, lib, userProfile, ... }:

{
  imports = [
    ./ghostty.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    lazygit
    (writeShellScriptBin "use-nix" ''
      config_path=""
      
      if [ -n "$NIX_CONFIG_DIR" ]; then
        config_path="$NIX_CONFIG_DIR"
      else
        # fallback to ~/.nix-config
        config_path="$HOME/.nix-config"
      fi

      if [ -z "$config_path" ]; then
        echo "Error: Could not find nix-config directory."
        echo "Please set \$NIX_CONFIG_DIR to its location."
        exit 1
      fi

      shell_name="default"
      if [ $# -gt 0 ]; then
        shell_name="$1"
      fi

      if [ "$shell_name" = "default" ]; then
        echo "use flake \"$config_path\"" > .envrc
      else
        echo "use flake \"$config_path#$shell_name\"" > .envrc
      fi

      direnv allow
    '')
  ] ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    wofi
    waybar
    mako
    swaylock
    swayidle
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

  programs.zoxide.enable = true;

  programs.zsh.enable = true;
  programs.fish.enable = true;

  wayland.windowManager.sway = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    systemd.enable = true;
    checkConfig = false;
    config = {
      modifier = "Mod4";
      terminal = "ghostty";
      menu = "wofi --show drun";
      startup = [
        { command = "waybar"; }
        { command = "mako"; }
      ];
      bars = [ ];
      keybindings = lib.mkOptionDefault {
        "Mod4+Shift+e" = "exec swaynag -t warning -m 'Exit Sway?' -B 'Yes' 'swaymsg exit'";
        "Mod4+l" = "exec swaylock -f";
      };
    };
    extraConfig = ''
      exec swayidle -w \
        timeout 300 'swaylock -f' \
        timeout 600 'swaymsg "output * power off"' \
        resume 'swaymsg "output * power on"' \
        before-sleep 'swaylock -f'
    '';
  };

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };
}
