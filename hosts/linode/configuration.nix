{ ... }:
{
  imports = [
    ../../modules/profiles/linode.nix
    ../../modules/server.nix
  ];

  networking.hostName = "linode";

  services.openssh.ports = [ 22 ];

  system.stateVersion = "26.05";
}
