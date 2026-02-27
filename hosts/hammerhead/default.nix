{ self, inputs, pkgs, ... }:
let 
  username = "noah";
in {
  imports = [
    ../../modules/shared
    ../../modules/darwin
    inputs.home-manager.darwinModules.home-manager
  ];

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${username} = import ../../modules/home;
  };

  system.primaryUser = username;

  # nix-darwin does not change the shell for existing users by default
  # so we use an activation script to enforce it declaratively.
  system.activationScripts.postActivation.text = ''
    if [ "$(/usr/bin/dscl . -read /Users/${username} UserShell | awk '{print $2}')" != "/run/current-system/sw/bin/fish" ]; then
      echo "Changing user shell to fish..."
      chsh -s /run/current-system/sw/bin/fish ${username}
    fi
  '';

  networking.hostName = "hammerhead";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
