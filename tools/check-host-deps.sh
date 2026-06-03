#!/usr/bin/env bash
# Verify host packages/commands required for a native GT-BE98 Merlin build.
# Usage:
#   ./tools/check-host-deps.sh          # full (after vendor clone)
#   ./tools/check-host-deps.sh --quick  # before setup (no vendor-only checks)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GTBE98_ROOT="${GTBE98_ROOT:-$ROOT}"
QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

FAIL=0
ARCH_HINT='sudo pacman -S --needed base-devel git perl python flex bison bc rsync patch unzip texinfo gettext openssl ncurses autoconf automake libtool autoconf-archive pkgconf gperf cpio xz zlib gawk subversion intltool cmake gengetopt lib32-glibc lib32-gcc-libs lib32-zlib'
DEBIAN_HINT='sudo apt-get install -y build-essential git perl python3 flex bison bc rsync patch unzip texinfo gettext openssl libssl-dev libncurses-dev autoconf automake libtool autoconf-archive pkgconf gperf cpio xz-utils zlib1g-dev gawk subversion intltool cmake gengetopt'
# 32-bit runtime for LnxDictPrep (i386 ELF in the Merlin tree):
DEBIAN_HINT_I386='sudo dpkg --add-architecture i386 && sudo apt-get update && sudo apt-get install -y libc6:i386 libstdc++6:i386 zlib1g:i386'

fail() { echo "check-host-deps: FAIL: $*" >&2; FAIL=1; }
ok() { echo "check-host-deps: OK: $*"; }

need_cmd() {
    local cmd="$1"
    local alt="${2:-}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    if [[ -n "$alt" ]] && command -v "$alt" >/dev/null 2>&1; then
        return 0
    fi
    fail "missing command: ${cmd}${alt:+ (or ${alt})}"
    return 1
}

echo "check-host-deps: checking host tools (--quick=${QUICK})"

# Core build (Merlin + U-Boot host tools + autotools packages)
for cmd in \
    make gcc g++ ld ar ranlib strip \
    git perl \
    flex bison bc rsync patch unzip cat sed awk gawk \
    autoconf automake libtool autoreconf \
    pkg-config \
    cmake python3 \
    gperf gengetopt cpio xz gzip \
    msgfmt msgmerge xgettext \
    openssl
do
    case "$cmd" in
        python3) need_cmd python3 python ;;
        # Debian's libtool package ships only libtoolize (no /usr/bin/libtool);
        # autoreconf uses libtoolize, so either binary satisfies the requirement.
        libtool) need_cmd libtoolize libtool ;;
        *) need_cmd "$cmd" ;;
    esac
done

# Some router packages; warn only (not all gt-be98 paths need them)
for cmd in svn intltool; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "optional: ${cmd}"
    else
        echo "check-host-deps: WARN: missing ${cmd} (install if configure/Makefile errors mention it)" >&2
    fi
done

# Host cc1 / libmpfr (Arch + crosstool LD_LIBRARY_PATH pitfall)
if command -v gcc >/dev/null 2>&1; then
    cc1="$(gcc -print-prog-name=cc1 2>/dev/null || true)"
    if [[ -n "$cc1" && -x "$cc1" ]]; then
        mpfr_line="$(ldd "$cc1" 2>/dev/null | grep libmpfr || true)"
        if [[ "$mpfr_line" == *"not found"* ]]; then
            fail "host cc1 missing libmpfr — install mpfr (Arch: pacman -S mpfr; Debian: apt-get install libmpfr6)"
        elif [[ "$mpfr_line" == *crosstools* || "$mpfr_line" == *am-toolchains* || "$mpfr_line" == *"/toolchain/"* ]]; then
            fail "host cc1 loads crosstool libmpfr — unset LD_LIBRARY_PATH and use ./build.sh only"
        else
            ok "host gcc/cc1 libmpfr"
        fi
    fi
else
    fail "missing command: gcc"
fi

# 32-bit loader for LnxDictPrep (i386 binary in router tree)
if [[ -f /lib/ld-linux.so.2 || -f /usr/lib32/ld-linux.so.2 || -f /lib/i386-linux-gnu/ld-linux.so.2 ]]; then
    ok "32-bit dynamic linker (ld-linux.so.2)"
else
    fail "no 32-bit dynamic linker — LnxDictPrep will fail (Arch: lib32-glibc lib32-gcc-libs; Debian: ${DEBIAN_HINT_I386})"
fi

# Vendor-specific: LnxDictPrep after clone
DICTPREP="${GTBE98_ROOT}/vendor/asuswrt-merlin.ng/release/src/router/tools/Lnx_AsusWrtDictPrep/LnxDictPrep"
if [[ "$QUICK" -eq 0 && -f "$DICTPREP" ]]; then
    ldd_out="$(ldd "$DICTPREP" 2>&1 || true)"
    if printf '%s\n' "$ldd_out" | grep -q 'not found'; then
        fail "LnxDictPrep missing 32-bit libraries"
        printf '%s\n' "$ldd_out" | grep 'not found' >&2
        echo "  Arch: sudo pacman -S --needed lib32-glibc lib32-gcc-libs lib32-zlib" >&2
        echo "  Debian: ${DEBIAN_HINT_I386}" >&2
    else
        ok "LnxDictPrep (${DICTPREP##*/}) libraries"
    fi
elif [[ "$QUICK" -eq 1 ]]; then
    ok "skipping LnxDictPrep ldd (--quick, vendor may not exist yet)"
fi

if [[ $FAIL -ne 0 ]]; then
    echo "" >&2
    echo "Install host dependencies, then re-run ./build.sh" >&2
    if command -v pacman >/dev/null 2>&1; then
        echo "  Arch hint: ${ARCH_HINT}" >&2
    elif command -v apt-get >/dev/null 2>&1; then
        echo "  Debian/Ubuntu hint: ${DEBIAN_HINT}" >&2
        echo "  Debian/Ubuntu 32-bit (LnxDictPrep): ${DEBIAN_HINT_I386}" >&2
    else
        echo "  See docs/host-deps-arch.md for package names" >&2
    fi
    exit 1
fi

ok "all host dependency checks passed"
exit 0
