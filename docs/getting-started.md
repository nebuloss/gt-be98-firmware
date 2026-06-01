# Première installation

Guide pour partir de zéro avec **uniquement** ce dépôt `gt-be98-firmware`.

## 1. Cloner ce dépôt

```bash
cd ~/misc/be98   # ou tout autre répertoire de travail
git clone git@github.com:<vous>/gt-be98-firmware.git
cd gt-be98-firmware
```

## 2. Dépendances hôte (Arch Linux)

```bash
sudo pacman -S --needed \
    base-devel git perl python flex bison bc rsync patch unzip \
    texinfo gettext openssl ncurses autoconf automake libtool \
    pkgconf gperf cpio xz zlib gawk
```

Détails et cas particuliers : [host-deps-arch.md](host-deps-arch.md).

## 3. Build (bootstrap automatique la première fois)

```bash
./build.sh
```

Si `vendor/` ou `toolchain/` manquent, `./build.sh` lance d’abord `tools/setup.sh` :

Étapes du bootstrap :

1. Clone **RMerl/am-toolchains** dans `toolchain/am-toolchains/` (~quelques Go)
2. Clone **gnuton/asuswrt-merlin.ng** dans `vendor/asuswrt-merlin.ng/` (~plusieurs Go)
3. Suppression des SDK Merlin inutiles (ne garde que `src-rt-5.04behnd.4916` pour le GT-BE98)
4. Application des 5 patches dans `patches/`

Durée : surtout limitée par le réseau (clone). Comptez 20–60 min selon la connexion.

Vérification toolchain :

```bash
export GTBE98_ROOT="$(pwd)"
source tools/env.sh
arm-buildroot-linux-gnueabi-gcc --version
# attendu : gcc 10.3.x (Buildroot), arm-buildroot-linux-gnueabi
```

La même commande enchaîne ensuite la compilation Merlin.

- Premier build : **long** (souvent 1–3 h selon la machine, bootstrap inclus)
- Builds suivants : incrémentaux, plus rapides
- Logs : `logs/build_YYYYMMDD_HHMMSS.log`

## 4. Récupérer l’image

```bash
ls -lh vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*.pkgtb
```

Voir [flashing.md](flashing.md) pour l’usage de ces fichiers.

## Espace disque indicatif

| Répertoire | Ordre de grandeur |
|------------|-------------------|
| `toolchain/` | ~2–4 Go |
| `vendor/` (après prune) | ~15–25 Go |
| Build + `targets/` | +5–15 Go |

Total typique : **30–40 Go**.

## Prochaines fois

```bash
./build.sh              # rebuild incrémental
./build.sh clean        # si vous modifiez les patches
```

Pour tout réinitialiser :

```bash
./tools/clean-vendor.sh   # supprime vendor/ et relance setup (garde toolchain)
# ou
rm -rf vendor toolchain && ./build.sh
```
