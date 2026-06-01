#!/usr/bin/env bash
# Native BCM HND toolchain environment (replaces Docker bcm-hnd-ax-4.19be_soft.sh).
# Source from build.sh only — not for interactive use unless you know what you do.
set -euo pipefail

if [[ -z "${GTBE98_ROOT:-}" ]]; then
    echo "env.sh: set GTBE98_ROOT before sourcing" >&2
    return 1 2>/dev/null || exit 1
fi

TC_HND="${GTBE98_ROOT}/toolchain/am-toolchains/brcm-arm-hnd"
if [[ ! -d "$TC_HND" ]]; then
    echo "Missing ${TC_HND} — run ./build.sh or ./tools/setup.sh" >&2
    return 1 2>/dev/null || exit 1
fi

export TOOLCHAIN_BASE="${TC_HND}"

# Never inherit crosstool libs into host tools (see tools/sanitize-host-env.sh).
unset LD_LIBRARY_PATH

GTBE98_TC_PATH=""

_add_tc_path() {
    local dir="$1"
    [[ -d "${dir}/usr/bin" ]] || return 0
    GTBE98_TC_PATH="${dir}/usr/bin:${GTBE98_TC_PATH}"
}

# Do not prepend crosstools */usr/lib to LD_LIBRARY_PATH: old libmpfr there breaks
# the host GCC (cc1: undefined symbol mpfr_asinpi) when building U-Boot host tools.
# Crosstools */usr/bin must not shadow host bison/flex/gcc (libreadline.so.6, etc.).

# GT-BE98 / BE4916: softfp GCC 10.3 + aarch64 10.3 (same as gnuton bcm-hnd-ax-4.19be_soft.sh)
for prefix in \
    crosstools-arm_softfp-gcc-10.3-linux-4.19-glibc-2.32-binutils-2.36.1 \
    crosstools-aarch64-gcc-10.3-linux-4.19-glibc-2.32-binutils-2.36.1 \
    crosstools-arm-gcc-5.5-linux-4.1-glibc-2.26-binutils-2.28.1 \
    crosstools-arm-gcc-10.3-linux-4.19-glibc-2.32-binutils-2.36.1
do
    [[ -d "${TC_HND}/${prefix}" ]] || continue
    _add_tc_path "${TC_HND}/${prefix}"
done

# Fallback: any crosstools-* under brcm-arm-hnd
if [[ -z "${GTBE98_TC_PATH}" ]]; then
    for d in "${TC_HND}"/crosstools-*/usr/bin; do
        [[ -d "$d" ]] && GTBE98_TC_PATH="${d}:${GTBE98_TC_PATH}"
    done
fi

# Host tools (bison, flex, gcc) from the distro; cross-* from toolchain dirs.
export PATH="/usr/bin:/bin:${GTBE98_TC_PATH}${PATH}"

if ! command -v arm-buildroot-linux-gnueabi-gcc >/dev/null 2>&1; then
    echo "arm-buildroot-linux-gnueabi-gcc not in PATH (check toolchain/)" >&2
    return 1 2>/dev/null || exit 1
fi

export GTBE98_TOOLCHAIN_READY=1
