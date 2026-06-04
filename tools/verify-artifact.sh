#!/usr/bin/env bash
# Post-build checks: boot chain (FIT/kernel) + rootfs essentials + pkgtb bundle integrity.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDK:-src-rt-5.04behnd.4916}"
TARGET="${TARGET:-${ROOT}/vendor/asuswrt-merlin.ng/release/${SDK}/targets/96813GW}"
FS="${TARGET}/fs.install"
FAIL=0

fail() { echo "verify-artifact: FAIL: $*" >&2; FAIL=1; }
ok() { echo "verify-artifact: OK: $*"; }

require_file() {
    local path="$1" min="${2:-1}"
    [[ -f "$path" ]] || { fail "missing file $(basename "$path")"; return; }
    [[ "$(stat -c%s "$path" 2>/dev/null || echo 0)" -ge "$min" ]] \
        || fail "file too small: $(basename "$path") (< ${min} bytes)"
}

require_find() {
    local name="$1"
    shift
    find "$FS" "$@" -type f 2>/dev/null | grep -q . \
        || fail "rootfs missing ${name}"
}

find_mkimage() {
    local c
    for c in \
        "${ROOT}/vendor/asuswrt-merlin.ng/release/${SDK}/bootloaders/obj/uboot/tools/mkimage" \
        "${ROOT}/vendor/asuswrt-merlin.ng/release/${SDK}/hostTools/mkimage" \
        mkimage
    do
        [[ -x "$c" ]] && { echo "$c"; return 0; }
    done
    return 1
}

