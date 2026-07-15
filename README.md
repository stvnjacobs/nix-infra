# nixos

NixOS system configuration managed with flakes.

## Structure

```
flake.nix                        # Flake inputs and nixosConfigurations
hosts/
  nixos/
    configuration.nix            # Host-level system config
    home.nix                     # Home Manager config for steven
    hardware-configuration.nix   # Auto-generated, do not edit
modules/
  users.nix                      # User accounts
  security.nix                   # Firewall and polkit
```

## Applying changes

```bash
# Build only (check for errors)
sudo nixos-rebuild build --flake .#nixos

# Activate temporarily (reverts on reboot)
sudo nixos-rebuild test --flake .#nixos

# Activate and set as boot default
sudo nixos-rebuild switch --flake .#nixos
```

## Formatting

```bash
nixfmt hosts/nixos/configuration.nix
```
