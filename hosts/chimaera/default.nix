{ inputs, lib, pkgs, ... }:
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
  networking.useNetworkd = true;

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
  programs.fish.enable = true;

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

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
