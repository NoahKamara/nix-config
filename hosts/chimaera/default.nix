{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/shared
    ../../modules/nixos
    ../../modules/user
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    ./disko.nix
  ]
  ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "chimaera";
  networking.domain = "chimaera.noahkamara.com";
  networking.fqdn = "chimaera.noahkamara.com";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.nat = {
    enable = true;
    # SNAT/MASQUERADE tunnel egress so replies route back through the VPS.
    externalInterface = "en+";
    internalInterfaces = [ "wg0" ];
  };

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
        # home-network
        publicKey = "W4+RVW+EUFaGhDMGN+VN2e/HxojGizhmHusmyKdC/Fw=";
        allowedIPs = [
          "10.44.0.2/32"
          "fd42:44:44::2/128"
          "192.168.178.0/24"
        ];
      }
      # {
      #   # stardust peer
      #   publicKey = "";
      #   allowedIPs = [
      #     "10.44.0.3/32"
      #     "fd42:44:44::3/128"
      #   ];
      # }
      # {
      #   # hammerhead
      #   publicKey = "hZfrGb9gDFAm0OyQgF1MauMCTw8btwXGQ9LsixQYWS8=";
      #   allowedIPs = [
      #     "10.44.0.4/32"
      #     "fd42:44:44::4/128"
      #   ];
      # }
    ];
  };

  systemd.tmpfiles.rules = [
    "d /etc/wireguard 0700 root root -"
  ];

  # Generate the WireGuard key at boot if missing, decoupled from networkd restarts.
  systemd.services.wireguard-keygen-wg0 = {
    description = "Generate WireGuard private key for wg0";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!/etc/wireguard/wg0.key";
    path = [
      pkgs.coreutils
      pkgs.wireguard-tools
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      keyFile=/etc/wireguard/wg0.key
      install -d -m 700 /etc/wireguard
      if [ -s "$keyFile" ]; then
        chmod 600 "$keyFile"
        chown root:root "$keyFile"
        exit 0
      fi

      tmpKeyFile="$(mktemp /etc/wireguard/wg0.key.XXXXXX)"
      umask 077
      wg genkey > "$tmpKeyFile"
      chmod 600 "$tmpKeyFile"
      chown root:root "$tmpKeyFile"
      mv -f "$tmpKeyFile" "$keyFile"
    '';
  };

  systemd.network.enable = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "en*";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    addresses = [
      { addressConfig.Address = "2a01:4f8:1c19:f643::1/64"; }
    ];
    routes = [
      { routeConfig.Gateway = "fe80::1"; }
    ];
  };

  networking.nameservers = [
    "2a01:4ff:ff00::add:1"
    "2a01:4ff:ff00::add:2"
  ];

  services.caddy = {
    enable = true;
    email = "mail@noahkamara.com";
    virtualHosts = {
      # Media Stack
      "jellyfin.chimaera.noahkamara.com".extraConfig = ''
        reverse_proxy 10.44.0.2:8096
      '';
      "jellyseer.noahkamara.com".extraConfig = ''
        reverse_proxy 10.44.0.2:5055
      '';
      # Home
      "home.noahkamara.com".extraConfig = ''
        reverse_proxy 192.168.178.71:8123
      '';
    };
  };

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/sda" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  services.qemuGuest.enable = true;

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = "x86_64-linux";
}
