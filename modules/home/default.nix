{ pkgs, lib, userProfile, ... }:

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

  programs.zoxide.enable = true;

  programs.zsh.enable = true;
  programs.fish.enable = true;

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };
}
