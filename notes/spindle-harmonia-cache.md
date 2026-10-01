# Future Task: Add a Local Harmonia Cache for Spindle

Spindle currently reads from `cache.nixos.org` and stores workflow artifacts on
disk, but it has no writable Nix binary cache. Workflows that build a custom
NixOS guest toplevel therefore log `not committing toplevel metadata` and may
rebuild that configuration on later runs. This is an optimization, not a
workflow correctness issue.

Possible follow-up:

- Run Harmonia on spindle, bound to loopback, serving the host Nix store.
- Store Harmonia's signing key outside the Nix store with root-only access.
- Configure spindle's `nixCache.uploadUrl` as `ssh-ng://localhost`.
- Add the local Harmonia URL and its public key to `nixCache.readUrls` and
  `nixCache.trustedPublicKeys` so guest builds can reuse uploaded paths.
- Review cache trust and retention before enabling uploads for additional
  users or repositories.

Tangled's `spindle-hel` deployment uses the same general pattern: Harmonia
serves the cache and spindle uploads to its local Nix store over SSH.
