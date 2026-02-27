{ self, inputs, pkgs, userProfile, ... }:
let
  localUserProfile = userProfile // {
    username = "noahkamara";
  };
  username = localUserProfile.username;
in {
  imports = [
    ../../modules/shared
    ../../modules/darwin
    ../../modules/user
    inputs.home-manager.darwinModules.home-manager
  ];

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  system.primaryUser = username;
  _module.args.userProfile = localUserProfile;

  networking.hostName = "hammerhead";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
