{ pkgs, lib, ... }:
let
  caddyConfig = import ../shared/service-proxy-caddy-config.nix { inherit pkgs; };
in
lib.mkIf pkgs.stdenv.isDarwin {
  launchd.daemons.service-proxy = {
    serviceConfig = {
      Label = "local.service-proxy";
      ProgramArguments = [
        "${pkgs.caddy}/bin/caddy"
        "run"
        "--config"
        "${caddyConfig}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/service-proxy.log";
      StandardErrorPath = "/tmp/service-proxy.log";
    };
  };
}
