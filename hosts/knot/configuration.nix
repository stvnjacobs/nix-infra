{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/linode-config.nix"
    ../../modules/server.nix
    ../../modules/knot.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "knot";
  networking.domain = "jacobs.land";

  system.stateVersion = "26.05";
}
