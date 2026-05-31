#!/usr/bin/env bash
# Build GT-BE98 firmware (native host + local toolchain in toolchain/).
#
# Usage:
#   ./setup.sh          # once: toolchain + vendor + patches
#   ./build.sh          # build
#   ./build.sh clean    # rebuild patched packages from scratch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VENDOR="${ROOT}/vendor/asuswrt-merlin.ng"
SDK="src-rt-5.04behnd.4916"
MODEL="gt-be98"
CLEAN="${1:-}"
LOG_DIR="${ROOT}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/build_${TIMESTAMP}.log"
IMAGE_DIR="${VENDOR}/release/${SDK}/targets/96813GW"

[[ -d "${VENDOR}/release/${SDK}" ]] || {
    echo "Run ./setup.sh first (missing ${VENDOR})" >&2
    exit 1
}

mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

export GTBE98_ROOT="$ROOT"
# shellcheck source=tools/env.sh
source "${ROOT}/tools/env.sh"

log "=== GT-BE98 build (native) ==="
log "Cross: $(command -v arm-buildroot-linux-gnueabi-gcc)"
[[ "$CLEAN" == "clean" ]] && log "Mode: clean"

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
    if [[ -f "${STAGE}/usr/local/lib/libssl.so" ]]; then
        mkdir -p "${STAGE}/usr/lib" "${STAGE}/usr/include"
        cp -af "${STAGE}/usr/local/lib/libssl"* "${STAGE}/usr/local/lib/libcrypto"* \
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
fi

START_TS=$(date +%s)
(
    cd "${VENDOR}/release/${SDK}"
    make FORCE=1 "${MODEL}"
) 2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
ELAPSED=$(( $(date +%s) - START_TS ))

log "=== Done in $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s — exit $EXIT_CODE ==="
if [[ $EXIT_CODE -eq 0 ]]; then
    ls -lh "${IMAGE_DIR}"/GT-BE98_*.pkgtb 2>/dev/null | tee -a "$LOG_FILE" \
        || log "Images in ${IMAGE_DIR}/"
else
    log "See ${LOG_FILE}"
fi
exit "$EXIT_CODE"
