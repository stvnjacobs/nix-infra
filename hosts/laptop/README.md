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

## Known issues

### Reloading Sway temporarily resets display scaling

Running `swaymsg reload` restarts `sway-session.target`. Because the Kanshi
service is bound to that target, Kanshi also restarts and Sway may temporarily
fall back to automatic output settings. In the laptop and Dell monitor setup,
this can reset the Dell to scale 1.0 and make applications appear very small.
Some applications may not recover cleanly after Kanshi reapplies the configured
scale.

Do not reload Sway to apply output configuration changes. Restart Kanshi
instead:

```bash
systemctl --user restart kanshi
```

Verify the active layout with:

```bash
swaymsg -t get_outputs | jq '.[] | {name, scale, rect}'
```

If an application remains incorrectly scaled after the output settings have
been restored, restart the application or log out of Sway and back in.
