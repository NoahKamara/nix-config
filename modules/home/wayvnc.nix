{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  services.wayvnc = {
    enable = true;
    autoStart = true;
    settings = {
      address = "127.0.0.1";
      port = 5900;
    };
  };

  systemd.user.services.wayvnc.Service.ExecStart = lib.mkForce [
    (pkgs.writeShellScript "start-wayvnc" ''
      set -eu

      runtime_dir="/run/user/$(id -u)"
      while true; do
        for socket in "$runtime_dir"/wayland-*; do
          [ -S "$socket" ] || continue
          wayland_display="$(basename "$socket")"

          # Only attach once this socket responds like a live Hyprland session.
          if ! WAYLAND_DISPLAY="$wayland_display" XDG_RUNTIME_DIR="$runtime_dir" \
            ${pkgs.hyprland}/bin/hyprctl monitors all >/dev/null 2>&1; then
            continue
          fi

          exec env \
            WAYLAND_DISPLAY="$wayland_display" \
            XDG_RUNTIME_DIR="$runtime_dir" \
            ${pkgs.wayvnc}/bin/wayvnc --disable-input 127.0.0.1 5900
        done
        sleep 2
      done
    '')
  ];

  systemd.user.services.wayvnc.Service.Restart = "on-failure";
  systemd.user.services.wayvnc.Service.RestartSec = 2;
}
