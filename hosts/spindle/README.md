# Spindle

The Tangled spindle (CI runner) at `spindle.jacobs.land` uses
`hosts/spindle/configuration.nix` as the `spindle` flake output. It runs
workflows with the microVM engine only.

Linode does not expose nested virtualization, so this host boots the PVM host
kernel (`modules/pvm-host.nix`, built from the same source and base config as
`linode-pvm`'s, plus the options spindle needs). Its
`kvm-pvm.ko` provides `/dev/kvm` without VT-x/SVM. Workflow VMs must boot a
PVM-aware kernel, so the host does not use tangled-core's stock images. It
installs the flake's `spindle-image` package as the `nixos` image instead.

| Piece | File |
| --- | --- |
| PVM host kernel and boot settings | `modules/pvm-host.nix` |
| PVM host kernel config | `pkgs/pvm-kernel.nix` |
| Host kernel config additions | `pvm.host.extraKernelConfig` in `modules/spindle.nix` |
| Spindle service, nginx + ACME, image install | `modules/spindle.nix` |
| Guest image: tangled-core's `spindle-nixos` + PVM guest kernel | `hosts/spindle/guest.nix` |
| Guest kernel config additions | `pvm.mkGuest` in `hosts/spindle/guest.nix` |

## Deploying

Build locally, or deploy over SSH:

```bash
nixos-rebuild build --flake .#spindle
nixos-rebuild switch --flake .#spindle --target-host root@spindle.jacobs.land
```

`switch` never swaps the running kernel. After a change to the host kernel, use
`boot` and then reboot:

```bash
nixos-rebuild boot --flake .#spindle --target-host root@spindle.jacobs.land
ssh root@spindle.jacobs.land reboot
```

A change to the guest image (`hosts/spindle/guest.nix`) goes out with `switch`.
The image is a store path, and `systemd-tmpfiles` points
`/var/lib/spindle/images/nixos` at the new path. New workflows use the new
image.

## Creating the host

The host is a `g6-standard-4` (4 vCPU, 8 GB) Linode in `us-east`:

```bash
./scripts/create-linode.sh spindle .#spindle us-east g6-standard-4
ssh root@<ip> reboot
```

The first `switch` runs on the base image's stock kernel. There,
`firewall.service` fails to reload because the configuration selects
`iptables-legacy`. The reboot into the PVM kernel fixes this.

After the reboot, check the host:

```bash
ssh root@<ip> 'uname -r; lsmod | grep ^kvm_pvm; ls -l /dev/kvm /dev/vhost-vsock; systemctl is-active spindle nginx firewall'
```

The kernel must be `6.12.33`, and `kvm_pvm` must be loaded.

Set the `A` and `AAAA` records for `spindle.jacobs.land`. ACME uses self-signed
certificates until DNS resolves, then retries on its timer. To retry
immediately, run `systemctl start acme-order-renew-spindle.jacobs.land`.

Check the endpoint:

```bash
curl --fail-with-body https://spindle.jacobs.land/xrpc/sh.tangled.owner
```

The response must contain the owner DID from `modules/spindle.nix`. The
appview checks this value when you register the spindle.

## Using it

1. Register `spindle.jacobs.land` in the Tangled spindle settings.
2. Select it in a repository's pipeline settings.
3. Add a workflow such as `.tangled/workflows/ci.yml`:

   ```yaml
   when:
     - event: ["push", "manual"]
       branch: ["main"]
   engine: microvm
   image: nixos
   dependencies:
     - hello
   steps:
     - name: hello
       command: |
         uname -r
         hello
   ```

   `uname -r` prints `6.12.33`, the PVM guest kernel.

Watch a run from the host:

```bash
journalctl -fu spindle
```

## Notes and limitations

- **Microvm only.** The host disables the upstream module's Docker, so
  `engine: nixery` workflows fail. The PVM host kernel has no nftables, and
  Docker's `iptables` needs it.
- **Host kernel options.** `modules/spindle.nix` adds to the PVM host kernel
  through `pvm.host.extraKernelConfig`: `CONFIG_TUN=m` for slirp4netns,
  `CONFIG_CFS_BANDWIDTH=y` for cgroup v2 `cpu.max` workflow CPU limits, and
  `CONFIG_USER_NS=y` for QEMU's per-workflow network namespaces. Deploy
  host-kernel changes with `nixos-rebuild boot` and reboot; `switch` does not
  replace the running kernel.
- **Budget.** Each workflow VM asks for 4 GiB and 2 vCPUs.
  `limits.total` (6 GiB, 4 vCPUs) allows one such VM at a time and leaves
  about 2 GiB for the host. `cgroup.enable` contains each VM so that an OOM
  kills the workflow, not spindle.
- **Guest kernel.** The upstream PVM guest config is monolithic and
  Kata-oriented. `guest.nix` builds everything in (`=y`) and adds what the
  NixOS guest needs: systemd options, zram, nftables for the firewall and
  Docker, and bridge/overlay networking. It enables `CONFIG_MODULES` only so
  the kernel build emits `modules.builtin`, which NixOS's module tooling
  reads. QEMU's `microvm` machine uses qboot by default, so the image needs no
  `-bios` override. PVM guests need `pti=off nokaslr`; the image adds both to
  `bootArgs`.
- **In-guest rebuilds use a stock kernel.** A workflow that sets
  `dependencies`, `services`, or `virtualisation` builds a new toplevel inside
  the guest from `/etc/spindle/nixos/default.nix`. That file imports
  tangled-core's base and runner modules, not `guest.nix`. The rebuilt
  system therefore references the stock nixpkgs kernel, which the guest
  substitutes but never boots. `switch-to-configuration test` keeps the
  running PVM kernel, and modprobe falls back to
  `/run/booted-system/kernel-modules`, a search path in nixpkgs' kmod. This
  costs download time, and it has not been tested end to end.
- **Jetstream at boot.** spindle retries Jetstream without backoff, so the
  service waits for `network-online.target`.

## References

- Self-hosting guide: https://docs.tangled.org/spindles.html#self-hosting-guide
- MicroVM host requirements + building/installing images:
  https://docs.tangled.org/spindles.html#running-microvm-workflows
- Engine architecture:
  https://tangled.org/tangled.org/core/blob/master/spindle/engines/microvm/README.md
- NixOS module (upstream in tangled-core, a flake input here):
  https://tangled.org/tangled.org/core/blob/master/nix/modules/spindle.nix
  (`services.tangled.spindle`)
- PVM host and guest kernels: [linode-pvm](../linode-pvm/README.md).
