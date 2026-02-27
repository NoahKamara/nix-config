{
  description = "Nix configuration monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    comfyui-nix.url = "github:utensils/comfyui-nix/8b2a35890823c8529a25a57c4d9fdbd712aa3b38";
    comfyui-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, comfyui-nix, ... } @ inputs:
  let
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    userProfile = {
      username = "noah";
      fullName = "Noah Kamara";
      email = "mail@noahkamara.com";
    };
  in
  {
    darwinConfigurations."hammerhead" = nix-darwin.lib.darwinSystem {
      specialArgs = { 
        inherit self inputs;
        userProfile = userProfile // { username = "noahkamara"; };
      };
      modules = [ ./hosts/hammerhead ];
    };

    nixosConfigurations."nebulon" = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit self inputs userProfile; };
      modules = [ ./hosts/nebulon ];
    };

    devShells = forAllSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
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
        };
      });
  };
}
