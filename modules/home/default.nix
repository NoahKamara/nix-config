{ pkgs, userProfile, ... }:

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
  ];

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

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };
}
