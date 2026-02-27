{ pkgs, ... }: {
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    installBatSyntax = false;
    package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
    settings = {
      theme = "light:Adwaita,dark:Adwaita Dark";
      macos-option-as-alt = true;
    };
  };
}
