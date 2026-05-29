{ ... }:
{
  noah.sops.enable = true;

  sops.defaultSopsFile = ../../secrets/chimaera.yaml;

  sops.secrets.hermes-env = {
    format = "yaml";
  };

  sops.secrets.icloud-app-password = {
    format = "yaml";
  };

  sops.secrets.wg0-private-key = { };
}
