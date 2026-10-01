# linode-pvm

Test host for [PVM (pagetable-based virtual machine)](https://github.com/virt-pvm)
nested virtualization on Linode. Linode does not expose `/dev/kvm` to guests;
PVM provides a KVM implementation that runs microVMs without hardware
virtualization extensions, so qemu microvm instances can run on any Linode.

This host tests virt-pvm as its maintainers distribute it, adding only what
NixOS needs to boot.

For an end-to-end walkthrough that creates a Linode and boots a tiny QEMU guest,
see [Boot a QEMU microVM on Linode](./TUTORIAL.md).

## Architecture

- **Kernels** — `pkgs/pvm-kernel.nix` builds Linux 6.12.33 from
  [virt-pvm/linux](https://github.com/virt-pvm/linux) (a `pvm-612` commit pinned
  by the `pvm-linux` flake input) with the upstream configs from
  [virt-pvm/misc](https://github.com/virt-pvm/misc), pinned by commit. It
  returns two kernels:
  - `host`, booted by this host (`boot.kernelPackages`) and exposed as
    `packages.pvm-host-kernel`. It carries `kvm-pvm.ko` (`CONFIG_KVM_PVM=m`),
    which registers `/dev/kvm` without VT-x/SVM.
  - `guest`, exposed as `packages.pvm-guest-kernel` for QEMU's `-kernel`.
    Guest kernels must be PVM-aware; stock kernels cannot boot under PVM.
- **Host constraints** — `kvm-intel`/`kvm-amd` cannot coexist with `kvm-pvm`
  (blacklisted). `kvm-pvm` refuses to load with page table isolation or KASLR
  active, so the host boots with `pti=off nokaslr`. The kernel only enables PTI
  on CPUs affected by Meltdown; on those, `pti=off` removes that mitigation.
  Check `/sys/devices/system/cpu/vulnerabilities/meltdown` on the Linode.
- **Guest boot** — QEMU must use the qboot firmware (`-bios qboot.rom`, shipped
  with QEMU) and pass `pti=off nokaslr` to the guest kernel in `-append`.

## NixOS Compatibility

The upstream host config is Kata-oriented, not a drop-in NixOS host config.
`pkgs/pvm-kernel.nix` adds these options for NixOS boot and host workloads:

| Kernel options | Reason |
| --- | --- |
| `CONFIG_NET_9P=m`, `CONFIG_NET_9P_VIRTIO=m`, `CONFIG_9P_FS=m`, `CONFIG_9P_FS_POSIX_ACL=y` | 9p modules the NixOS qemu-guest profile loads in the initrd. |
| `CONFIG_FUSE_FS=m`, `CONFIG_VIRTIO_FS=m` | virtio-fs module the qemu-guest profile loads; virtio-fs depends on FUSE. |
| `CONFIG_VIRTIO_BALLOON=m`, `CONFIG_HW_RANDOM_VIRTIO=m` | virtio modules the qemu-guest profile loads. |
| `CONFIG_NETFILTER_ADVANCED=y`, `CONFIG_NETFILTER_XT_MATCH_PKTTYPE=m` | NixOS's iptables firewall rules use the `pkttype` match. |

The NixOS-side settings for running on this kernel (firewall backend, initrd
modules, kernel parameters) live in `modules/pvm-host.nix`, which documents the
reason for each.

## Deploying

Create the Linode from the generic base image (see the top-level README), deploy
this configuration, then reboot into the PVM kernel:

```bash
./scripts/create-linode.sh linode-pvm .#linode-pvm
ssh root@<ip> reboot
```

`nixos-rebuild` never swaps the running kernel; a new kernel only takes effect
at the next reboot. For kernel changes, use `boot` and reboot deliberately:

```bash
nixos-rebuild boot --flake .#linode-pvm --target-host root@<ip>
ssh root@<ip> reboot
```

Use `switch` for changes that do not touch the kernel. If a new kernel does not
come back, pick the previous generation from the GRUB menu via the LISH console,
then run `nixos-rebuild switch --rollback`.

## References

- PVM setup guide (host kernel build + guest kernel + kata):
  https://github.com/virt-pvm/misc/blob/main/pvm-get-started-with-kata.md
- Host/guest kernel configs used above: https://github.com/virt-pvm/misc
- Kernel source: https://github.com/virt-pvm/linux/tree/pvm-612
- ATC'23 paper "PVM: Isolating Software Faults at the Hardware Boundary":
  https://dl.acm.org/doi/10.1145/3600006.3613158
- Cloud Hypervisor also supports PVM from v35; avoid a virtio-pmem rootfs, see
  [virt-pvm/linux#1](https://github.com/virt-pvm/linux/issues/1).
