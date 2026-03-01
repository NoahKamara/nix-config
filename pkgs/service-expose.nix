{ pkgs }:

pkgs.writeShellScriptBin "service-expose" ''
  set -euo pipefail

  usage() {
    cat >&2 <<'EOF'
usage:
  service-expose <name> <path> <upstream> -- <command> [args...]
  service-expose list
  service-expose ls
EOF
  }

  api_base="''${SERVICE_EXPOSE_API_BASE:-http://127.0.0.1:2019}"
  routes_collection_endpoint="''${api_base}/config/apps/http/servers/srv0/routes"
  full_config_endpoint="''${api_base}/config/"
  load_endpoint="''${api_base}/load"

  list_services() {
    routes_json="$(${pkgs.curl}/bin/curl -fsS "$routes_collection_endpoint")"
    printf '%s' "$routes_json" \
      | ${pkgs.jq}/bin/jq -r '
        if type != "array" then
          empty
        else
          map(select((."@id" // "") | startswith("service-")))
          | .[]
          | [
              (."@id" | sub("^service-"; "")),
              ((.match // [] | .[0]? | .path // [] | .[0]?) // ""),
              ((.handle // [] | map(select(.handler == "reverse_proxy")) | .[0]? | .upstreams // [] | .[0]? | .dial) // "")
            ]
          | @tsv
        end' \
      | while IFS="$(printf '\t')" read -r name path upstream; do
          if [ -n "$name" ]; then
            printf '%s\t%s\t%s\n' "$name" "$path" "$upstream"
          fi
        done
  }

  if [ "$#" -eq 1 ] && [ "$1" = "list" -o "$1" = "ls" ]; then
    printf 'NAME\tPATH\tUPSTREAM\n'
    list_services
    exit 0
  fi

  if [ "$#" -lt 4 ]; then
    usage
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

  route_id="service-''${name}"
  routes_endpoint="''${api_base}/config/apps/http/servers/srv0/routes"
  replace_routes() {
    routes_json="$1"
    current_config="$(${pkgs.curl}/bin/curl -fsS "$full_config_endpoint")"
    next_config="$(printf '%s' "$current_config" \
      | ${pkgs.jq}/bin/jq -c \
        --argjson routes "$routes_json" '
          .apps.http.servers.srv0.routes = $routes
        ')"
    ${pkgs.curl}/bin/curl -fsS \
      -H "Content-Type: application/json" \
      -X POST \
      --data "$next_config" \
      "$load_endpoint" >/dev/null
  }

  register_route() {
    payload="$(${pkgs.jq}/bin/jq -n \
      --arg id "$route_id" \
      --arg path "$route_path" \
      --arg upstream "$upstream" \
      '{
        "@id": $id,
        terminal: true,
        match: [{ path: [$path, "\($path)/*"] }],
        handle: [
          {
            handler: "subroute",
            routes: [
              {
                match: [{ path: [$path] }],
                handle: [{ handler: "rewrite", uri: "/" }]
              },
              {
                match: [{ path: ["\($path)/*"] }],
                handle: [{ handler: "rewrite", strip_path_prefix: $path }]
              }
            ]
          },
          { handler: "reverse_proxy", upstreams: [{ dial: $upstream }] }
        ]
      }')"

    max_attempts=5
    attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
      existing_routes="$(${pkgs.curl}/bin/curl -fsS "$routes_endpoint")"
      updated_routes="$(printf '%s' "$existing_routes" \
        | ${pkgs.jq}/bin/jq -c \
          --arg id "$route_id" \
          --argjson route "$payload" '
            (if type == "array" then . else [] end)
            | map(select((."@id" // "") != $id))
            | [$route] + .
            | (map(select((."@id" // "") != "fallback-404")) + map(select((."@id" // "") == "fallback-404")))
          ')"

      if replace_routes "$updated_routes"; then
        return 0
      fi

      if [ "$attempt" -lt "$max_attempts" ]; then
        sleep 1
      fi
      attempt=$((attempt + 1))
    done

    echo "service-expose: failed to register route '$route_id' after $max_attempts attempts" >&2
    return 1
  }

  unregister_route() {
    max_attempts=5
    attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
      existing_routes="$(${pkgs.curl}/bin/curl -fsS "$routes_endpoint")"
      updated_routes="$(printf '%s' "$existing_routes" \
        | ${pkgs.jq}/bin/jq -c \
          --arg id "$route_id" '
            (if type == "array" then . else [] end)
            | map(select((."@id" // "") != $id))
            | (map(select((."@id" // "") != "fallback-404")) + map(select((."@id" // "") == "fallback-404")))
          ')"

      if replace_routes "$updated_routes"; then
        return 0
      fi

      if [ "$attempt" -lt "$max_attempts" ]; then
        sleep 1
      fi
      attempt=$((attempt + 1))
    done

    return 0
  }

  child_pid=""
  cleanup_ran=0

  cleanup() {
    # Avoid running cleanup twice when both signal and EXIT traps fire.
    if [ "$cleanup_ran" -eq 1 ]; then
      return
    fi
    cleanup_ran=1

    if [ -n "$child_pid" ]; then
      kill "$child_pid" >/dev/null 2>&1 || true
    fi
    unregister_route
  }

  trap cleanup EXIT INT TERM HUP QUIT

  register_route
  "$@" &
  child_pid=$!
  wait "$child_pid"
''
