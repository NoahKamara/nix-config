{ pkgs, ... }:
let
  caddyConfig = import ../shared/service-proxy-caddy-config.nix { inherit pkgs; };
in
{
  networking.firewall.allowedTCPPorts = [ 8080 ];

  systemd.services.service-proxy = {
    description = "Dynamic LAN reverse proxy (Caddy)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.caddy}/bin/caddy run --config ${caddyConfig}";
      ExecReload = "${pkgs.caddy}/bin/caddy reload --config ${caddyConfig}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
