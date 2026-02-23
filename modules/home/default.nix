{ pkgs, ... }:

{
  imports = [
    ./ghostty.nix
  ];

  home.stateVersion = "24.11";
  home.username = "noahkamara";
  home.homeDirectory = "/Users/noahkamara";

  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    lazygit
  ];

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git.enable = true;

  programs.zoxide.enable = true;

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Helper to initialize Nix shells from the monorepo
      function use-nix
        set -l config_path ""
        
        if test -n "$NIX_CONFIG_DIR"
          set config_path $NIX_CONFIG_DIR
        else
          # fallback to ~/.nix-config
          set config_path ~/.nix-config
        end

        if test -z "$config_path"
          echo "Error: Could not find nix-config directory."
          echo "Please set \$NIX_CONFIG_DIR to its location."
          return 1
        end

        set shell_name default
        if test (count $argv) -gt 0
          set shell_name $argv[1]
        end

        if test "$shell_name" = "default"
          echo "use flake \"$config_path\"" > .envrc
        else
          echo "use flake \"$config_path#$shell_name\"" > .envrc
        end
        direnv allow
      end
    '';
  };

  home.file.".aerospace.toml".source = ./aerospace.toml;
}
