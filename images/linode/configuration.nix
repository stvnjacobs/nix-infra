{ ... }:
{
  imports = [
    ../../modules/profiles/linode.nix
    ../../modules/server.nix
  ];

  networking.hostName = "linode";

  system.stateVersion = "25.11";
}
