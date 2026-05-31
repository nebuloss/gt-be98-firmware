# GT-BE98 firmware build

Dépôt léger pour compiler le firmware **ASUS ROG Rapture GT-BE98** (Asuswrt-Merlin NG, BCM96813 / `src-rt-5.04behnd.4916`).

| Sur GitHub | En local seulement |
|------------|-------------------|
| Scripts, patches (~100 Ko) | `vendor/asuswrt-merlin.ng` (clone Merlin, ignoré par git) |
| | `logs/` |

## Prérequis

- Docker
- `gnuton/asuswrt-merlin-toolchains-docker:latest`
- ~25–35 Go disque pour `vendor/` après clone + build

## Usage

```bash
git clone git@github.com:<vous>/gt-be98-firmware.git
cd gt-be98-firmware

./setup.sh          # clone upstream, supprime les autres SDK, applique les patches
./build.sh          # compile
./build.sh clean    # après modification des patches
```

Firmware produit :

```
vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*.pkgtb
```

## Structure

```
gt-be98-firmware/
├── README.md
├── UPSTREAM              # URL/ref/commit upstream (mis à jour par setup.sh)
├── setup.sh
├── build.sh
├── patches/              # correctifs glibc 2.32 / TI-RPC
├── tools/
│   ├── apply-patches.sh
│   ├── prune-vendor.sh   # garde uniquement src-rt-5.04behnd.4916
│   └── clean-vendor.sh   # rm vendor + re-setup
├── logs/                 # gitignored
└── vendor/               # gitignored
    └── asuswrt-merlin.ng/
```

## Épuration du vendor

`setup.sh` supprime automatiquement les SDK Merlin inutiles (`release/src-rt-5.02*`, `release/src-rt-5.04axhnd*`, etc.) et conserve :

- `release/src-rt-5.04behnd.4916` (GT-BE98)
- `release/src/router/` (userspace partagé)

Le premier `git clone` télécharge tout le dépôt upstream ; l’épuration libère de l’espace disque **après** le clone.

## Pinning upstream

```bash
UPSTREAM_REF=<tag-or-commit> ./setup.sh
```

Le commit exact est enregistré dans `UPSTREAM` après chaque `setup.sh`.

## Publier sur GitHub

```bash
cd gt-be98-firmware
git init
git add README.md UPSTREAM .gitignore setup.sh build.sh patches/ tools/
git commit -m "GT-BE98: build wrapper and HND glibc 2.32 patches"
git remote add origin git@github.com:<vous>/gt-be98-firmware.git
git branch -M main
git push -u origin main
```

Ne jamais committer `vendor/` ni `logs/`.

## Patches

Voir [patches/README.md](patches/README.md). Validés sur toolchain ARM glibc 2.32 / GCC 10 (busybox tirpc, openssl stage, lighttpd, nfs-utils, portmap).

## Crédits

- [gnuton/asuswrt-merlin.ng](https://github.com/gnuton/asuswrt-merlin.ng)
- [gnuton/asuswrt-merlin-toolchains-docker](https://github.com/gnuton/Asuswrt-Merlin-Toolchains-Docker)
