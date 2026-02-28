#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

REPO_RAW_BASE="https://raw.githubusercontent.com/noahkamara/nix-config/main"

run_local_or_remote() {
  local rel_path="$1"

  if [[ -f "$rel_path" ]]; then
    exec bash "$rel_path"
  fi

  exec bash <(curl -sSfL "${REPO_RAW_BASE}/${rel_path}")
}

is_nixos() {
  if [[ -f /etc/os-release ]] && grep -q '^ID=nixos$' /etc/os-release; then
    return 0
  fi

  [[ -e /etc/NIXOS ]]
}

case "$(uname -s)" in
  Darwin)
    info "Detected macOS (Darwin). Running Hammerhead installer..."
    run_local_or_remote "hosts/hammerhead/install.sh"
    ;;
  Linux)
    if is_nixos; then
      info "Detected NixOS. Running Nebulon installer..."
      run_local_or_remote "hosts/nebulon/install.sh"
    else
      error "Linux detected, but this is not NixOS."
      error "This installer supports macOS (hammerhead) and NixOS (nebulon)."
      exit 1
    fi
    ;;
  *)
    error "Unsupported OS: $(uname -s)"
    error "This installer supports macOS (hammerhead) and NixOS (nebulon)."
    exit 1
    ;;
esac
