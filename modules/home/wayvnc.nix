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
        wayland_display="$(
          find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null \
            | sort -V \
            | tail -n1 \
            | sed 's#.*/##'
        )"
        [ -n "$wayland_display" ] || { sleep 2; continue; }
        echo "wayvnc: WAYLAND_DISPLAY=$wayland_display output=auto"
        exec env \
          WAYLAND_DISPLAY="$wayland_display" \
          XDG_RUNTIME_DIR="$runtime_dir" \
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
