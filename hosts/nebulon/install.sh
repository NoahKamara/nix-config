#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

REPO_URL="https://github.com/noahkamara/nix-config.git"
FLAKE_HOST="nebulon"
WORK_DIR="/root/nix-config"

# --- Preflight checks ---

if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root (sudo -i first)."
  exit 1
fi

# --- Step 1: Clone config ---

info "Cloning nix-config..."
if [[ -d "$WORK_DIR" ]]; then
  warn "$WORK_DIR already exists."
  read -rp "Delete and re-clone? [y/N] " ans
  if [[ "${ans,,}" == "y" ]]; then
    rm -rf "$WORK_DIR"
  else
    info "Reusing existing $WORK_DIR"
  fi
fi

if [[ ! -d "$WORK_DIR" ]]; then
  nix-shell -p git --run "git clone $REPO_URL $WORK_DIR"
fi
cd "$WORK_DIR"

# --- Step 2: Generate hardware config ---

info "Generating hardware configuration..."
rm -rf /tmp/hw-config
nixos-generate-config --root /tmp/hw-config --no-filesystems
cp /tmp/hw-config/etc/nixos/hardware-configuration.nix "./hosts/$FLAKE_HOST/hardware-configuration.nix"
info "Hardware config written to hosts/$FLAKE_HOST/hardware-configuration.nix"

# --- Step 3: Disk selection ---

echo ""
echo -e "${BOLD}Available disks:${NC}"
echo ""
lsblk -o NAME,SIZE,TYPE,MODEL -d -e 7,11
echo ""

# Collect by-id links, deduplicate by resolved device (keep longest name per device)
declare -A seen_devices
declare -a DISK_IDS=()

while IFS= read -r link; do
  [[ -z "$link" ]] && continue
  target=$(readlink -f "$link")
  name=$(basename "$link")
  if [[ -z "${seen_devices[$target]+x}" ]] || [[ ${#name} -gt ${#seen_devices[$target]} ]]; then
    if [[ -z "${seen_devices[$target]+x}" ]]; then
      DISK_IDS+=("$target")
    fi
    seen_devices[$target]="$name"
  fi
done < <(find /dev/disk/by-id/ -maxdepth 1 -not -name '*-part*' -type l 2>/dev/null | sort)

if [[ ${#DISK_IDS[@]} -eq 0 ]]; then
  error "No disks found in /dev/disk/by-id/. Cannot continue."
  exit 1
fi

echo -e "${BOLD}Select a disk by number:${NC}"
echo ""
for i in "${!DISK_IDS[@]}"; do
  target="${DISK_IDS[$i]}"
  name="${seen_devices[$target]}"
  size=$(lsblk -ndro SIZE "$target" 2>/dev/null || echo "???")
  model=$(lsblk -ndro MODEL "$target" 2>/dev/null || echo "")
  echo "  [$i] $target  ($size) $model"
  echo "      by-id: $name"
done
echo ""

read -rp "Disk number: " disk_idx

if ! [[ "$disk_idx" =~ ^[0-9]+$ ]] || [[ "$disk_idx" -ge ${#DISK_IDS[@]} ]]; then
  error "Invalid selection."
  exit 1
fi

SELECTED_TARGET="${DISK_IDS[$disk_idx]}"
SELECTED_NAME="${seen_devices[$SELECTED_TARGET]}"
SELECTED_DISK="/dev/disk/by-id/$SELECTED_NAME"

echo ""
info "Selected: $SELECTED_NAME"
info "  Path:   $SELECTED_DISK"
info "  Device: $SELECTED_TARGET"

# --- Step 4: Partition warning ---

PART_COUNT=$(lsblk -nro TYPE "$SELECTED_TARGET" | grep -c 'part' || true)

echo ""
if [[ "$PART_COUNT" -gt 0 ]]; then
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║                    *** WARNING ***                           ║${NC}"
  echo -e "${RED}${BOLD}║                                                              ║${NC}"
  echo -e "${RED}${BOLD}║  This disk already has $PART_COUNT partition(s)!                        ║${NC}"
  echo -e "${RED}${BOLD}║  ALL DATA on this disk will be PERMANENTLY DESTROYED.        ║${NC}"
  echo -e "${RED}${BOLD}║                                                              ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}Existing layout of ${SELECTED_TARGET}:${NC}"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$SELECTED_TARGET"
  echo ""
  echo -e "${RED}Type the disk name to confirm destruction:${NC} ${BOLD}${SELECTED_NAME}${NC}"
  read -rp "> " confirm_name
  if [[ "$confirm_name" != "$SELECTED_NAME" ]]; then
    error "Confirmation failed. Aborting."
    exit 1
  fi
else
  echo -e "${YELLOW}This disk appears empty (no partitions).${NC}"
  read -rp "Proceed with install to ${SELECTED_NAME}? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    info "Aborted."
    exit 0
  fi
fi

# --- Step 5: Run disko-install ---

echo ""
info "Partitioning and mounting disk with disko..."
info "  Flake:  .#${FLAKE_HOST}"
info "  Disk:   ${SELECTED_DISK}"
echo ""

nix --extra-experimental-features "nix-command flakes" \
  run 'github:nix-community/disko/latest#disko' -- \
  --mode destroy,format,mount \
  --flake ".#${FLAKE_HOST}" \
  --disk main "$SELECTED_DISK"

info "Activating swap so the NixOS build has enough memory..."
swapon /dev/vg0/swap || warn "Could not activate swap — continuing anyway"

info "Installing NixOS..."
nixos-install --flake ".#${FLAKE_HOST}" --no-root-passwd

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║              Installation complete!                          ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "After reboot, enroll TPM2 for automatic LUKS unlock:"
info "  sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-root --tpm2-device=auto"
echo ""

read -rp "Reboot now? [y/N] " do_reboot
if [[ "${do_reboot,,}" == "y" ]]; then
  info "Rebooting..."
  reboot
else
  info "Skipped reboot. Run 'reboot' when ready."
fi
