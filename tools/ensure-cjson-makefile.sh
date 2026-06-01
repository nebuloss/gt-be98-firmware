#!/usr/bin/env bash
# Install GT-BE98 cjson Makefile (CMake 4.x + cross). Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${VENDOR:-${ROOT}/vendor/asuswrt-merlin.ng}"
SDK="${SDK:-src-rt-5.04behnd.4916}"
DST="${VENDOR}/release/${SDK}/router-sysdep/cjson/Makefile"
SRC="${ROOT}/files/cjson-Makefile"
CJSON_DIR="${VENDOR}/release/${SDK}/router-sysdep/cjson/cjson"

[[ -f "$SRC" ]] || { echo "Missing $SRC" >&2; exit 1; }
[[ -d "$(dirname "$DST")" ]] || { echo "Missing $(dirname "$DST") — run ./build.sh or ./tools/setup.sh" >&2; exit 1; }

if ! grep -q 'CMAKE_EXTRA := -DCMAKE_POLICY_VERSION_MINIMUM=3.5' "$DST" 2>/dev/null; then
    install -m 644 "$SRC" "$DST"
    echo "ensure-cjson-makefile: installed $SRC -> $DST"
fi

if [[ -f "${CJSON_DIR}/CMakeCache.txt" ]] \
    && ! grep -q 'CMAKE_POLICY_VERSION_MINIMUM:.*=3.5' "${CJSON_DIR}/CMakeCache.txt" 2>/dev/null; then
    rm -rf "${CJSON_DIR}"
    echo "ensure-cjson-makefile: removed stale ${CJSON_DIR}"
fi
