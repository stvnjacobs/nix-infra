#!/usr/bin/env bash
# Usage: ./scripts/create-linode.sh <label> <flake-ref> [region] [type]
# Example: ./scripts/create-linode.sh example .#example us-east g6-standard-2
#
# Boot sequence:
#   1. Create instance unbooted — Linode defaults new instances to its own kernel
#      (linode/latest-64bit), which panics on a NixOS image. We must switch the
#      boot configuration before the instance ever starts.
#   2. Switch to linode/grub2 and pin disk layout — Linode's GRUB finds the NixOS
#      grub.cfg on disk and boots it. Disks are explicitly mapped by filesystem type
#      so the image disk is always /dev/sda and swap is always /dev/sdb, regardless
#      of the order Linode assigned them.
#   3. Boot, wait for SSH, then deploy the NixOS config via nixos-rebuild.
set -euo pipefail

LABEL="${1:?Usage: $0 <label> <flake-ref> [region] [type]}"
FLAKE_REF="${2:?Usage: $0 <label> <flake-ref> [region] [type]}"
REGION="${3:-us-east}"
TYPE="${4:-g6-standard-2}"
IMAGE="private/40532238"

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

# Identify disks by filesystem type so the mapping is stable regardless of
# whatever order Linode assigned them. Pin image disk to /dev/sda and swap to
# /dev/sdb so grub.device = "/dev/sda" is always correct.
IMAGE_DISK_ID=$(linode-cli linodes disks-list "$LINODE_ID" \
  --text --no-headers --format id,filesystem 2>&1 | awk '$2 != "swap" {print $1; exit}')
SWAP_DISK_ID=$(linode-cli linodes disks-list "$LINODE_ID" \
  --text --no-headers --format id,filesystem 2>&1 | awk '$2 == "swap" {print $1; exit}')

linode-cli linodes config-update "$LINODE_ID" "$CONFIG_ID" \
  --kernel linode/grub2 \
  --devices.sda.disk_id "$IMAGE_DISK_ID" \
  --devices.sdb.disk_id "$SWAP_DISK_ID" > /dev/null

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
