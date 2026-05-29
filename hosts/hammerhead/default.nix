{
  config,
  inputs,
  pkgs,
  userProfile,
  ...
}:
let
  wgInterface = "wg0";
in
{
  imports = [
    ../../platform/darwin
    ../../profiles/common.nix
    ../../profiles/desktop.nix
    ../../profiles/dev.nix
    inputs.home-manager.darwinModules.home-manager
    ./sops.nix
  ];

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  system.primaryUser = userProfile.username;

  networking.hostName = "hammerhead";

  # Road-warrior WireGuard client to the VPS (chimaera).
  # nix-darwin will create a launchd daemon (wg-quick-wg0) and use wireguard-go.
  networking.wg-quick.interfaces.${wgInterface} = {
    autostart = true;
    address = [
      "10.44.0.3/32"
      "fd42:44:44::3/128"
    ];
    privateKeyFile = config.sops.secrets.wg0-private-key.path;
    peers = [
      {
        # Obtain this from the VPS:
        #   ssh root@chimaera.noahkamara.com 'wg show wg0 public-key'
        publicKey = "wilnt20OQLWs7ZDlSSodfTtkwz2mSq+S8ccYlSoQlCk=";
        allowedIPs = [
          "10.44.0.0/24"
          "fd42:44:44::/64"
        ];
        endpoint = "chimaera.noahkamara.com:51820";
        persistentKeepalive = 25;
      }
    ];
  };

  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
