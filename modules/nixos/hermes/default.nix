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
    mkMerge
    mkOption
    types
    ;

  cfg = config.noah.services.hermes-agent;
  defaultHostUser =
    if userProfile != null && userProfile ? username then userProfile.username else "noah";
  hermesAgentInput = inputs.hermes-agent;
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;

  # Wrap each registered skill's source dir as <name>/SKILL.md so it can be
  # passed to the agent's skills.external_dirs (one dir per skill).
  mkSkillDir =
    name: src:
    pkgs.runCommand "hermes-skill-${name}" { } ''
      mkdir -p $out/${name}
      cp -r ${src}/. $out/${name}/
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
    ./dashboard.nix
    ./calendar.nix
    ./email.nix
    ./todoist.nix
    ./plugins.nix
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

    internalSkills = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            source = mkOption {
              type = types.path;
              description = "Directory containing the skill's SKILL.md (and any assets).";
            };
            alwaysLoad = mkOption {
              type = types.bool;
              default = false;
              description = "Add this skill to config.yaml skills.always_load.";
            };
          };
        }
      );
      default = { };
      internal = true;
      description = ''
        Skill registry populated by domain modules (calendar, email, …).
        Rendered once into skills.always_load / skills.external_dirs to avoid
        the recursiveUpdate list-clobber that direct settings writes would hit.
      '';
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = lib.mkDefault true;

    services.hermes-agent = {
      enable = true;
      # Default package omits messaging SDKs; lazy-install cannot write to /nix/store.
      package = hermesPackage;
      addToSystemPackages = true;
      environmentFiles =
        if cfg.sopsSecretName != null then [ config.sops.secrets.${cfg.sopsSecretName}.path ] else [ ];

      container = {
        enable = true;
        backend = "docker";
        inherit (cfg.container) hostUsers extraVolumes;
      };

      settings = mkMerge [
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
        (lib.optionalAttrs (cfg.internalSkills != { }) {
          skills.always_load = lib.attrNames (lib.filterAttrs (_: s: s.alwaysLoad) cfg.internalSkills);
          skills.external_dirs = lib.mapAttrsToList (name: s: mkSkillDir name s.source) cfg.internalSkills;
        })
        cfg.settings
      ];
    };

    systemd.services.hermes-agent.restartTriggers = [
      config.services.hermes-agent.package
      (pkgs.writeText "hermes-agent-restart-trigger.json" (builtins.toJSON restartTriggerConfig))
      hermesAgentInput
    ]
    ++ lib.optional (cfg.sopsSecretName != null) config.sops.secrets.${cfg.sopsSecretName}.sopsFile;

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
  };
}
