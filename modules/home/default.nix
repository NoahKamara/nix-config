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

  programs.zoxide.enable = true;

  programs.zsh.enable = true;
  programs.fish.enable = true;

  home.pointerCursor = lib.mkIf pkgs.stdenv.isLinux {
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  wayland.windowManager.hyprland = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    systemd.enable = true;
    settings = {
      bind = [
        "ALT, SPACE, exec, wofi --show drun"
      ];
    };
  };

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    HYPRCURSOR_THEME = "Adwaita";
    HYPRCURSOR_SIZE = "24";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };
}
