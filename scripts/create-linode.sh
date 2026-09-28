#!/usr/bin/env bash
# Usage: ./scripts/create-linode.sh <label> <flake-ref> [region] [type]
# Example: ./scripts/create-linode.sh example .#example us-east g6-standard-2
#
# Environment:
#   IMAGE             Linode image ID (default: private/41512458)
#   SSH_KEY           Public key injected for root (default: ~/.ssh/id_ed25519.pub)
#   SSH_WAIT_TIMEOUT  Seconds to wait for first-boot SSH (default: 300)
#
# The image must be a NixOS Linode image built from this flake's `linode` host
# (see README). The patched nixpkgs Linode module mounts root by the `nixos`
# label and swap by the `linode-swap` label. Instances are created unbooted
# because Linode's default kernel cannot boot the image; this script changes
# the boot configuration to linode/grub2 before first boot.
#
# Linode's disk-slot assignments are preserved. Linode's GRUB boots from the
# config's root_device, which already points at the image disk, and the
# kernel's /dev/sd* order does not matter because of the label mounts.
set -euo pipefail

LABEL="${1:?Usage: $0 <label> <flake-ref> [region] [type]}"
FLAKE_REF="${2:?Usage: $0 <label> <flake-ref> [region] [type]}"
REGION="${3:-us-east}"
TYPE="${4:-g6-standard-2}"
IMAGE="${IMAGE:-private/41512458}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519.pub}"
SSH_WAIT_TIMEOUT="${SSH_WAIT_TIMEOUT:-300}"

[[ -r "$SSH_KEY" ]] || { echo "Error: SSH public key not readable: $SSH_KEY" >&2; exit 1; }

cleanup_on_error() {
  if [[ -n "${LINODE_ID:-}" ]]; then
    echo "Instance $LINODE_ID was created; delete it with scripts/delete-linode.sh if needed." >&2
  fi
}
trap cleanup_on_error ERR

printf "==> Creating Linode '%s' from %s (not booted)...\n" "$LABEL" "$IMAGE"
LINODE_ID=$(linode-cli linodes create \
  --image "$IMAGE" \
  --region "$REGION" \
  --type "$TYPE" \
  --label "$LABEL" \
  --root_pass "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)" \
  --authorized_keys "$(<"$SSH_KEY")" \
  --booted false \
  --text --no-headers --format id)
printf '    Linode ID: %s\n' "$LINODE_ID"

printf '%s\n' '==> Configuring grub2 boot...'
CONFIG_ID=$(linode-cli linodes configs-list "$LINODE_ID" --text --no-headers --format id)
[[ -n "$CONFIG_ID" ]] || {
  echo "Error: could not find the instance configuration." >&2
  exit 1
}

linode-cli linodes config-update "$LINODE_ID" "$CONFIG_ID" \
  --kernel linode/grub2 > /dev/null

printf '%s\n' '==> Booting...'
linode-cli linodes boot "$LINODE_ID" > /dev/null
IP=$(linode-cli linodes view "$LINODE_ID" --text --no-headers --format ipv4 | awk '{ print $1 }')
printf '    IP: %s\n' "$IP"

printf '%s\n' '==> Waiting for SSH...'
ssh_deadline=$((SECONDS + SSH_WAIT_TIMEOUT))
until ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$IP" true 2>/dev/null; do
  if (( SECONDS >= ssh_deadline )); then
    echo "Error: SSH did not become ready within ${SSH_WAIT_TIMEOUT} seconds." >&2
    exit 1
  fi
  sleep 5
done

printf "==> Deploying %s...\n" "$FLAKE_REF"
nixos-rebuild switch --flake "$FLAKE_REF" --target-host "root@$IP"
trap - ERR

printf '\nDone. %s is running at %s\n' "$LABEL" "$IP"
printf 'To update: nixos-rebuild switch --flake %s --target-host root@%s\n' "$FLAKE_REF" "$IP"
