#!/usr/bin/env bash
# Install GT-BE98 cjson Makefile (CMake 4.x + cross) and related Bcmbuild/router hooks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=setup-common.sh
source "$(dirname "$0")/setup-common.sh"

DST="${GTBE98_VENDOR}/release/${GTBE98_SDK}/${GTBE98_SYSDEP}/cjson/Makefile"
SRC="${GTBE98_ROOT}/files/cjson-Makefile"
CJSON_DIR="${GTBE98_VENDOR}/release/${GTBE98_SDK}/${GTBE98_SYSDEP}/cjson/cjson"
BCMBUILD="${GTBE98_VENDOR}/release/${GTBE98_SDK}/${GTBE98_SYSDEP}/cjson/Bcmbuild.mk"
ROUTER_MK="${GTBE98_VENDOR}/release/src/router/Makefile"

[[ -f "$SRC" ]] || { echo "Missing $SRC" >&2; exit 1; }
[[ -d "$(dirname "$DST")" ]] || {
    echo "Missing $(dirname "$DST") — run ./build.sh or ./tools/setup.sh" >&2
    exit 1
}

if ! grep -q 'CMAKE_EXTRA := -DCMAKE_POLICY_VERSION_MINIMUM=3.5' "$DST" 2>/dev/null; then
    install -m 644 "$SRC" "$DST"
    echo "ensure-cjson-makefile: installed $SRC -> $DST"
fi

if [[ -f "${CJSON_DIR}/CMakeCache.txt" ]] \
    && ! grep -q 'CMAKE_POLICY_VERSION_MINIMUM:.*=3.5' "${CJSON_DIR}/CMakeCache.txt" 2>/dev/null; then
    rm -rf "${CJSON_DIR}"
    echo "ensure-cjson-makefile: removed stale ${CJSON_DIR}"
fi

if [[ -f "$BCMBUILD" ]] && ! grep -q 'ensure-cjson-makefile.sh' "$BCMBUILD" 2>/dev/null; then
    awk '
        /^conditional_build:$/ && !done {
            print
            print "ifneq ($(GTBE98_ROOT),)"
            print "\t@$(GTBE98_ROOT)/tools/ensure-cjson-makefile.sh"
            print "endif"
            getline; print
            getline; print
            getline
            print "\t@test -n \"$$(ls $(LIB_INSTALL_DIR)/$(LIB).so* 2>/dev/null)\" || (echo \"Bcmbuild.mk: $(LIB) not built in $(LIB_INSTALL_DIR)\" >&2; exit 1)"
            print
            done=1
            next
        }
        { print }
    ' "$BCMBUILD" >"${BCMBUILD}.tmp" && mv "${BCMBUILD}.tmp" "$BCMBUILD"
    echo "ensure-cjson-makefile: patched Bcmbuild.mk"
fi

if [[ -f "$ROUTER_MK" ]] && ! grep -A2 '^cjson:$' "$ROUTER_MK" | grep -q 'GTBE98_TC_ROOT'; then
    awk '
        /^\tcjson:$/ { in_cjson=1 }
        in_cjson && /^\t-\$\(MAKE\) -C \$\(TOPX_DIR\) -f Bcmbuild\.mk$/ {
            print "ifneq ($(GTBE98_TC_ROOT),)"
            print "\t$(MAKE) -C $(TOPX_DIR) -f Bcmbuild.mk"
            print "else"
            print "\t-$(MAKE) -C $(TOPX_DIR) -f Bcmbuild.mk"
            print "endif"
            in_cjson=0
            next
        }
        /^\tcjson-install:$/ { in_install=1 }
        in_install && /^\t-\$\(MAKE\) -C \$\(TOPX_DIR\) INSTALLDIR=\$\(INSTALLDIR\)\/cjson install$/ {
            print "ifneq ($(GTBE98_TC_ROOT),)"
            print "\t$(MAKE) -C $(TOPX_DIR) INSTALLDIR=$(INSTALLDIR)/cjson install"
            print "else"
            print "\t-$(MAKE) -C $(TOPX_DIR) INSTALLDIR=$(INSTALLDIR)/cjson install"
            print "endif"
            in_install=0
            next
        }
        { print }
    ' "$ROUTER_MK" >"${ROUTER_MK}.tmp" && mv "${ROUTER_MK}.tmp" "$ROUTER_MK"
    echo "ensure-cjson-makefile: patched router Makefile (cjson targets)"
fi
