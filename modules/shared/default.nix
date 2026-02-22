{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    curl
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.enable = true;

  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 2; Minute = 0; };
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;
}
