# PVM (pagetable-based virtual machine) kernels, built from virt-pvm/linux
# with the upstream configs from virt-pvm/misc.
#
#   - host: carries the kvm-pvm.ko module (CONFIG_KVM_PVM=m), which provides
#     /dev/kvm without VT-x/SVM. See hosts/linode-pvm/configuration.nix for
#     its boot requirements.
#   - guest: PVM-aware kernel for QEMU microvm guests; stock kernels cannot
#     boot under PVM. Guests need `pti=off nokaslr` on their command line.
#
# Each attribute is a linuxPackages set; use `.kernel` for the kernel itself.
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

  build =
    configfile:
    linuxKernel.customPackage {
      inherit version configfile;
      src = pvm-src;
      # NixOS modules read kernel options from the config to check their
      # requirements.
      allowImportFromDerivation = true;
    };
in
{
  # The upstream host config is Kata-oriented. Add the modules the NixOS
  # qemu-guest profile loads in the initrd, the `pkttype` match the NixOS
  # firewall uses, and TUN for slirp4netns.
  host = build (
    runCommand "pvm-host-${version}.config" { } ''
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
      CONFIG_TUN=m
      CONFIG_NETFILTER_ADVANCED=y
      CONFIG_NETFILTER_XT_MATCH_PKTTYPE=m
      EOF
    ''
  );

  guest = build (upstreamConfig "guest" "sha256-oX2HflEXKIp2K8vto4JepdhcY8hUJ1InPsLcLGb5YJs=");
}
