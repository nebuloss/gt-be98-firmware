#!/usr/bin/env bash
# Remove vendor tree and re-run setup (clone + prune + patches).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

read -r -p "Remove vendor/ and re-clone upstream? [y/N] " ans
[[ "${ans,,}" == "y" ]] || exit 0

rm -rf "${ROOT}/vendor"
exec "${ROOT}/setup.sh"
