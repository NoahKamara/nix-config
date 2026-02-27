{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    extest.enable = true;
  };


  environment.systemPackages = with pkgs; [
    discord
  ];
}
