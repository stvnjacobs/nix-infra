# PVM nested virtualization test host.
#
# Linode does not expose nested virtualization (/dev/kvm) to guests. PVM
# (pagetable-based virtual machine) provides a KVM implementation that runs
# guests without hardware virtualization extensions; see modules/pvm-host.nix.
#
# Guest kernels must be PVM-aware; see packages.pvm-guest-kernel.
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/linode-config.nix"
    ../../modules/server.nix
    ../../modules/pvm-host.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "linode-pvm";

  system.stateVersion = "26.05";
}
