{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  programs.steam = {
    enable = true;
    extest.enable = true;
  };

  environment.systemPackages = with pkgs; [
    discord
  ];
}
