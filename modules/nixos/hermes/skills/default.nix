{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.noah.services.hermes-agent;
  builtinSkillCatalog = import ./builtins.nix;
  builtinSkillNames = lib.attrNames builtinSkillCatalog;

  # Wrap each registered skill's source dir as <name>/SKILL.md so it can be
  # passed to the agent's skills.external_dirs (one dir per skill).
  mkSkillDir =
    name: src:
    pkgs.runCommand "hermes-skill-${name}" { } ''
      mkdir -p $out/${name}
      cp -r ${src}/. $out/${name}/
    '';

  mkBuiltinSkillOption =
    name: meta:
    mkOption {
      type = types.bool;
      default = false;
      description = meta.description + lib.optionalString (meta.category != null) " [${meta.category}]";
    };

  isBuiltinSkillEnabled =
    name:
    lib.attrByPath [
      "noah"
      "services"
      "hermes-agent"
      "builtinSkills"
      name
    ] false config;

  internalSkillNames = lib.attrNames cfg.internalSkills;

  disabledBuiltinSkills = lib.filter (name: !isBuiltinSkillEnabled name) (
    lib.subtractLists internalSkillNames builtinSkillNames
  );
in
{
  options.noah.services.hermes-agent.internalSkills = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          source = mkOption {
            type = types.path;
            description = "Directory containing the skill's SKILL.md (and any assets).";
          };
          alwaysLoad = mkOption {
            type = types.bool;
            default = false;
            description = "Add this skill to config.yaml skills.always_load.";
          };
        };
      }
    );
    default = { };
    internal = true;
    description = ''
      Skill registry populated by domain modules (calendar, email, …).
      Rendered once into skills.always_load / skills.external_dirs to avoid
      the recursiveUpdate list-clobber that direct settings writes would hit.
    '';
  };

  options.noah.services.hermes-agent.builtinSkills = mkOption {
    type = types.submodule {
      options = lib.mapAttrs mkBuiltinSkillOption builtinSkillCatalog;
    };
    description = ''
      Bundled Hermes skills (share/hermes-agent/skills). Disabled skills are
      written to config.yaml `skills.disabled`. Defaults are off; opt in per skill.
    '';
  };

  config = mkIf cfg.enable {
    services.hermes-agent.settings = mkMerge [
      (lib.optionalAttrs (cfg.internalSkills != { }) {
        skills.always_load = lib.attrNames (lib.filterAttrs (_: s: s.alwaysLoad) cfg.internalSkills);
        skills.external_dirs = lib.mapAttrsToList (name: s: mkSkillDir name s.source) cfg.internalSkills;
      })
      (lib.optionalAttrs (disabledBuiltinSkills != [ ]) {
        skills.disabled = disabledBuiltinSkills;
      })
    ];
  };
}
