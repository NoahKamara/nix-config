# Agent Instructions

This file is intentionally short and only covers non-obvious, repo-specific pitfalls.

## Scope And Priority

- If this file conflicts with explicit user instructions, follow the user.
- Do not change implementation approach to work around sandbox/tooling limitations unless explicitly requested by the user.
- Keep hosts thin. Put reusable logic in modules.
- Prefer small edits in existing modules over creating new abstractions.

## Hard Invariants

- System packages in `modules/shared` stay minimal.
- Tools needed in every shell go in `modules/home/default.nix`.
- General dev tools go in `devShells.default` in `flake.nix`.
- macOS GUI apps go in `modules/darwin/default.nix` under Homebrew casks.
- Host files in `hosts/*` should mostly wire imports and user/home-manager linkage.

## Repeated Failure Patterns

- Do not hardcode `home.username` or `home.homeDirectory` in `modules/home/default.nix`.
- Do not put Darwin-only options in shared modules.
- Keep `nix.gc.interval` in `modules/darwin/default.nix`, not `modules/shared/default.nix`.
- Gate macOS-only Home Manager files with `pkgs.stdenv.isDarwin`.
  Example: `.aerospace.toml` must be Darwin-only.
- Keep Ghostty package selection platform-aware in Home Manager.
  Use `null` on Darwin (Homebrew cask path) and `pkgs.ghostty` on non-Darwin.

## Validation Checklist

- After each numbered phase, run: `sudo darwin-rebuild switch --flake .#hammerhead`.
- For Linux host work, run: `sudo nixos-rebuild switch --flake .#<host>` when applicable.
- If touching flake wiring, run: `nix flake check`.

## Out Of Scope Unless Requested

- Do not edit `flake.lock` unless the task explicitly requires input updates.
- Do not move large config blocks across modules unless asked.
- Do not add project-specific tooling to this repo-level flake.

## Reference Skill

- Follow `.agents/skills/nix-best-practices/SKILL.md` for flake and overlay patterns.
