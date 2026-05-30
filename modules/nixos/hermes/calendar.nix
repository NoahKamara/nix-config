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

  cfg = config.noah.services.hermes-agent;
  calCfg = cfg.calendar;
  hermesStateDir = config.services.hermes-agent.stateDir;
  hermesUser = config.services.hermes-agent.user;
  hermesGroup = config.services.hermes-agent.group;
  containerDataDir = "/data";

  vdirsyncerCollections =
    if calCfg.collections != [ ] then
      "[${lib.concatStringsSep ", " (map (c: ''"${c}"'') calCfg.collections)}]"
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
    username = "${calCfg.appleId}"
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
in
{
  options.noah.services.hermes-agent.calendar = {
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

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || !calCfg.enable || calCfg.appleId != "";
          message = "noah.services.hermes-agent.calendar.appleId must be set when calendar is enabled.";
        }
      ];
    }
    (mkIf (cfg.enable && calCfg.enable) {
      services.hermes-agent.extraPackages = [
        pkgs.vdirsyncer
        pkgs.khal
      ];

      noah.services.hermes-agent.internalSkills.icloud-calendar = {
        source = ./skills/icloud-calendar;
        alwaysLoad = true;
      };

      systemd.services.hermes-agent.restartTriggers = lib.optional (
        calCfg.appPasswordSopsName != null
      ) config.sops.secrets.${calCfg.appPasswordSopsName}.sopsFile;

      system.activationScripts.hermes-agent-calendar = lib.stringAfter [ "hermes-agent-setup" ] ''
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
        ${lib.optionalString (calCfg.appPasswordSopsName != null) ''
          APP_PASSWORD="${config.sops.secrets.${calCfg.appPasswordSopsName}.path}"
          if [ -f "$APP_PASSWORD" ]; then
            install -o ${hermesUser} -g ${hermesGroup} -m 0600 "$APP_PASSWORD" ${hermesStateDir}/.hermes/icloud-calendar-password
          else
            echo "hermes-agent: iCloud calendar app password not found at $APP_PASSWORD" >&2
          fi
        ''}
      '';
    })
  ];
}
