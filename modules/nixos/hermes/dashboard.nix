{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;

  cfg = config.noah.services.hermes-agent;
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
in
{
  options.noah.services.hermes-agent.dashboard = {
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

  config = mkIf (cfg.enable && cfg.dashboard.enable) {
    services.hermes-agent.environment = lib.optionalAttrs (cfg.dashboard.publicUrl != null) {
      HERMES_DASHBOARD_PUBLIC_URL = cfg.dashboard.publicUrl;
    };

    system.activationScripts.hermes-cli-subpackages = lib.stringAfter [ "hermes-agent-setup" ] ''
      rm -rf ${hermesCliOverlayRoot}
      OVERLAY="${hermesCliOverlayRoot}/hermes_cli"
      mkdir -p "$OVERLAY/dashboard_auth" "$OVERLAY/proxy"
      cp -r ${hermesAgentInput}/hermes_cli/dashboard_auth/. "$OVERLAY/dashboard_auth/"
      cp -r ${hermesAgentInput}/hermes_cli/proxy/. "$OVERLAY/proxy/"
      chown -R ${hermesUser}:${hermesGroup} ${hermesCliOverlayRoot}
    '';

    systemd.services.hermes-dashboard = {
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
  };
}
