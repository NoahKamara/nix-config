{ pkgs, lib, userProfile, ... }:
let
  username = userProfile.username;
  homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
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
    };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit userProfile; };
    users.${username} = import ../home;
  };
}
