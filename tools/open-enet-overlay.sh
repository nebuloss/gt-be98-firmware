#!/usr/bin/env bash
# open-enet-overlay.sh - bake the open BCM4916 Ethernet driver boot hook into a
# GT-BE98 image (post-build rootfs overlay; the bootfs/kernel/DTB are untouched).
#
#   tools/open-enet-overlay.sh [BASE.pkgtb] [OUT.pkgtb]
#
# BASE defaults to the image this repo builds (bcm96813GW_nand_squashfs_update
# .pkgtb). An image that already carries the v3 hook (the July open-trial
# image) works too: the old guard and payload are replaced.
#
# Run on the BUILD HOST (needs dumpimage, mkimage, unsquashfs, mksquashfs).
# The output is a 2-image FIT (bootfs + rootfs) for the open flasher
# (gt-be98-buildroot board/gt-be98/flash/open-flash.sh: dumpimage -p0/-p1);
# it is not a web-GUI upgrade image.
#
# Rootfs changes:
#   rom/etc/init.d/bcm-base-drivers.sh   + guard (files/open-enet/bcm-base-drivers.guard)
#                                          right after `start)`, before any insmod
#   usr/lib/open-enet/load.sh            v4 (files/open-enet/load.sh)
#   lib/modules/<kver>/extra/bcm4916-runner.ko
#   lib/firmware/brcm/bcm4916-runner-microcode.bin
#   lib/firmware/brcm/merlin16-shortfin.bin        (if present in the payload)
#   (XPHY firmware: stock /rom/etc/fw/xphy_firmware.bin, read by the driver)
#
# Payload (NOT in git - proprietary / user-extracted, see .gitignore):
#   $OE_PAYLOAD/bcm4916-runner.ko             built against THIS image's kernel
#   $OE_PAYLOAD/bcm4916-runner-microcode.bin  RFW1 container (required)
#   $OE_PAYLOAD/merlin16-shortfin.bin         10G serdes uC blob (optional)
# OE_PAYLOAD defaults to <repo>/open-enet-payload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TGT="$ROOT/vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW"
BASE="${1:-$TGT/bcm96813GW_nand_squashfs_update.pkgtb}"
OUT="${2:-$ROOT/out/GT-BE98_open-enet_$(date +%Y%m%d-%H%M).pkgtb}"
PAY="${OE_PAYLOAD:-$ROOT/open-enet-payload}"
SRC="$ROOT/files/open-enet"
W="$(mktemp -d "${TMPDIR:-/tmp}/oe-overlay.XXXXXX")"
trap 'rm -rf "$W"' EXIT
die() { echo "!! $*" >&2; exit 1; }
say() { echo "== $*"; }

for t in dumpimage mkimage unsquashfs mksquashfs sha256sum strings; do
	command -v $t >/dev/null || die "missing host tool: $t"
done
[ -f "$BASE" ] || die "no base image: $BASE"
for f in bcm4916-runner.ko bcm4916-runner-microcode.bin; do
	[ -f "$PAY/$f" ] || die "payload missing: $PAY/$f"
done
grep -qa "parm=ifprefix:" "$PAY/bcm4916-runner.ko" ||
	die "bcm4916-runner.ko has no ifprefix parameter (needs the open-enet-boot driver)"
head -c4 "$PAY/bcm4916-runner-microcode.bin" | grep -q RFW1 ||
	die "microcode is not an RFW1 container"

# ---- split -------------------------------------------------------------------
say "base $(basename "$BASE")"
dumpimage -T flat_dt -p 0 -o "$W/bootfs.itb" "$BASE" >/dev/null
dumpimage -T flat_dt -p 1 -o "$W/rootfs.sqfs" "$BASE" >/dev/null
SB="$(unsquashfs -s "$W/rootfs.sqfs")"
echo "$SB" | grep -q "Compression xz" || die "base rootfs is not xz squashfs"
echo "$SB" | grep -q "Block size 131072" || die "base rootfs block size != 131072"
# every stock file is 0/0 and there are no device nodes: -all-root is exact
unsquashfs -lln "$W/rootfs.sqfs" | awk '$2 != "0/0" { bad = 1 } END { exit bad }' ||
	die "base rootfs has non-root owners; -all-root would change them"
unsquashfs -q -d "$W/r" "$W/rootfs.sqfs" >/dev/null
R="$W/r"

