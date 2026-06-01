#!/usr/bin/env bash
# Full repo bootstrap: toolchain + vendor + prune + patches.
# Usually invoked by ./build.sh via ensure-setup.sh; run manually after rm -rf vendor/.
set -euo pipefail

# shellcheck source=setup-common.sh
source "$(dirname "$0")/setup-common.sh"
gtbe98_read_upstream_config

echo "=== 1/4 Toolchain (RMerl/am-toolchains) ==="
"${GTBE98_ROOT}/tools/fetch-toolchain.sh"

echo "=== 2/4 Upstream Merlin ==="
"${GTBE98_ROOT}/tools/setup-vendor.sh"

echo "=== 3/4 Prune unused SDK trees ==="
"${GTBE98_ROOT}/tools/prune-vendor.sh"

echo "=== 4/4 Apply GT-BE98 patches ==="
"${GTBE98_ROOT}/tools/apply-patches.sh"

gtbe98_verify_sdk

COMMIT=$(git -C "${GTBE98_VENDOR}" rev-parse HEAD 2>/dev/null || echo unknown)
cat > "${GTBE98_UPSTREAM_FILE}" <<EOF
url=${GTBE98_UPSTREAM_URL}
ref=${GTBE98_UPSTREAM_REF}
commit=${COMMIT}
EOF

echo ""
echo "Setup complete."
echo "  Toolchain: toolchain/am-toolchains (see toolchain/TOOLCHAIN_PIN)"
echo "  Upstream:  ${COMMIT}"
echo "  Build:     ./build.sh"
echo "  Firmware:  ${GTBE98_SDK_DIR}/targets/96813GW/"
