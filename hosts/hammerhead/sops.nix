{ userProfile, ... }:
let
  ageKeyFile = "/Users/${userProfile.username}/Library/Application Support/sops/age/keys.txt";
in
{
  sops.defaultSopsFile = ../../secrets/hammerhead.yaml;
  sops.age.keyFile = ageKeyFile;

  sops.secrets.wg0-private-key = { };
}
