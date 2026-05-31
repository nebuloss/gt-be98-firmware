# gt-be98-firmware

Compilation du firmware **ASUS ROG Rapture GT-BE98** (Asuswrt-Merlin NG, puce BCM96813).

Ce dépôt est **autonome** : il ne contient que les scripts, patches et la documentation. Le code Merlin et les toolchains sont récupérés localement par `./setup.sh` (non versionnés sur Git).

## Démarrage rapide

```bash
git clone git@github.com:<vous>/gt-be98-firmware.git
cd gt-be98-firmware

# Arch Linux — une fois
# Voir docs/host-deps-arch.md

./setup.sh
./build.sh
```

Image produite :

`vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*.pkgtb`

## Documentation

| Document | Contenu |
|----------|---------|
| [docs/getting-started.md](docs/getting-started.md) | Installation from scratch, espace disque, premier build |
| [docs/build-guide.md](docs/build-guide.md) | `setup.sh`, `build.sh clean`, logs, pins de versions |
| [docs/scripts.md](docs/scripts.md) | Rôle de chaque script dans `tools/` |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Erreurs connues (tirpc, lighttpd, nfs-utils, portmap…) |
| [docs/flashing.md](docs/flashing.md) | Fichiers `.pkgtb` et flash routeur |
| [docs/migration.md](docs/migration.md) | Quitter un ancien clone `asuswrt-merlin.ng` monolithique |
| [docs/host-deps-arch.md](docs/host-deps-arch.md) | Paquets pacman pour le build hôte |
| [patches/README.md](patches/README.md) | Détail des 5 patches GCC 10 / TI-RPC |

## Prérequis

- Linux (testé sur **Arch**), **sans Docker**
- ~30–40 Go d’espace libre après `setup.sh`
- Git, make, et paquets listés dans [docs/host-deps-arch.md](docs/host-deps-arch.md)

## Ce qui est versionné sur Git

- `patches/` — correctifs pour toolchain **glibc 2.32 / GCC 10** (HND)
- `build.sh`, `setup.sh`, `tools/`
- `docs/`, `README.md`, `UPSTREAM` (template)

**Jamais sur Git :** `vendor/`, `toolchain/`, `logs/` (voir `.gitignore`).

## Upstream

| Composant | Source |
|-----------|--------|
| Firmware sources | [gnuton/asuswrt-merlin.ng](https://github.com/gnuton/asuswrt-merlin.ng) → `vendor/` |
| Cross-toolchains | [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains) → `toolchain/` |

Les commits exacts sont enregistrés dans `UPSTREAM` et `toolchain/TOOLCHAIN_PIN` après chaque `./setup.sh`.

## Licence / crédits

Sources et toolchains : projets Merlin / RMerl / gnuton (voir liens ci-dessus).  
Les patches de ce dépôt couvrent des échecs de build spécifiques au GT-BE98 sur toolchain récente ; ils ne sont pas un fork officiel Asus.
