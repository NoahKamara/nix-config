{ pkgs }:

pkgs.writeShellScriptBin "service-expose" ''
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

  trap unregister_route EXIT INT TERM

  register_route
  "$@"
''
