#!/usr/bin/env bash
# Clone RMerl/am-toolchains into toolchain/ (no Docker).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TC_REPO="${ROOT}/toolchain/am-toolchains"
TC_PIN="${ROOT}/toolchain/TOOLCHAIN_PIN"
TC_URL="${TC_URL:-https://github.com/RMerl/am-toolchains.git}"
TC_REF="${TC_REF:-master}"
HND="${TC_REPO}/brcm-arm-hnd"

gcc_ok() {
    [[ -d "$HND" ]] && compgen -G "${HND}/crosstools-arm_softfp-gcc-"*"/usr/bin/arm-buildroot-linux-gnueabi-gcc" >/dev/null
}

if gcc_ok; then
    echo "Toolchain already present under ${HND}"
    exit 0
fi

echo "Cloning ${TC_URL} (ref: ${TC_REF}) ..."
mkdir -p "${ROOT}/toolchain"
if [[ -d "${TC_REPO}/.git" ]]; then
    echo "Updating existing toolchain clone ..."
    git -C "${TC_REPO}" fetch --depth 1 origin "${TC_REF}" 2>/dev/null || git -C "${TC_REPO}" fetch origin
    git -C "${TC_REPO}" checkout "${TC_REF}"
else
    if ! git clone --depth 1 --branch "${TC_REF}" "${TC_URL}" "${TC_REPO}" 2>/dev/null; then
        git clone "${TC_URL}" "${TC_REPO}"
        git -C "${TC_REPO}" checkout "${TC_REF}"
    fi
fi

if ! gcc_ok; then
    echo "ERROR: arm_softfp GCC 10.3 not found under ${HND}" >&2
    echo "Try: TC_REF=<tag> ./tools/fetch-toolchain.sh" >&2
    ls -1 "${HND}" 2>/dev/null || true
    exit 1
fi

COMMIT=$(git -C "${TC_REPO}" rev-parse HEAD 2>/dev/null || echo unknown)
cat > "${TC_PIN}" <<EOF
url=${TC_URL}
ref=${TC_REF}
commit=${COMMIT}
EOF

echo "Toolchain ready (commit ${COMMIT})"
echo "GCC: $(compgen -G "${HND}/crosstools-arm_softfp-gcc-"*"/usr/bin/arm-buildroot-linux-gnueabi-gcc" | head -1)"
