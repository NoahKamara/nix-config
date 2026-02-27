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
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            jq
            just
          ];
        };

      } // {
        swift = pkgs.mkShell {
          packages = with pkgs; [
            swift
            swiftformat
            clang
            pkg-config
            openssl
            zlib
          ];
        };
      });

    apps = forAllSystems (system:
      let
        comfyPackages = inputs.comfyui-nix.packages.${system};
        comfyCpu = "${comfyPackages.default}/bin/comfy-ui";
        comfyRocm =
          if system == "x86_64-linux" then "${comfyPackages.rocm}/bin/comfy-ui" else comfyCpu;
        comfyCuda =
          if system == "x86_64-linux" then "${comfyPackages.cuda}/bin/comfy-ui" else comfyCpu;
        comfyDefault = if system == "x86_64-linux" then comfyCuda else comfyCpu;
      in
      {
        default = {
          type = "app";
          program = comfyDefault;
        };

        comfyui = {
          type = "app";
          program = comfyDefault;
        };

        comfyui-cpu = {
          type = "app";
          program = comfyCpu;
        };
      } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
        comfyui-rocm = {
          type = "app";
          program = comfyRocm;
        };

        comfyui-cuda = {
          type = "app";
          program = comfyCuda;
        };
      });
  };
}
