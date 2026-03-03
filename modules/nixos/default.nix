{ ... }:
let
  keys = import ../keys.nix;
  authorizedKeys = builtins.attrValues keys;
in
{
  nix.gc.dates = "weekly";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
    openFirewall = true;
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
}
