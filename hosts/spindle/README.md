# Spindle

The Tangled spindle (CI runner) at `spindle.jacobs.land` uses
`hosts/spindle/configuration.nix` as the `spindle` flake output. It runs
workflows with the microVM engine, and with the nixery engine (Docker).

Linode does not expose nested virtualization, so this host boots the PVM host
kernel from the `nixos-pvm` flake input (`pvm.host.enable`). Its `kvm-pvm.ko`
provides `/dev/kvm` without VT-x/SVM. Workflow VMs must boot a PVM guest
kernel, so the host does not use tangled-core's stock images. It installs the
flake's `spindle-image` package as the `nixos` image instead.

| Piece | Where |
| --- | --- |
| PVM host kernel and boot settings | `nixos-pvm`'s host module, enabled in `hosts/spindle/configuration.nix` |
| Spindle service, nginx + ACME, image install | `modules/spindle.nix` |
| Guest image: tangled-core's `spindle-nixos` + PVM guest kernel | `nixos-pvm`'s guest module, enabled in `spindleGuest` in `flake.nix` |

Both kernels are `nixos-pvm`'s packages (`linux-pvm`, `linux-pvm-guest`),
built from `nixos-pvm`'s own nixpkgs pin with nixpkgs' common kernel config.
The host and the image use the same derivations as those packages, so one
build serves all three. Each kernel takes about an hour to build, and there is
no binary cache, so the first deploy after a kernel change builds them
locally.

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

A change to the guest image (`spindleGuest` in `flake.nix`) goes out with `switch`.
The image is a store path, and `systemd-tmpfiles` points
`/var/lib/spindle/images/nixos` at the new path. New workflows use the new
image.

## Creating the host

The host is a `g6-standard-4` (4 vCPU, 8 GB) Linode in `us-east`:

```bash
./scripts/create-linode.sh spindle .#spindle us-east g6-standard-4
ssh root@<ip> reboot
```

The first `switch` runs on the base image's stock kernel; the reboot switches
to the PVM kernel.

Before the first `switch`, create the spindle's signing key. spindle never
generates it and does not start without it. It signs the did:web document at
`/.well-known/did.json`, which tg and the knot use to find the spindle. Keep it
out of the Nix store and back it up: a new key changes the spindle's identity
key.

```bash
ssh root@<ip> 'install -d -m 700 /var/lib/secrets &&
  openssl ecparam -name prime256v1 -genkey -noout -out /var/lib/secrets/spindle-key.pem &&
  chmod 600 /var/lib/secrets/spindle-key.pem'
```

After the reboot, check the host:

```bash
ssh root@<ip> 'uname -r; lsmod | grep ^kvm_pvm; ls -l /dev/kvm /dev/vhost-vsock; systemctl is-active spindle nginx firewall docker; iptables -V'
```

The kernel must be `6.12.33`, `kvm_pvm` must be loaded, and `iptables -V` must
report `nf_tables`.

Set the `A` and `AAAA` records for `spindle.jacobs.land`. ACME uses self-signed
certificates until DNS resolves, then retries on its timer. To retry
immediately, run `systemctl start acme-order-renew-spindle.jacobs.land`.

Check the endpoint:

```bash
curl --fail-with-body https://spindle.jacobs.land/xrpc/sh.tangled.owner
```

The response must contain the owner DID from `modules/spindle.nix`. The
appview checks this value when you register the spindle.

Check the DID document:

```bash
curl --fail-with-body https://spindle.jacobs.land/.well-known/did.json
```

It must have the `id` `did:web:spindle.jacobs.land` and a `#tangled_spindle`
service of type `TangledSpindle` pointing at `https://spindle.jacobs.land`.

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

- **Docker is back.** The upstream module enables Docker for
  `engine: nixery` workflows; the PVM host kernel has nixpkgs' common config,
  including the nf_tables support Docker's `iptables` needs. Nixery
  containers are not counted in `limits.total`, so they compete with microVMs
  for the host's remaining memory.
- **Host kernel options.** The host kernel comes with nixpkgs' common config,
  which has what spindle needs: `TUN` (a module) for slirp4netns,
  `CFS_BANDWIDTH` for cgroup v2 `cpu.max` workflow CPU limits, and `USER_NS`
  for QEMU's per-workflow network namespaces. More options would go through
  `boot.kernelPatches`, which means building and maintaining a kernel of our
  own. Deploy host-kernel changes with `nixos-rebuild boot` and reboot;
  `switch` does not replace the running kernel.
- **Budget.** Each workflow VM asks for 4 GiB and 2 vCPUs.
  `limits.total` (6 GiB, 4 vCPUs) allows one such VM at a time and leaves
  about 2 GiB for the host. `cgroup.enable` contains each VM so that an OOM
  kills the workflow, not spindle.
- **Guest kernel.** The guest kernel is modular, like nixpkgs' own kernels.
  tangled-core's image config slims its modules and loads the virtio, erofs,
  ext4 and overlay modules in the initrd, as for its stock kernel. QEMU's
  `microvm` machine uses qboot by default, so the image needs no `-bios`
  override. PVM guests need `pti=off nokaslr`; the guest module adds both to
  the kernel parameters.
- **Module lookup after in-guest rebuilds.** A workflow that sets
  `dependencies`, `services`, or `virtualisation` builds a new toplevel inside
  the guest from `/etc/spindle/nixos/default.nix`. That file imports
  tangled-core's base and runner modules, not the PVM guest module. The rebuilt
  system therefore references the stock nixpkgs kernel, which the guest
  substitutes but never boots. `switch-to-configuration test` keeps the
  running PVM kernel. Modules loaded after that come from kmod's search path:
  `/run/booted-system/kernel-modules` first, then
  `/run/current-system/kernel-modules`. Because the guest kernel is now
  modular, this matters (Docker in the guest needs overlay, bridge and
  `nf_*`), and it has not been tested end to end. Modules from the rebuilt
  config's `boot.extraModulePackages` are built for the stock kernel and do
  not load.
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
- PVM host and guest kernels: the `nixos-pvm` repo (`nixos-pvm` flake input).
