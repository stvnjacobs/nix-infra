# linode-pvm

Test host for [PVM (pagetable-based virtual machine)](https://github.com/virt-pvm)
nested virtualization on Linode. Linode does not expose `/dev/kvm` to guests;
PVM provides a KVM implementation that runs microVMs without hardware
virtualization extensions, so qemu microvm instances can run on any Linode.

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
| `CONFIG_TUN=m` | Required by slirp4netns once spindle networking is wired in. |
| `CONFIG_NETFILTER_ADVANCED=y`, `CONFIG_NETFILTER_XT_MATCH_PKTTYPE=m` | NixOS's iptables firewall rules use the `pkttype` match. |

The host selects `pkgs.iptables-legacy` because nftables is not enabled in the
upstream kernel config. It also sets `boot.initrd.includeDefaultModules = false`
and disables the systemd initrd TPM module: the PVM config lacks NixOS's default
USB/SATA/HID and TPM drivers, and this Linode needs none of them.

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

## Spindle (not yet configured)

Run a Tangled spindle with the microVM engine on this host. References:

- Self-hosting guide: https://docs.tangled.org/spindles.html#self-hosting-guide
- MicroVM host requirements + building/installing images:
  https://docs.tangled.org/spindles.html#running-microvm-workflows
- Engine architecture:
  https://tangled.org/tangled.org/core/blob/master/spindle/engines/microvm/README.md
- NixOS module (upstream in tangled-core, already a flake input here):
  https://tangled.org/tangled.org/core/blob/master/nix/modules/spindle.nix
  (`services.tangled.spindle`)

The spindle engine launches QEMU, so the [QEMU tutorial](./TUTORIAL.md) is the
relevant smoke test. Cloud Hypervisor also supports PVM (from v35; avoid
virtio-pmem rootfs, see [virt-pvm/linux#1](https://github.com/virt-pvm/linux/issues/1)),
but it is not a drop-in replacement for spindle's engine.

Spindle is not configured on `linode-pvm` yet. The host config does not import
the Tangled spindle module or install its runtime dependencies; the tutorial
uses a temporary `nix shell` for QEMU. The smoke test validates the PVM host and
guest, but not spindle startup, vsock, or its workflow image.

Remaining work:

- Import and configure the spindle module.
- Make spindle's QEMU invocation use `-bios qboot.rom` and pass
  `pti=off nokaslr` to the guest.
- Validate vsock under `kvm-pvm`.
- Build a PVM-aware spindle image. Stock spindle images (`spindle-nixos-image`,
  `spindle-alpine-image` from the tangled-core flake) boot stock guest kernels,
  which cannot run under PVM. The NixOS image (built with microvm.nix) must be
  rebuilt with `packages.pvm-guest-kernel`. The image contract per spec.json:
  agent (`shuttle`) started on boot, a `spindle-workflow` user, and a
  `/workspace` work directory.
