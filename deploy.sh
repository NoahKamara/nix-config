#!/usr/bin/env bash

set -euo pipefail


if [ $# -lt 1 ]; then
  echo "Usage: $0 <host>"
  echo "Available hosts:"
  nix eval --json --impure --expr 'builtins.attrNames (builtins.getFlake (toString ./.)).nixosConfigurations' | jq -r '.[]'
  exit 1
fi

HOST=$1
FQDN=$(nix eval --raw .#nixosConfigurations.${HOST}.config.networking.fqdn)

# Local evaluator system (e.g. x86_64-linux, aarch64-darwin)
LOCAL_SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')

# Target system from the flake (e.g. x86_64-linux)
TARGET_SYSTEM=$(nix eval --raw ".#nixosConfigurations.${HOST}.pkgs.stdenv.hostPlatform.system")

BUILD_FLAGS=()
if [[ "${LOCAL_SYSTEM}" != "${TARGET_SYSTEM}" ]]; then
  BUILD_FLAGS=(--build-host "root@${FQDN}")
fi

nix run nixpkgs#nixos-rebuild -- \
  switch \
  --flake ".#${HOST}" \
  --target-host "root@${FQDN}" \
  "${BUILD_FLAGS[@]}"