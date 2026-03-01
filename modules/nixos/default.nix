{ ... }:

{
  # NixOS uses `dates` instead of Darwin's `interval` GC schedule.
  nix.gc.dates = "weekly";

  # Required by Home Manager when useUserPackages=true so desktop entries and
  # portal definitions are linked into the system profile.
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
}
