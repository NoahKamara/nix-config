{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    extest.enable = true;
  };

  environment.systemPackages = with pkgs; [
    discord
  ];
}
