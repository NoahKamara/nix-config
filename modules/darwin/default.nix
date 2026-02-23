{ ... }:

{
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  system.defaults = {
    # Minimal dock — AeroSpace manages windows, not the dock
    dock = {
      autohide = true;
      launchanim = false;
      mru-spaces = false; # don't reorder Spaces by recent use
      show-process-indicators = false;
      show-recents = false;
      tilesize = 42;
      magnification = true;
      largesize = 46;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      ShowStatusBar = true;
      ShowPathbar = true;
      FXDefaultSearchScope = "SCsp"; # search current folder by default
      FXPreferredViewStyle = "Nlsv"; # list view
      _FXSortFoldersFirst = true;
    };

    trackpad = {
      Clicking = true; # tap to click
      FirstClickThreshold = 1; # light click
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleInterfaceStyleSwitchesAutomatically = true;
    };

    # Settings without first-class nix-darwin options
    CustomUserPreferences = {
      # Disable Stage Manager and macOS tiling — AeroSpace handles this
      "com.apple.WindowManager" = {
        GloballyEnabled = false;
        EnableStandardClickToShowDesktop = false;
        EnableTiledWindowMargins = false;
        HideDesktop = true;
      };
      "com.apple.dock" = {
        workspaces-swoosh-animation-off = true;
        enterMissionControlByTopWindowDrag = false;
      };
      # Each display gets independent Spaces (required for AeroSpace multi-monitor)
      "com.apple.spaces" = {
        spans-displays = false;
      };
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "uninstall";
    };
    taps = [
      "nikitabobko/tap"
    ];
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
