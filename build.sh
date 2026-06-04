#!/usr/bin/env bash
# Build GT-BE98 firmware (native host + local toolchain in toolchain/).
#
# Usage:
#   ./build.sh          # auto-runs tools/setup.sh if toolchain/vendor missing
#   ./build.sh clean    # rebuild patched packages from scratch
# Manual bootstrap: ./tools/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VENDOR="${ROOT}/vendor/asuswrt-merlin.ng"
SDK="src-rt-5.04behnd.4916"
MODEL="gt-be98"
CLEAN="${1:-}"
LOG_DIR="${ROOT}/logs"
BUILD_TMP_DIR="${LOG_DIR}/build-tmp"
mkdir -p "$BUILD_TMP_DIR"
export TMPDIR="$BUILD_TMP_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/build_${TIMESTAMP}.log"
IMAGE_DIR="${VENDOR}/release/${SDK}/targets/96813GW"

export GTBE98_ROOT="$ROOT"

# Image assembly calls sbin tools (sgdisk for the GPT table, others). On Arch
# /usr/sbin is symlinked into /usr/bin so they are always on PATH; on Debian
# /sbin and /usr/sbin are separate and absent from a normal user's PATH, so the
# GPT step fails with "sgdisk: command not found" and the image is built without
# a partition table. Ensure the sbin dirs are on PATH before anything runs.
for sbindir in /usr/local/sbin /usr/sbin /sbin; do
    [[ -d "$sbindir" && ":$PATH:" != *":$sbindir:"* ]] && PATH="$PATH:$sbindir"
done
export PATH

"${ROOT}/tools/check-host-deps.sh" --quick
"${ROOT}/tools/ensure-setup.sh"
"${ROOT}/tools/check-host-deps.sh"

mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

export GTBE98_TC_ROOT="${ROOT}/toolchain/am-toolchains/brcm-arm-hnd"

# shellcheck source=tools/sanitize-host-env.sh
source "${ROOT}/tools/sanitize-host-env.sh"
gtbe98_sanitize_ld_library_path

# shellcheck source=tools/env.sh
source "${ROOT}/tools/env.sh"
gtbe98_sanitize_ld_library_path

log "=== GT-BE98 build (native) ==="
log "Toolchain root: ${GTBE98_TC_ROOT} (no /opt/toolchains)"
log "Cross: $(command -v arm-buildroot-linux-gnueabi-gcc)"
log "Host LD_LIBRARY_PATH: (cleared for make — Merlin must not use crosstool lib/)"
[[ "$CLEAN" == "clean" ]] && log "Mode: clean"

gtbe98_sanitize_ld_library_path

# Idempotent: vendor can be reset or patches updated since last setup.
if ! "${ROOT}/tools/apply-patches.sh" 2>&1 | tee -a "$LOG_FILE"; then
    log "apply-patches.sh failed — see ${LOG_FILE}"
    exit 1
fi
CJSON_MK="${VENDOR}/release/${SDK}/router-sysdep.gt-be98/cjson/Makefile"
grep -q 'CMAKE_EXTRA := -DCMAKE_POLICY_VERSION_MINIMUM=3.5' "$CJSON_MK" || {
    echo "cjson CMake fix missing in $CJSON_MK — run ./tools/apply-patches.sh" >&2
    exit 1
}

rm -f "${VENDOR}/release/${SDK}/chip_profile.tmp" \
      "${VENDOR}/release/${SDK}/router/chip_profile.tmp"

BWDPI="${VENDOR}/release/${SDK}/bcmdrivers/broadcom/net/wl/bcm96813/main/src/router/bwdpi_source"
if [[ -d "$BWDPI" ]]; then
    cp -f "${BWDPI}/include/udb/sysdeps/bcm4916-tmcfg_udb.h" "${BWDPI}/include/udb/tmcfg_udb.h"
    cp -f "${BWDPI}/include/tdts/sysdeps/bcm4916-tmcfg.h"     "${BWDPI}/include/tdts/tmcfg.h"
fi

if [[ "$CLEAN" == "clean" ]]; then
    RBB="${VENDOR}/release/src/router/busybox"
    SBB="${VENDOR}/release/${SDK}/bcmdrivers/broadcom/net/wl/bcm96813/main/src/router/busybox"
    for bb in "$RBB" "$SBB"; do
        [[ -d "$bb" ]] || continue
        rm -f "$bb/include/autoconf.h" "$bb/include/applets.h" \
              "$bb/include/applet_tables.h" "$bb/.config"
    done
    STAGE="${VENDOR}/release/${SDK}/bcmdrivers/broadcom/net/wl/bcm96813/main/src/router/arm-glibc/stage"
    if [[ -d "${STAGE}/usr/local/lib" ]] && ls "${STAGE}/usr/local/lib"/libssl* >/dev/null 2>&1; then
        mkdir -p "${STAGE}/usr/lib" "${STAGE}/usr/include"
        cp -af "${STAGE}/usr/local/lib"/libssl* "${STAGE}/usr/local/lib"/libcrypto* \
            "${STAGE}/usr/lib/" 2>/dev/null || true
        cp -af "${STAGE}/usr/local/include/openssl" "${STAGE}/usr/include/" 2>/dev/null || true
    fi
    rm -f "${VENDOR}/release/src/router/curl/Makefile"
    rm -f "${VENDOR}/release/src/router/lighttpd-1.4.39/src/server.o" \
          "${VENDOR}/release/src/router/lighttpd-1.4.39/src/fdevent_poll.o"
    rm -f "${VENDOR}/release/src/router/nfs-utils-1.3.4/stamp-h1"
    rm -f "${VENDOR}/release/src/router/portmap/portmap" \
          "${VENDOR}/release/src/router/portmap/"*.o \
          "${VENDOR}/release/src/router/portmap/.depend"
    rm -rf "${VENDOR}/release/${SDK}/router-sysdep.gt-be98/cjson/cjson"
fi

START_TS=$(date +%s)
# Merlin router/Makefile may export LD_LIBRARY_PATH:=$(TOOLCHAIN)/lib — override + patch 0009.
(
    cd "${VENDOR}/release/${SDK}"
    gtbe98_sanitize_ld_library_path
    # -u: no inherited LD; LD_LIBRARY_PATH= on CLI overrides makefile export for host tools.
    # SHELL=/bin/bash: the SDK build/prebuild_checks.mk asserts $BASH_VERSION; on
    # Debian /bin/sh is dash (Arch's is bash), so force bash for all (sub-)makes.
    env -u LD_LIBRARY_PATH \
        make FORCE=1 \
        SHELL=/bin/bash \
        GTBE98_TC_ROOT="${GTBE98_TC_ROOT}" \
        GTBE98_ROOT="${GTBE98_ROOT}" \
        LD_LIBRARY_PATH= \
        TMPDIR="${TMPDIR}" \
        "${MODEL}"
) 2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
ELAPSED=$(( $(date +%s) - START_TS ))

log "=== Done in $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s — exit $EXIT_CODE ==="
if [[ $EXIT_CODE -eq 0 ]]; then
    ls -lh "${IMAGE_DIR}"/GT-BE98_*.pkgtb 2>/dev/null | tee -a "$LOG_FILE" \
        || log "Images in ${IMAGE_DIR}/"
    if ! "${ROOT}/tools/verify-artifact.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "Artifact verification failed — see ${LOG_FILE}"
        exit 1
    fi
else
    log "See ${LOG_FILE}"
fi
exit "$EXIT_CODE"
