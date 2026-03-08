{
  lib,
  isDarwin,
  isLinux,
  userProfile,
  ...
}:
{
  imports =
    lib.optionals isDarwin [ ../modules/darwin/service-proxy.nix ]
    ++ lib.optionals isLinux [ ../modules/nixos/service-proxy.nix ];

  home-manager.users.${userProfile.username}.imports = [
    ../modules/home/desktop.nix
  ];
}
