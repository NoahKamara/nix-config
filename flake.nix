{
  description = "Nix configuration monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
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
              let
                baseOverrides = (basePythonOverrides final prev) // {
                  mss = prev.mss.overridePythonAttrs (_: {
                    doCheck = false;
                  });
                };
              in
              baseOverrides
              // {
                # Keep xformers enabled but force low parallelism to avoid
                # cicc/nvcc OOM kills during FlashAttention compilation.
                xformers = baseOverrides.xformers.overridePythonAttrs (old: {
                  enableParallelBuilding = false;
                  MAX_JOBS = "2";
                  NVCC_THREADS = "1";
                  NIX_BUILD_CORES = "2";
                  CMAKE_BUILD_PARALLEL_LEVEL = "2";
                  XFORMERS_DISABLE_FLASH_ATTN = "1";
                  XFORMERS_DISABLE_FLASH_ATTN_3 = "1";
                  preBuild = (old.preBuild or "") + ''
                    export MAX_JOBS=2
                    export NVCC_THREADS=1
                    export NIX_BUILD_CORES=2
                    export CMAKE_BUILD_PARALLEL_LEVEL=2
                    export TORCH_CUDA_ARCH_LIST=8.9
                    export CUDAARCHS=89
                  '';
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
