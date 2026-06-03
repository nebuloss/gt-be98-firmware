# GT-BE98 system architecture

Static analysis of the **Asuswrt-Merlin NG** SDK (`src-rt-5.04behnd.4916`), this repo’s build wrapper, and the **BCM96813 / profile 96813GW** image for the **ASUS ROG Rapture GT-BE98**.

This is **not** OpenWrt: there is no `procd` or `opkg`. Userspace is **glibc**, **SysV init** (`BUILD_SYSV_INIT=y`), **Broadcom `bcm_boot_launcher`**, and Asus **`rc`** (`release/src/router/rc/`).

## Reading order

| Doc | Topic |
|-----|--------|
| [01-host-and-build.md](01-host-and-build.md) | Host deps, bootstrap, patches, `build.sh`, env vars, logs |
| [02-build-graph.md](02-build-graph.md) | Make targets: `gt-be98` → SDK `parallel_targets` → `buildimage` |
| [03-firmware-formats.md](03-firmware-formats.md) | `.pkgtb`, `.itb`, `rootfs.img`, flash semantics |
| [04-packages.md](04-packages.md) | Merlin `obj-$(RTCONFIG_*)` inventory vs GT-BE98 `.config` |
| [05-runtime-os.md](05-runtime-os.md) | Boot chain, storage, rc3.d, NVRAM, services |

## Related docs in this repo

- [../getting-started.md](../getting-started.md) — first clone and disk space
- [../build-guide.md](../build-guide.md) — `build.sh`, pins, `clean`
- [../deploy-and-test.md](../deploy-and-test.md) — deploy, test, stock restore, rescue, brick recovery  
- [../flashing.md](../flashing.md) — output paths and flash safety
- [../../patches/README.md](../../patches/README.md) — **25** patches (0001–0023 host/cross, 0024–0025 functional, plus `0013b`)
- [../../tools/verify-artifact.sh](../../tools/verify-artifact.sh) — post-build FIT / pkgtb / rootfs checks

## Key paths (after `./build.sh`)

| Path | Role |
|------|------|
| `vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/` | Broadcom HND SDK root (`SRCBASE`) |
| `vendor/.../targets/96813GW/` | Built images (`GT-BE98_*.pkgtb`, `rootfs.img`, `.itb`) |
| `vendor/.../targets/96813GW/fs.install/` | Staged rootfs before squashfs |
| `vendor/.../router-sysdep.gt-be98/` | Board overlay (scripts, mcpd, wlan, cjson, …) |
| `vendor/.../bcmdrivers/.../bcm96813/main/src/router/.config` | Merlin Kconfig export for this build |
| `toolchain/am-toolchains/brcm-arm-hnd/` | Pinned cross toolchain (`GTBE98_TC_ROOT`) |

## Scope

These documents are produced by **read-only** inspection of Makefiles, Kconfig, DTS, and init/rc sources. They do not replace a hardware bring-up test or a full reverse of every BCM binary blob.
