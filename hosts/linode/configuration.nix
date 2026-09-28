{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/linode-config.nix"
    ../../modules/server.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "linode";

  services.openssh.ports = [ 22 ];

  system.stateVersion = "26.05";
}
