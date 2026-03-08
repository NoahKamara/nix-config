{
  userProfile,
  ...
}:
{
  imports = [ ];

  home-manager.users.${userProfile.username}.imports = [
    ../modules/home/desktop.nix
  ];
}
