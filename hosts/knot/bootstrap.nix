{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/linode-config.nix"
    ../../modules/server.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "knot";
  networking.domain = "jacobs.land";

  services.openssh.ports = [
    22
    2222
  ];

  system.stateVersion = "26.05";
}
