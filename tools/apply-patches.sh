#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${VENDOR:-${ROOT}/vendor/asuswrt-merlin.ng}"
PATCH_DIR="${ROOT}/patches"

[[ -d "$VENDOR/release" ]] || {
    echo "Missing vendor tree: $VENDOR — run ./build.sh or ./tools/setup.sh" >&2
    exit 1
}

cd "$VENDOR"
for p in "${PATCH_DIR}"/[0-9]*.patch; do
    echo "Applying $(basename "$p") ..."
    # 0009: superseded when 0016+ GTBE98 EXTRALDFLAGS block is already present
    if [[ "$(basename "$p")" == "0009-router-host-ld-library-path.patch" ]] \
        && grep -q 'ifneq ($(GTBE98_TC_ROOT),)' release/src/router/Makefile 2>/dev/null; then
        echo "  already applied (GTBE98_TC_ROOT in Makefile), skipping"
        continue
    fi
    # 0022: never treat as "already applied" — router hunk can be reversed while cjson/Makefile is pristine
    if [[ "$(basename "$p")" == "0022-cjson-cmake-libcreduction.patch" ]]; then
        "${ROOT}/tools/ensure-cjson-makefile.sh"
        grep -q 'CMAKE_EXTRA := -DCMAKE_POLICY_VERSION_MINIMUM=3.5' \
            release/src-rt-5.04behnd.4916/router-sysdep/cjson/Makefile \
            || { echo "Failed: $p (cjson Makefile missing CMake 4.x fix)" >&2; exit 1; }
        patch_log="$(mktemp)"
        if ! patch -p1 -N --forward -i "$p" >"$patch_log" 2>&1; then
            grep -qE 'hunks ignored|Reversed \(or previously applied\)' "$patch_log" \
                || { cat "$patch_log" >&2; rm -f "$patch_log"; echo "Failed: $p" >&2; exit 1; }
        fi
        rm -f "$patch_log"
        echo "  0022: OK"
        continue
    fi
    # 0002: idempotent guard (re-apply used to duplicate embedded_signal_handler)
    if [[ "$(basename "$p")" == "0002-lighttpd-embedded-build.patch" ]] \
        && grep -q 'GTBE98_LIGHTTPD_EMBEDDED_SIG' \
            release/src/router/lighttpd-1.4.39/src/server.c 2>/dev/null; then
        echo "  already applied (GTBE98_LIGHTTPD_EMBEDDED_SIG), skipping"
        continue
    fi
    patch_log="$(mktemp)"
    if patch -p1 -N --forward -i "$p" >"$patch_log" 2>&1; then
        rm -f "$patch_log"
        continue
    fi
    if grep -qE 'hunks ignored|Reversed \(or previously applied\)' "$patch_log" \
        || patch -p1 --reverse --dry-run -i "$p" >/dev/null 2>&1; then
        echo "  already applied, skipping"
        rm -f "$patch_log"
        continue
    fi
    cat "$patch_log" >&2
    rm -f "$patch_log"
    echo "Failed: $p" >&2
    exit 1
done
echo "Patches applied under $VENDOR"
