{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.noah.sops;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options.noah.sops.enable = lib.mkEnableOption "sops-nix (SSH host key decryption)";

  config = lib.mkIf cfg.enable {
    sops.age.sshKeyPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };
}
