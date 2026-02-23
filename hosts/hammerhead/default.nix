{ self, inputs, pkgs, ... }:

{
  imports = [
    ../../modules/shared
    ../../modules/darwin
    inputs.home-manager.darwinModules.home-manager
  ];

  programs.fish.enable = true;

  users.users.noahkamara = {
    name = "noahkamara";
    home = "/Users/noahkamara";
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.noahkamara = import ../../modules/home;
  };

  system.primaryUser = "noahkamara";

  networking.hostName = "hammerhead";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
