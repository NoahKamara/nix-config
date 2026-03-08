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

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  # Auto-discover and sync Windows bootloader to the NixOS ESP.
  systemd.services.sync-windows-boot = {
    description = "Sync Windows bootloader to NixOS ESP";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.util-linux
      pkgs.rsync
    ];
    script = ''
      esp_source=$(findmnt -n -o SOURCE /boot)
      tmpdir=$(mktemp -d)

      for part in /dev/disk/by-uuid/*; do
        [ -L "$part" ] || continue
        resolved=$(readlink -f "$part")
        [ "$resolved" != "$esp_source" ] || continue

        fstype=$(lsblk -nro FSTYPE "$resolved" 2>/dev/null || true)
        [ "$fstype" = "vfat" ] || continue

        if mount -o ro "$resolved" "$tmpdir" 2>/dev/null; then
          if [ -f "$tmpdir/EFI/Microsoft/Boot/bootmgfw.efi" ]; then
            mkdir -p /boot/EFI/Microsoft
            rsync -a --delete "$tmpdir/EFI/Microsoft/" /boot/EFI/Microsoft/
            umount "$tmpdir"
            rmdir "$tmpdir"
            exit 0
          fi
          umount "$tmpdir"
        fi
      done

      rmdir "$tmpdir" 2>/dev/null || true
    '';
  };

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
