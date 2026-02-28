{ self, inputs, lib, pkgs, ... }:
{
  imports = [
    ../../modules/shared
    ../../modules/nixos
    ../../modules/nixos/gaming.nix
    ../../modules/user
    inputs.home-manager.nixosModules.home-manager
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix ++ [
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  networking.hostName = "nebulon";
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
    editor = false;
    extraEntries = {
      "windows.conf" = ''
        title Windows
        efi /EFI/Microsoft/Boot/bootmgfw.efi
      '';
    };
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Mount Windows EFI partition read-only; nofail so boot continues if the disk is absent
  fileSystems."/mnt/win-efi" = {
    device = "/dev/disk/by-uuid/__WIN_ESP_UUID__";
    fsType = "vfat";
    options = [ "ro" "nofail" "noauto" ];
  };

  # Sync Windows bootloader to NixOS ESP so systemd-boot can see it
  systemd.services.sync-windows-boot = {
    description = "Sync Windows bootloader to NixOS ESP";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.util-linux pkgs.rsync ];
    script = ''
      if mount /mnt/win-efi 2>/dev/null; then
        if [ -d /mnt/win-efi/EFI/Microsoft ]; then
          mkdir -p /boot/EFI/Microsoft
          rsync -a --delete /mnt/win-efi/EFI/Microsoft/ /boot/EFI/Microsoft/
        fi
        umount /mnt/win-efi
      fi
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
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
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

  hardware.graphics.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  programs.fish.enable = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "24.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    wayvnc
  ];

  networking.firewall.allowedTCPPorts = [ 5900 ];

  systemd.user.services.wayvnc = {
    description = "WayVNC server";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

}
