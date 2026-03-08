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
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      deploy-rs,
      pre-commit,
      lanzaboote,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      preCommitChecks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        pre-commit.lib.${system}.run {
          src = ./.;
          hooks.nix-fmt = {
            enable = true;
            name = "nix fmt";
            entry = "${pkgs.nixfmt}/bin/nixfmt";
            files = "\\.nix$";
            pass_filenames = true;
          };
        }
      );
      nixosDeployHosts = [
        "nebulon"
        "chimaera"
        "stardust"
      ];
      deployHostnames = {
        chimaera = "chimaera.noahkamara.com";
      };
      userProfile = {
        username = "noah";
        fullName = "Noah Kamara";
        email = "mail@noahkamara.com";
      };
      baseSpecialArgs = { inherit self inputs; };
      mkNixosHost =
        host:
        nixpkgs.lib.nixosSystem {
          specialArgs = baseSpecialArgs // {
            inherit userProfile;
            isDarwin = false;
            isLinux = true;
          };
          modules = [ ./hosts/${host} ];
        };
      mkDarwinHost =
        {
          host,
          userProfileOverride ? { },
        }:
        nix-darwin.lib.darwinSystem {
          specialArgs = baseSpecialArgs // {
            userProfile = userProfile // userProfileOverride;
            isDarwin = true;
            isLinux = false;
          };
          modules = [ ./hosts/${host} ];
        };
    in
    {
      # Macbook Pro 14"
      darwinConfigurations."hammerhead" = mkDarwinHost {
        host = "hammerhead";
        userProfileOverride = {
          username = "noahkamara";
        };
      };

      # Workstation PC
      nixosConfigurations."nebulon" = mkNixosHost "nebulon";

      # VPS
      nixosConfigurations."chimaera" = mkNixosHost "chimaera";

      # NAS
      nixosConfigurations."stardust" = mkNixosHost "stardust";

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          default = pkgs.mkShellNoCC {
            packages =
              (with pkgs; [
                jq
                just
                nil
                nixd
                nixfmt
              ])
              ++ preCommitChecks.${system}.enabledPackages;
            shellHook = preCommitChecks.${system}.shellHook;
          };

        }
        // {
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
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        pkgs.nixfmt
      );

      deploy = {
        # Allow extra time for post-activation reconnect when network services restart.
        confirmTimeout = 300;
        nodes = nixpkgs.lib.genAttrs nixosDeployHosts (
          host:
          let
            nixosConfig = self.nixosConfigurations.${host};
            targetSystem = nixosConfig.pkgs.stdenv.hostPlatform.system;
            localSystem = if builtins ? currentSystem then builtins.currentSystem else "unknown";
          in
          {
            hostname = deployHostnames.${host} or nixosConfig.config.networking.hostName;
            sshUser = "root";

            remoteBuild = targetSystem != localSystem;

            profiles.system = {
              user = "root";
              path = deploy-rs.lib.${targetSystem}.activate.nixos nixosConfig;
            };
          }
        );
      };

      checks =
        (builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib)
        // forAllSystems (system: {
          pre-commit = preCommitChecks.${system};
        });
    };
}
