# Boot a QEMU microVM on Linode

This walkthrough creates a Linode running the PVM host kernel, then boots a
minimal PVM-aware Linux guest with QEMU. It ends at a guest shell; it does not
set up Tangled spindle or vsock.

Creating the Linode starts a billable instance. The commands below use the
`us-east` region and `g6-standard-2` size by default; change these if needed.
The final section deletes the instance.

Before starting, use an x86_64 Linux workstation with Nix flakes enabled. You
also need a Linode API token configured for `linode-cli` and an SSH public key
at `~/.ssh/id_ed25519.pub`. Check the CLI login and key before building:

```console
$ nix develop
$ linode-cli linodes list --text
$ test -r ~/.ssh/id_ed25519.pub && echo "SSH key is readable"
SSH key is readable
```

If your public key is at a different path, export `SSH_KEY=/path/to/key.pub`
before running `scripts/create-linode.sh`.

## 1. Create the host

From the repository root, create a Linode from the generic base image and deploy
the `linode-pvm` configuration to it. The first deploy builds the PVM host
kernel on your workstation, which takes a while:

```bash
./scripts/create-linode.sh linode-pvm-tutorial .#linode-pvm us-east g6-standard-2
```

At the end the script prints the instance IP. The Linode is still running the
base image's stock kernel, so reboot it into the PVM kernel, substituting that
IP:

```console
$ ssh root@203.0.113.42 reboot
```

## 2. Check the host

Wait for SSH to return, then connect as root:

```console
$ ssh root@203.0.113.42
```

Check that the PVM kernel is running and that `kvm-pvm` loaded at boot and
created `/dev/kvm`:

```console
root@linode-pvm:~# uname -r
6.12.33
root@linode-pvm:~# lsmod | grep '^kvm_pvm'
kvm_pvm ...
root@linode-pvm:~# ls -l /dev/kvm
crw-rw-rw- 1 root kvm ... /dev/kvm
root@linode-pvm:~# systemctl is-active firewall.service
active
```

If the kernel version is not `6.12.33`, the Linode did not boot the new
generation; check the GRUB menu through the LISH console. If `kvm_pvm` is not
loaded, `journalctl -k -g kvm_pvm` shows why. Stop here until both are fixed:
QEMU cannot use PVM without `/dev/kvm`.

## 3. Build the guest kernel

On your workstation, in the repository, build the PVM-aware guest kernel and
copy it to the Linode:

```console
$ GUEST_KERNEL=$(nix build .#pvm-guest-kernel --no-link --print-out-paths)
$ scp "$GUEST_KERNEL/bzImage" root@203.0.113.42:/root/pvm-guest-kernel
```

The guest kernel must be PVM-aware too; a stock kernel is not a substitute.
The guest also needs `pti=off nokaslr` on its command line.

## 4. Make a tiny guest initramfs

Still on your workstation, open a shell with `fakeroot` and `cpio` from this
flake's pinned nixpkgs:

```console
$ nix shell --inputs-from . nixpkgs#fakeroot nixpkgs#cpio --command bash
```

In that shell, assemble an initramfs with a console, procfs, sysfs, and a shell.
It uses a static BusyBox so the guest does not depend on the workstation's
libraries. BusyBox is copied by path rather than added to the shell, because its
static `mknod` would bypass `fakeroot`:

```bash
BUSYBOX=$(nix build --inputs-from . nixpkgs#pkgsStatic.busybox --no-link --print-out-paths)
WORK=$(mktemp -d)
mkdir -p "$WORK"/{bin,dev,proc,sys}
cp "$BUSYBOX/bin/busybox" "$WORK/bin/busybox"
ln -s busybox "$WORK/bin/sh"
ln -s busybox "$WORK/bin/mount"
ln -s busybox "$WORK/bin/uname"
cat > "$WORK/init" <<'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
echo "PVM microVM booted; guest kernel: $(uname -r)"
exec /bin/sh
EOF
chmod +x "$WORK/init"
cd "$WORK"
fakeroot bash -euo pipefail -c '
  mknod dev/console c 5 1
  find . -print0 | cpio --null -o --format=newc | gzip -9 > /tmp/pvm-initrd.cpio.gz
'
```

Copy the initramfs to the Linode, then leave the temporary shell:

```console
$ scp /tmp/pvm-initrd.cpio.gz root@203.0.113.42:/root/pvm-initrd.cpio.gz
$ exit
```

## 5. Boot the microVM

Back in the Linode SSH session, run QEMU from a temporary Nix shell. QEMU's
`microvm` machine takes the kernel and initramfs directly. PVM guests need the
qboot firmware that ships with QEMU instead of the default SeaBIOS:

```console
root@linode-pvm:~# nix shell nixpkgs#qemu -c qemu-system-x86_64 \
  -machine microvm -bios qboot.rom \
  -accel kvm -cpu host -m 512M -smp 1 \
  -kernel /root/pvm-guest-kernel \
  -initrd /root/pvm-initrd.cpio.gz \
  -append 'console=ttyS0 rdinit=/init pti=off nokaslr' \
  -nographic -no-reboot
```

Successful boot reaches the guest shell and prints the PVM guest kernel version:

```text
PVM microVM booted; guest kernel: 6.12.33
~ # uname -r
6.12.33
~ #
```

This proves QEMU opened `/dev/kvm`, entered the `microvm` machine, and ran the
PVM-aware guest kernel to userspace. Exit QEMU with `Ctrl-A`, then `X`.

During this successful boot, the host also logged `kvm_pvm: Inject event in
non-PVM mode` and a KVM PFN-cache warning. The guest still reached userspace;
the related upstream report is [virt-pvm/linux#21](https://github.com/virt-pvm/linux/issues/21).

If QEMU reports that `/dev/kvm` is unavailable, return to step 2. If the VM
starts but the guest does not reach the shell, capture the full serial output
and check that both copied files came from the commands above.

## 6. Delete the Linode

From the repository root, delete the instance when finished:

```console
$ ./scripts/delete-linode.sh linode-pvm-tutorial
```
