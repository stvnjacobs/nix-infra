{ ... }:
{
  imports = [
    ../../modules/profiles/linode.nix
    ../../modules/server.nix
    ../../modules/knot.nix
  ];

  networking.hostName = "knot";
  networking.domain = "jacobs.land";

  system.stateVersion = "26.05";
}
