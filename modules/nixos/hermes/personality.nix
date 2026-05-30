{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.noah.services.hermes-agent;
  pCfg = cfg.personality;
  svc = config.services.hermes-agent;

  # SOUL.md must land in HERMES_HOME (stateDir/.hermes), NOT the workspace.
  # The upstream `documents` option installs into MESSAGING_CWD, which Hermes
  # only scans for AGENTS.md/.cursorrules — it never reads SOUL.md from there.
  soulFile =
    if cfg.soul == null then
      null
    else if builtins.isString cfg.soul then
      pkgs.writeText "hermes-soul.md" cfg.soul
    else
      cfg.soul;
in
{
  options.noah.services.hermes-agent = {
    soul = mkOption {
      type = types.nullOr (types.either types.str types.path);
      default = null;
      example = lib.literalExpression "./SOUL.md";
      description = ''
        Agent identity (slot #1 of the system prompt). Either an inline
        string or a path to a SOUL.md file. Installed into HERMES_HOME
        (`''${stateDir}/.hermes/SOUL.md`) declaratively — overwritten on
        every activation, so Nix is the source of truth. Leave null to let
        Hermes seed its built-in default identity.
      '';
    };

    personality = {
      systemPrompt = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = ''
          Durable personality overlay written to config.yaml
          `agent.system_prompt`. Applied on top of SOUL.md in both the
          messaging gateway and the interactive CLI. This is the same key
          the `/personality` command writes to, so a manual `/personality`
          switch persists until the next rebuild reasserts this value.
        '';
      };

      definitions = mkOption {
        type = types.attrsOf (types.either types.str (types.attrsOf types.str));
        default = { };
        example = lib.literalExpression ''
          {
            codereviewer = "You are a meticulous code reviewer...";
          }
        '';
        description = ''
          Named custom personalities written to config.yaml
          `agent.personalities`. Switch to one at runtime with
          `/personality <name>`. Values are either a plain system-prompt
          string or an attrset with `system_prompt`/`description`/`tone`/`style`.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.hermes-agent.settings = mkMerge [
        (lib.optionalAttrs (pCfg.systemPrompt != null) {
          agent.system_prompt = pCfg.systemPrompt;
        })
        (lib.optionalAttrs (pCfg.definitions != { }) {
          agent.personalities = pCfg.definitions;
        })
      ];
    }

    (mkIf (soulFile != null) {
      # Runs after the upstream module's activation so HERMES_HOME exists.
      system.activationScripts."hermes-agent-soul" = lib.stringAfter [ "hermes-agent-setup" ] ''
        install -o ${svc.user} -g ${svc.group} -m 0640 \
          ${soulFile} ${svc.stateDir}/.hermes/SOUL.md
      '';

      # SOUL.md is read fresh per prompt build, but redeploys should still
      # bounce the gateway so a new identity takes effect immediately.
      systemd.services.hermes-agent.restartTriggers = [ soulFile ];
    })
  ]);
}
