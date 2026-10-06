#!/bin/sh
# /usr/lib/open-enet/load.sh v4 - boot hook of the open BCM4916 Ethernet driver
# (github.com/nebuloss/gt-be98-open-ethernet). Called by the guard in
# /rom/etc/init.d/bcm-base-drivers.sh when /data/open_enet exists, in place of
# the stock datapath (bdmf/rdpa/bcm_enet), BEFORE rc builds br0.
#
# v4 loads bcm_mpm + the open driver here, synchronously, with ifprefix=eth:
# the open port is "eth0" when rc runs, so nvram lan_ifnames and the VLAN
# bridges (eth0.N -> brN) pick it up unchanged - no re-homing. The USB
# management NIC is loaded AFTER the driver and renamed mgmtN, never bridged.
#
# Exit status (read by the guard):
#   1 = declined, Runner NOT touched -> the guard runs the stock datapath;
#   0 = handled: open driver up, or it failed after touching the Runner
#       (stock cannot run then) -> USB lifeline as in v3 (USB NIC = eth0,
#       bridged by rc, no open port to loop with).
#
# Safety:
#   - HW watchdog petted from a shell loop: a hard SoC hang stops it -> reset.
#   - attempt counter: MAX_TRIES armed boots without a hold -> declined and the
#     arm flag is renamed /data/open_enet.tripped (stock datapath from then on).
#   - soft deadman: DEADMAN s without /tmp/oe-hold -> trip the flag + reboot
#     (next boot = stock datapath). DEADMAN=0 disables it.
#   - AUTOHOLD=1: hold automatically once eth0 has carrier, br0 an IPv4
#     address and eth0 received frames.
#   - L2 loop: with the open eth0 up, a USB-backed netdev is never left in a
#     bridge (renamed mgmtN, its bridge/VLAN uppers removed, checked every
#     500 ms for the life of the boot).
#
# Tunables in /data/open-enet/open-enet.conf (sourced, all optional):
#   PORTS=0x20 IFPREFIX=eth PARAMS="" MAX_TRIES=2 DEADMAN=900 AUTOHOLD=0
#   LIFELINE_IP=a.b.c.d/nn  (static address + dropbear on the USB NIC)
# Overrides on /data (no reflash): /data/open-enet/load-override.sh (whole
# script), /data/open-enet/bcm4916-runner.ko, /data/open-enet/fw/brcm/*.
set +e
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
[ -x /data/open-enet/load-override.sh ] && exec /bin/sh /data/open-enet/load-override.sh

L=/data/open-enet
BC=$L/trial.log
M=/lib/modules/$(uname -r)
NODE=/sys/bus/platform/devices/82000000.rdpa_drv
mkdir -p "$L"
[ -f "$BC" ] && mv -f "$BC" "$BC.prev"
log() { echo "$(cut -d. -f1 /proc/uptime 2>/dev/null)s $*" >> "$BC"; sync; }

PORTS=0x20; IFPREFIX=eth; PARAMS=""; MAX_TRIES=2; DEADMAN=900; AUTOHOLD=0
LIFELINE_IP=""
[ -f "$L/open-enet.conf" ] && . "$L/open-enet.conf"

KO=$M/extra/bcm4916-runner.ko
[ -f "$L/bcm4916-runner.ko" ] && KO=$L/bcm4916-runner.ko
MPM=$M/extra/bcm_mpm.ko
UC=brcm/bcm4916-runner-microcode.bin
log "=== load.sh v4: ko=$KO ports=$PORTS ifprefix=$IFPREFIX params='$PARAMS' ==="

decline() {
	log "DECLINED ($*): Runner untouched -> stock datapath"
	exit 1
}

# ---- 0. pre-flight: every check here leaves the Runner untouched --------
tries=$(cat "$L/tries" 2>/dev/null); tries=${tries:-0}
if [ "$tries" -ge "$MAX_TRIES" ]; then
	mv -f /data/open_enet /data/open_enet.tripped; sync
	decline "$tries armed boots without a hold; flag -> /data/open_enet.tripped"
