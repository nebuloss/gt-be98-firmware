#!/bin/sh
#
# usbnet.sh - use the USB Ethernet adapter as the default route,
#             fall back to the built-in Ethernet (br0) when it is not usable.
#
# A supervisor checks the adapter every few seconds:
#   - adapter plugged, link up, DHCP lease  ->  route through USB
#   - anything else                         ->  remove our rules; the stock
#                                               routing (br0) takes over
#
# Only policy rules and our own table are touched; the main table is left as
# the firmware set it up.
#
# Usage: usbnet.sh start | stop | status

DRIVER=ax88179_178a          # USB adapter driver (ASIX AX88179A)
BR0=br0                      # built-in Ethernet, the fallback
TABLE=177                    # our routing table (100/200 belong to the stock WAN)
INTERVAL=5                   # seconds between checks

# Rule priorities. 17-19 must come before the stock rule 20 (table 8437),
# which holds a LAN route via br0.
PRIO_FROM_BR0=17             # replies from the br0 address stay on br0
PRIO_FROM_USB=18             # replies from the USB address stay on USB
PRIO_TO_LAN=19               # LAN traffic goes through USB
PRIO_MAIN=95                 # other specific routes (WiFi test subnets) keep working
PRIO_DEFAULT=96              # default route through USB

HOOK=/data/usbnet/udhcpc.hook
RUN=/tmp/usbnet
LEASE=$RUN/lease             # written by the DHCP hook
ACTIVE=$RUN/active           # present while USB routing is installed
DHCP_PID=$RUN/udhcpc.pid
SUPERVISOR_PID=$RUN/supervisor.pid
LOG=$RUN/log

log() {
	echo "$(date '+%F %T') $*" >>"$LOG"
}

# Print the interface name of the USB adapter, if plugged in.
find_adapter() {
	for dev in /sys/class/net/*; do
		driver=$(readlink "$dev/device/driver" 2>/dev/null)
		if [ "${driver##*/}" = "$DRIVER" ]; then
			echo "${dev##*/}"
			return 0
		fi
	done
	return 1
}

has_link() {
	[ "$(cat "/sys/class/net/$1/carrier" 2>/dev/null)" = 1 ]
}

# Network address of IP $1 with prefix length $2, e.g. 10.0.0.18 24 -> 10.0.0.0
network_of() {
	prefix=$2
	old_ifs=$IFS
	IFS=.
	set -- $1
	IFS=$old_ifs

	addr=$(( ($1 << 24) | ($2 << 16) | ($3 << 8) | $4 ))
	netmask=$(( (0xffffffff << (32 - prefix)) & 0xffffffff ))
	net=$(( addr & netmask ))
	echo "$((net >> 24 & 255)).$((net >> 16 & 255)).$((net >> 8 & 255)).$((net & 255))"
}

# ---- DHCP client --------------------------------------------------------

dhcp_running() {
	[ -f "$DHCP_PID" ] && kill -0 "$(cat "$DHCP_PID")" 2>/dev/null
}

dhcp_start() {
	udhcpc -i "$1" -b -p "$DHCP_PID" -s "$HOOK" -x hostname:GT-BE98-USB >>"$LOG" 2>&1
}

dhcp_stop() {
	dhcp_running && kill "$(cat "$DHCP_PID")"
	rm -f "$DHCP_PID" "$LEASE"
}

# ---- routing -------------------------------------------------------------

remove_rules() {
	for prio in $PRIO_FROM_BR0 $PRIO_FROM_USB $PRIO_TO_LAN $PRIO_MAIN $PRIO_DEFAULT; do
		while ip rule del pref "$prio" 2>/dev/null; do :; done
	done
	ip route flush table "$TABLE" 2>/dev/null
}

