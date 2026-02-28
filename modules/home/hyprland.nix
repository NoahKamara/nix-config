{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {

  # ── Hyprland ────────────────────────────────────────────────────────
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;

    settings = {
      "$mod" = "SUPER";

      monitor = [ ", preferred, auto, 1" ];

      exec-once = [
        "waybar"
        "mako"
      ];

      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 2;
        "col.active_border" = "rgba(88c0d0ff) rgba(81a1c1ff) 45deg";
        "col.inactive_border" = "rgba(3b4252ff)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 4;
          passes = 2;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 8;
          render_power = 2;
          color = "rgba(1a1a1aee)";
        };
      };

      animations = {
        enabled = true;
        bezier = "ease, 0.25, 0.1, 0.25, 1";
        animation = [
          "windows, 1, 4, ease, slide"
          "windowsOut, 1, 4, ease, slide"
          "fade, 1, 4, ease"
          "workspaces, 1, 3, ease, slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      input = {
        follow_mouse = 1;
        sensitivity = 0;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      bind = [
        # Launcher
        "ALT, SPACE, exec, wofi --show drun"

        # Terminal
        "$mod, Return, exec, ghostty"

        # Window management
        "$mod, Q, killactive"
        "$mod, F, fullscreen, 0"
        "$mod SHIFT, F, togglefloating"
        "$mod, P, pseudo"
        "$mod, S, togglesplit"

        # Focus
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Move windows
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Scroll through workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"

        # Media keys
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];

      binde = [
        # Resize with mod + arrow keys
        "$mod CTRL, H, resizeactive, -20 0"
        "$mod CTRL, L, resizeactive, 20 0"
        "$mod CTRL, K, resizeactive, 0 -20"
        "$mod CTRL, J, resizeactive, 0 20"

        # Volume
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

        # Brightness
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # ── Waybar ──────────────────────────────────────────────────────────
  programs.waybar = {
    enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      spacing = 8;

      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "cpu" "memory" "tray" ];

      "hyprland/workspaces" = {
        format = "{name}";
        on-click = "activate";
      };

      "hyprland/window" = {
        max-length = 50;
        separate-outputs = true;
      };

      clock = {
        format = "{:%a %b %d  %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      cpu = {
        format = "  {usage}%";
        interval = 3;
      };

      memory = {
        format = "  {percentage}%";
        interval = 3;
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "  muted";
        format-icons.default = [ "" "" "" ];
        on-click = "pavucontrol";
      };

      network = {
        format-wifi = "  {signalStrength}%";
        format-ethernet = "  {ifname}";
        format-disconnected = "  off";
        tooltip-format = "{ifname}: {ipaddr}/{cidr}";
      };

      tray = {
        spacing = 8;
      };
    };

    style = ''
      * {
        font-family: "JetBrains Mono", "Symbols Nerd Font", monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(43, 48, 59, 0.92);
        color: #d8dee9;
        border-bottom: 2px solid rgba(136, 192, 208, 0.4);
      }

      #workspaces button {
        padding: 0 8px;
        color: #81a1c1;
        border: none;
        border-radius: 0;
      }

      #workspaces button.active {
        color: #88c0d0;
        border-bottom: 2px solid #88c0d0;
      }

      #workspaces button:hover {
        background: rgba(136, 192, 208, 0.15);
      }

      #window {
        padding: 0 12px;
        color: #a3be8c;
      }

      #clock {
        font-weight: bold;
        color: #d8dee9;
      }

      #cpu, #memory, #pulseaudio, #network, #tray {
        padding: 0 10px;
      }

      #cpu { color: #ebcb8b; }
      #memory { color: #b48ead; }

      #pulseaudio {
        color: #a3be8c;
      }

      #pulseaudio.muted {
        color: #bf616a;
      }

      #network {
        color: #88c0d0;
      }

      #network.disconnected {
        color: #bf616a;
      }

      #tray {
        padding: 0 8px;
      }
    '';
  };

  # ── Mako (notifications) ───────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      font = "JetBrains Mono 11";
      background-color = "#2b303bee";
      text-color = "#d8dee9";
      border-color = "#88c0d0";
      border-radius = 8;
      border-size = 2;
      padding = "12";
      default-timeout = 5000;
    };
  };

  # ── Session variables ──────────────────────────────────────────────
  home.sessionVariables = {
    HYPRCURSOR_THEME = "Adwaita";
    HYPRCURSOR_SIZE = "24";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # ── Cursor theme ───────────────────────────────────────────────────
  home.pointerCursor = {
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
