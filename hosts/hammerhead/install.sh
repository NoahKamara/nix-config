#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

REPO_URL="https://github.com/noahkamara/nix-config.git"
FLAKE_HOST="hammerhead"
WORK_DIR="${WORK_DIR:-$HOME/nix-config}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  error "This installer is for macOS only."
  exit 1
fi

ensure_xcode_cli() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi

  warn "Xcode Command Line Tools are not installed."
  info "Launching the installer dialog..."
  xcode-select --install || true

  info "Complete the installation, then press Enter to continue."
  read -r

  if ! xcode-select -p >/dev/null 2>&1; then
    error "Xcode Command Line Tools still not detected."
    exit 1
  fi
}

ensure_nix_via_lix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  info "Installing Lix (provides nix)..."
  curl -sSf -L https://install.lix.systems/lix | sh -s -- install

  # shellcheck disable=SC1091
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  if ! command -v nix >/dev/null 2>&1; then
    error "nix command not found after Lix installation."
    error "Try: . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    exit 1
  fi
}

clone_repo() {
  if [[ -d "$WORK_DIR/.git" ]]; then
    info "Reusing existing checkout at $WORK_DIR"
    return
  fi

  if [[ -e "$WORK_DIR" ]]; then
    error "$WORK_DIR exists but is not a git checkout."
    error "Set WORK_DIR to an empty path and rerun."
    exit 1
  fi

  info "Cloning nix-config to $WORK_DIR"
  git clone "$REPO_URL" "$WORK_DIR"
}

first_switch() {
  cd "$WORK_DIR"

  info "Running first nix-darwin switch for $FLAKE_HOST"
  info "You may be prompted for your password by sudo."
  sudo -i /nix/var/nix/profiles/default/bin/nix \
    --extra-experimental-features "nix-command flakes" \
    run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
    switch --flake ".#$FLAKE_HOST"
}

info "Starting fresh macOS bootstrap for $FLAKE_HOST"
ensure_xcode_cli
ensure_nix_via_lix
clone_repo
first_switch

info "Done. Future updates can use: darwin-rebuild switch --flake $WORK_DIR#$FLAKE_HOST"
