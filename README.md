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

## Hosts

- [Laptop](hosts/laptop/README.md): applying changes and known issues.
- [Knot](hosts/knot/README.md): deployment, initial setup, and recovery.
