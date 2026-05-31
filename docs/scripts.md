# Scripts

Tous les scripts sont à lancer depuis la **racine** du dépôt `gt-be98-firmware/`.

## Racine

### `setup.sh`

Orchestration complète de l’environnement local :

1. `tools/fetch-toolchain.sh`
2. Clone `vendor/asuswrt-merlin.ng` si absent
3. `tools/prune-vendor.sh`
4. `tools/apply-patches.sh`
5. Mise à jour de `UPSTREAM`

### `build.sh [clean]`

- Source `tools/env.sh` (cross GCC dans `PATH`)
- Prépare bwdpi, optionnellement nettoie les artefacts patchés
- Lance `make FORCE=1 gt-be98` dans le SDK
- Affiche les `.pkgtb` GT-BE98 en cas de succès

## `tools/`

### `fetch-toolchain.sh`

Clone [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains) dans `toolchain/am-toolchains/`.

Vérifie la présence de `arm-buildroot-linux-gnueabi-gcc` (softfp GCC 10.3). Idempotent.

### `env.sh`

Configure `TOOLCHAIN_BASE`, `PATH`, `LD_LIBRARY_PATH` pour `brcm-arm-hnd/`.

**Ne pas** l’exécuter directement : il attend `GTBE98_ROOT` (défini par `build.sh`).

Test manuel :

```bash
export GTBE98_ROOT="$(pwd)"
source tools/env.sh
which arm-buildroot-linux-gnueabi-gcc
```

### `apply-patches.sh`

Applique `patches/0001-*.patch` … `0005-*.patch` dans `vendor/asuswrt-merlin.ng/` (`patch -p1`).

Ignore les patches déjà appliqués (test reverse).

### `prune-vendor.sh`

Dans `vendor/.../release/`, supprime tous les `src-rt-*` sauf `src-rt-5.04behnd.4916`.

Conserve `release/src/router/` (obligatoire pour le build).

### `clean-vendor.sh`

Demande confirmation, supprime `vendor/`, relance `setup.sh` (garde `toolchain/`).

## Fichiers de pin

| Fichier | Contenu |
|---------|---------|
| `UPSTREAM` | URL, ref, commit du clone Merlin |
| `toolchain/TOOLCHAIN_PIN` | URL, ref, commit de am-toolchains |

Créés ou mis à jour par `setup.sh` / `fetch-toolchain.sh`.
