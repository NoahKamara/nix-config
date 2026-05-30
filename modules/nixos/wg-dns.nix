{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.noah.services.wg-dns;
in
{
  options.noah.services.wg-dns = {
    enable = mkEnableOption ''
      Split-horizon DNS on the WireGuard hub (dnsmasq on wg0).

      WireGuard clients set DNS to the hub address so selected hostnames resolve
      to the tunnel instead of the VPS public IP. Everything else is forwarded
      upstream.
    '';

    ipv4 = mkOption {
      type = types.str;
      default = "10.44.0.1";
      description = "IPv4 address returned for configured hostnames.";
    };

    ipv6 = mkOption {
      type = types.str;
      default = "fd42:44:44::1";
      description = "IPv6 address returned for configured hostnames.";
    };

    hosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "agent.example.com"
        "git.example.com"
      ];
      description = ''
        Hostnames that resolve to ipv4/ipv6 for clients using this resolver.
        Use for services fronted by Caddy on the hub or otherwise reachable
        only/mostly via the tunnel.
      '';
    };

    upstreamNameservers = mkOption {
      type = types.listOf types.str;
      default = [
        "2a01:4ff:ff00::add:1"
        "2a01:4ff:ff00::add:2"
      ];
      description = "Upstream resolvers for names not overridden above.";
    };
  };

  config = mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      settings = {
        bind-interfaces = true;
        listen-address = [
          cfg.ipv4
          cfg.ipv6
        ];
        address = lib.flatten (
          map (host: [
            "/${host}/${cfg.ipv4}"
            "/${host}/${cfg.ipv6}"
          ]) cfg.hosts
        );
        server = cfg.upstreamNameservers;
        domain-needed = true;
        bogus-priv = true;
        no-resolv = true;
      };
    };

    networking.firewall.interfaces.wg0 = {
      allowedUDPPorts = [ 53 ];
      allowedTCPPorts = [ 53 ];
    };
  };
}
