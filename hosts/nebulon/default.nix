{
  inputs,
  lib,
  pkgs,
  config,
  userProfile,
  ...
}:
{
  imports = [
    ../../platform/nixos
    ../../profiles/common.nix
    ../../profiles/desktop.nix
    ../../profiles/dev.nix
    ../../profiles/gaming.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.lanzaboote.nixosModules.lanzaboote
  ]
  ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
  ++ [
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  networking.hostName = "nebulon";
  networking.networkmanager.enable = true;
  networking.interfaces.enp34s0.wakeOnLan = {
    enable = true;
    policy = [ "magic" ];
  };

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.systemd-boot.configurationLimit = 12;
  boot.loader.systemd-boot.windows = {
    # Find this via EDK2 shell `map -c` + `ls <HANDLE>:\\EFI` (e.g. HD0b1 or FS1).
    main.efiDeviceHandle = "HD0b1";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.xserver.enable = false;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions --cmd start-hyprland";
      };
    };
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;
  services.dbus.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  system.stateVersion = "24.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  environment.systemPackages = with pkgs; [
    sbctl
  ];

  networking.firewall.allowedTCPPorts = [
    5900
    8188
  ];
}
