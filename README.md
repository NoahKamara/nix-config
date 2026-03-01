# Nix Configuration Monorepo

Declarative, flake-based system configuration for:

* macOS (via nix-darwin)
* NixOS (Linux workstation)

This repository provides a single source of truth for system, user, and development environments across machines.

---

## Setup macOS

This section covers bootstrapping and daily use on macOS via nix-darwin.

### Prerequisites

* Install Nix (Lix works too) so `nix` is available on your `PATH`.
* If you hit build failures later, install Xcode Command Line Tools: `xcode-select --install`

**Lix users:** If `nix` isn't found after installing Lix:

* Use the full path: `/nix/var/nix/profiles/default/bin/nix`
* Or source the profile script (zsh/bash): `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`

### Bootstrap nix-darwin

Install [nix-darwin](https://github.com/nix-darwin/nix-darwin). Use `sudo -i` instead of plain `sudo` due to [this issue](https://github.com/nix-darwin/nix-darwin/issues/1527).

This flake defines `darwinConfigurations.hammerhead`.

**First switch** (works even before `darwin-rebuild` is on your PATH):

```bash
nix --extra-experimental-features "nix-command flakes" \
  run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake .#hammerhead"
```

**Subsequent switches:**

```bash
darwin-rebuild switch --flake ".#hammerhead"
```

### Update inputs

```bash
nix flake update
darwin-rebuild switch --flake ".#hammerhead"
```

---

## Hosts

### Fresh install (auto-detect OS)

Use this on a fresh machine. It auto-detects macOS vs NixOS and runs the correct host installer.

```bash
bash <(curl -sL https://raw.githubusercontent.com/noahkamara/nix-config/main/install.sh)
```

### Hammerhead (macOS)

macOS workstation managed via nix-darwin and Home Manager.

#### Fresh install (one command, Lix)

On a freshly set up macOS machine:

```bash
bash <(curl -sL https://raw.githubusercontent.com/noahkamara/nix-config/main/install.sh)
```

The script will:
1. Ensure Xcode Command Line Tools are installed
2. Install Lix (if `nix` is not already available)
3. Clone this repository
4. Run the first `darwin-rebuild switch --flake .#hammerhead`

#### Rebuild

```bash
darwin-rebuild switch --flake .#hammerhead
```

### Nebulon (NixOS)

NixOS workstation with full declarative system configuration.

* GPT layout managed by `disko`
* LUKS-encrypted LVM (TPM2 auto-unlock)
* LVM: 32G swap (hibernation-ready) + btrfs root with subvolumes
* btrfs subvolumes: `@`, `@home`, `@nix`, `@snapshots`
* Hyprland desktop with tuigreet

#### Fresh install

Boot from a NixOS installer/live ISO, then:

```bash
sudo -i
nix-shell -p curl --run "bash <(curl -sL https://raw.githubusercontent.com/noahkamara/nix-config/main/install.sh)"
```

The script will:
1. Clone this repo
2. Generate hardware configuration
3. List available disks and prompt you to select one
4. Warn if the disk is already partitioned (requires typing the disk name to confirm)
5. Patch the selected disk into `disko.nix`, partition, format, and mount
6. Activate swap and run `nixos-install`
7. Enroll TPM2 for automatic LUKS unlock (if a TPM2 device is detected)
8. Offer to reboot

<details>
<summary>Manual install (without script)</summary>

```bash
sudo -i

nix-shell -p git
git clone https://github.com/noahkamara/nix-config.git
cd nix-config

nixos-generate-config --root /tmp/hw-config --no-filesystems
cp /tmp/hw-config/etc/nixos/hardware-configuration.nix ./hosts/nebulon/hardware-configuration.nix

# identify the target disk
ls -l /dev/disk/by-id/ | grep nvme

# set the disk in disko.nix
sed -i 's|diskDevice = ".*"|diskDevice = "/dev/disk/by-id/<your-target-disk>"|' ./hosts/nebulon/disko.nix
git add hosts/nebulon/

# partition, format, and mount
nix --extra-experimental-features "nix-command flakes" \
  build '.#nixosConfigurations.nebulon.config.system.build.diskoScript' \
  --print-out-paths --no-link | xargs -I{} bash {}

# activate swap for the build
swapon /dev/vg0/swap

# install
nixos-install --flake '.#nebulon' --no-root-passwd

# enroll TPM2 (if available)
systemd-cryptenroll /dev/disk/by-partlabel/disk-main-root --tpm2-device=auto

reboot
```

</details>

Notes:
* The generated `/tmp/hw-config/etc/nixos/configuration.nix` is not used in this flake setup.
* `hosts/nebulon/default.nix` replaces traditional `configuration.nix`.
* `hosts/nebulon/disko.nix` is the source of truth for partitioning/filesystems/swap.

#### Rebuild

```bash
sudo nixos-rebuild switch --flake .#nebulon
```

#### Encrypted user vault (`~/vault.img`)

`nebulon` includes a `vault` shell command that manages a Disko-backed encrypted image file in your home directory:

* Image path: `~/vault.img`
* Maximum size: `100G` (sparse file)
* Mount point: `~/Vault`
* Encryption: LUKS

Commands:

```bash
vault open
vault status
vault close
```

Notes:
* `vault open` creates `~/vault.img` on first run, then uses `disko --mode format,mount` to initialize/mount it.
* `vault close` unmounts `~/Vault` and closes the LUKS mapper.
* The command uses `sudo` for mount/cryptsetup operations, so it will prompt for your password.

#### Troubleshooting

If you hit `no space left on device` in the live installer:

```bash
# check which filesystem is full
df -h / /tmp /mnt /mnt/boot

# if live /tmp is full, keep build temp files on target disk
mkdir -p /mnt/tmp
chmod 1777 /mnt/tmp
export TMPDIR=/mnt/tmp

# retry nixos-install
nixos-install --flake '.#nebulon' --no-root-passwd
```

---

## Development Shells

You can manually enter the default development shell (with `jq`, `just`, etc.) by running:

```bash
nix develop
```

Or you can enter a specific shell (like the Swift environment) by running:

```bash
nix develop .#swift
```

### Automatic Environment Activation (direnv)

This repository includes `direnv` and `nix-direnv` setup via Home Manager to automatically load these shells when you `cd` into a project directory. 

**1. Configure the Project Folder**
In your specific project folder, create a `.envrc` file to point to the desired shell in this flake:

* For the **Swift** shell: `echo "use flake ~/Tools/nix-config#swift" > .envrc`
* For the **Default** shell: `echo "use flake ~/Tools/nix-config" > .envrc`

**2. Allow the Environment**
Navigate to the folder in your terminal and allow the environment:

```bash
direnv allow
```

**3. Use in VSCode-based IDEs**
To make VSCode recognize these tools (for language servers, formatters like `swiftformat`, etc.), you have two options:
* **Option A (Recommended)**: Install the **`direnv`** extension (`mkhl.direnv`) in Cursor. It will automatically load the Nix environment when you open the folder.
* **Option B**: Launch VSCoe directly from the activated terminal (`code .`), which passes the Nix environment variables to the editor.

---

Optional per-project shells can be added under `devShells` in `flake.nix`.

---

For AI agents: see [AGENTS.md](AGENTS.md) for build commands, coding conventions, repository structure, and editing guidance.

---

## Applications

### ComfyUI

Image generation UI, packaged via [comfyui-nix](https://github.com/utensils/comfyui-nix). CUDA GPU acceleration is enabled automatically on `x86_64-linux`.

```bash
nix run .#comfyui
```

### service-expose

`service-expose` dynamically exposes a local service through the host Caddy proxy on port `8080`.

Usage:

```bash
service-expose <name> <path> <upstream> -- <command> [args...]
```

Example (run ComfyUI behind `/comfy`):

```bash
service-expose comfy /comfy 127.0.0.1:8188 -- nix run .#comfyui
```

List active exposed services:

```bash
service-expose ls
```

When `service-expose` exits (including `Ctrl+C`), it unregisters the dynamic route from Caddy.
