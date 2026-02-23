{ pkgs, ... }: {
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    installBatSyntax = false;
    package = null; # Don't try to install via Nix, since we use the Homebrew Cask
    settings = {
      theme = "light:Adwaita,dark:Adwaita Dark";
      macos-option-as-alt = true;
    };
  };
}
