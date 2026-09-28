# nixos

NixOS system configuration managed with flakes.

## Developing

Enter the development shell with development and deployment tools:

```bash
nix develop
```

### Formatting

```bash
nixfmt hosts/laptop/configuration.nix
```

## Patched nixpkgs

Server hosts (`linode`, `knot-bootstrap`, `knot`) are evaluated from a patched copy
of their nixpkgs input via `patchedNixosSystem` in `flake.nix`. The patches are
listed in `serverNixpkgsPatches`:

- [nixpkgs#416192](https://github.com/NixOS/nixpkgs/pull/416192) — makes
  `virtualisation/linode-config.nix` mount root by the `nixos` label and swap by the
  `linode-swap` label, so booting no longer depends on Linode's `/dev/sd*` order.

Remove a patch once it is in the pinned nixpkgs. The laptop uses unpatched nixpkgs.

## Hosts

- [Laptop](hosts/laptop/README.md): applying changes and known issues.
- [Knot](hosts/knot/README.md): deployment, initial setup, and recovery.

## Images

### Linode image

`linode-image-gz` is the `linode` host's configuration built with nixpkgs's
`images.linode` variant. Build a gzip'd disk image suitable for upload as a Linode
custom image:

```bash
nix build .#linode-image-gz
linode-cli image-upload \
  --label "$(basename result/nixos-image-linode-*.img.gz | sed 's/-x86_64-linux\.img\.gz//')" \
  --region us-east result/nixos-image-linode-*.img.gz
```

The image uses `linode/grub2` as the boot method. After uploading, update `IMAGE` in
`scripts/create-linode.sh` with the new image ID. Configuration changes are deployed
via `nixos-rebuild --target-host`, not by rebuilding the image.
