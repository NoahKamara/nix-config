{ self, inputs, lib, pkgs, ... }:
{
  imports = [
    ../../modules/shared
    ../../modules/nixos
    ../../modules/user
    inputs.home-manager.nixosModules.home-manager
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix ++ [
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  networking.hostName = "stardust";
  networking.networkmanager.enable = true;

  services.qemuGuest.enable = true;

  # Required when Home Manager user packages provide xdg portal files.
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    openFirewall = true;
  };

  # Add authorized keys for root user
  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  programs.fish.enable = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "24.11";

  nixpkgs.hostPlatform = "x86_64-linux";
}
