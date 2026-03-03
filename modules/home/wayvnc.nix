{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  services.wayvnc = {
    enable = true;
    autoStart = true;
    settings = {
      address = "0.0.0.0";
      port = 5900;
    };
  };

  systemd.user.services.wayvnc.Service.ExecStart = lib.mkForce [
    (pkgs.writeShellScript "start-wayvnc" ''
      set -eu

      runtime_dir="/run/user/$(id -u)"
      while true; do
        socket="$(ls "$runtime_dir"/wayland-* 2>/dev/null | head -n1 || true)"
        if [ -n "$socket" ]; then
          wayland_display="$(basename "$socket")"
          exec ${pkgs.wayvnc}/bin/wayvnc --gpu --socket "$wayland_display"
        fi
        sleep 2
      done
    '')
  ];

  systemd.user.services.wayvnc.Service.Restart = "on-failure";
  systemd.user.services.wayvnc.Service.RestartSec = 2;
}
