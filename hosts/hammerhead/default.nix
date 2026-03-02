{ self, inputs, lib, pkgs, userProfile, ... }:
let
  wgInterface = "wg0";
  wgPrivateKeyFile = "/etc/wireguard/${wgInterface}.key";
in
{
  imports = [
    ../../modules/shared
    ../../modules/darwin
    ../../modules/darwin/service-proxy.nix
    ../../modules/darwin/gaming.nix
    ../../modules/user
    inputs.home-manager.darwinModules.home-manager
  ];

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  system.primaryUser = userProfile.username;

  networking.hostName = "hammerhead";

  # Road-warrior WireGuard client to the VPS (chimaera).
  # Replace the placeholder server public key, then set autostart = true.
  networking.wg-quick.interfaces.${wgInterface} = {
    autostart = false;
    address = [
      "10.44.0.3/32"
      "fd42:44:44::3/128"
    ];
    privateKeyFile = wgPrivateKeyFile;
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

  # Keep the private key local on the machine and generate it once.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    set -eu
    /usr/bin/install -d -m 700 /etc/wireguard
    if [ ! -s "${wgPrivateKeyFile}" ]; then
      umask 077
      ${pkgs.wireguard-tools}/bin/wg genkey > "${wgPrivateKeyFile}"
    fi
    /bin/chmod 600 "${wgPrivateKeyFile}"
    /usr/sbin/chown root:wheel "${wgPrivateKeyFile}"
  '';

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
