{
  description = "Nix configuration monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, ... } @ inputs:
  let
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in
  {
    darwinConfigurations."hammerhead" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self inputs; };
      modules = [ ./hosts/hammerhead ];
    };

    devShells = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            jq
            just
          ];
        };

      } // {
        swift = pkgs.mkShell {
          buildInputs = with pkgs; [
            swift
            swiftformat
            clang
            pkg-config
            openssl
            zlib
          ];

          shellHook = ''
            export SWIFT_BACKTRACE=enable=yes
          '';
        };
      });
  };
}
