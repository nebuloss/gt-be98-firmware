# Shared paths and checks for setup / ensure-setup (source only).
GTBE98_ROOT="${GTBE98_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GTBE98_VENDOR="${GTBE98_VENDOR:-${GTBE98_ROOT}/vendor/asuswrt-merlin.ng}"
GTBE98_SDK="src-rt-5.04behnd.4916"
GTBE98_SDK_DIR="${GTBE98_SDK_DIR:-${GTBE98_VENDOR}/release/${GTBE98_SDK}}"
GTBE98_UPSTREAM_FILE="${GTBE98_UPSTREAM_FILE:-${GTBE98_ROOT}/UPSTREAM}"
GTBE98_TC_ROOT="${GTBE98_TC_ROOT:-${GTBE98_ROOT}/toolchain/am-toolchains/brcm-arm-hnd}"
GTBE98_DEFAULT_UPSTREAM_REF="${GTBE98_DEFAULT_UPSTREAM_REF:-ad42d5e81a53bc20e6d583f1b8e1748d09f964c8}"

gtbe98_cross_gcc() {
    compgen -G "${GTBE98_TC_ROOT}/crosstools-arm_softfp-gcc-"*"/usr/bin/arm-buildroot-linux-gnueabi-gcc" >/dev/null
}

gtbe98_cross_gcc_ok() {
    [[ -d "${GTBE98_TC_ROOT}" ]] && gtbe98_cross_gcc
}

gtbe98_sdk_ok() {
    [[ -d "${GTBE98_SDK_DIR}" ]]
}

gtbe98_read_upstream_config() {
    if [[ -f "${GTBE98_UPSTREAM_FILE}" ]]; then
        GTBE98_UPSTREAM_URL="${GTBE98_UPSTREAM_URL:-$(grep -E '^url=' "${GTBE98_UPSTREAM_FILE}" | cut -d= -f2-)}"
        GTBE98_UPSTREAM_REF="${GTBE98_UPSTREAM_REF:-$(grep -E '^ref=' "${GTBE98_UPSTREAM_FILE}" | cut -d= -f2-)}"
    fi
    GTBE98_UPSTREAM_URL="${GTBE98_UPSTREAM_URL:-https://github.com/gnuton/asuswrt-merlin.ng.git}"
    GTBE98_UPSTREAM_REF="${GTBE98_UPSTREAM_REF:-${GTBE98_DEFAULT_UPSTREAM_REF}}"
}

gtbe98_verify_sdk() {
    gtbe98_sdk_ok || {
        echo "Missing GT-BE98 SDK: ${GTBE98_SDK_DIR}" >&2
        echo "  Run: ./build.sh  (auto-setup) or ./tools/setup.sh" >&2
        echo "  Or: rm -rf vendor && ./tools/setup.sh" >&2
        exit 1
    }
}

gtbe98_needs_setup() {
    ! gtbe98_cross_gcc_ok || ! gtbe98_sdk_ok
}

gtbe98_setup_missing_reason() {
    if ! gtbe98_cross_gcc_ok; then
        echo "toolchain (arm-buildroot-linux-gnueabi-gcc)"
    fi
    if ! gtbe98_sdk_ok; then
        echo "vendor SDK (${GTBE98_SDK})"
    fi
}
