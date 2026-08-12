{ lib, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/linode-config.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";

  swapDevices = [ { device = "/dev/disk/by-label/linode-swap"; } ];
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
}
