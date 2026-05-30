{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.noah.services.hermes-agent;
in
{
  options.noah.services.hermes-agent.todoist = {
    enable = mkEnableOption ''
      Todoist task management via Doist's hosted MCP endpoint.
      Requires TODOIST_API_KEY in the sops-backed hermes-env secret.
    '';
  };

  config = mkIf (cfg.enable && cfg.todoist.enable) {
    services.hermes-agent.mcpServers.todoist = {
      url = "https://ai.todoist.net/mcp";
      headers.Authorization = "Bearer \${TODOIST_API_KEY}";
    };
  };
}
