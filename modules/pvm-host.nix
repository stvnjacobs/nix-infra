# Run as a PVM (pagetable-based virtual machine) host.
#
# PVM is a KVM implementation that runs guests without hardware virtualization
# extensions, for VMs whose provider does not expose nested virtualization
# (e.g. Linode). The PVM host kernel from pkgs/pvm-kernel.nix carries
# kvm-pvm.ko, which registers /dev/kvm without VT-x/SVM. Guests must run a
# PVM-aware kernel (packages.pvm-guest-kernel); stock kernels cannot boot.
#
# The host kernel only builds what NixOS itself needs on a virtio VM. Modules
# whose workloads need more set pvm.host.extraKernelConfig.
#
# Requires the `pvm-linux` flake input in specialArgs.
{
  config,
  lib,
  pkgs,
  pvm-linux,
  ...
}:
let
  pvm = pkgs.callPackage ../pkgs/pvm-kernel.nix { pvm-src = pvm-linux; };
in
{
  options.pvm.host.extraKernelConfig = lib.mkOption {
    type = lib.types.lines;
    default = "";
    example = ''
      # QEMU tap networking.
      CONFIG_TUN=m
    '';
    description = ''
      Kconfig lines appended to the PVM host kernel config. Options whose
      dependencies are unmet are dropped silently; check the built config.
      Changes replace the kernel, so deploy with `nixos-rebuild boot` and
      reboot.
    '';
  };

  config = {
    boot.kernelPackages = pvm.mkHost config.pvm.host.extraKernelConfig;

    boot.kernelModules = [ "kvm-pvm" ];
    # kvm-intel and kvm-amd cannot coexist with kvm-pvm.
    boot.blacklistedKernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    boot.kernelParams = [
      # kvm-pvm refuses to load when page table isolation is active. The
      # kernel only enables PTI on CPUs affected by Meltdown (older Intel), so
      # this is a no-op elsewhere; on affected CPUs it removes the Meltdown
      # mitigation. Check /sys/devices/system/cpu/vulnerabilities/meltdown on
      # the host.
      "pti=off"
      # kvm-pvm refuses to load when kernel memory layout randomization is on.
      "nokaslr"
    ];

    # The PVM host kernel config (from virt-pvm, Kata-oriented) does not build
    # the USB/SATA/HID drivers NixOS loads in the initrd by default, so skip
    # the default module list. Virtio VMs get what they need from the
    # qemu-guest profile. Hosts that boot from other hardware must list its
    # drivers in boot.initrd.availableKernelModules and enable them in
    # pvm.host.extraKernelConfig.
    boot.initrd.includeDefaultModules = false;

    # Likewise, the kernel config does not build the TPM modules the systemd
    # initrd loads.
    boot.initrd.systemd.tpm2.enable = false;

    # The PVM host kernel config enables xtables but not nftables.
    networking.firewall.package = pkgs.iptables-legacy;
  };
}
