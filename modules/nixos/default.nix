{ ... }:

{
  imports = [
    ./gaming.nix
  ];

  # NixOS uses `dates` instead of Darwin's `interval` GC schedule.
  nix.gc.dates = "weekly";
}
