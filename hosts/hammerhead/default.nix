{ self, inputs, pkgs, userProfile, ... }:
{
  imports = [
    ../../modules/shared
    ../../modules/darwin
    ../../modules/darwin/gaming.nix
    ../../modules/user
    inputs.home-manager.darwinModules.home-manager
  ];

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  system.primaryUser = userProfile.username;

  networking.hostName = "hammerhead";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
