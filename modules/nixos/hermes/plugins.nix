{
  config,
  lib,
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
  pCfg = cfg.plugins;
in
{
  options.noah.services.hermes-agent.plugins = {
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

  config = mkIf cfg.enable {
    services.hermes-agent.settings = mkMerge [
      (lib.optionalAttrs (pCfg.enabled != [ ]) {
        plugins.enabled = pCfg.enabled;
      })
      (lib.optionalAttrs (pCfg.memoryProvider != null) {
        memory.provider = pCfg.memoryProvider;
      })
      (lib.optionalAttrs (pCfg.webBackend != null) {
        web.backend = pCfg.webBackend;
      })
    ];
  };
}
