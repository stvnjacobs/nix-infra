# Knot

The Tangled Knot git-hosting server uses `hosts/knot/configuration.nix` as the
`knot` flake output. It uses its original Linode image with an explicit
root-filesystem UUID.

## Later deployments

Build locally or deploy over administrative SSH on port 2222 (Knot Git SSH uses
port 22):

```sh
nixos-rebuild build --flake .#knot
NIX_SSHOPTS="-p 2222" nixos-rebuild switch --flake .#knot --target-host root@<ip-or-hostname>
```

## Initial setup

Use this procedure to create `knot.jacobs.land`.

Run all local commands from the root of this repository.

### Before you start

Make sure that these requirements are met:

- You can use the Linode account with `linode-cli`.
- You can use the private Linode image in `scripts/create-linode.sh`.
- The public key `$HOME/.ssh/id_ed25519.pub` exists.
- You can change the DNS record for `knot.jacobs.land`.
- You have a secure location for the Knot master key.

Enter the development shell:

```sh
nix develop
```

### Understand the SSH port change

The setup uses two NixOS configurations:

| Configuration | Administrative SSH | Knot Git SSH |
| --- | --- | --- |
| `.#knot-bootstrap` | Ports 22 and 2222 | Off |
| `.#knot` | Port 2222 | Port 22 |

The transition configuration keeps both administrative SSH ports open. This configuration prevents a lockout during the port change.

> **WARNING:** Do not deploy `.#knot` until a new SSH connection works on port 2222.

### 1. Create the server

Create the Linode with the transition configuration:

```sh
./scripts/create-linode.sh knot .#knot-bootstrap
```

The script prints the server IP address. Use this address for `<ip>` in the remaining steps.

The script deploys `.#knot-bootstrap` through port 22. Knot does not run in this configuration.

### 2. Configure DNS

Set the `A` record for `knot.jacobs.land` to `<ip>`.

Wait for the DNS change. Then, make sure that DNS returns `<ip>`:

```sh
dig +short A knot.jacobs.land
```

Do not deploy the final configuration until this command returns the correct address. The final deployment requests a TLS certificate for `knot.jacobs.land`.

### 3. Install the master key

Generate one master key on your local computer:

```sh
openssl rand -base64 32
```

Save the key in a password manager or an equivalent secret store. Do not save the key in this repository.

Open an administrative SSH session:

```sh
ssh root@<ip>
```

Create the environment file on the server:

```sh
install -d -m 0700 /etc/knot
umask 077
vim /etc/knot/master.env
```

Put only this line in the file:

```text
KNOT_MASTER_KEY=<master-key>
```

Set the file mode and close the SSH session:

```sh
chmod 0600 /etc/knot/master.env
exit
```

Make sure that the file has the correct owner and mode:

```sh
ssh root@<ip> 'stat -c "%a %U:%G %n" /etc/knot/master.env'
```

The command must show this result:

```text
600 root:root /etc/knot/master.env
```

### 4. Test port 2222

Make sure that new SSH connections work on both administrative ports:

```sh
ssh root@<ip> true
ssh -p 2222 root@<ip> true
```

Both commands must complete without an error.

Open a new session on port 2222. Keep this session open during the final deployment:

```sh
ssh -p 2222 root@<ip>
```

> **WARNING:** Do not continue if the port 2222 connection fails.

### 5. Deploy knot-rs

In a different terminal, deploy the final configuration through port 2222:

```sh
NIX_SSHOPTS="-p 2222" nixos-rebuild switch --flake .#knot --target-host root@<ip>
```

The final configuration makes these changes:

- sshd stops listening on port 22.
- sshd continues to listen on port 2222.
- knot-rs starts to listen on port 22.
- nginx starts to serve HTTPS on ports 80 and 443.

Keep the port 2222 session open until all checks in the next section are successful.

### 6. Verify the server

Make sure that the required services are active:

```sh
ssh -p 2222 root@<ip> 'systemctl is-active knot-rs nginx'
```

The command must print `active` for both services.

Check the Knot HTTP endpoints:

```sh
curl --fail-with-body --silent --show-error https://knot.jacobs.land/xrpc/_health
curl --fail-with-body --silent --show-error https://knot.jacobs.land/xrpc/sh.tangled.owner
curl --fail-with-body --silent --show-error https://knot.jacobs.land/.well-known/did.json
```

The `sh.tangled.owner` response must contain the first DID in `server.admins`. The Tangled appview uses this value when you register the Knot.

Make sure that the Knot SSH service answers on port 22:

```sh
ssh-keyscan -p 22 knot.jacobs.land
```

The command must return one or more SSH host keys.

Open one new administrative session after the deployment:

```sh
ssh -p 2222 root@<ip>
```

You can now close the session that you kept open during the deployment.

### 7. Back up Knot

Back up these items as one recovery set:

- The master key in your secret store
- `/var/lib/knot/sealed-keys`
- `/var/lib/knot/repos/`
- `/var/lib/knot/ssh_host_key`

The `repos` directory contains all Git repositories and Knot access-control data. The sealed-key file and the master key are both necessary to prove repository ownership to atproto. The SSH host key keeps the same server identity after a restore.

Store the recovery set separately from the server. Update the backup after Knot data changes. Test the restore procedure.
