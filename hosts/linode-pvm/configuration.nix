# PVM nested virtualization test host.
#
# Linode does not expose nested virtualization (/dev/kvm) to guests. PVM
# (pagetable-based virtual machine) provides a KVM implementation that runs
# guests without hardware virtualization extensions. The host boots the PVM
# host kernel from pkgs/pvm-kernel.nix, whose kvm-pvm.ko registers /dev/kvm.
#
# Guest kernels must be PVM-aware; see packages.pvm-guest-kernel.
{
  pkgs,
  modulesPath,
  pvm-linux,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/linode-config.nix"
    ../../modules/server.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "linode-pvm";
  # The PVM host kernel has xtables support but not nftables.
  networking.firewall.package = pkgs.iptables-legacy;

  boot.kernelPackages =
    (pkgs.callPackage ../../pkgs/pvm-kernel.nix {
      pvm-src = pvm-linux;
    }).host;

  boot.kernelModules = [ "kvm-pvm" ];
  # kvm-intel and kvm-amd cannot coexist with kvm-pvm.
  boot.blacklistedKernelModules = [
    "kvm-intel"
    "kvm-amd"
  ];

  # The PVM host config (from virt-pvm, Kata-oriented) does not build the
  # USB/SATA/HID drivers NixOS loads in the initrd by default. This host only
  # needs the virtio modules listed by the qemu-guest and linode profiles, so
  # skip the default module list.
  boot.initrd.includeDefaultModules = false;

  # Likewise for the TPM modules the systemd initrd loads; this VM has no
  # TPM and the PVM host config does not build them.
  boot.initrd.systemd.tpm2.enable = false;

  boot.kernelParams = [
    # kvm-pvm refuses to load when page table isolation is active. The kernel
    # only enables PTI on CPUs affected by Meltdown (older Intel), so this is
    # a no-op elsewhere; on affected CPUs it removes the Meltdown mitigation.
    "pti=off"
    # kvm-pvm refuses to load when kernel memory layout randomization is on.
    "nokaslr"
  ];

  system.stateVersion = "26.05";
}
