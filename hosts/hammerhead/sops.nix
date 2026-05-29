{ userProfile, ... }:
let
  ageKeyFile = "/Users/${userProfile.username}/Library/Application Support/sops/age/keys.txt";
in
{
  sops.defaultSopsFile = ../../secrets/hammerhead.yaml;
  sops.age.keyFile = ageKeyFile;
  sops.age.sshKeyPaths = [ ];

  sops.secrets.wg0-private-key = { };
}
