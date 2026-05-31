#!/usr/bin/env bash
# Remove Merlin SDK trees not needed for GT-BE98 (BCM96813 / src-rt-5.04behnd.4916).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${VENDOR:-${ROOT}/vendor/asuswrt-merlin.ng}"
KEEP="src-rt-5.04behnd.4916"
RELEASE="${VENDOR}/release"

[[ -d "${RELEASE}" ]] || {
    echo "Missing ${RELEASE} — run ./setup.sh first" >&2
    exit 1
}

cd "${RELEASE}"
removed=0
for d in src-rt-*; do
    [[ -e "$d" ]] || continue
    [[ "$d" == "$KEEP" ]] && continue
    echo "Removing release/${d}"
    rm -rf "$d"
    removed=$((removed + 1))
done

echo "Kept release/${KEEP} and release/src/router/"
echo "Removed ${removed} other SDK director(ies)."
