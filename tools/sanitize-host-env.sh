#!/usr/bin/env bash
# Host compiler isolation for native Merlin builds (sourced from build.sh).
# Crosstools lib/ on LD_LIBRARY_PATH breaks host cc1 (mpfr_asinpi on Arch).
set -euo pipefail

gtbe98_sanitize_ld_library_path() {
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        if [[ "${LD_LIBRARY_PATH}" == *crosstools* || "${LD_LIBRARY_PATH}" == *toolchain* || "${LD_LIBRARY_PATH}" == *am-toolchains* ]]; then
            echo "build.sh: clearing LD_LIBRARY_PATH (crosstools libs break host gcc): ${LD_LIBRARY_PATH}" >&2
        fi
    fi
    unset LD_LIBRARY_PATH
}
