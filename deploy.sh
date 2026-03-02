#!/usr/bin/env bash

set -euo pipefail


if [ $# -lt 1 ]; then
  echo "Usage: $0 <host>"
  echo "Available hosts:"
  nix eval --json .#deploy.nodes | jq -r 'keys[]'
  exit 1
fi

HOST=$1
nix run github:serokell/deploy-rs -- ".#${HOST}"
