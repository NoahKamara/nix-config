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

  # Auto-discover and sync Windows bootloader to NixOS ESP so systemd-boot can see it
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
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    wayvnc
  ];

  networking.firewall.allowedTCPPorts = [ 5900 8188 ];

  systemd.user.services.wayvnc = {
    description = "WayVNC server";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "start-wayvnc" ''
        set -eu

        runtime_dir="/run/user/$(id -u)"
        while true; do
          socket="$(ls "$runtime_dir"/wayland-* 2>/dev/null | head -n1 || true)"
          if [ -n "$socket" ]; then
            wayland_display="$(basename "$socket")"
            exec ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900 --socket "$wayland_display"
          fi
          sleep 2
        done
      '';
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

}
