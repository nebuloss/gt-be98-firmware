#!/usr/bin/env bash
# Bootstrap strongSwan autotools for native gt-be98 build (aux files + Makefile.in).
set -euo pipefail

dir="${1:?strongswan source directory}"
cd "$dir"

need=()
for f in config.guess config.sub compile missing install-sh; do
	[[ -f "$f" ]] || need+=("$f")
done

if [[ ${#need[@]} -gt 0 ]]; then
	am_dir="$(ls -d /usr/share/automake-* 2>/dev/null | sort -V | tail -1)" || true
	[[ -n "$am_dir" ]] || {
		echo "strongswan-ensure-aux: install automake (pacman -S automake)" >&2
		exit 1
	}
	for f in "${need[@]}"; do
		cp -f "${am_dir}/${f}" "./${f}"
		chmod a+x "./${f}" 2>/dev/null || true
	done
	echo "strongswan-ensure-aux: installed ${need[*]}"
fi

if [[ ! -f ltmain.sh ]]; then
	lt="$(ls /usr/share/libtool/build-aux/ltmain.sh /usr/share/libtool/ltmain.sh 2>/dev/null | head -1)" || true
	[[ -n "$lt" ]] || {
		echo "strongswan-ensure-aux: install libtool (pacman -S libtool)" >&2
		exit 1
	}
	cp -f "$lt" ./ltmain.sh
fi

if [[ ! -f Makefile.in ]]; then
	echo "strongswan-ensure-aux: generating Makefile.in (autoreconf -ifi)..."
	command -v autoreconf >/dev/null || {
		echo "strongswan-ensure-aux: install autoconf automake libtool" >&2
		exit 1
	}
	autoreconf -ifi
fi
