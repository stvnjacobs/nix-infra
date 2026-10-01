# PVM adjustments for the spindle NixOS microVM image.
#
# Layered on top of tangled-core's `spindle-nixos` module (microvm.nix plus
# tangled's base and QEMU runner config), which boots a stock nixpkgs kernel.
# PVM guests must boot a PVM-aware kernel with `pti=off nokaslr`.
{
  lib,
  pkgs,
  pvm-linux,
  ...
}:
let
  pvm = pkgs.callPackage ../../pkgs/pvm-kernel.nix { pvm-src = pvm-linux; };

  # The upstream guest config is a monolithic, Kata-oriented kernel. Add what
  # the NixOS guest and common workflows need. Everything is built in (=y);
  # CONFIG_MODULES only exists so the build emits modules.builtin, which
  # NixOS's initrd module closure and modprobe consult.
  kernelPackages = pvm.mkGuest ''
    CONFIG_MODULES=y
    CONFIG_MODULE_UNLOAD=y

    # systemd
    CONFIG_DMIID=y
    CONFIG_TMPFS_POSIX_ACL=y
    CONFIG_TMPFS_XATTR=y
    CONFIG_CRYPTO_HMAC=y
    CONFIG_CONFIGFS_FS=y
    CONFIG_PSI=y
    CONFIG_KEYS=y
    CONFIG_RD_ZSTD=y

    # zramSwap in tangled's base.nix
    CONFIG_ZSMALLOC=y
    CONFIG_ZRAM=y
    CONFIG_CRYPTO_ZSTD=y

    # iptables-nft: the NixOS firewall and Docker
    CONFIG_NF_TABLES=y
    CONFIG_NF_TABLES_INET=y
    CONFIG_NF_TABLES_IPV4=y
    CONFIG_NF_TABLES_IPV6=y
    CONFIG_NFT_COMPAT=y
    CONFIG_NFT_CT=y
    CONFIG_NFT_NAT=y
    CONFIG_NFT_MASQ=y
    CONFIG_NFT_REDIR=y
    CONFIG_NFT_REJECT=y
    CONFIG_NFT_LOG=y
    CONFIG_NFT_LIMIT=y
    CONFIG_NFT_FIB_INET=y
    CONFIG_NFT_FIB_IPV4=y
    CONFIG_NFT_FIB_IPV6=y
    CONFIG_IP6_NF_IPTABLES=y
    CONFIG_IP6_NF_FILTER=y
    CONFIG_IP6_NF_MANGLE=y
    CONFIG_IP6_NF_RAW=y
    CONFIG_IP6_NF_NAT=y
    CONFIG_IP6_NF_TARGET_MASQUERADE=y
    CONFIG_IP6_NF_TARGET_REJECT=y
    CONFIG_IP6_NF_MATCH_RPFILTER=y

    # Docker networking
    CONFIG_BRIDGE_NETFILTER=y
    CONFIG_TUN=y
    CONFIG_DUMMY=y
    CONFIG_MACVLAN=y
    CONFIG_IPVLAN=y
    CONFIG_VXLAN=y
  '';
in
{
  boot.kernelPackages = kernelPackages;

  # kvm-pvm guests must run without page table isolation or KASLR.
  boot.kernelParams = [
    "pti=off"
    "nokaslr"
  ];
}
