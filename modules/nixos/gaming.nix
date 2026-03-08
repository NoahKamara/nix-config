{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  programs.steam = {
    enable = true;
    extest.enable = true;
  };

  environment.systemPackages = with pkgs; [
    discord
  ];
}
