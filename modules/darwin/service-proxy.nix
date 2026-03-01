{ pkgs, ... }:
let
  caddyConfig = import ../shared/service-proxy-caddy-config.nix { inherit pkgs; };
in
{
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
