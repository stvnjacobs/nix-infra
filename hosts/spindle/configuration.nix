# Tangled spindle (CI runner) running microVM workflows on a PVM host.
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/linode-config.nix"
    ../../modules/server.nix
    ../../modules/pvm-host.nix
    ../../modules/spindle.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "spindle";
  networking.domain = "jacobs.land";

  system.stateVersion = "26.05";
}
