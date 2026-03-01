{ pkgs, ... }:
let
  caddyConfig = pkgs.writeText "service-proxy-caddy.json" ''
    {
      "admin": {
        "listen": "127.0.0.1:2019"
      },
      "apps": {
        "http": {
          "servers": {
            "srv0": {
              "listen": [
                ":8080"
              ],
              "routes": [
                {
                  "@id": "fallback-404",
                  "handle": [
                    {
                      "handler": "static_response",
                      "status_code": 404,
                      "body": "Not Found"
                    }
                  ]
                }
              ]
            }
          }
        }
      }
    }
  '';
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
