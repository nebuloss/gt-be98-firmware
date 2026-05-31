# GT-BE98 firmware build

Dépôt léger pour compiler le firmware **ASUS ROG Rapture GT-BE98** (Asuswrt-Merlin NG, BCM96813 / `src-rt-5.04behnd.4916`).

| Sur GitHub | En local seulement |
|------------|-------------------|
| Scripts, patches (~100 Ko) | `toolchain/` — [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains) |
| | `vendor/asuswrt-merlin.ng` — clone Merlin |
| | `logs/` |

## Prérequis

- **Arch Linux** (ou autre distro) avec outils de build hôte — voir [docs/host-deps-arch.md](docs/host-deps-arch.md)
- **Pas de Docker** pour compiler
- ~30–40 Go disque (`toolchain/` + `vendor/` + build)

## Usage

```bash
git clone git@github.com:<vous>/gt-be98-firmware.git
cd gt-be98-firmware

./setup.sh          # toolchain + vendor + prune + patches
./build.sh          # compile (natif)
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
├── UPSTREAM                  # pin commit Merlin
├── setup.sh
├── build.sh                  # make natif + toolchain locale
├── patches/
├── docs/host-deps-arch.md
├── tools/
│   ├── fetch-toolchain.sh    # clone am-toolchains → toolchain/
│   ├── env.sh                # PATH / LD_LIBRARY_PATH
│   ├── apply-patches.sh
│   ├── prune-vendor.sh
│   └── clean-vendor.sh
├── toolchain/                # gitignored
│   ├── TOOLCHAIN_PIN
│   └── am-toolchains/brcm-arm-hnd/
├── logs/                     # gitignored
└── vendor/                   # gitignored
```

## Toolchain locale

`setup.sh` clone [RMerl/am-toolchains](https://github.com/gnuton/asuswrt-merlin.ng.git) dans `toolchain/am-toolchains/`. Le build utilise **GCC arm softfp 10.3 / glibc 2.32** sous `brcm-arm-hnd/` (comme l’image gnuton, sans Docker).

Pin optionnel :

```bash
TC_REF=<branch-or-commit> ./setup.sh
```

## Épuration du vendor

Seul `release/src-rt-5.04behnd.4916` est conservé (+ `release/src/router/`).

## Publier sur GitHub

```bash
git add README.md UPSTREAM .gitignore setup.sh build.sh patches/ tools/ docs/
git commit -m "your message"
git push
```

Ne jamais committer `vendor/`, `toolchain/` ni `logs/`.

## Patches

Voir [patches/README.md](patches/README.md).

## Crédits

- [gnuton/asuswrt-merlin.ng](https://github.com/gnuton/asuswrt-merlin.ng)
- [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains)
