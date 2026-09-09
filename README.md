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
    configuration.nix            # Example Linode host config
images/
  linode/
    configuration.nix            # Source for linode-image-gz
modules/
  profiles/
    linode.nix                   # Linode platform profile
  server.nix                     # Shared server base
  users.nix                      # User accounts
  security.nix                   # Firewall and polkit
```

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

Build a gzip'd disk image suitable for upload as a Linode custom image:

```bash
nix build .#linode-image-gz
linode-cli image-upload \
  --label "$(basename result/nixos-image-linode-*.img.gz | sed 's/-x86_64-linux\.img\.gz//')" \
  --region us-east result/nixos-image-linode-*.img.gz
```

The image uses `linode/grub2` as the boot method. After uploading, update `IMAGE` in
`scripts/create-linode.sh` with the new image ID. Configuration changes are deployed via
`nixos-rebuild --target-host`, not by rebuilding the image.
