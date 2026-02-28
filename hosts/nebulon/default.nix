{ self, inputs, lib, pkgs, ... }:
{
  imports = [
    ../../modules/shared
    ../../modules/nixos
    ../../modules/user
    inputs.home-manager.nixosModules.home-manager
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

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

  boot.initrd.luks.devices.cryptswap = {
    device = "/dev/disk/by-uuid/eaa36e47-8a07-42b1-ae38-e9356d0d4ce7";
    allowDiscards = true;
  };

  swapDevices = [
    { device = "/dev/mapper/cryptswap"; }
  ];

  boot.resumeDevice = "/dev/mapper/cryptswap";
	
  programs.hyprland.enable = true;

  services.xserver.enable = false;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd Hyprland";
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
