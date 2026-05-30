{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.noah.services.hermes-agent;
  dCfg = cfg.todoist.delegation;
  hermesStateDir = config.services.hermes-agent.stateDir;
  hermesUser = config.services.hermes-agent.user;
  hermesGroup = config.services.hermes-agent.group;
  npx = "${pkgs.nodejs_22}/bin/npx";

  mkCronJob = import ./lib/mkCronJob.nix { inherit config lib pkgs; };

  # Deep-merge keeps stale HTTP transport keys; stdio MCP must not also carry url.
  stripTodoistHttpMcpTransport = pkgs.writeScript "hermes-strip-todoist-http-mcp" ''
    #!${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3
    import sys
    from pathlib import Path

    import yaml

    config_path = Path(sys.argv[1])
    if not config_path.exists():
        sys.exit(0)

    with open(config_path) as f:
        data = yaml.safe_load(f) or {}

    todoist = (data.get("mcp_servers") or {}).get("todoist")
    if not isinstance(todoist, dict) or not todoist.get("command"):
        sys.exit(0)

    changed = False
    for key in ("url", "headers"):
        if key in todoist:
            del todoist[key]
            changed = True

    if changed:
        with open(config_path, "w") as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)
  '';

  pollScript = pkgs.writeText "hermes-check-todos.py" (
    builtins.replaceStrings
      [ "@delegatedLabel@" "@approvalLabel@" "@projectName@" "@maxPerRun@" ]
      [ dCfg.delegatedLabel dCfg.approvalLabel dCfg.project (toString dCfg.maxPerRun) ]
      (builtins.readFile ./todoist/check-todos.py)
  );

  handlePrompt = pkgs.writeText "hermes-delegation-handle-prompt.md" ''
    You are Hermes executing delegated tasks from Noah's Todoist.

    The "Script Output" above lists tasks labeled "${dCfg.delegatedLabel}" in
    the delegation project. Work through EACH task using the delegation skill
    (labels, approval gates, human handoff, Todoist tools).

    After processing all tasks, write a SHORT Telegram summary per the skill:
    one line per task (completed / needs-approval / human-handoff). If the queue
    was empty, respond with exactly [SILENT] and nothing else.
  '';

  cronJob = mkCronJob {
    name = "todoist-delegation";
    inherit (dCfg) interval deliver;
    jobName = dCfg.jobName;
    script = pollScript;
    scriptName = "check-todos.py";
    prompt = handlePrompt;
    promptName = "delegation-handle-prompt.md";
    skills = [ "delegation" ];
  };
in
{
  options.noah.services.hermes-agent.todoist = {
    enable = mkEnableOption ''
      Todoist task management via @doist/todoist-mcp (stdio MCP).
      Requires TODOIST_API_KEY in the sops-backed hermes-env secret.
    '';

    delegation = {
      enable = mkEnableOption ''
        Delegation inbox: a cron job polls Todoist for tasks labeled
        `delegatedLabel` and executes them. Tasks needing user input get
        labeled `approvalLabel` and a Telegram ping. Idle ticks cost no
        tokens.
      '';

      interval = mkOption {
        type = types.str;
        default = "every 10m";
        example = "every 5m";
        description = "Hermes cron schedule string for the delegation poll.";
      };

      deliver = mkOption {
        type = types.str;
        default = "telegram";
        description = "Where the agent's execution summary is delivered.";
      };

      project = mkOption {
        type = types.str;
        default = "Delegation";
        example = "Hermes";
        description = ''
          Todoist project name to scope the delegation filter. Tasks outside
          this project are ignored even if they carry the delegated label.
        '';
      };

      delegatedLabel = mkOption {
        type = types.str;
        default = "delegated";
        description = ''
          Todoist label that marks a task as delegated to the agent. The
          poller only surfaces tasks with this label.
        '';
      };

      approvalLabel = mkOption {
        type = types.str;
        default = "approval-needed";
        description = ''
          Todoist label the agent adds when it needs user confirmation.
          Tasks with this label are excluded from the poll filter until
          the user removes it.
        '';
      };

      maxPerRun = mkOption {
        type = types.ints.positive;
        default = 5;
        description = "Max delegated tasks surfaced to the agent per tick.";
      };

      jobName = mkOption {
        type = types.str;
        default = "todoist-delegation";
        description = "Name of the managed Hermes cron job.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.todoist.enable) (
    lib.mkMerge [
      {
        services.hermes-agent = {
          extraPackages = [ pkgs.nodejs_22 ];

          mcpServers.todoist = {
            command = npx;
            args = [
              "-y"
              "@doist/todoist-mcp"
            ];
            env.TODOIST_API_KEY = "\${TODOIST_API_KEY}";
          };
        };

        system.activationScripts.hermes-agent-todoist-mcp = lib.stringAfter [ "hermes-agent-setup" ] ''
          ${stripTodoistHttpMcpTransport} ${hermesStateDir}/.hermes/config.yaml
          chown ${hermesUser}:${hermesGroup} ${hermesStateDir}/.hermes/config.yaml
        '';
      }

      (mkIf dCfg.enable {
        noah.services.hermes-agent.internalSkills.delegation = {
          source = ./skills/delegation;
          alwaysLoad = true;
        };

        system.activationScripts.hermes-agent-todoist-delegation = cronJob.activationScript;
        systemd.services.hermes-agent-todoist-delegation = cronJob.systemdService;
      })
    ]
  );
}
