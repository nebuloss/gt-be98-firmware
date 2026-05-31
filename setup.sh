#!/usr/bin/env bash
# Fetch toolchain, clone upstream Merlin, prune SDKs, apply GT-BE98 patches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VENDOR="${ROOT}/vendor/asuswrt-merlin.ng"
UPSTREAM_FILE="${ROOT}/UPSTREAM"

echo "=== 1/4 Toolchain (RMerl/am-toolchains) ==="
"${ROOT}/tools/fetch-toolchain.sh"

# Override via env: UPSTREAM_REF=<tag> ./setup.sh
if [[ -f "$UPSTREAM_FILE" ]]; then
    UPSTREAM_URL="${UPSTREAM_URL:-$(grep -E '^url=' "$UPSTREAM_FILE" | cut -d= -f2-)}"
    UPSTREAM_REF="${UPSTREAM_REF:-$(grep -E '^ref=' "$UPSTREAM_FILE" | cut -d= -f2-)}"
fi
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/gnuton/asuswrt-merlin.ng.git}"
UPSTREAM_REF="${UPSTREAM_REF:-master}"

echo "=== 2/4 Upstream Merlin ==="
if [[ -d "${VENDOR}/.git" ]]; then
    echo "Vendor already present: ${VENDOR}"
    echo "To refresh: rm -rf vendor && ./setup.sh"
else
    echo "Cloning ${UPSTREAM_URL} (ref: ${UPSTREAM_REF}) ..."
    mkdir -p "${ROOT}/vendor"
    if ! git clone --depth 1 --branch "${UPSTREAM_REF}" "${UPSTREAM_URL}" "${VENDOR}" 2>/dev/null; then
        git clone "${UPSTREAM_URL}" "${VENDOR}"
        git -C "${VENDOR}" checkout "${UPSTREAM_REF}"
    fi
fi

echo "=== 3/4 Prune unused SDK trees ==="
"${ROOT}/tools/prune-vendor.sh"

echo "=== 4/4 Apply GT-BE98 patches ==="
"${ROOT}/tools/apply-patches.sh"

COMMIT=$(git -C "${VENDOR}" rev-parse HEAD 2>/dev/null || echo unknown)
cat > "${UPSTREAM_FILE}" <<EOF
url=${UPSTREAM_URL}
ref=${UPSTREAM_REF}
commit=${COMMIT}
EOF

echo ""
echo "Setup complete."
echo "  Toolchain: toolchain/am-toolchains (see toolchain/TOOLCHAIN_PIN)"
echo "  Upstream:  ${COMMIT}"
echo "  Build:     ./build.sh"
echo "  Firmware:  vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/"
