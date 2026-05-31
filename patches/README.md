# GT-BE98 (HND / glibc 2.32 / GCC 10) build patches

Patches for building **Asuswrt-Merlin NG** on **BCM96813 / GT-BE98** with the
`gnuton/asuswrt-merlin-toolchains-docker` image and SDK `release/src-rt-5.04behnd.4916`.

Root cause: the ARM glibc 2.32 toolchain exposes **TI-RPC only** (`tirpc/rpc/rpc.h`),
and GCC 10 defaults to **`-fno-common`**, which breaks several legacy router packages.

## Apply patches

From the repository root:

```bash
patch -p1 < patches/gt-be98-hnd-glibc32/0001-router-Makefile-tirpc-openssl-nfs-portmap.patch
patch -p1 < patches/gt-be98-hnd-glibc32/0002-lighttpd-embedded-build.patch
patch -p1 < patches/gt-be98-hnd-glibc32/0003-nfs-utils-gcc10-tirpc.patch
patch -p1 < patches/gt-be98-hnd-glibc32/0004-portmap-portmap.c.patch
patch -p1 < patches/gt-be98-hnd-glibc32/0005-portmap-tirpc_compat.h.patch
```

Or copy `release/src/router/portmap/tirpc_compat.h` and apply the other diffs with `git apply`.

## Build

```bash
./build.sh gt-be98 default          # normal incremental build
./build.sh gt-be98 default clean    # wipe stale objects for patched packages first
```

## Patch summary

| Patch | File(s) | Problem | Fix |
|-------|---------|---------|-----|
| 0001 | `release/src/router/Makefile` | Busybox NFS mount needs tirpc; OpenSSL 1.1 `install_sw` installs under `usr/local`; curl links `usr/lib`; nfs-utils had `--disable-tirpc`; portmap had no tirpc | Add `-I.../tirpc`, link `tirpc`/`libtirpc`; copy ssl/crypto to `stage/usr/lib`; enable TI-RPC for `HND_ROUTER`; portmap `-ltirpc` |
| 0002 | `lighttpd-1.4.39/src/server.c`, `fdevent_poll.c` | `-DEMBEDDED_EANBLE=1` without `HAVE_SIGACTION`; undefined `signal_handler` / `srv` in poll stub | `embedded_signal_handler()`; `fprintf(stderr,…)` in non-poll stub |
| 0003 | `nfs-utils-1.3.4` mountd/statd | GCC 10 duplicate `v4root_needed`, `SM_stat_chge` in headers | Single `v4root_needed` in `xtab.c` (already upstream layout); remove from `v4root.c`; `extern` + one definition in `statd.c` |
| 0004–0005 | `portmap/portmap.c`, new `tirpc_compat.h` | libtirpc `svc_getcaller` is `sockaddr_in6` (`sin6_port`) | Map callers to `sockaddr_in` for legacy `pmap_check` |

## Notes

- **nfs-utils `xtab.c`**: `int v4root_needed` must remain in `support/export/xtab.c` (feeds `libexport.a`). Patch 0003 only removes the duplicate in `utils/mountd/v4root.c`.
- **lighttpd autotools**: If `configure` was re-run in-tree, ignore unrelated diffs under `lighttpd-1.4.39/configure*`; only `src/server.c` and `src/fdevent_poll.c` are required.
- **Verified** on 2026-05-31: full `make FORCE=1 gt-be98` exit 0, image under `release/src-rt-5.04behnd.4916/targets/96813GW/`.

## `build.sh` (repo root)

Helper script (not part of the numbered patches):

- Stages BCM6813 **bwdpi** `tmcfg` header symlinks (required for GT-BE98).
- Optional **`clean`** argument: clears busybox generated headers, openssl stage sync, and object files for curl/lighttpd/nfs-utils/portmap when iterating on these fixes.
- Runs Docker with `bcm-hnd-ax-4.19be_soft.sh` and `make FORCE=1 <model>`.
