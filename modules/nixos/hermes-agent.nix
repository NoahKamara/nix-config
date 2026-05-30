{
  config,
  lib,
  inputs,
  pkgs,
  userProfile ? null,
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
  defaultHostUser =
    if userProfile != null && userProfile ? username then userProfile.username else "noah";
  hermesStateDir = config.services.hermes-agent.stateDir;
  hermesUser = config.services.hermes-agent.user;
  hermesGroup = config.services.hermes-agent.group;
  hermesAgentInput = inputs.hermes-agent;
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;
  # Upstream 0.15.x wheels omit hermes_cli/* subpackages (dashboard_auth, proxy).
  # Install them at activation from the flake source instead of rebuilding the package
  # locally (which breaks deploy checks when cross-compiling from aarch64-darwin).
  # https://github.com/NousResearch/hermes-agent/issues/34701
  hermesCliOverlayRoot = "${hermesStateDir}/lib/hermes-cli-overlay";
  hermesVenvSite = "${hermesPackage.passthru.hermesVenv}/${pkgs.python312.sitePackages}";
  hermesDashboardLauncher = pkgs.writeText "hermes-dashboard-launcher.py" ''
    import runpy
    import sys

    overlay = "${hermesCliOverlayRoot}/hermes_cli"
    sys.path.insert(0, "${hermesVenvSite}")
    import hermes_cli

    hermes_cli.__path__.append(overlay)
    sys.argv = ["hermes"] + sys.argv[1:]
    raise SystemExit(runpy.run_module("hermes_cli.main", run_name="__main__"))
  '';
  hermesDashboardWrapper = pkgs.writeShellScript "hermes-dashboard" ''
    export HERMES_BUNDLED_SKILLS="${hermesPackage}/share/hermes-agent/skills"
    export HERMES_BUNDLED_PLUGINS="${hermesPackage}/share/hermes-agent/plugins"
    export HERMES_WEB_DIST="${hermesPackage}/share/hermes-agent/web_dist"
    export HERMES_TUI_DIR="${hermesPackage}/ui-tui"
    export HERMES_PYTHON="${hermesPackage.passthru.hermesVenv}/bin/python3"
    export HERMES_NODE="${pkgs.nodejs_22}/bin/node"
    exec ${pkgs.python312}/bin/python3 ${hermesDashboardLauncher} "$@"
  '';
  containerDataDir = "/data";
  icloudCalendarSkillMd = pkgs.writeText "icloud-calendar-SKILL.md" (
    builtins.readFile ./hermes-skills/icloud-calendar/SKILL.md
  );
  icloudCalendarSkill = pkgs.runCommand "hermes-icloud-calendar-skill" { } ''
    mkdir -p $out/icloud-calendar
    cp ${icloudCalendarSkillMd} $out/icloud-calendar/SKILL.md
  '';
  agentmailSkillMd = pkgs.writeText "agentmail-SKILL.md" (
    builtins.readFile ./hermes-skills/agentmail/SKILL.md
  );
  agentmailSkill = pkgs.runCommand "hermes-agentmail-skill" { } ''
    mkdir -p $out/agentmail
    cp ${agentmailSkillMd} $out/agentmail/SKILL.md
  '';
  vdirsyncerCollections =
    if cfg.calendar.collections != [ ] then
      "[${lib.concatStringsSep ", " (map (c: ''"${c}"'') cfg.calendar.collections)}]"
    else
      "[\"from b\"]";
  vdirsyncerConfig = pkgs.writeText "hermes-vdirsyncer-config" ''
    [general]
    status_path = "${containerDataDir}/calendar/status"

    [pair icloud_calendars]
    a = "icloud_local"
    b = "icloud_remote"
    collections = ${vdirsyncerCollections}

    [storage icloud_local]
    type = "filesystem"
    path = "${containerDataDir}/calendar/local/"
    fileext = ".ics"

    [storage icloud_remote]
    type = "caldav"
    url = "https://caldav.icloud.com/"
    username = "${cfg.calendar.appleId}"
    password.fetch = ["command", "cat", "${containerDataDir}/.hermes/icloud-calendar-password"]
    item_types = ["VEVENT"]
  '';
  khalConfig = pkgs.writeText "hermes-khal-config" ''
    [locale]
    timeformat = %H:%M
    dateformat = %Y-%m-%d
    longdateformat = %Y-%m-%d
    datetimeformat = %Y-%m-%d %H:%M
    default_timezone = UTC

    [calendars]

    [[d]]
    path = ${containerDataDir}/calendar/local/*
    type = discover
  '';
  restartTriggerConfig = {
    inherit (config.services.hermes-agent)
      container
      documents
      environment
      extraArgs
      extraDependencyGroups
      mcpServers
      settings
      ;
    extraPackages = map toString config.services.hermes-agent.extraPackages;
    extraPlugins = map toString config.services.hermes-agent.extraPlugins;
    extraPythonPackages = map toString config.services.hermes-agent.extraPythonPackages;
  };
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  options.noah.services.hermes-agent = {
    enable = mkEnableOption "Hermes agent (container mode, declarative NixOS module)";

    sopsSecretName = mkOption {
      type = types.nullOr types.str;
      default = "hermes-env";
      description = ''
        sops-nix secret name (YAML key in the host secrets file).
        Decrypted path is passed to services.hermes-agent.environmentFiles.
        For Telegram, include TELEGRAM_BOT_TOKEN and TELEGRAM_ALLOWED_USERS
        (dotenv-style KEY=value lines in the secret value).
        For AgentMail, include AGENTMAIL_API_KEY (from console.agentmail.to).
        Set null to disable sops-backed env files.
      '';
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Declarative config.yaml fragment (deep-merged by the upstream module).";
    };

    dashboard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the Hermes web dashboard.";
      };

      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Bind address for the Hermes dashboard.";
      };

      port = mkOption {
        type = types.port;
        default = 9119;
        description = "Port for the Hermes dashboard.";
      };

      publicUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://agent.example.com";
        description = "Public URL for dashboard OAuth callbacks behind a reverse proxy.";
      };

      insecure = mkOption {
        type = types.bool;
        default = false;
        description = "Pass --insecure to disable the dashboard OAuth gate for externally protected deployments.";
      };
    };

    container = {
      hostUsers = mkOption {
        type = types.listOf types.str;
        default = [ defaultHostUser ];
        description = ''
          Host users who get ~/.hermes symlinked to service state and hermes group membership.
        '';
      };

      extraVolumes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra docker volume mounts (host:container:mode).";
      };
    };

    calendar = {
      enable = mkEnableOption ''
        iCloud Calendar read/write via CalDAV (vdirsyncer + khal).
        Requires an iCloud app-specific password in sops.
      '';

      appleId = mkOption {
        type = types.str;
        default = if userProfile != null && userProfile ? email then userProfile.email else "";
        example = "you@icloud.com";
        description = "iCloud Apple ID email address for CalDAV.";
      };

      appPasswordSopsName = mkOption {
        type = types.nullOr types.str;
        default = "icloud-app-password";
        description = ''
          sops-nix secret name (YAML key in the host secrets file) containing the
          iCloud app-specific password from appleid.apple.com.
          Set null to manage credentials manually in $HERMES_HOME.
        '';
      };

      collections = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "home"
          "6BF07365-CE70-4C52-A646-EABDE233726D"
        ];
        description = ''
          iCloud calendar collection IDs to sync (from `vdirsyncer discover --list`).
          iCloud Reminder lists (Einkauf, To Do, etc.) also appear over CalDAV —
          do not include them here. When empty, all remote collections are synced
          (not recommended for iCloud). VTODO items are always excluded via item_types.
        '';
      };
    };

    todoist = {
      enable = mkEnableOption ''
        Todoist task management via Doist's hosted MCP endpoint.
        Requires TODOIST_API_KEY in the sops-backed hermes-env secret.
      '';
    };

    agentmail = {
      enable = mkEnableOption ''
        AgentMail agent-owned inboxes via the agentmail-mcp MCP server.
        Requires AGENTMAIL_API_KEY in the sops-backed hermes-env secret.
      '';
    };

    plugins = {
      enabled = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "security-guidance"
          "disk-cleanup"
        ];
        description = ''
          Standalone Hermes plugins to opt into (config.yaml `plugins.enabled`
          allow-list). Use the plugin key, e.g. "disk-cleanup". Backend, web,
          and memory providers are selected via webBackend/memoryProvider, not
          this list.
        '';
      };

      memoryProvider = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "holographic";
        description = ''
          Exclusive long-term memory provider (config.yaml `memory.provider`).
          "holographic" is a local SQLite/FTS5 fact store needing no external
          account; its only non-stdlib dependency (numpy) already ships in the
          sealed venv, so no package override is required.
        '';
      };

      webBackend = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "brave_free";
        description = ''
          Web search backend (config.yaml `web.backend`). HTTP-based providers
          (brave_free, searxng, xai) use only packages already in the sealed
          venv. "ddgs" additionally requires pkgs.python312Packages.ddgs via
          services.hermes-agent.extraPythonPackages, which forces a package
          rebuild that executes the target-arch interpreter at build time and
          can break cross-compiled deploy checks from aarch64-darwin.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || !cfg.calendar.enable || cfg.calendar.appleId != "";
          message = "noah.services.hermes-agent.calendar.appleId must be set when calendar is enabled.";
        }
      ];
    }
    (mkIf cfg.enable {
      virtualisation.docker.enable = lib.mkDefault true;

      services.hermes-agent = {
        enable = true;
        # Default package omits messaging SDKs; lazy-install cannot write to /nix/store.
        package = hermesPackage;
        addToSystemPackages = true;
        extraPackages =
          lib.optionals cfg.calendar.enable [
            pkgs.vdirsyncer
            pkgs.khal
          ]
          ++ lib.optionals cfg.agentmail.enable [
            pkgs.nodejs_22
          ];
        environment = lib.optionalAttrs (cfg.dashboard.publicUrl != null) {
          HERMES_DASHBOARD_PUBLIC_URL = cfg.dashboard.publicUrl;
        };
        environmentFiles =
          if cfg.sopsSecretName != null then [ config.sops.secrets.${cfg.sopsSecretName}.path ] else [ ];

        container = {
          enable = true;
          backend = "docker";
          inherit (cfg.container) hostUsers extraVolumes;
        };

        settings = lib.mkMerge [
          {
            model = {
              provider = "openrouter";
              default = "deepseek/deepseek-v4-flash";
              base_url = "https://openrouter.ai/api/v1";
            };
            fallback_model = {
              provider = "openrouter";
              default = "deepseek/deepseek-v4-pro";
              base_url = "https://openrouter.ai/api/v1";
            };
          }
          (lib.optionalAttrs (cfg.calendar.enable || cfg.agentmail.enable) {
            skills.always_load =
              (lib.optional cfg.calendar.enable "icloud-calendar")
              ++ (lib.optional cfg.agentmail.enable "agentmail");
            skills.external_dirs =
              (lib.optional cfg.calendar.enable icloudCalendarSkill)
              ++ (lib.optional cfg.agentmail.enable agentmailSkill);
          })
          (lib.optionalAttrs cfg.todoist.enable {
            mcp_servers.todoist = {
              url = "https://ai.todoist.net/mcp";
              headers = {
                Authorization = "Bearer \${TODOIST_API_KEY}";
              };
            };
          })
          (lib.optionalAttrs cfg.agentmail.enable {
            mcp_servers.agentmail = {
              command = "npx";
              args = [
                "-y"
                "agentmail-mcp"
              ];
              env = {
                AGENTMAIL_API_KEY = "\${AGENTMAIL_API_KEY}";
              };
            };
          })
          (lib.optionalAttrs (cfg.plugins.enabled != [ ]) {
            plugins.enabled = cfg.plugins.enabled;
          })
          (lib.optionalAttrs (cfg.plugins.memoryProvider != null) {
            memory.provider = cfg.plugins.memoryProvider;
          })
          (lib.optionalAttrs (cfg.plugins.webBackend != null) {
            web.backend = cfg.plugins.webBackend;
          })
          cfg.settings
        ];
      };

      system.activationScripts.hermes-cli-subpackages = lib.stringAfter [ "hermes-agent-setup" ] ''
        rm -rf ${hermesCliOverlayRoot}
        OVERLAY="${hermesCliOverlayRoot}/hermes_cli"
        mkdir -p "$OVERLAY/dashboard_auth" "$OVERLAY/proxy"
        cp -r ${hermesAgentInput}/hermes_cli/dashboard_auth/. "$OVERLAY/dashboard_auth/"
        cp -r ${hermesAgentInput}/hermes_cli/proxy/. "$OVERLAY/proxy/"
        chown -R ${hermesUser}:${hermesGroup} ${hermesCliOverlayRoot}
      '';

      system.activationScripts.hermes-agent-calendar = lib.mkIf cfg.calendar.enable (
        lib.stringAfter [ "hermes-agent-setup" ] ''
          mkdir -p ${hermesStateDir}/calendar/local ${hermesStateDir}/calendar/status
          mkdir -p ${hermesStateDir}/home/.config/vdirsyncer ${hermesStateDir}/home/.config/khal
          mkdir -p ${hermesStateDir}/bin
          chown -R ${hermesUser}:${hermesGroup} ${hermesStateDir}/calendar ${hermesStateDir}/home/.config
          chmod 2770 ${hermesStateDir}/calendar ${hermesStateDir}/calendar/local ${hermesStateDir}/calendar/status

          ln -sfn ${pkgs.vdirsyncer}/bin/vdirsyncer ${hermesStateDir}/bin/vdirsyncer
          ln -sfn ${pkgs.khal}/bin/khal ${hermesStateDir}/bin/khal
          chown -h ${hermesUser}:${hermesGroup} ${hermesStateDir}/bin/vdirsyncer ${hermesStateDir}/bin/khal

          install -o ${hermesUser} -g ${hermesGroup} -m 0644 ${vdirsyncerConfig} ${hermesStateDir}/home/.config/vdirsyncer/config
          install -o ${hermesUser} -g ${hermesGroup} -m 0644 ${khalConfig} ${hermesStateDir}/home/.config/khal/config
          ${lib.optionalString (cfg.calendar.appPasswordSopsName != null) ''
            APP_PASSWORD="${config.sops.secrets.${cfg.calendar.appPasswordSopsName}.path}"
            if [ -f "$APP_PASSWORD" ]; then
              install -o ${hermesUser} -g ${hermesGroup} -m 0600 "$APP_PASSWORD" ${hermesStateDir}/.hermes/icloud-calendar-password
            else
              echo "hermes-agent: iCloud calendar app password not found at $APP_PASSWORD" >&2
            fi
          ''}
        ''
      );

      systemd.services.hermes-agent.restartTriggers = [
        config.services.hermes-agent.package
        (pkgs.writeText "hermes-agent-restart-trigger.json" (builtins.toJSON restartTriggerConfig))
        hermesAgentInput
      ]
      ++ lib.optional (cfg.sopsSecretName != null) config.sops.secrets.${cfg.sopsSecretName}.sopsFile
      ++ lib.optional (
        cfg.calendar.enable && cfg.calendar.appPasswordSopsName != null
      ) config.sops.secrets.${cfg.calendar.appPasswordSopsName}.sopsFile;

      # Hermes intentionally exits 1 on unmarked SIGTERM so Restart= can revive it.
      # During nixos-rebuild that makes stop look like a failure and can hit StartLimit.
      systemd.services.hermes-agent = {
        startLimitIntervalSec = 0;
        serviceConfig.SuccessExitStatus = [ "1" ];
        preStop = lib.mkBefore ''
          if ${pkgs.docker}/bin/docker inspect hermes-agent &>/dev/null; then
            ${pkgs.docker}/bin/docker exec hermes-agent \
              /data/current-package/bin/hermes gateway stop || true
          fi
        '';
      };

      systemd.services.hermes-dashboard = mkIf cfg.dashboard.enable {
        description = "Hermes Agent Web Dashboard";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "hermes-agent.service"
        ];
        wants = [
          "network-online.target"
          "hermes-agent.service"
        ];

        environment = {
          HOME = config.services.hermes-agent.stateDir;
          HERMES_HOME = "${config.services.hermes-agent.stateDir}/.hermes";
          HERMES_MANAGED = "true";
          # Dashboard runs on the host (separate systemd unit). Without this,
          # main() execs into the managed container where the wheel still lacks
          # hermes_cli/dashboard_auth.
          HERMES_DEV = "1";
          MESSAGING_CWD = config.services.hermes-agent.workingDirectory;
        };

        serviceConfig = {
          User = config.services.hermes-agent.user;
          Group = config.services.hermes-agent.group;
          SupplementaryGroups = [ "docker" ];
          WorkingDirectory = config.services.hermes-agent.workingDirectory;
          ExecStart = lib.concatStringsSep " " (
            [
              "${hermesDashboardWrapper}"
              "dashboard"
              "--host"
              cfg.dashboard.host
              "--port"
              (toString cfg.dashboard.port)
              "--no-open"
              "--tui"
            ]
            ++ lib.optional cfg.dashboard.insecure "--insecure"
          );
          Restart = "always";
          RestartSec = 5;
          UMask = "0007";
        };

        path = [
          hermesDashboardWrapper
          config.services.hermes-agent.package
          pkgs.docker
          pkgs.bash
          pkgs.coreutils
          pkgs.git
        ];
      };
    })
  ];
}
