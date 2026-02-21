{
  description = "nix-darwin system flake (macOS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        with pkgs; [
          git
          vim
        ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      # Enable Nix daemon (recommended on macOS).
      services.nix-daemon.enable = true;

      # If you use unfree packages, keep this on (e.g. 1Password, some fonts).
      nixpkgs.config.allowUnfree = true;

      # Hostname should match the flake output name (darwinConfigurations.<name>).
      networking.hostName = "hammerhead";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#hammerhead
    darwinConfigurations."hammerhead" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
  };
}
