{
  config,
  lib,
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

  cfg = config.noah.services.forgejo;
  forgejoCfg = config.services.forgejo;
  forgejoExe = lib.getExe forgejoCfg.package;
  defaultAdminUsername =
    if userProfile != null && userProfile ? username then userProfile.username else "forgejo-admin";
  defaultAdminEmail =
    if userProfile != null && userProfile ? email then userProfile.email else "admin@example.invalid";
in
{
  options.noah.services.forgejo = {
    enable = mkEnableOption "Forgejo behind Caddy";

    hostName = mkOption {
      type = types.str;
      example = "git.example.com";
      description = "Public hostname served by Caddy for Forgejo.";
    };

    httpPort = mkOption {
      type = types.port;
      default = 3000;
      description = "Local HTTP port used by the Forgejo web service.";
    };

    sshPort = mkOption {
      type = types.port;
      default = 22;
      description = "Public SSH port advertised in clone URLs.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo";
      description = "Forgejo state directory.";
    };

    backup = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable periodic local Forgejo dumps.";
      };

      interval = mkOption {
        type = types.str;
        default = "04:31";
        description = "systemd timer expression for Forgejo dumps.";
      };
    };

    bootstrapAdmin = {
      enable = mkEnableOption "one-shot Forgejo admin bootstrap";

      username = mkOption {
        type = types.str;
        default = defaultAdminUsername;
        description = "Username for the initial Forgejo admin.";
      };

      email = mkOption {
        type = types.str;
        default = defaultAdminEmail;
        description = "Email address for the initial Forgejo admin.";
      };

      passwordFile = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/bootstrap/admin-password";
        description = "Root-only file storing the generated initial admin password.";
      };

      markerFile = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/bootstrap/admin-created";
        description = "Sentinel file indicating the initial admin bootstrap completed.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      inherit (cfg) stateDir;

      database.type = "postgres";

      dump = {
        enable = cfg.backup.enable;
        interval = cfg.backup.interval;
      };

      settings = {
        server = {
          DOMAIN = cfg.hostName;
          ROOT_URL = "https://${cfg.hostName}/";
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = cfg.httpPort;
          DISABLE_SSH = false;
          SSH_DOMAIN = cfg.hostName;
          SSH_PORT = cfg.sshPort;
        };

        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = false;
        };

        session = {
          COOKIE_SECURE = true;
        };
      };
    };

    services.caddy.virtualHosts.${cfg.hostName}.extraConfig = ''
      encode zstd gzip
      reverse_proxy 127.0.0.1:${toString cfg.httpPort}
    '';

    systemd.tmpfiles.rules = mkIf cfg.bootstrapAdmin.enable [
      "d '${cfg.stateDir}/bootstrap' 0700 root root - -"
    ];

    systemd.services.forgejo-bootstrap-admin = mkIf cfg.bootstrapAdmin.enable {
      description = "Bootstrap initial Forgejo admin";
      wantedBy = [ "multi-user.target" ];
      after = [
        "forgejo.service"
        "postgresql.service"
      ];
      requires = [
        "forgejo.service"
        "postgresql.service"
      ];
      unitConfig.ConditionPathExists = "!${cfg.bootstrapAdmin.markerFile}";
      path = with pkgs; [
        coreutils
        openssl
        ripgrep
        util-linux
      ];
      script = ''
        set -eu

        password_file='${cfg.bootstrapAdmin.passwordFile}'
        marker_file='${cfg.bootstrapAdmin.markerFile}'
        bootstrap_dir="$(dirname "$password_file")"

        install -d -m 0700 -o root -g root "$bootstrap_dir"

        if runuser -u ${forgejoCfg.user} -- \
          ${forgejoExe} \
          -w ${cfg.stateDir} \
          -c ${cfg.stateDir}/custom/conf/app.ini \
          admin user list --admin | rg -w -- '${cfg.bootstrapAdmin.username}' >/dev/null
        then
          install -m 0600 -o root -g root /dev/null "$marker_file"
          exit 0
        fi

        if [ ! -s "$password_file" ]; then
          umask 077
          openssl rand -base64 24 > "$password_file"
          chmod 0600 "$password_file"
          chown root:root "$password_file"
        fi

        password="$(cat "$password_file")"

        runuser -u ${forgejoCfg.user} -- \
          ${forgejoExe} \
          -w ${cfg.stateDir} \
          -c ${cfg.stateDir}/custom/conf/app.ini \
          admin user create \
          --username '${cfg.bootstrapAdmin.username}' \
          --email '${cfg.bootstrapAdmin.email}' \
          --password "$password" \
          --admin \
          --must-change-password

        install -m 0600 -o root -g root /dev/null "$marker_file"
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
