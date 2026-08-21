# knot-rs setup notes

## Step 1 - create the server

The first knot created used a base Linode configuration. This is a generic server configuration with some Linode defaults applied through the `.#linode` flake.

```sh
./scripts/create-linode knot .#linode
```

## Step 2 - generate and configure master key

Generate once and store it off-server:

```sh
openssl rand -base64 32
```

Write the output to `/etc/knot/master.env` on the knot server:

```sh
# /etc/knot/master.env
KNOT_MASTER_KEY=<base64 output from above>
```

Lock down the file:

```sh
chmod 600 /etc/knot/master.env
```

**Back this up separately from the server.** Back up the master key together with `/var/lib/knot/knot.sealed` (the sealed key store) — they are useless without each other. Losing the master key means the knot can no longer prove cryptographic ownership of its repos to atproto, even though the repos remain readable as plain git. Also back up `/var/lib/knot/repos/` — every git repo plus the knot's ACL data lives there, and it's the knot's entire state.

## Step 3 - moving sshd to port 2222 (giving port 22 to knot-rs)

Tangled's client always generates clone URLs without a port number (assumes 22). knot-rs must own port 22 for those URLs to work without users needing `~/.ssh/config` workarounds.

Do this in two deployment steps to avoid locking yourself out:

### Step 3a — add port 2222 to sshd, keep 22

Temporarily set both ports in `modules/knot.nix`:

```nix
services.openssh.ports = [ 22 2222 ];
```

Deploy:

```sh
nixos-rebuild switch --flake .#knot --target-host root@<ip>
```

From a separate terminal, confirm port 2222 works:

```sh
ssh -p 2222 root@<ip>
```

### Step 3b — hand port 22 to knot-rs

Once port 2222 is confirmed working, switch to the final config (`services.openssh.ports = [ 2222 ]` with `server.ssh_listen_addr = "[::]:22"`):

```sh
nixos-rebuild switch --flake .#knot --target-host root@<ip>
```

All subsequent SSH admin access to the server is on port 2222:

```sh
ssh -p 2222 root@<ip>
```

## Step 4 - verifying the deployment

```sh
curl -s https://knot.jacobs.land/xrpc/_health
curl -s https://knot.jacobs.land/xrpc/sh.tangled.owner
curl -s https://knot.jacobs.land/.well-known/did.json
```

`sh.tangled.owner` should return the first DID in `server.admins`. That's what the Tangled appview reads when you register the knot.
