{ pkgs, lib, userProfile, ... }:
let
  username = userProfile.username;
  homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  keys = import ../keys.nix;
  authorizedKeys = builtins.attrValues keys;
in
{
  users.users.${username} =
    {
      name = username;
      home = homeDirectory;
      shell = pkgs.fish;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      linger = true;
      openssh.authorizedKeys.keys = authorizedKeys;
    };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit userProfile; };
    users.${username} = import ../home;
  };
}
