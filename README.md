# nixos

NixOS system configuration managed with flakes.

## Structure

```
flake.nix                        # Flake inputs and nixosConfigurations
hosts/
  laptop/
    configuration.nix            # Laptop host config
    home.nix                     # Home Manager config for steven
    hardware-configuration.nix   # Auto-generated, do not edit
  linode/
    configuration.nix            # Generic Linode host; also the base image
  knot/
    configuration.nix            # Tangled Knot server on Linode
modules/
  server.nix                     # Shared server base
  knot.nix                       # Knot service, ACME, and nginx
  users.nix                      # User accounts
  security.nix                   # Firewall and polkit
```

## Patched nixpkgs

Server hosts (`linode`, `knot`) are evaluated from a patched copy of their nixpkgs
input via `patchedNixosSystem` in `flake.nix`. The patches are listed in
`serverNixpkgsPatches`:

- [nixpkgs#416192](https://github.com/NixOS/nixpkgs/pull/416192) — makes
  `virtualisation/linode-config.nix` mount root by the `nixos` label and swap by the
  `linode-swap` label, so booting no longer depends on Linode's `/dev/sd*` order.

Remove a patch once it is in the pinned nixpkgs. The laptop uses unpatched nixpkgs.

## Formatting

```bash
nixfmt hosts/laptop/configuration.nix
```

## Hosts

These are the target platforms which can be deployed using `nixos-rebuild`.

### Laptop

The active laptop configuration is `hosts/laptop/configuration.nix`, exposed as the
`laptop` flake output:

```bash
sudo nixos-rebuild build --flake .#laptop
sudo nixos-rebuild test --flake .#laptop
sudo nixos-rebuild switch --flake .#laptop
```

## Images

These are configurations for building base NixOS images for the target platform.

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
`scripts/create-linode.sh` with the new image ID. Configuration changes are deployed via
`nixos-rebuild --target-host`, not by rebuilding the image.
