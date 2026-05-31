# Patches GT-BE98 (HND / glibc 2.32 / GCC 10)

Correctifs pour compiler **gnuton/asuswrt-merlin.ng** sur **BCM96813 / GT-BE98** avec la toolchain **arm softfp GCC 10.3** de [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains) (build natif, sans Docker).

## Application automatique

```bash
./setup.sh
# ou, si vendor/ existe déjà :
./tools/apply-patches.sh
```

Les patches sont appliqués dans `vendor/asuswrt-merlin.ng/` avec `patch -p1` depuis la racine du clone Merlin.

## Application manuelle

Depuis `vendor/asuswrt-merlin.ng/` :

```bash
patch -p1 < ../../patches/0001-router-Makefile-tirpc-openssl-nfs-portmap.patch
patch -p1 < ../../patches/0002-lighttpd-embedded-build.patch
patch -p1 < ../../patches/0003-nfs-utils-gcc10-tirpc.patch
patch -p1 < ../../patches/0004-portmap-portmap.c.patch
patch -p1 < ../../patches/0005-portmap-tirpc_compat.h.patch
```

## Résumé

| Patch | Fichiers | Problème | Correction |
|-------|----------|----------|------------|
| 0001 | `release/src/router/Makefile` | Busybox NFS + tirpc ; OpenSSL sous `usr/local` ; nfs-utils sans tirpc ; portmap sans `-ltirpc` | Flags/link tirpc ; copie ssl vers `stage/usr/lib` ; TI-RPC HND |
| 0002 | `lighttpd-1.4.39/src/server.c`, `fdevent_poll.c` | `EMBEDDED_EANBLE` sans handlers autoconf | `embedded_signal_handler()` ; stub poll sans `srv` |
| 0003 | `nfs-utils-1.3.4` mountd/statd | Duplicates GCC 10 `v4root_needed`, `SM_stat_chge` | Une définition ; `extern` dans header |
| 0004–0005 | `portmap/portmap.c`, `tirpc_compat.h` | libtirpc `sockaddr_in6` / `sin6_port` | Shim vers API `sockaddr_in` |

## Notes

- **`v4root_needed`** : doit rester défini dans `support/export/xtab.c` (libexport). Le patch ne retire que le doublon dans `utils/mountd/v4root.c`.
- **lighttpd** : seuls `src/server.c` et `src/fdevent_poll.c` sont requis ; ignorer le bruit autotools si `configure` a été relancé ailleurs.
- **Vérifié** : build complet `make FORCE=1 gt-be98` exit 0 (2026-05-31), images sous `targets/96813GW/`.

## Après modification d’un patch

```bash
./build.sh clean
```

Voir [../docs/troubleshooting.md](../docs/troubleshooting.md).
