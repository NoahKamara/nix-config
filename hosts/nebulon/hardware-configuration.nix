{ lib, ... }:

{
  # Placeholder to keep flake evaluation/build working before first install.
  # Replace this file with `nixos-generate-config` output on the target machine.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];
}