use_usb() {
	. "$LEASE"           # iface ip mask gateway
	lan="$(network_of "$ip" "$mask")/$mask"
	br0_ip=$(ip -4 -o addr show dev "$BR0" 2>/dev/null | awk '{ split($4, a, "/"); print a[1]; exit }')

	# Nothing to do if this exact setup is already in place.
	state="$iface $ip $lan $gateway $br0_ip"
	if [ "$(cat "$ACTIVE" 2>/dev/null)" = "$state" ] &&
	   ip rule | grep -q "^$PRIO_DEFAULT:"; then
		return
	fi

	remove_rules
	ip route add "$lan" dev "$iface" src "$ip" table "$TABLE"
	ip route add default via "$gateway" dev "$iface" table "$TABLE"

	[ -n "$br0_ip" ] && ip rule add pref "$PRIO_FROM_BR0" from "$br0_ip" lookup main
	ip rule add pref "$PRIO_FROM_USB" from "$ip" lookup "$TABLE"
	ip rule add pref "$PRIO_TO_LAN" to "$lan" lookup "$TABLE"
	ip rule add pref "$PRIO_MAIN" lookup main suppress_prefixlength 0
	ip rule add pref "$PRIO_DEFAULT" lookup "$TABLE"

	echo "$state" >"$ACTIVE"
	log "using USB: $iface $ip, gateway $gateway"
}

use_br0() {
	[ -f "$ACTIVE" ] || return
	remove_rules
	rm -f "$ACTIVE"
	log "falling back to $BR0: $1"
}

# ---- supervisor ----------------------------------------------------------

# Two interfaces on the same LAN: each answers ARP only for its own address.
fix_arp() {
	for conf in all "$1"; do
		echo 1 >"/proc/sys/net/ipv4/conf/$conf/arp_ignore"
		echo 2 >"/proc/sys/net/ipv4/conf/$conf/arp_announce"
	done
}

check() {
	if ! iface=$(find_adapter); then
		if [ -n "$current" ]; then
			log "adapter $current unplugged"
			current=
			dhcp_stop
		fi
		use_br0 "no adapter"
		return
	fi

	if [ "$iface" != "$current" ]; then
		log "adapter plugged in as $iface"
		current=$iface
		dhcp_stop
		fix_arp "$iface"
	fi

	ip link set "$iface" up
	dhcp_running || dhcp_start "$iface"

	if ! has_link "$iface"; then
		use_br0 "no link on $iface"
	elif [ ! -f "$LEASE" ]; then
		use_br0 "no DHCP lease on $iface"
	else
		use_usb
	fi
}

shutdown() {
	dhcp_stop
	use_br0 "supervisor stopped"
	rm -f "$SUPERVISOR_PID"
	exit 0
}

supervise() {
	echo $$ >"$SUPERVISOR_PID"
	trap shutdown INT TERM
	log "supervisor started"
	grep -q "^$DRIVER " /proc/modules || modprobe "$DRIVER" 2>/dev/null

	current=
	while true; do
		check
		# /tmp is RAM: keep the log small.
		if [ "$(wc -c <"$LOG")" -gt 65536 ]; then
			tail -c 32768 "$LOG" >"$LOG.old" && mv "$LOG.old" "$LOG"
		fi
		sleep "$INTERVAL"
	done
}

supervisor_running() {
	[ -f "$SUPERVISOR_PID" ] && kill -0 "$(cat "$SUPERVISOR_PID")" 2>/dev/null
}

# ---- commands ------------------------------------------------------------

cmd_start() {
	if supervisor_running; then
		echo "already running (pid $(cat "$SUPERVISOR_PID"))"
		return
	fi
	"$0" supervise </dev/null >/dev/null 2>&1 &
	echo "started"
}

cmd_stop() {
	supervisor_running || { echo "not running"; return; }
	pid=$(cat "$SUPERVISOR_PID")
	kill "$pid"
	# The supervisor exits after its current sleep; wait for it.
	waited=0
	while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt $((INTERVAL * 3)) ]; do
		sleep 1
		waited=$((waited + 1))
	done
	echo "stopped"
}

cmd_status() {
	if supervisor_running; then
		echo "supervisor: running (pid $(cat "$SUPERVISOR_PID"))"
	else
		echo "supervisor: stopped"
	fi
	if iface=$(find_adapter); then
		echo "adapter:    $iface, link $(has_link "$iface" && echo up || echo down)"
	else
		echo "adapter:    not plugged"
	fi
	if [ -f "$ACTIVE" ]; then
		echo "route:      USB"
	else
		echo "route:      $BR0 (fallback)"
	fi
	echo "default:    $(ip route get 1.1.1.1 | head -1)"
	echo
	ip rule
	echo
	tail -5 "$LOG" 2>/dev/null
}

mkdir -p "$RUN"
case "$1" in
	start)     cmd_start ;;
	stop)      cmd_stop ;;
	status)    cmd_status ;;
	supervise) supervise ;;
	*)         echo "usage: $0 start|stop|status" >&2; exit 2 ;;
esac
