{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  services.wayvnc = {
    enable = true;
    autoStart = true;
    settings = {
      address = "localhost";
      port = 5900;
    };
  };

  systemd.user.services.wayvnc.Service.ExecStart = lib.mkForce [
    (pkgs.writeShellScript "start-wayvnc" ''
      set -eu

      runtime_dir="/run/user/$(id -u)"
      while true; do
        hypr_sig="$(
          find "$runtime_dir/hypr" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
            | sort -V \
            | tail -n1 \
            | sed 's#.*/##'
        )"
        [ -n "$hypr_sig" ] || { sleep 2; continue; }

        wayland_display="$(
          find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null \
            | sort -V \
            | tail -n1 \
            | sed 's#.*/##'
        )"
        [ -n "$wayland_display" ] || { sleep 2; continue; }

        output="$(
          env \
            WAYLAND_DISPLAY="$wayland_display" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            HYPRLAND_INSTANCE_SIGNATURE="$hypr_sig" \
            ${pkgs.hyprland}/bin/hyprctl -j monitors all 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r '
              [ .[]
                | select((.disabled // false | not) and ((.width // 0) > 0) and ((.height // 0) > 0))
              ] as $active
              | (([$active[] | select(.focused == true)] + $active)[0].name // empty)
            '
        )"

        if [ -n "$output" ]; then
          echo "wayvnc: HYPRLAND_INSTANCE_SIGNATURE=$hypr_sig WAYLAND_DISPLAY=$wayland_display output=$output"
          exec env \
            WAYLAND_DISPLAY="$wayland_display" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            HYPRLAND_INSTANCE_SIGNATURE="$hypr_sig" \
            ${pkgs.wayvnc}/bin/wayvnc \
            --disable-input \
            --disable-resizing \
            --output "$output" \
            127.0.0.1 5900
        fi

        echo "wayvnc: HYPRLAND_INSTANCE_SIGNATURE=$hypr_sig WAYLAND_DISPLAY=$wayland_display output=auto"
        exec env \
          WAYLAND_DISPLAY="$wayland_display" \
          XDG_RUNTIME_DIR="$runtime_dir" \
          HYPRLAND_INSTANCE_SIGNATURE="$hypr_sig" \
          ${pkgs.wayvnc}/bin/wayvnc \
          --disable-input \
          --disable-resizing \
          127.0.0.1 5900
        sleep 2
      done
    '')
  ];

  systemd.user.services.wayvnc.Service.Restart = "on-failure";
  systemd.user.services.wayvnc.Service.RestartSec = 2;
}
