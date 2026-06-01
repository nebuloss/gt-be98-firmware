# 04 — Package inventory

How **Asuswrt-Merlin** selects userspace packages for GT-BE98, and which pieces come from **Broadcom board sysdep** instead of `release/src/router/Makefile`.

## Mechanism

| Layer | Selection | Source file |
|-------|-----------|-------------|
| Merlin router | `obj-y`, `obj-$(RTCONFIG_*)`, `ifeq ($(RTCONFIG_*),y)` | `release/src/router/Makefile` |
| Kconfig export | `RTCONFIG_*=y` / not set | `bcmdrivers/.../bcm96813/main/src/router/.config` (after build) |
| Board overlay | `Bcmbuild.mk` / sysdep Makefiles | `router-sysdep.gt-be98/*` |
| BDK userspace | SDK `userspace` target | Wired through BCM build, not Merlin `obj-y` |

Merlin does **not** use kernel-style `obj-y` in the kernel tree; router packages are Make targets installed into `INSTALLDIR`, then merged at **`libcreduction`**.

## Counts (GT-BE98 profile, static grep)

| Metric | Count |
|--------|------:|
| `RTCONFIG_*=y` in router `.config` | **226** |
| `obj-$(RTCONFIG_*)` lines in `router/Makefile` | **~344** |
| Enabled flag → package mappings (unique packages) | **~163** |
| Always-on `obj-y` lines (subset; many are duplicates/variants) | **~100+** |

Hundreds of `RTCONFIG_*` symbols exist in Kconfig but are **off** for GT-BE98 (other SKUs). They are not listed here.

## Always-built core (`obj-y` highlights)

These are representative packages **not** gated by `RTCONFIG_*` for HND GT-BE98:

| Package / dir | Role |
|---------------|------|
| `busybox` | PID 1 / shell / core utilities |
| `shared`, `nvram` | Common library, NVRAM API |
| `rc` | Asus **`rc`** daemon (`init.c`, `services.c`, …) |
| `httpd`, `json-c`, `libwebapi` | Web UI and APIs |
| `dnsmasq` | DNS/DHCP |
| `ipset-7.6`, `iptables-1.8.10`, `iproute2-*` | Firewall / routing |
| `ctf`, `dhd_monitor` | Broadcom offload / Wi-Fi monitor |
| `networkmap`, `infosvr`, `wanduck` | LAN discovery, info, WAN health |
| `ebtables`, `miniupnpd`, `ntpd` (via rc) | L2 filter, UPnP, time |

Full list: grep `^obj-y` in `release/src/router/Makefile` (many lines are `ifeq` duplicates for other SoCs).

## HND-only (`obj-$(HND_ROUTER)`)

| Package | Role |
|---------|------|
| `bcm_boot_launcher` | Runs `/rom/etc/rc3.d` SysV scripts before handing off to `rc` |
| `httpdshared` | Shared HTTP assets for HND |

## Enabled optional stacks (by `RTCONFIG_*`)

Static intersection of **`obj-$(RTCONFIG_*)`** with **226** enabled flags in the GT-BE98 `.config`.

### VPN and tunnels

| RTCONFIG | Built packages (from Makefile) |
|----------|----------------------------------|
| `RTCONFIG_OPENVPN` | `openvpn`, `openssl`, `libovpn`, `lz4`, `libcap-ng`, `openpam`, `easy-rsa`, `ministun` |
| `RTCONFIG_STRONGSWAN` | `strongswan` |
| `RTCONFIG_WIREGUARD` | `wireguard-tools`, `zlib`, `libpng`, `qrencode` |
| `RTCONFIG_L2TP` | `rp-l2tp` |
| `RTCONFIG_PPTP` / `RTCONFIG_ACCEL_PPTPD` | `accel-pptp`, `accel-pptpd` |
| `RTCONFIG_IPSEC` / `RTCONFIG_IPSEC_SERVER` | Enabled in `.config`; wired via ipsec/strongswan paths in `rc` |

Patches: **0018** (accel-pptpd cross), **0019–0020** (strongswan autotools), **0021** (nfs-utils host rpcgen — see NFS).

### USB, NAS, sharing

| RTCONFIG | Built packages |
|----------|----------------|
| `RTCONFIG_SAMBASRV` | `samba-3.6.x_opwrt`, `wsdd2` |
| `RTCONFIG_SAMBACLIENT` | `samba-3.5.8`, `sambaclient` |
| `RTCONFIG_NFS` | `nfs-utils-1.3.4`, `portmap` |
| `RTCONFIG_WEBDAV` | `lighttpd-1.4.39`, `sqlite`, `libxml2`, `pcre-8.31`, `libexif` |
| `RTCONFIG_TFAT` | `tuxera` |
| `RTCONFIG_USB` / extras | Many client modules (`usb-modeswitch`, `comgt`, …) when modem/printer flags set |

