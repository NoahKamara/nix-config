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
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = lib.mkDefault true;

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
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
  };
}
