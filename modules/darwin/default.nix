{ ... }:

{
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
    };
    casks = [
      # AI Tools
      "antigravity"
      "codex"
      "cursor"
      "arc"

      # System Tools
      "betterdisplay"
      "nikitabobko/tap/aerospace"
      "daisydisk"
      "nordvpn"
      "keka"
      "shottr"

      # Dev
      "xcodes-app"
      "sf-symbols"
      "container"
      "docker-desktop"
      "ghostty"

      # Communication
      "discord"
      "signal"

      # Productivity
      "obsidian"
      "raycast"
    ];
  };
}
