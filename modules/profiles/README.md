# Platform profiles

Platform profiles handle hardware and boot concerns — where a machine runs, not what it does. Each server host imports exactly one profile.

## linode.nix

For instances deployed from a custom Linode image (`packages.linode-image-gz`) using `linode/grub2` boot.

Wraps nixpkgs's `virtualisation/linode-config.nix`, which handles: serial console, eth0 DHCP, and required virtio kernel modules. Overrides root to mount by label and swap to mount by label, so both are stable regardless of which `/dev/sd*` Linode assigns to each disk.