fi
[ -f "$KO" ] || decline "no module $KO"
[ -f "$MPM" ] || decline "no $MPM"
[ -f "$L/fw/$UC" ] || [ -f "/lib/firmware/$UC" ] || decline "no Runner microcode $UC"
[ -f "$L/fw/brcm/merlin16-shortfin.bin" ] || [ -f /lib/firmware/brcm/merlin16-shortfin.bin ] ||
	log "WARN: no merlin16 serdes firmware (10G XPORT serdes skipped)"
[ -e "$NODE" ] || decline "no $NODE DT node"
[ -e "$NODE/driver" ] && decline "$NODE already bound"
grep -q "parm=ifprefix:" "$KO" || [ "$IFPREFIX" = rnr ] || \
	decline "module has no ifprefix parameter"
[ -e /sys/class/net/${IFPREFIX}0 ] && decline "${IFPREFIX}0 already exists"
# the MPM is the Runner's buffer manager; loading it leaves the Runner alone
# (the stock path would load it too)
grep -q '^bcm_mpm ' /proc/modules || insmod "$MPM" 2>> "$BC"
grep -q '^bcm_mpm ' /proc/modules || decline "bcm_mpm did not load"
echo $((tries + 1)) > "$L/tries"; sync

# ---- 1. watchdog petter, deadman, autohold, dmesg breadcrumbs -----------
( while :; do wdtctl ping >/dev/null 2>&1; sleep 15; done ) &
PET=$!
held() { [ -f /tmp/oe-hold ] && { echo 0 > "$L/tries"; sync; }; [ -f /tmp/oe-hold ]; }
if [ "$DEADMAN" -gt 0 ]; then
	( t=0
	  while [ $t -lt "$DEADMAN" ]; do held && exit 0; sleep 10; t=$((t + 10)); done
	  held && exit 0
	  log "deadman ${DEADMAN}s without /tmp/oe-hold -> trip flag + reboot"
	  mv -f /data/open_enet /data/open_enet.tripped; sync
	  # if the soft reboot is swallowed, the unpetted HW watchdog resets
	  wdtctl -t 60 start >/dev/null 2>&1; kill $PET; reboot -f ) &
fi
if [ "$AUTOHOLD" = 1 ]; then
	( E=${IFPREFIX}0; t=0
	  while [ $t -lt 600 ] && [ ! -f /tmp/oe-hold ]; do
		rx=$(cat /sys/class/net/$E/statistics/rx_packets 2>/dev/null)
		if [ "$(cat /sys/class/net/$E/carrier 2>/dev/null)" = 1 ] &&
		   [ "${rx:-0}" -gt 50 ] && ip -4 addr show br0 2>/dev/null | grep -q 'inet '; then
			touch /tmp/oe-hold; log "autohold: $E carrier, rx $rx, br0 has IPv4"
		fi
		sleep 5; t=$((t + 5))
	  done ) &
fi
# breadcrumbs until held (or the deadman window ends): bounded /data writes
( t=0; while [ $t -lt 900 ] && [ ! -f /tmp/oe-hold ]; do
	dmesg > "$L/dmesg.live" 2>/dev/null; sync; sleep 3; t=$((t + 3)); done
  dmesg > "$L/dmesg.live" 2>/dev/null; sync ) &

# ---- 2. the open driver (before the USB NIC, so it gets eth0) -----------
modprobe firmware_class 2>/dev/null
[ -d "$L/fw" ] && echo -n "$L/fw" > /sys/module/firmware_class/parameters/path
P="ports=$PORTS $PARAMS"
[ "$IFPREFIX" != rnr ] && P="$P ifprefix=$IFPREFIX"
log "insmod $KO $P"
insmod "$KO" $P >> "$BC" 2>&1
RET=$?
dmesg | grep -E 'bcm4916|bring-up|Runner' | tail -20 >> "$BC"
OPEN_UP=0
if [ $RET = 0 ] && [ -e "$NODE/driver" ] && [ -d /sys/class/net/${IFPREFIX}0 ]; then
	OPEN_UP=1
	touch /tmp/oe-open-up
	ip link set ${IFPREFIX}0 up
	OPEN=$(ls /sys/class/net | grep "^$IFPREFIX[0-9]$" | tr '\n' ' ')
	log "open driver UP: $OPEN"
