{ self, inputs, ... }:

{
  imports = [
    ../../modules/shared
    ../../modules/darwin
    inputs.home-manager.darwinModules.home-manager
  ];

  users.users.noahkamara = {
    name = "noahkamara";
    home = "/Users/noahkamara";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.noahkamara = import ../../modules/home;
  };

  system.primaryUser = "noahkamara";

  networking.hostName = "hammerhead";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
