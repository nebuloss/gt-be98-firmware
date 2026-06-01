# Scripts

Tous les scripts sont à lancer depuis la **racine** du dépôt `gt-be98-firmware/`.

## Racine

### `build.sh [clean]`

- Si toolchain ou SDK Merlin manquent : `tools/ensure-setup.sh` → `tools/setup.sh`
- Exporte `GTBE98_TC_ROOT` vers `toolchain/am-toolchains/brcm-arm-hnd` (sans `/opt/toolchains`)
- `tools/sanitize-host-env.sh` : supprime `LD_LIBRARY_PATH`, vérifie que `cc1` utilise la libmpfr système
- Source `tools/env.sh` (cross GCC dans `PATH`, outils hôte depuis `/usr/bin`, pas de `LD_LIBRARY_PATH`)
- Lance `make` via `env -u LD_LIBRARY_PATH` et `LD_LIBRARY_PATH=` (contre le `export` Merlin dans `router/Makefile`)
- Prépare bwdpi, optionnellement nettoie les artefacts patchés
- Lance `make FORCE=1 GTBE98_TC_ROOT=... gt-be98` dans le SDK
- Affiche les `.pkgtb` GT-BE98 en cas de succès

## `tools/`

### `check-host-deps.sh`

Vérifie les commandes hôte requises (`gcc`, `make`, `cmake`, `bison`, `pkg-config`, multilib 32 bits, etc.) et l’état de `LnxDictPrep` après clone vendor.

```bash
./tools/check-host-deps.sh --quick   # avant bootstrap (pas de ldd LnxDictPrep)
./tools/check-host-deps.sh           # complet (appelé deux fois par build.sh)
```

### `ensure-setup.sh`

Appelé par `build.sh`. Lance `tools/setup.sh` uniquement si le cross-GCC ou `release/src-rt-5.04behnd.4916` est absent. `GTBE98_SKIP_SETUP=1` désactive l’auto-setup (échec si artefacts manquants).

### `setup.sh`

Bootstrap complet (4 étapes) :

1. `fetch-toolchain.sh`
2. `setup-vendor.sh`
3. `prune-vendor.sh`
4. `apply-patches.sh` + mise à jour de `UPSTREAM`

### `setup-vendor.sh`

Clone ou checkout du commit Merlin (voir `UPSTREAM`, `GTBE98_DEFAULT_UPSTREAM_REF` dans `setup-common.sh`).

### `setup-common.sh`

Chemins et fonctions partagées (`gtbe98_sdk_ok`, `gtbe98_cross_gcc_ok`, …). À sourcer, pas à exécuter.

### `fetch-toolchain.sh`

Clone [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains) dans `toolchain/am-toolchains/`.

Vérifie la présence de `arm-buildroot-linux-gnueabi-gcc` (softfp GCC 10.3). Idempotent.

### `env.sh`

Configure `TOOLCHAIN_BASE` et `PATH` pour `brcm-arm-hnd/` (pas de `LD_LIBRARY_PATH` ni de `/opt/toolchains`).

**Ne pas** l’exécuter directement : il attend `GTBE98_ROOT` (défini par `build.sh`).

Test manuel :

```bash
export GTBE98_ROOT="$(pwd)"
source tools/env.sh
which arm-buildroot-linux-gnueabi-gcc
```

### `verify-artifact.sh`

Contrôles post-build (appelé automatiquement par `./build.sh` en cas de succès) :

- Images : `GT-BE98_*_nand_squashfs*.pkgtb`, `bcm96813GW_uboot_linux.itb`, `rootfs.img`
- Chaîne de boot FIT : ATF, U-Boot, noyau Linux, `fdt_GT-BE98` / `conf_lx_GT-BE98`
- Bundle `.pkgtb` : métadonnées `nand_squashfs`, embarquement squashfs identique à `rootfs.img`
- Rootfs : `busybox`, `rc`, `libc`, `nvram`, `dhd`/`wl`, firmware `rtecdc.bin`, `rom/etc` de base
- Régressions Merlin : VPN, Samba, `libcjson`, UI web, Tor, etc.

```bash
./tools/verify-artifact.sh
```

### `apply-patches.sh`

Applique `patches/0001-*.patch` … `0005-*.patch` dans `vendor/asuswrt-merlin.ng/` (`patch -p1`).

Ignore les patches déjà appliqués (test reverse).

### `prune-vendor.sh`

Dans `vendor/.../release/`, supprime tous les `src-rt-*` sauf `src-rt-5.04behnd.4916`.

Conserve `release/src/router/` (obligatoire pour le build).

### `clean-vendor.sh`

Demande confirmation, supprime `vendor/`, relance `tools/setup.sh` (garde `toolchain/`).

## Fichiers de pin

| Fichier | Contenu |
|---------|---------|
| `UPSTREAM` | URL, ref, commit du clone Merlin |
| `toolchain/TOOLCHAIN_PIN` | URL, ref, commit de am-toolchains |

Créés ou mis à jour par `tools/setup.sh` / `fetch-toolchain.sh`.
