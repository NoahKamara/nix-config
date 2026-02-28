{ config, pkgs, ... }:

{
  # nix-darwin does not change the shell for existing users by default,
  # so enforce fish for the configured primary user during activation.
  system.activationScripts.postActivation.text = ''
    if [ "$(/usr/bin/dscl . -read /Users/${config.system.primaryUser} UserShell | awk '{print $2}')" != "${pkgs.fish}/bin/fish" ]; then
      echo "Changing user shell to fish..."
      chsh -s ${pkgs.fish}/bin/fish ${config.system.primaryUser}
    fi
  '';

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  nix.gc.interval = {
    Weekday = 0;
    Hour = 2;
    Minute = 0;
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
      # Browsers
      "arc"
      "tor-browser"

      # AI Tools
      "antigravity"
      "codex"
      "cursor"

      # System Tools
      "betterdisplay"
      "nikitabobko/tap/aerospace"
      "daisydisk"
      "nordvpn"
      "keka"
      "shottr"
      "KeePassXC"
      "vlc"

      # Dev
      "xcodes-app"
      "sf-symbols"
      "container"
      "docker-desktop"
      "ghostty"

      # Communication
      "signal"

      # Productivity
      "obsidian"
      "raycast"
    ];
  };
}
