{ lib, isLinux, ... }:
{
  imports = lib.optionals isLinux [
    ../modules/nixos/gaming.nix
  ];
}
