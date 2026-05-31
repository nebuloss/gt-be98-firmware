#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${VENDOR:-${ROOT}/vendor/asuswrt-merlin.ng}"
PATCH_DIR="${ROOT}/patches"

[[ -d "$VENDOR/release" ]] || {
    echo "Missing vendor tree: $VENDOR — run ./setup.sh first" >&2
    exit 1
}

cd "$VENDOR"
for p in "${PATCH_DIR}"/[0-9]*.patch; do
    echo "Applying $(basename "$p") ..."
    if patch -p1 --forward -i "$p"; then
        continue
    fi
    if patch -p1 --reverse --dry-run -i "$p" >/dev/null 2>&1; then
        echo "  already applied, skipping"
        continue
    fi
    echo "Failed: $p" >&2
    exit 1
done
echo "Patches applied under $VENDOR"