Patches: **0001–0005** (NFS, portmap, tirpc), **0002** (lighttpd embedded), **0021**, **0023** (coovachilli gengetopt).

### Security, parental control, DPI

| RTCONFIG | Built packages |
|----------|----------------|
| `RTCONFIG_BWDPI` | `bwdpi_source`, `sqlite` |
| `RTCONFIG_COOVACHILLI` | `coovachilli` |
| `RTCONFIG_CONNTRACK` | `conntrack`, `libmnl`, `libnetfilter_*` |
| `RTCONFIG_EBTABLES` | `ebtables` |

### Wi-Fi (Merlin side)

| RTCONFIG | Built packages |
|----------|----------------|
| `RTCONFIG_DHDAP` | `dhd`, `pciefd` (full dongle stack) |
| `RTCONFIG_BCMBSD` | `bsd` |
| `RTCONFIG_EMF` | `emf`, `igs` (multicast snooping) |

Radio firmware and `wl`/`dhd` binaries are staged under `rom/etc/wlan/` (see verify script).

### Cloud and utilities

| RTCONFIG | Built packages |
|----------|----------------|
| `RTCONFIG_CLOUDSYNC` | `neon`, `curl`, `openssl`, `libxml2`, `asuswebstorage`, `smartsync_api`, … |
| `RTCONFIG_LETSENCRYPT` | `acme.sh`, `libletsencrypt`, `openssl`, `socat` |
| `RTCONFIG_AWSIOT` | `aws-iot` |

Patch **0010** (neon → staged libxml2).

### Special case: Tor

`RTCONFIG_TOR=y` uses an **`ifeq`** block (not `obj-$(RTCONFIG_TOR)`):

```makefile
ifeq ($(RTCONFIG_TOR),y)
obj-y += openssl zlib libevent-2.0.21 tor
endif
```

So Tor is in the GT-BE98 image when the flag is `y`.

## `obj-y` networking tools (always on this profile)

Includes **`ipset-7.6`** (patches **0011–0012**), **`lldpd-0.9.8`** (patches **0013** / **0013b**), **`iptables`**, **`iproute2`**.

## Board sysdep packages (`router-sysdep.gt-be98`)

Built outside the main `obj-$(RTCONFIG_*)` table:

| Directory | Binary / artifact | Role |
|-----------|-------------------|------|
| `mcpd/` | `mcpd` | Multi-AP / controller daemon |
| `bdmf_shell/` | `bdmf`, scripts | Runner/RDPA control; `rdpa_init.sh` |
| `rdpactl/` | `librdpactl.so` | RDPA control library |
| `wlan/scripts/` | `hndnvram.sh`, `wifi.sh`, … | Wi-Fi bring-up, NVRAM |
| `wdtctl/` | watchdog helpers | Firmware upgrade watchdog |
| `cjson/` | `libcjson` | JSON for platform apps (patch **0022**) |
| `scripts/std/` | `mount-fs.sh`, … | Early mount / defaults |

## Patches ↔ packages (quick map)

| Patches | Packages / area |
|---------|-----------------|
| 0001, 0003–0005, 0021 | NFS, portmap, tirpc |
| 0002, 0014 | lighttpd, cmake packages |
| 0006 | router `config` / ncurses test |
| 0007–0009 | toolchain paths, `LD_LIBRARY_PATH` |
| 0010–0013b | neon, ipset, lldpd |
| 0015–0017 | flac, extralflags, pcre |
| 0018–0020 | accel-pptpd, strongswan |
| 0022–0023 | cjson, coovachilli |

## Regenerating this inventory

From repo root (after a successful build):

```bash
CFG=vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/bcmdrivers/broadcom/net/wl/bcm96813/main/src/router/.config
grep -E '^RTCONFIG_.*=y$' "$CFG" | wc -l
grep -c '^obj-\$(RTCONFIG_' vendor/asuswrt-merlin.ng/release/src/router/Makefile
```

No audit scripts are required; the `.config` and `Makefile` are the source of truth.

## See also

- [02-build-graph.md](02-build-graph.md) — when packages install into `fs.install`
- [05-runtime-os.md](05-runtime-os.md) — which binaries `rc` starts at runtime
- [../../patches/README.md](../../patches/README.md) — patch details