KVER="$(ls "$R/lib/modules" | head -1)"
MD="$R/lib/modules/$KVER/extra"
[ -f "$MD/bcm_mpm.ko" ] || die "base has no $KVER/extra/bcm_mpm.ko"
vm() { strings -a "$1" | sed -n 's/^vermagic=//p' | head -1; }
[ "$(vm "$PAY/bcm4916-runner.ko")" = "$(vm "$MD/bcm_mpm.ko")" ] ||
	die "vermagic mismatch: ko '$(vm "$PAY/bcm4916-runner.ko")' vs image '$(vm "$MD/bcm_mpm.ko")'"

# ---- guard -------------------------------------------------------------------
F="$R/rom/etc/init.d/bcm-base-drivers.sh"
[ -f "$F" ] || die "no $F"
awk -v guard="$SRC/bcm-base-drivers.guard" '
	/# --- open-ethernet .*hook/   { skip = 1; next }   # drop an older hook
	/# --- end open-ethernet/      { skip = 0; next }
	skip                          { next }
	{ print }
	!done && /^[ \t]*start\)[ \t]*$/ {
		while ((getline l < guard) > 0) print l
		done = 1
	}
	END { if (!done) exit 3 }' "$F" > "$W/bbd.sh" || die "no start) label in $F"
cat "$W/bbd.sh" > "$F"
g=$(grep -n 'open-ethernet hook v4' "$F" | cut -d: -f1)
# first insmod executed under start) - the helper functions above it do not count
st=$(awk '/^[ \t]*start\)[ \t]*$/ { print NR; exit }' "$F")
i=$(awk -v s="$st" 'NR > s && /^[^#]*insmod/ { print NR; exit }' "$F")
[ -n "$g" ] && [ -n "$i" ] && [ "$g" -lt "$i" ] || die "guard not before the first insmod"
[ "$(grep -c 'open-ethernet hook v4' "$F")" = 1 ] || die "guard present more than once"

# ---- payload -----------------------------------------------------------------
rm -rf "$R/usr/lib/open-enet"			# v3: baked .ko + fw copies, unused now
mkdir -p "$R/usr/lib/open-enet" "$R/lib/firmware/brcm"
install -m 0755 "$SRC/load.sh" "$R/usr/lib/open-enet/load.sh"
install -m 0644 "$PAY/bcm4916-runner.ko" "$MD/bcm4916-runner.ko"
install -m 0644 "$PAY/bcm4916-runner-microcode.bin" "$R/lib/firmware/brcm/"
if [ -f "$PAY/merlin16-shortfin.bin" ]; then
	install -m 0644 "$PAY/merlin16-shortfin.bin" "$R/lib/firmware/brcm/"
else
	echo "   note: no merlin16-shortfin.bin (driver skips the 10G XPORT serdes load)"
fi
[ -f "$R/rom/etc/fw/xphy_firmware.bin" ] || echo "   note: base has no /rom/etc/fw/xphy_firmware.bin"

# ---- repack ------------------------------------------------------------------
mksquashfs "$R" "$W/rootfs.new.sqfs" -comp xz -b 131072 -all-root -noappend -quiet
cat > "$W/pkgtb.its" <<'ITS'
/dts-v1/;
/ {
	description = "GT-BE98 open-enet bundle";
	#address-cells = <1>;
	images {
		bootfs { description = "bootfs"; data = /incbin/("./bootfs.itb"); type = "firmware";
			 arch = "arm64"; os = "linux"; compression = "none"; hash-1 { algo = "sha256"; }; };
		rootfs { description = "rootfs"; data = /incbin/("./rootfs.new.sqfs"); type = "firmware";
			 arch = "arm64"; os = "linux"; compression = "none"; hash-1 { algo = "sha256"; }; };
	};
	configurations { default = "conf"; conf { description = "bundle"; }; };
};
ITS
mkdir -p "$(dirname "$OUT")"
(cd "$W" && mkimage -f pkgtb.its "$OUT" >/dev/null)

# ---- verify round trip ---------------------------------------------------------
dumpimage -T flat_dt -p 0 -o "$W/chk0" "$OUT" >/dev/null
dumpimage -T flat_dt -p 1 -o "$W/chk1" "$OUT" >/dev/null
cmp -s "$W/chk0" "$W/bootfs.itb" || die "bootfs round trip differs"
cmp -s "$W/chk1" "$W/rootfs.new.sqfs" || die "rootfs round trip differs"
say "OUT $OUT"
echo "   rootfs $(stat -c%s "$W/rootfs.new.sqfs") B (base $(stat -c%s "$W/rootfs.sqfs") B)"
echo "   sha256 $(sha256sum "$OUT" | cut -c1-16)  bootfs unchanged $(sha256sum "$W/bootfs.itb" | cut -c1-16)"
