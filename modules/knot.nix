{ config, ... }:
{
  # 80/443 for nginx TLS termination; knot public API on 5555 (loopback-only).
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "stjacobs@fastmail.fm";
  };

  services.nginx = {
    enable = true;
    virtualHosts.${config.networking.fqdn} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:5555";
        proxyWebsockets = true;
      };
    };
  };

  services.tangled.knot = {
    enable = true;
    server = {
      listenAddr = "127.0.0.1:5555";
      hostname = config.networking.fqdn;
      owner = "did:plc:eyfrtl2gxdohgbjf573dsj6m";
    };
  };
}