verify_pkgtb_rootfs_embed() {
    local pkgtb="$1" rootfs="$2"
    local magic_hex ref_size offset offs chunk n_offs

    magic_hex="$(head -c4 "$rootfs" | od -An -tx1 | tr -d ' \n')"
    if [[ "$magic_hex" != "68737173" ]]; then
        echo "rootfs.img is not squashfs (missing hsqs magic)" >&2
        return 1
    fi

    mapfile -t offs < <(grep -aob 'hsqs' "$pkgtb" 2>/dev/null | cut -d: -f1 || true)
    n_offs=${#offs[@]}
    if [[ "$n_offs" -eq 0 ]]; then
        echo "pkgtb has no embedded squashfs" >&2
        return 1
    fi
    if [[ "$n_offs" -ne 1 ]]; then
        echo "pkgtb has ${n_offs} squashfs blobs (expected 1)" >&2
        return 1
    fi
    offset="${offs[0]}"
    ref_size=$(stat -c%s "$rootfs")

    chunk="$(mktemp)"
    trap 'rm -f "$chunk"' RETURN
    if ! dd if="$pkgtb" of="$chunk" bs=1 skip="$offset" count="$ref_size" status=none 2>/dev/null; then
        echo "pkgtb embedded squashfs shorter than rootfs.img" >&2
        return 1
    fi
    if ! cmp -s "$chunk" "$rootfs"; then
        echo "pkgtb embedded squashfs does not match rootfs.img" >&2
        return 1
    fi
    echo "pkgtb embeds rootfs.img (${ref_size} bytes squashfs at offset ${offset})"
}

verify_itb_boot_chain() {
    local itb="$1" mk="$2"
    local listing
    listing="$("$mk" -l "$itb" 2>/dev/null)" || { fail "mkimage cannot read $(basename "$itb")"; return; }
    echo "$listing" | grep -q 'Description:  ATF' \
        || fail "ITB missing ATF firmware"
    echo "$listing" | grep -q 'Description:  U-Boot' \
        || fail "ITB missing U-Boot"
    echo "$listing" | grep -q 'Description:  Linux kernel' \
        || fail "ITB missing Linux kernel"
    echo "$listing" | grep -q 'fdt_GT-BE98' \
        || fail "ITB missing GT-BE98 device tree"
    echo "$listing" | grep -q 'conf_lx_GT-BE98' \
        || fail "ITB missing conf_lx_GT-BE98 configuration"
    ok "ITB boot chain: ATF + U-Boot + kernel + fdt_GT-BE98"
}

[[ -d "$TARGET" ]] || { fail "missing ${TARGET} — run ./build.sh first"; exit 1; }

echo "verify-artifact: target ${TARGET}"

# --- Flash images (update bundle) ---
PKGTB="$(ls -1 "${TARGET}"/GT-BE98_*_nand_squashfs.pkgtb 2>/dev/null | head -1 || true)"
PKGTB_LOADER="$(ls -1 "${TARGET}"/GT-BE98_*_nand_squashfs_loader.pkgtb 2>/dev/null | head -1 || true)"
ITB="${TARGET}/bcm96813GW_uboot_linux.itb"
ROOTFS_IMG="${TARGET}/rootfs.img"

for img in "$PKGTB" "$PKGTB_LOADER" "$ITB"; do
    [[ -n "$img" ]] || continue
    require_file "$img" 5242880
done
[[ -n "$PKGTB" ]] && ok "pkgtb $(basename "$PKGTB") ($(du -h "$PKGTB" | cut -f1))"
[[ -n "$PKGTB_LOADER" ]] && ok "loader pkgtb $(basename "$PKGTB_LOADER") ($(du -h "$PKGTB_LOADER" | cut -f1))"

# Loader bundle must be larger (includes U-Boot loader blob).
if [[ -n "$PKGTB" && -n "$PKGTB_LOADER" ]]; then
    pk_sz=$(stat -c%s "$PKGTB")
    ld_sz=$(stat -c%s "$PKGTB_LOADER")
    [[ "$ld_sz" -gt "$pk_sz" ]] \
        || fail "loader pkgtb not larger than update pkgtb (unexpected bundle layout)"
fi

require_file "$ROOTFS_IMG" 10485760
ok "rootfs.img ($(du -h "$ROOTFS_IMG" | cut -f1))"

# Kernel binary used to build FIT (sanity: build produced a kernel).
if compgen -G "${TARGET}/vmlinux"* >/dev/null; then
    ok "vmlinux present in targets"
else
    fail "no vmlinux in ${TARGET} (kernel build incomplete?)"
fi

MKIMAGE=""
if MKIMAGE="$(find_mkimage)"; then
    verify_itb_boot_chain "$ITB" "$MKIMAGE"
else
    fail "mkimage not found — cannot verify ITB FIT contents"
fi

# --- pkgtb bundle metadata + embedded rootfs ---
if [[ -z "$PKGTB" ]]; then
    fail "GT-BE98_*_nand_squashfs.pkgtb missing"
else
    # grep -a on the blob (avoid strings|grep -q + pipefail SIGPIPE).
    for token in GT-BE98 nand_squashfs bootfs rootfs squashfs; do
        grep -aFq "$token" "$PKGTB" 2>/dev/null \
            || fail "pkgtb missing expected token: ${token}"
    done
    ok "pkgtb metadata (GT-BE98, nand_squashfs, bootfs, rootfs)"

    if verify_pkgtb_rootfs_embed "$PKGTB" "$ROOTFS_IMG"; then
        ok "pkgtb embeds rootfs.img squashfs (byte-identical)"
    else
        fail "pkgtb rootfs embed mismatch or invalid squashfs"
    fi
fi

# --- Staged rootfs: boot-critical userspace ---
if [[ ! -d "$FS" ]]; then
    fail "missing staged rootfs ${FS}"
else
    ok "fs.install staged ($(du -sh "$FS" | cut -f1))"

    for path in bin/busybox sbin/rc lib/libc.so.6 usr/sbin/dhd usr/sbin/wl usr/sbin/httpd; do
        [[ -e "${FS}/${path}" ]] || fail "rootfs missing boot path: ${path}"
    done
    find "$FS" \( -path '*/bin/nvram' -o -path '*/sbin/nvram' -o -path '*/usr/sbin/nvram' \) \
        -type f 2>/dev/null | grep -q . || fail "rootfs missing nvram"
    ok "boot userspace: busybox, rc, libc, nvram, dhd, wl, httpd"

    # Dynamic linker (multi-arch tree may ship both).
    find "$FS/lib" -maxdepth 1 -name 'ld-linux*.so*' -type f 2>/dev/null | grep -q . \
        || fail "rootfs missing dynamic linker under lib/"
    ok "dynamic linker present"

    # Wireless dongle firmware (required for Wi-Fi bring-up on HND).
    find "$FS/rom/etc/wlan" -name 'rtecdc.bin' 2>/dev/null | grep -q . \
        || fail "rootfs missing dhd firmware (rom/etc/wlan/.../rtecdc.bin)"
    ok "dhd firmware blobs in rom/etc/wlan"

    # Read-only etc templates merged at runtime (Merlin uses rom/etc + JFFS).
    for path in rom/etc/services rom/etc/init.d; do
        [[ -e "${FS}/${path}" ]] || fail "rootfs missing ${path}"
    done
    ok "rom/etc base config (services, init.d)"

    # Squashfs input must match staged tree size order-of-magnitude.
    fs_bytes=$(du -sb "$FS" | cut -f1)
    img_bytes=$(stat -c%s "$ROOTFS_IMG")
    if [[ "$img_bytes" -lt 33554432 ]]; then
        fail "rootfs.img suspiciously small (< 32 MiB)"
    elif [[ "$img_bytes" -gt "$fs_bytes" ]]; then
        fail "rootfs.img larger than unstaged fs.install (packaging error?)"
    else
        ok "rootfs.img size plausible (${img_bytes} bytes compressed, ${fs_bytes} bytes staged)"
    fi
fi

# --- Optional / feature binaries (regression guards from prior build fixes) ---
if [[ -d "$FS" ]]; then
    for bin in dnsmasq openvpn wg lighttpd; do
        require_find "$bin" \( -path "*/bin/${bin}" -o -path "*/sbin/${bin}" -o -path "*/usr/sbin/${bin}" \)
    done
    # nfsd/exportfs only when NFS is actually selected. GT-BE98's config_gt-be98
    # has RTCONFIG_NFS off by default; a stale busybox autoconf.h can spuriously
    # enable it (see docs/troubleshooting.md), which is how earlier incremental
    # builds shipped the NFS server. Don't require the NFS binaries unless the
    # build's router .config selected NFS — otherwise a correct clean build fails.
    ROUTER_CONFIG="${ROOT}/vendor/asuswrt-merlin.ng/release/src/router/.config"
    if grep -q '^RTCONFIG_NFS=y' "$ROUTER_CONFIG" 2>/dev/null; then
        for bin in nfsd exportfs; do
            require_find "$bin" \( -path "*/bin/${bin}" -o -path "*/sbin/${bin}" -o -path "*/usr/sbin/${bin}" \)
        done
        ok "network/VPN/NFS/lighttpd binaries (NFS enabled)"
    else
        ok "network/VPN/lighttpd binaries (NFS disabled in config — nfsd/exportfs not required)"
    fi

    find "$FS" -path '*/usr/lib/ipsec/charon' -type f 2>/dev/null | grep -q . \
        || fail "rootfs missing strongswan (charon)"
    find "$FS" -path '*/usr/lib/ipsec/stroke' -type f 2>/dev/null | grep -q . \
        || fail "rootfs missing strongswan (stroke)"
    find "$FS" \( -name smbd -o -name samba_multicall \) 2>/dev/null | grep -q . \
        || fail "rootfs missing Samba"
    find "$FS" -name 'libcjson.so*' 2>/dev/null | grep -q . \
        || fail "rootfs missing libcjson"
    [[ -f "${FS}/www/index.asp" ]] || fail "rootfs missing web UI (www/index.asp)"
    [[ -f "${FS}/usr/sbin/Tor" || -f "${FS}/usr/sbin/tor" ]] || fail "rootfs missing Tor"
    ok "Merlin feature set (VPN, Samba, cjson, web UI, Tor)"
fi

if [[ $FAIL -eq 0 ]]; then
    ok "all boot + bundle checks passed"
    ls -lh "${TARGET}"/GT-BE98_*_nand_squashfs*.pkgtb "${TARGET}"/bcm96813GW_uboot_linux.itb "${TARGET}"/rootfs.img 2>/dev/null || true
    exit 0
fi
exit 1