else
	log "open driver FAILED (insmod ret=$RET) after touching the Runner -> v3 lifeline mode"
fi

# ---- 3. USB management NIC ------------------------------------------------
for k in usb/common/usb-common usb/core/usbcore usb/host/xhci-hcd usb/host/xhci-plat-hcd; do
	insmod $M/kernel/drivers/$k.ko 2>> "$BC"
done
insmod $M/extra/bcm_bca_usb.ko 2>> "$BC"
for k in mii usb/usbnet usb/ax88179_178a usb/cdc_ether; do
	insmod $M/kernel/drivers/net/$k.ko 2>> "$BC"
done

# is $1 backed by a USB device?
usbdev() { readlink -f /sys/class/net/$1/device 2>/dev/null | grep -q /usb; }

# Remove every bridge/VLAN upper of USB-backed netdevs and name them mgmtN.
# Never bridged: eth0 and the USB NIC sit on the same LAN (L2 loop).
tame_usb() {
	for d in /sys/class/net/eth* /sys/class/net/usb* /sys/class/net/mgmt*; do
		[ -e "$d" ] || continue
		n=${d##*/}
		case " $OPEN " in *" $n "*) continue ;; esac
		case $n in *.*) continue ;; esac
		usbdev $n || continue
		for u in $d/upper_*; do
			[ -e "$u" ] || continue
			u=${u##*/upper_}
			if [ -d /sys/class/net/$u/bridge ]; then
				brctl delif $u $n 2>/dev/null && log "loop guard: $n out of $u"
			else
				ip link del $u 2>/dev/null && log "loop guard: deleted $u on $n"
			fi
		done
		case $n in mgmt*) continue ;; esac
		i=0; while [ -e /sys/class/net/mgmt$i ]; do i=$((i + 1)); done
		ip link set $n down
		ip link set $n name mgmt$i && log "USB NIC $n -> mgmt$i"
		n=mgmt$i
		for c in all $n; do
			echo 1 > /proc/sys/net/ipv4/conf/$c/arp_ignore
			echo 2 > /proc/sys/net/ipv4/conf/$c/arp_announce
		done
		ip link set $n up
		if [ -n "$LIFELINE_IP" ]; then
			ip addr add $LIFELINE_IP dev $n 2>/dev/null
			if [ ! -f /tmp/oe-db-up ]; then
				mkdir -p /tmp/oe-db
				dropbear -R -E -p ${LIFELINE_IP%/*}:2222 \
					-d /tmp/oe-db/dss -r /tmp/oe-db/rsa 2>> "$BC" &&
					touch /tmp/oe-db-up
			fi
		elif [ ! -x /data/usbnet/usbnet.sh ]; then
			udhcpc -b -i $n >/dev/null 2>&1	# usbnet.sh does DHCP when present
		fi
	done
}

if [ $OPEN_UP = 1 ]; then
	# the first enumeration is renamed before rc's start_lan; the AX88179
	# re-enumerates later, so keep watching for the life of the boot
	t=0
	while [ $t -lt 20 ]; do
		tame_usb
		ls /sys/class/net | grep -q '^mgmt' && break
		sleep 1; t=$((t + 1))
	done
	( while :; do tame_usb; usleep 500000 2>/dev/null || sleep 1; done ) &
	log "USB loop guard running; returning to init (rc bridges ${IFPREFIX}0)"
else
	# v3 lifeline: the USB NIC takes the free name eth0 and rc bridges it
	# into br0 (the box keeps its address); no open port to loop with
	log "lifeline mode: USB NIC left to rc (bridged as eth0)"
fi
exit 0
