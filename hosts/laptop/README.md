# laptop

## Applying changes

```bash
# Build only (check for errors)
sudo nixos-rebuild build --flake .#laptop

# Activate temporarily (reverts on reboot)
sudo nixos-rebuild test --flake .#laptop

# Activate and set as boot default
sudo nixos-rebuild switch --flake .#laptop
```
