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
    echo "Missing ${TC_HND} — run ./setup.sh" >&2
    return 1 2>/dev/null || exit 1
fi

export TOOLCHAIN_BASE="${TC_HND}"

_add_tc_path() {
    local dir="$1"
    [[ -d "${dir}/usr/bin" ]] || return 0
    export PATH="${dir}/usr/bin:${PATH}"
}

_add_tc_lib() {
    local dir="$1"
    [[ -d "${dir}/usr/lib" ]] || return 0
    export LD_LIBRARY_PATH="${dir}/usr/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
}

# GT-BE98 / BE4916: softfp GCC 10.3 + aarch64 10.3 (same as gnuton bcm-hnd-ax-4.19be_soft.sh)
for prefix in \
    crosstools-arm_softfp-gcc-10.3-linux-4.19-glibc-2.32-binutils-2.36.1 \
    crosstools-aarch64-gcc-10.3-linux-4.19-glibc-2.32-binutils-2.36.1 \
    crosstools-arm-gcc-5.5-linux-4.1-glibc-2.26-binutils-2.28.1 \
    crosstools-arm-gcc-10.3-linux-4.19-glibc-2.32-binutils-2.36.1
do
    [[ -d "${TC_HND}/${prefix}" ]] || continue
    _add_tc_path "${TC_HND}/${prefix}"
    _add_tc_lib "${TC_HND}/${prefix}"
done

# Fallback: any crosstools-* under brcm-arm-hnd
if ! command -v arm-buildroot-linux-gnueabi-gcc >/dev/null 2>&1; then
    for d in "${TC_HND}"/crosstools-*/usr/bin; do
        [[ -d "$d" ]] && export PATH="${d}:${PATH}"
    done
    for d in "${TC_HND}"/crosstools-*/usr/lib; do
        [[ -d "$d" ]] && export LD_LIBRARY_PATH="${d}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    done
fi

if ! command -v arm-buildroot-linux-gnueabi-gcc >/dev/null 2>&1; then
    echo "arm-buildroot-linux-gnueabi-gcc not in PATH (check toolchain/)" >&2
    return 1 2>/dev/null || exit 1
fi

export GTBE98_TOOLCHAIN_READY=1
