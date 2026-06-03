#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=setup-common.sh
source "$(dirname "$0")/setup-common.sh"
VENDOR="${VENDOR:-${GTBE98_VENDOR}}"
PATCH_DIR="${ROOT}/patches"
GTBE98_ROOT="$ROOT"
PATCH_LOG_DIR="${ROOT}/logs/patch-apply"
PATCH_TMP_DIR="${ROOT}/logs/patch-tmp"
PATCH_FLAGS=( -p1 --batch -N --forward -F 10 --reject-file=/dev/null )

# Functional (runtime-behaviour) patches catalogued in patches/README.md.
# Unlike 0001-0023 (build fixes), these change the firmware's default
# behaviour and are NOT required for a successful build — but their absence
# silently ships un-hardened firmware, so warn loudly when one is missing.
GTBE98_FUNCTIONAL_PATCHES=(
    "0024-infosvr-disable-by-default.patch"
    "0025-mainfh-exclude-ifnames-from-hapd.patch"
)

gtbe98_patch_cleanup_artifacts() {
    find "$VENDOR" -name '*.orig' -delete 2>/dev/null || true
    find "$VENDOR" -name '*.rej' -delete 2>/dev/null || true
}

gtbe98_check_vendor_writable() {
    local probe="${VENDOR}/.gtbe98-write-probe"
    if ! ( : >"$probe" ) 2>/dev/null; then
        echo "Failed: cannot write under ${VENDOR} (disk quota or permissions)" >&2
        exit 1
    fi
    rm -f "$probe"
}

# Return 0 if patch content is already present (skip forward patch entirely).
gtbe98_patch_semantics_ok() {
    local base="$1"
    local mk="release/src/router/Makefile"
    case "$base" in
        0001-router-Makefile-tirpc-openssl-nfs-portmap.patch)
            grep -q '$(if $(RTCONFIG_NFS),tirpc,)' "$mk" 2>/dev/null
            ;;
        0002-lighttpd-embedded-build.patch)
            grep -q 'GTBE98_LIGHTTPD_EMBEDDED_SIG' release/src/router/lighttpd-1.4.39/src/server.c 2>/dev/null
            ;;
        0003-nfs-utils-gcc10-tirpc.patch)
            ! grep -q '^int v4root_needed;' release/src/router/nfs-utils-1.3.4/utils/mountd/v4root.c 2>/dev/null \
                && grep -q 'SM_stat_chge' release/src/router/nfs-utils-1.3.4/utils/statd/statd.c 2>/dev/null
            ;;
        0005-portmap-tirpc_compat.h.patch)
            grep -q 'PORTMAP_TIRPC_COMPAT_H' release/src/router/portmap/tirpc_compat.h 2>/dev/null
            ;;
        0006-router-config-ncurses-host-check.patch)
            grep -q 'int main(void) { return 0; }' release/src/router/config/Makefile 2>/dev/null
            ;;
        0008-router-uboot-toolchain-root.patch)
            grep -q 'GTBE98_TC_ROOT' \
                release/src-rt-5.04behnd.4916/bootloaders/build/configs/options_6813_nand.conf.GT-BE98 2>/dev/null
            ;;
        0009-router-host-ld-library-path.patch)
            grep -q 'ifneq ($(GTBE98_TC_ROOT),)' "$mk" 2>/dev/null
            ;;
        0013-lldpd-cross-libxml2.patch)
            grep -q 'lldpd-0.9.8:.*libxml2' "$mk" 2>/dev/null
            ;;
        0013b-lldpd-1.0.11-libxml2.patch)
            grep -q 'lldpd-1.0.11:.*libxml2' "$mk" 2>/dev/null
            ;;
        0016-extralfags-cross-libgcc.patch)
            grep -q 'libgcc_s.so' "$mk" 2>/dev/null \
                && grep -q 'pcre-8.31: libpcre.so.1.0.1 not built' "$mk" 2>/dev/null
            ;;
        0017-pcre-stage-no-relink.patch)
            grep -q 'Avoid libtool install relink' "$mk" 2>/dev/null
            ;;
        0021-nfs-utils-host-rpcgen.patch)
            grep -q 'GTBE98_BUILD_NFS_HOST_RPCGEN' "$mk" 2>/dev/null \
                && grep -q 'rpcgen-rpc_clntout.o' "$mk" 2>/dev/null \
                && grep -q '\-C \$@/support' "$mk" 2>/dev/null
            ;;
        0023-coovachilli-gengetopt-optional.patch)
            grep -q 'command -v gengetopt' \
                release/src/router/coovachilli/src/Makefile.am 2>/dev/null \
                && grep -q 'command -v gengetopt' \
                release/src/router/coovachilli/src/Makefile 2>/dev/null
            ;;
        0022-cjson-cmake-libcreduction.patch)
            grep -q 'CMAKE_EXTRA := -DCMAKE_POLICY_VERSION_MINIMUM=3.5' \
                "release/${GTBE98_SDK}/${GTBE98_SYSDEP}/cjson/Makefile" 2>/dev/null \
                && grep -q 'ensure-cjson-makefile.sh' \
                "release/${GTBE98_SDK}/${GTBE98_SYSDEP}/cjson/Bcmbuild.mk" 2>/dev/null \
                && grep -q '@test -n.*LIB_INSTALL_DIR.*LIB).so' \
                "release/${GTBE98_SDK}/${GTBE98_SYSDEP}/cjson/Bcmbuild.mk" 2>/dev/null \
                && grep -A3 '^cjson:' "$mk" 2>/dev/null | grep -q 'GTBE98_TC_ROOT'
            ;;
        0024-infosvr-disable-by-default.patch)
            # functional: infosvr_enable guard added to both rc files
            grep -q 'infosvr_enable' release/src/router/rc/services.c 2>/dev/null \
                && grep -q 'infosvr_enable' release/src/router/rc/watchdog.c 2>/dev/null
            ;;
        0025-mainfh-exclude-ifnames-from-hapd.patch)
            # functional: hapd_exclude_ifnames filter added to wlif_utils_ax.c
            grep -q 'hapd_exclude_ifnames' release/src/router/shared/wlif_utils_ax.c 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

