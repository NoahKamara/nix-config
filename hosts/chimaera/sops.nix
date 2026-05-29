{ ... }:
{
  noah.sops.enable = true;

  sops.defaultSopsFile = ../../secrets/chimaera.yaml;

  sops.secrets.wg0-private-key = { };
}
