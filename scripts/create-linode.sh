#!/usr/bin/env bash
# Usage: ./scripts/create-linode.sh <label> <flake-ref> [region] [type]
# Example: ./scripts/create-linode.sh example .#example us-east g6-standard-2
#
# Boot sequence:
#   1. Create instance unbooted — Linode defaults new instances to its own kernel
#      (linode/latest-64bit), which panics on a NixOS image. We must switch the
#      boot configuration before the instance ever starts.
#   2. Switch to linode/grub2 — Linode's GRUB loads grub.cfg from the config's
#      root_device, which Linode's default config already points at the image
#      disk. Disk-slot assignments are otherwise left alone: the kernel may
#      enumerate disks in any order, and the patched nixpkgs Linode module mounts
#      root by the `nixos` label and swap by the `linode-swap` label.
#   3. Boot, wait for SSH, then deploy the NixOS config via nixos-rebuild.
set -euo pipefail

LABEL="${1:?Usage: $0 <label> <flake-ref> [region] [type]}"
FLAKE_REF="${2:?Usage: $0 <label> <flake-ref> [region] [type]}"
REGION="${3:-us-east}"
TYPE="${4:-g6-standard-2}"
IMAGE="private/41512458"

echo "==> Creating Linode '$LABEL' (not booted)..."
LINODE_ID=$(linode-cli linodes create \
  --image "$IMAGE" \
  --region "$REGION" \
  --type "$TYPE" \
  --label "$LABEL" \
  --root_pass "$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)" \
  --authorized_keys "$(cat "$HOME/.ssh/id_ed25519.pub")" \
  --booted false \
  --text --no-headers --format id 2>&1)

echo "    Linode ID: $LINODE_ID"

echo "==> Configuring grub2 boot..."
CONFIG_ID=$(linode-cli linodes configs-list "$LINODE_ID" \
  --text --no-headers --format id 2>&1)

linode-cli linodes config-update "$LINODE_ID" "$CONFIG_ID" \
  --kernel linode/grub2 > /dev/null

echo "==> Booting..."
linode-cli linodes boot "$LINODE_ID" > /dev/null

IP=$(linode-cli linodes view "$LINODE_ID" \
  --text --no-headers --format ipv4 2>&1)
echo "    IP: $IP"

echo "==> Waiting for SSH..."
until ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$IP" true 2>/dev/null; do
  sleep 5
done

echo "==> Deploying $FLAKE_REF..."
nixos-rebuild switch \
  --flake "$FLAKE_REF" \
  --target-host "root@$IP"

echo ""
echo "Done. $LABEL is running at $IP"
echo "To update: nixos-rebuild switch --flake $FLAKE_REF --target-host root@$IP"
