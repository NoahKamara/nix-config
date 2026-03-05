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
        # Prefer the most recently created Wayland socket to avoid stale/older sessions.
        socket="$(
          find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null \
            | sort -V \
            | tail -n1 || true
        )"
        if [ -n "$socket" ]; then
          wayland_display="$(basename "$socket")"
          exec ${pkgs.wayvnc}/bin/wayvnc --socket "$wayland_display"
        fi
        sleep 2
      done
    '')
  ];

  systemd.user.services.wayvnc.Service.Restart = "on-failure";
  systemd.user.services.wayvnc.Service.RestartSec = 2;
}
