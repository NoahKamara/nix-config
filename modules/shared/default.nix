{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.enable = true;

  nixpkgs.config.allowUnfree = true;
}
