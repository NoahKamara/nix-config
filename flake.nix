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
        comfyPkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBrokenPredicate = pkg: (pkg.pname or "") == "open-clip-torch";
            allowUnsupportedSystem = system == "aarch64-linux";
          };
        };
        comfyVersions = import "${comfyui-nix}/nix/versions.nix";
        mkComfyPackages =
          gpuSupport:
          let
            basePythonOverrides = import "${comfyui-nix}/nix/python-overrides.nix" {
              pkgs = comfyPkgs;
              versions = comfyVersions;
              inherit gpuSupport;
            };
            pythonOverrides = final: prev:
              (basePythonOverrides final prev)
              // {
                mss = prev.mss.overridePythonAttrs (_: {
                  doCheck = false;
                });
              };
          in
          import "${comfyui-nix}/nix/packages.nix" {
            pkgs = comfyPkgs;
            lib = comfyPkgs.lib;
            versions = comfyVersions;
            inherit pythonOverrides gpuSupport;
          };

        gpuSupport' = if system == "x86_64-linux" then "cuda" else "none";
        comfy = "${(mkComfyPackages gpuSupport').default}/bin/comfy-ui";
      in
      {
        default = {
          type = "app";
          program = comfy;
        };

        comfyui = {
          type = "app";
          program = comfy;
        };
      });
  };
}
