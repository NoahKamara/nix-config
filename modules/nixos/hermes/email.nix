{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.noah.services.hermes-agent;
in
{
  options.noah.services.hermes-agent.agentmail = {
    enable = mkEnableOption ''
      AgentMail agent-owned inboxes via the agentmail-mcp MCP server.
      Requires AGENTMAIL_API_KEY in the sops-backed hermes-env secret.
    '';
  };

  config = mkIf (cfg.enable && cfg.agentmail.enable) {
    services.hermes-agent = {
      extraPackages = [ pkgs.nodejs_22 ];

      mcpServers.agentmail = {
        command = "npx";
        args = [
          "-y"
          "agentmail-mcp"
        ];
        env.AGENTMAIL_API_KEY = "\${AGENTMAIL_API_KEY}";
      };
    };

    noah.services.hermes-agent.internalSkills.agentmail = {
      source = ./skills/agentmail;
      alwaysLoad = true;
    };
  };
}
