{ config, ... }:
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # knot-rs owns port 22; sshd moves to 2222.
  services.openssh.ports = [ 2222 ];

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

  services.tangled.knot-rs = {
    enable = true;
    user = "git";
    environmentFile = "/etc/knot/master.env";
    settings = {
      server = {
        hostname = config.networking.fqdn;
        admins = [ "did:plc:eyfrtl2gxdohgbjf573dsj6m" ];
        ssh_listen_addr = "[::]:22";
        ssh_host_key_file = "/var/lib/knot/ssh_host_ed25519_key";
      };
      repo.scan_path = "/var/lib/knot/repos";
      secrets.sealed_key_file = "/var/lib/knot/knot.sealed";
      atproto.plc_directory = "https://plc.directory";
      xrpc.trusted_proxy_header = "x-forwarded-for";
    };
  };
}
