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
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = lib.mkDefault true;

    services.hermes-agent = {
      enable = true;
      # Default package omits messaging SDKs; lazy-install cannot write to /nix/store.
      package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;
      addToSystemPackages = true;
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
            default = "deepseek/deepseek-v4-pro";
            base_url = "https://openrouter.ai/api/v1";
          };
        }
        cfg.settings
      ];
    };

    systemd.services.hermes-agent.restartTriggers = [
      config.services.hermes-agent.package
      (pkgs.writeText "hermes-agent-restart-trigger.json" (builtins.toJSON restartTriggerConfig))
    ]
    ++ lib.optional (cfg.sopsSecretName != null) config.sops.secrets.${cfg.sopsSecretName}.sopsFile;

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
        MESSAGING_CWD = config.services.hermes-agent.workingDirectory;
      };

      serviceConfig = {
        User = config.services.hermes-agent.user;
        Group = config.services.hermes-agent.group;
        WorkingDirectory = config.services.hermes-agent.workingDirectory;
        ExecStart = lib.concatStringsSep " " (
          [
            "${lib.getExe config.services.hermes-agent.package}"
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
        config.services.hermes-agent.package
        pkgs.bash
        pkgs.coreutils
        pkgs.git
      ];
    };
  };
}
