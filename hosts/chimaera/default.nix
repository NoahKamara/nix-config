{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ../../platform/nixos
    ../../modules/nixos/sops.nix
    ../../modules/nixos/forgejo.nix
    ../../modules/nixos/wg-dns.nix
    ../../modules/nixos/hermes
    ./sops.nix
    ../../profiles/common.nix
    ../../profiles/dev.nix
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
  noah.services.forgejo = {
    enable = true;
    hostName = "git.noahkamara.com";
    bootstrapAdmin.enable = true;
  };
  # Split DNS for WireGuard clients: these names → 10.44.0.1 (Caddy on chimaera).
  noah.services.wg-dns = {
    enable = true;
    hosts = [
      "agent.noahkamara.com" # Hermes (WG-gated)
      "chimaera.noahkamara.com" # SSH / deploy via tunnel
      "git.noahkamara.com" # Forgejo
      "jellyfin.noahkamara.com" # media stack (home-network peer)
      "jellyseer.noahkamara.com"
      "home.noahkamara.com" # Home Assistant (192.168.178.71 via home-network peer)
    ];
  };
  noah.services.hermes-agent = {
    enable = true;
    dashboard.insecure = true;
    soul = ../../modules/nixos/hermes/SOUL.md;
    calendar = {
      enable = true;
      collections = [
        "home" # Privat
        "6BF07365-CE70-4C52-A646-EABDE233726D" # Events & Friends
        "16bc2f30-e9b8-4f7e-b84e-83957740ac0c" # Familie
        "7A1B3D74-0CC1-4734-8793-1B982BBF0407" # Mela
      ];
    };
    todoist.enable = true;
    todoist.delegation.enable = true;
    agentmail.enable = true;
    agentmail.poll.enable = true;
    builtinSkills = {
      maps = true;
      obsidian = true;
      plan = true;
      segment-anything-model = true;
    };
    plugins = {
      enabled = [
        "security-guidance"
        "disk-cleanup"
      ];
      memoryProvider = "holographic";
    };
  };
  networking.firewall.allowedUDPPorts = [
    51820
    64738
  ];
  networking.firewall.allowedTCPPorts = [
    80
    443
    64738
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

  networking.wireguard.interfaces.wg0 = {
    ips = [
      "10.44.0.1/24"
      "fd42:44:44::1/64"
    ];
    mtu = 1380;
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.wg0-private-key.path;

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
      {
        # hammerhead
        publicKey = "X6JrUfnkc8D0QiqIOsm+1j9rbLifX1+H0Msu3Y7x4WM=";
        allowedIPs = [
          "10.44.0.3/32"
          "fd42:44:44::3/128"
        ];
      }
      {
        # phone (Atomic mobile) — wg pubkey < phone.private, then uncomment
        publicKey = "JsQNqcR1hIHv58ASb5TA9PKu9zwvgPYR3i5noI/4rQk=";
        allowedIPs = [
          "10.44.0.4/32"
          "fd42:44:44::4/128"
        ];
      }
    ];
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
      "jellyfin.noahkamara.com".extraConfig = ''
        reverse_proxy 10.44.0.2:8096
      '';
      "jellyseer.noahkamara.com".extraConfig = ''
        reverse_proxy 10.44.0.2:5055
      '';
      # Home
      "home.noahkamara.com".extraConfig = ''
        reverse_proxy 192.168.178.71:8123
      '';
      # Hermes — WireGuard-gated dashboard + OpenAI-compatible API (Atomic mobile)
      "agent.noahkamara.com".extraConfig = ''
        @wireguard remote_ip 10.44.0.0/24 fd42:44:44::/64 192.168.178.0/24
        handle @wireguard {
          handle /v1/* {
            reverse_proxy 127.0.0.1:${toString config.noah.services.hermes-agent.apiServer.port}
          }
          handle /api/* {
            reverse_proxy 127.0.0.1:${toString config.noah.services.hermes-agent.apiServer.port}
          }
          handle {
            reverse_proxy 127.0.0.1:${toString config.noah.services.hermes-agent.dashboard.port}
          }
        }
        respond 404
      '';
    };
  };

  # Mumble (Murmur) voice server.
  services.murmur = {
    enable = true;
    openFirewall = false; # managed explicitly above
    registerName = "chimaera";
    bandwidth = 128000;
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
