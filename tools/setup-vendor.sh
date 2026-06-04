#!/usr/bin/env bash
# Clone or refresh upstream asuswrt-merlin.ng (pinned SDK commit).
set -euo pipefail

# shellcheck source=setup-common.sh
source "$(dirname "$0")/setup-common.sh"
gtbe98_read_upstream_config

echo "=== Upstream Merlin ==="
if [[ -d "${GTBE98_VENDOR}/.git" ]]; then
    if ! gtbe98_sdk_ok; then
        echo "Vendor present but SDK missing — checking out ${GTBE98_UPSTREAM_REF} ..."
        git -C "${GTBE98_VENDOR}" fetch --depth 1 origin "${GTBE98_UPSTREAM_REF}" 2>/dev/null \
            || git -C "${GTBE98_VENDOR}" fetch origin "${GTBE98_UPSTREAM_REF}"
        git -C "${GTBE98_VENDOR}" checkout --detach "${GTBE98_UPSTREAM_REF}"
        gtbe98_verify_sdk
    else
        echo "Vendor already present: ${GTBE98_VENDOR}"
        echo "To refresh: rm -rf vendor && ./tools/setup.sh"
    fi
else
    echo "Cloning ${GTBE98_UPSTREAM_URL} (ref: ${GTBE98_UPSTREAM_REF}) ..."
    mkdir -p "${GTBE98_ROOT}/vendor"
    if [[ "${GTBE98_UPSTREAM_REF}" =~ ^[0-9a-f]{7,40}$ ]]; then
        # Pinned to a SHA. `git clone --depth 1 --branch` only accepts branch/tag
        # names, so naively cloning a SHA pulls the FULL history (~3G of .git we
        # never use). Instead shallow-fetch just that commit (GitHub serves
        # by-SHA fetches via allowAnySHA1InWant), keeping .git to one snapshot.
        # Fall back to a full clone if the server refuses a by-SHA fetch.
        if git init -q "${GTBE98_VENDOR}" \
            && git -C "${GTBE98_VENDOR}" remote add origin "${GTBE98_UPSTREAM_URL}" \
            && git -C "${GTBE98_VENDOR}" fetch --depth 1 origin "${GTBE98_UPSTREAM_REF}" 2>/dev/null; then
            git -C "${GTBE98_VENDOR}" checkout --detach FETCH_HEAD
        else
            echo "  shallow by-SHA fetch unavailable; falling back to full clone ..."
            rm -rf "${GTBE98_VENDOR}"
            git clone "${GTBE98_UPSTREAM_URL}" "${GTBE98_VENDOR}"
            git -C "${GTBE98_VENDOR}" checkout --detach "${GTBE98_UPSTREAM_REF}"
        fi
    elif ! git clone --depth 1 --branch "${GTBE98_UPSTREAM_REF}" "${GTBE98_UPSTREAM_URL}" "${GTBE98_VENDOR}" 2>/dev/null; then
        git clone "${GTBE98_UPSTREAM_URL}" "${GTBE98_VENDOR}"
        git -C "${GTBE98_VENDOR}" checkout "${GTBE98_UPSTREAM_REF}"
    fi
    gtbe98_verify_sdk
fi
