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
    optional
    types
    ;
  cfg = config.noah.services.hermes-agent;
  pCfg = cfg.agentmail.poll;

  mkCronJob = import ./lib/mkCronJob.nix { inherit config lib pkgs; };

  # Skills the triage agent loads. The agentmail skill documents how to label
  # messages handled; icloud-calendar is only loaded when the calendar module
  # is on (otherwise the cron scheduler logs a skipped-skill warning).
  pollSkills = [ "agentmail" ] ++ optional cfg.calendar.enable "icloud-calendar";

  # Bake the configurable label/limit into the stdlib script at build time so
  # it needs no extra runtime env (it already inherits AGENTMAIL_API_KEY).
  pollScript = pkgs.writeText "hermes-check-mail.py" (
    builtins.replaceStrings
      [ "@handledLabel@" "@maxPerRun@" ]
      [ pCfg.handledLabel (toString pCfg.maxPerRun) ]
      (builtins.readFile ./agentmail/check-mail.py)
  );

  handlePrompt = pkgs.writeText "hermes-agentmail-handle-prompt.md" ''
    You are Hermes triaging emails the user forwarded to their AgentMail inbox.

    The "Script Output" above lists unhandled inbound emails. Each has an
    inbox_id, message_id, from, subject, date and body.

    Handle EACH email. Do NOT reply to the sender. For each one:

    - If it implies a task or to-do, create a Todoist task (Todoist MCP tools)
      with a clear title; add a due date when the email implies one.
    - If it contains a concrete dated event (appointment, meeting, booking,
      deadline), create a calendar event with the icloud-calendar skill.
    - If it only needs the user's awareness, just note it for the summary.

    Then mark it handled so it is never processed again: use the agentmail MCP
    update_message tool to add the label "${pCfg.handledLabel}" to that
    message_id. Do this for every email you processed, including pure FYIs and
    noise.

    Finally, write a SHORT summary — this is sent to the user on Telegram.
    One line per email: what it was and what you did (todo / event / FYI).
    Keep it terse and skimmable.

    If, after labeling everything handled, there is genuinely nothing worth the
    user's attention (e.g. spam or automated noise), respond with exactly
    [SILENT] and nothing else to suppress the Telegram message.
  '';

  cronJob = mkCronJob {
    name = "agentmail-poll";
    inherit (pCfg) interval deliver jobName;
    script = pollScript;
    scriptName = "check-mail.py";
    prompt = handlePrompt;
    promptName = "agentmail-handle-prompt.md";
    skills = pollSkills;
  };
in
{
  options.noah.services.hermes-agent.agentmail = {
    enable = mkEnableOption ''
      AgentMail agent-owned inboxes via the agentmail-mcp MCP server.
      Requires AGENTMAIL_API_KEY in the sops-backed hermes-env secret.
    '';

    poll = {
      enable = mkEnableOption ''
        Scheduled email triage: a cron job runs a polling script every
        `interval`. The script fetches unhandled inbound mail from the
        AgentMail REST API and only wakes the agent when there is new mail,
        so idle ticks cost no tokens. The agent then creates todos / calendar
        events and/or nags the user via `deliver`.
      '';

      interval = mkOption {
        type = types.str;
        default = "every 10m";
        example = "every 15m";
        description = "Hermes cron schedule string (e.g. 'every 10m', '0 * * * *').";
      };

      deliver = mkOption {
        type = types.str;
        default = "telegram";
        example = "telegram:-1001234567890";
        description = ''
          Where the agent's summary/nag is delivered. Bare platform names
          (e.g. "telegram") require the matching home channel to be set in the
          hermes-env secret (TELEGRAM_HOME_CHANNEL). Use "platform:chat_id" to
          target an explicit chat, or "local" to only save output to the
          dashboard cron log.
        '';
      };

      maxPerRun = mkOption {
        type = types.ints.positive;
        default = 10;
        description = "Max emails surfaced to the agent per tick (caps prompt size).";
      };

      handledLabel = mkOption {
        type = types.str;
        default = "hermes-handled";
        description = ''
          AgentMail label the agent adds once an email is handled. The poller
          skips messages carrying this label, so handling is idempotent.
        '';
      };

      jobName = mkOption {
        type = types.str;
        default = "agentmail-poll";
        description = "Name of the managed Hermes cron job (recreated on each deploy).";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.agentmail.enable) (
    lib.mkMerge [
      {
        services.hermes-agent = {
          extraPackages = [ pkgs.nodejs_22 ];

          mcpServers.agentmail = {
            command = "${pkgs.nodejs_22}/bin/npx";
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
      }

      (mkIf pCfg.enable {
        system.activationScripts.hermes-agent-agentmail-poll = cronJob.activationScript;
        systemd.services.hermes-agent-agentmail-poll = cronJob.systemdService;
      })
    ]
  );
}
