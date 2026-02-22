{ pkgs, ... }:

{
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

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 10000;
      ignoreAllDups = true;
    };
  };

  home.file.".aerospace.toml".source = ./aerospace.toml;
}
