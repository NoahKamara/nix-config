{ pkgs, lib, userProfile, ... }:

{
  imports = [
    ./ghostty.nix
    ./hyprland.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    lazygit
    (writeShellScriptBin "use-nix" ''
      config_path="''${NIX_CONFIG_DIR:-$HOME/.nix-config}"
      shell_name="''${1:-default}"

      if [ "$shell_name" = "default" ]; then
        echo "use flake \"$config_path\"" > .envrc
      else
        echo "use flake \"$config_path#$shell_name\"" > .envrc
      fi

      direnv allow
    '')
    (writeShellScriptBin "service-expose" ''
      set -eu

      if [ "$#" -lt 4 ]; then
        echo "usage: service-expose <name> <path> <upstream> -- <command> [args...]" >&2
        exit 1
      fi

      name="$1"
      route_path="$2"
      upstream="$3"
      shift 3

      if [ "''${1:-}" = "--" ]; then
        shift
      fi

      if [ "$#" -eq 0 ]; then
        echo "service-expose: missing command to run" >&2
        exit 1
      fi

      case "$route_path" in
        /*) ;;
        *)
          echo "service-expose: route path must start with '/'" >&2
          exit 1
          ;;
      esac

      api_base="''${SERVICE_EXPOSE_API_BASE:-http://127.0.0.1:2019}"
      route_id="service-''${name}"
      routes_endpoint="''${api_base}/config/apps/http/servers/srv0/routes/0"
      id_endpoint="''${api_base}/id/''${route_id}"

      register_route() {
        payload="$(${pkgs.jq}/bin/jq -n \
          --arg id "$route_id" \
          --arg path "$route_path" \
          --arg upstream "$upstream" \
          '{
            "@id": $id,
            match: [{ path: [$path, "\($path)/*"] }],
            handle: [
              { handler: "rewrite", strip_path_prefix: $path },
              { handler: "reverse_proxy", upstreams: [{ dial: $upstream }] }
            ]
          }')"

        ${pkgs.curl}/bin/curl -fsS -X DELETE "$id_endpoint" >/dev/null 2>&1 || true
        ${pkgs.curl}/bin/curl -fsS \
          -H "Content-Type: application/json" \
          -X POST \
          --data "$payload" \
          "$routes_endpoint" >/dev/null
      }

      unregister_route() {
        ${pkgs.curl}/bin/curl -fsS -X DELETE "$id_endpoint" >/dev/null 2>&1 || true
      }

      cleanup() {
        unregister_route
      }

      trap cleanup EXIT INT TERM

      register_route
      "$@"
    '')
  ] ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
    wofi
    wl-clipboard
    grim
    slurp
    brightnessctl
    playerctl
    pavucontrol
  ]);

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      hide_env_diff = true;
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = userProfile.fullName;
      user.email = userProfile.email;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        identityFile = [
          "~/.ssh/id_ed25519"
          "~/.ssh/id_rsa"
        ];
      };
    };
  };

  home.activation.generateSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
      mkdir -p "$HOME/.ssh"
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -C "${userProfile.email}" -f "$HOME/.ssh/id_ed25519" -N ""
    fi
  '';

  programs.zoxide.enable = true;

  programs.zsh.enable = true;
  programs.fish.enable = true;

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    TERMINAL = "ghostty";
  };

  # macOS Window Management
  home.file.".aerospace.toml" = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };
}
