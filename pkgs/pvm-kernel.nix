# PVM (pagetable-based virtual machine) kernels, built from virt-pvm/linux
# with the upstream configs from virt-pvm/misc.
#
#   - host: carries the kvm-pvm.ko module (CONFIG_KVM_PVM=m), which provides
#     /dev/kvm without VT-x/SVM. See modules/pvm-host.nix for
#     its boot requirements.
#   - guest: PVM-aware kernel for QEMU microvm guests; stock kernels cannot
#     boot under PVM. Guests need `pti=off nokaslr` on their command line.
#
# Each attribute is a linuxPackages set; use `.kernel` for the kernel itself.
# mkHost and mkGuest take extra Kconfig lines to append to the respective
# config. The kernel build resolves the result like `make olddefconfig`, so
# options whose dependencies are unmet are dropped silently; check the built
# config.
#
# `pvm-src` is the `pvm-linux` flake input, pinned to a commit. To update,
# change that commit, `version` and `configRev` together and refresh the
# config hashes.
{
  linuxKernel,
  fetchurl,
  runCommand,
  pvm-src,
}:
let
  version = "6.12.33";

  # virt-pvm/misc commit holding pvm-{host,guest}-<version>.config.
  configRev = "6923f736264d35c971c29e19330673d902f2d924";
  upstreamConfig =
    name: hash:
    fetchurl {
      url = "https://raw.githubusercontent.com/virt-pvm/misc/${configRev}/pvm-${name}-${version}.config";
      inherit hash;
    };
  guestConfig = upstreamConfig "guest" "sha256-oX2HflEXKIp2K8vto4JepdhcY8hUJ1InPsLcLGb5YJs=";

  build =
    configfile:
    linuxKernel.customPackage {
      inherit version configfile;
      src = pvm-src;
      # NixOS modules read kernel options from the config to check their
      # requirements.
      allowImportFromDerivation = true;
    };

  # The upstream host config is Kata-oriented. Add the modules the NixOS
  # qemu-guest profile loads in the initrd and the `pkttype` match the NixOS
  # firewall uses, then `extraConfig`.
  mkHost =
    extraConfig:
    build (
      runCommand "pvm-host-${version}.config" { inherit extraConfig; } ''
        cat ${upstreamConfig "host" "sha256-E83RJZSO3Zk8hCDOHR7ppfMkO+vYFt/ar1PNWvpo5yk="} > $out
        cat >> $out <<EOF
        CONFIG_NET_9P=m
        CONFIG_NET_9P_VIRTIO=m
        CONFIG_9P_FS=m
        CONFIG_9P_FS_POSIX_ACL=y
        CONFIG_FUSE_FS=m
        CONFIG_VIRTIO_FS=m
        CONFIG_VIRTIO_BALLOON=m
        CONFIG_HW_RANDOM_VIRTIO=m
        CONFIG_NETFILTER_ADVANCED=y
        CONFIG_NETFILTER_XT_MATCH_PKTTYPE=m
        EOF
        printf '%s\n' "$extraConfig" >> $out
      ''
    );

  # The upstream guest config, then `extraConfig`.
  mkGuest =
    extraConfig:
    build (
      runCommand "pvm-guest-${version}.config" { inherit extraConfig; } ''
        cat ${guestConfig} > $out
        printf '%s\n' "$extraConfig" >> $out
      ''
    );
in
{
  inherit mkHost mkGuest;
  host = mkHost "";
  guest = build guestConfig;
}