gtbe98_verify_required_patches() {
    local missing=()
    gtbe98_patch_semantics_ok "0021-nfs-utils-host-rpcgen.patch" \
        || missing+=("0021-nfs-utils-host-rpcgen")
    gtbe98_patch_semantics_ok "0022-cjson-cmake-libcreduction.patch" \
        || missing+=("0022-cjson-cmake")
    gtbe98_patch_semantics_ok "0006-router-config-ncurses-host-check.patch" \
        || missing+=("0006-ncurses-host-check")
    if ((${#missing[@]} > 0)); then
        echo "Failed: required patch content missing in vendor: ${missing[*]}" >&2
        echo "  If disk quota is full, free inodes/quota then re-run ./tools/apply-patches.sh" >&2
        return 1
    fi
    return 0
}

# Warn (do not fail) when a catalogued functional patch file is absent: the
# build still succeeds, but the resulting firmware lacks that hardening.
gtbe98_warn_missing_functional_patches() {
    local missing=() b
    for b in "${GTBE98_FUNCTIONAL_PATCHES[@]}"; do
        [[ -f "${PATCH_DIR}/${b}" ]] || missing+=("$b")
    done
    ((${#missing[@]} > 0)) || return 0
    echo "WARNING: functional patch file(s) missing from ${PATCH_DIR}:" >&2
    for b in "${missing[@]}"; do echo "  - ${b}" >&2; done
    echo "  These are catalogued in patches/README.md but not present, so the" >&2
    echo "  firmware will build WITHOUT their runtime hardening (e.g. 0024 leaves" >&2
    echo "  infosvr/UDP 9999 enabled, 0025 leaves the MAINFH BSS in place)." >&2
    echo "  Restore the .patch file(s) and re-run ./build.sh to apply them." >&2
}

[[ -d "$VENDOR/release" ]] || {
    echo "Missing vendor tree: $VENDOR — run ./build.sh or ./tools/setup.sh" >&2
    exit 1
}

mkdir -p "$PATCH_LOG_DIR" "$PATCH_TMP_DIR"
export TMPDIR="$PATCH_TMP_DIR"
gtbe98_check_vendor_writable
gtbe98_patch_cleanup_artifacts

cd "$VENDOR"
for p in "${PATCH_DIR}"/[0-9]*.patch; do
    base="$(basename "$p")"
    echo "Applying ${base} ..."
    patch_log="${PATCH_LOG_DIR}/${base}.log"

    if gtbe98_patch_semantics_ok "$base"; then
        echo "  already applied, skipping"
        continue
    fi

    if [[ "$base" == "0022-cjson-cmake-libcreduction.patch" ]]; then
        "${ROOT}/tools/ensure-cjson-makefile.sh"
        : >"$patch_log"
        if patch "${PATCH_FLAGS[@]}" -i "$p" >>"$patch_log" 2>&1 \
            || grep -qE 'Reversed|previously applied|hunks ignored' "$patch_log" 2>/dev/null; then
            :
        else
            cat "$patch_log" >&2
            echo "Failed: $p" >&2
            exit 1
        fi
        "${ROOT}/tools/ensure-cjson-makefile.sh"
        if ! gtbe98_patch_semantics_ok "$base"; then
            echo "Failed: $p (cjson CMake/Bcmbuild/router fix incomplete)" >&2
            exit 1
        fi
        echo "  0022: OK"
        gtbe98_patch_cleanup_artifacts
        continue
    fi

    : >"$patch_log"
    patch_pe=0
    if patch "${PATCH_FLAGS[@]}" -i "$p" >>"$patch_log" 2>&1; then
        patch_pe=0
    else
        patch_pe=$?
    fi
    gtbe98_patch_cleanup_artifacts

    if [[ "$patch_pe" -eq 0 ]] || gtbe98_patch_semantics_ok "$base"; then
        continue
    fi

    if grep -qE 'Reversed \(or previously applied\)|previously applied|hunks ignored|already exists' "$patch_log" 2>/dev/null \
        && ! grep -qiE 'hunks FAILED|cant find file to patch' "$patch_log" 2>/dev/null; then
        if gtbe98_patch_semantics_ok "$base" \
            || { [[ "$patch_pe" -ne 0 ]] && ! grep -qiE 'FAILED' "$patch_log" 2>/dev/null; }; then
            echo "  already applied, skipping"
            continue
        fi
    fi

    if grep -qi 'disk quota exceeded\|write error\|No space left' "$patch_log" 2>/dev/null; then
        echo "Failed: $p — disk quota exceeded when writing vendor/" >&2
        echo "  Free quota, run: find vendor -name '*.orig' -o -name '*.rej' -delete" >&2
        exit 1
    fi
    if grep -qiE 'FAILED|hunks FAILED|cant find file to patch' "$patch_log" 2>/dev/null; then
        cat "$patch_log" >&2
        echo "Failed: $p — see ${patch_log}" >&2
        exit 1
    fi
    cat "$patch_log" >&2
    echo "Failed: $p (exit ${patch_pe}, log: ${patch_log})" >&2
    exit 1
done

gtbe98_patch_cleanup_artifacts
"${ROOT}/tools/ensure-cjson-makefile.sh" >/dev/null 2>&1 || true
gtbe98_verify_required_patches || exit 1
gtbe98_warn_missing_functional_patches
echo "Patches applied under $VENDOR"
