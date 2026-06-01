#!/usr/bin/env bash
# Run full setup when toolchain or vendor SDK is missing (called from build.sh).
set -euo pipefail

# shellcheck source=setup-common.sh
source "$(dirname "$0")/setup-common.sh"

if [[ "${GTBE98_SKIP_SETUP:-}" == "1" ]]; then
    if gtbe98_needs_setup; then
        echo "GTBE98_SKIP_SETUP=1 but missing: $(gtbe98_setup_missing_reason | tr '\n' ' ')" >&2
        exit 1
    fi
    exit 0
fi

if gtbe98_needs_setup; then
    reason="$(gtbe98_setup_missing_reason | tr '\n' ',' | sed 's/,$//')"
    echo "=== Missing ${reason} — running setup ===" >&2
    "${GTBE98_ROOT}/tools/setup.sh"
fi
