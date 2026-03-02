{ self, inputs, lib, pkgs, ... }:
let
  keys = import ../../modules/keys.nix;
  authorizedKeys = builtins.attrValues keys;
in
{
  imports = [
    ../../modules/shared
    ../../modules/nixos
    ../../modules/user
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    ./disko.nix
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "chimaera";
  networking.domain = "chimaera.noahkamara.com";
  networking.fqdn = "chimaera.noahkamara.com";
  networking.useNetworkd = true;
  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Forwarding is required so the VPS can route traffic between tunnel peers
  # and toward networks reachable behind a peer.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # WireGuard server on the VPS. Keep the private key on the machine and point
  # this file path to it (for example via nixos-anywhere file upload or a
  # provisioning step).
  networking.wireguard.interfaces.wg0 = {
    ips = [
      "10.44.0.1/24"
      "fd42:44:44::1/64"
    ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/wg0.key";

    peers = [
      {
        # stardust peer
        publicKey = "bexqvHQvQgAGEKMOAuhMkDowBe1cLEX1FBCKxdVoDgo=";
        allowedIPs = [
          "10.44.0.2/32"
          "fd42:44:44::2/128"
        ];
      }
      # {
      #   # non-Nix home-network peer
      #   publicKey = "REPLACE_WITH_HOME_PEER_PUBLIC_KEY";
      #   allowedIPs = [
      #     "10.44.0.3/32"
      #     "fd42:44:44::3/128"
      #     # Route your home LAN via this peer if needed.
      #     "192.168.1.0/24"
      #   ];
      # }
    ];
  };

  systemd.tmpfiles.rules = [
    "d /etc/wireguard 0700 root root -"
  ];

  # networkd cannot use generatePrivateKeyFile; create the key before networkd.
  systemd.services.wireguard-keygen-wg0 = {
    description = "Generate WireGuard private key for wg0";
    before = [ "systemd-networkd.service" ];
    requiredBy = [ "systemd-networkd.service" ];
    path = [ pkgs.coreutils pkgs.wireguard-tools ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      install -d -m 700 /etc/wireguard
      if [ ! -s /etc/wireguard/wg0.key ]; then
        umask 077
        wg genkey > /etc/wireguard/wg0.key
      fi
      chmod 600 /etc/wireguard/wg0.key
      chown root:root /etc/wireguard/wg0.key
    '';
  };

  systemd.network.enable = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "en*";
    networkConfig.DHCP = "yes";
  };

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
  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/sda" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  services.qemuGuest.enable = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = "x86_64-linux";
}
