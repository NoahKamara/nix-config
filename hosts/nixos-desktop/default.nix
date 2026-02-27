{ self, inputs, lib, pkgs, ... }:

{
  imports = [
    ../../modules/shared
    ../../modules/nixos
    inputs.home-manager.nixosModules.home-manager
  ] ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "nixos-desktop";
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  programs.fish.enable = true;

  users.users.noahkamara = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.noahkamara = import ../../modules/home;
  };

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = "24.11";

  nixpkgs.hostPlatform = "x86_64-linux";
}
