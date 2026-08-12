#!/usr/bin/env bash
# Usage: ./scripts/delete-linode.sh <label>
set -euo pipefail

LABEL="${1:?Usage: $0 <label>}"

LINODE_ID=$(linode-cli linodes list \
  --text --no-headers --format "id,label" \
  | awk -v label="$LABEL" '$2 == label {print $1}')

if [[ -z "$LINODE_ID" ]]; then
  echo "Error: no Linode found with label '$LABEL'" >&2
  exit 1
fi

echo "==> Deleting Linode '$LABEL' (ID: $LINODE_ID)..."
linode-cli linodes delete "$LINODE_ID"
echo "Done."
