{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;

  cfg = config.noah.services.hermes-agent;
in
{
  options.noah.services.hermes-agent.apiServer = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the Hermes OpenAI-compatible API server (hermes gateway, port 8642).";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Bind address for the API server. Keep on loopback when exposing via Caddy;
        the container uses host networking so this is the chimaera host address.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8642;
      description = "Port for the Hermes OpenAI-compatible API server.";
    };
  };

  config = mkIf (cfg.enable && cfg.apiServer.enable) {
    services.hermes-agent.environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = cfg.apiServer.host;
      API_SERVER_PORT = toString cfg.apiServer.port;
    };
  };
}
