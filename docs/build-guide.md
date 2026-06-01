# Guide de compilation

## Commandes

| Commande | Effet |
|----------|--------|
| `./build.sh` | Bootstrap si besoin, puis `make FORCE=1 gt-be98` (natif) |
| `./build.sh clean` | Nettoie objets des paquets patchés, puis build |
| `./tools/setup.sh` | Bootstrap manuel (toolchain + vendor + prune + patches) |

## Variables d’environnement optionnelles

### Upstream Merlin (`vendor/`)

```bash
UPSTREAM_REF=<branch-or-commit> ./tools/setup.sh
UPSTREAM_URL=https://github.com/gnuton/asuswrt-merlin.ng.git ./tools/setup.sh
```

Après le bootstrap (`tools/setup.sh` ou premier `./build.sh`), le fichier `UPSTREAM` contient :

```
url=...
ref=...
commit=<sha>
```

### Toolchain (`toolchain/`)

```bash
TC_REF=<branch-or-commit> ./tools/fetch-toolchain.sh
```

Après fetch, `toolchain/TOOLCHAIN_PIN` contient le commit de [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains).

## Mode `clean`

`./build.sh clean` supprime avant le make :

- Headers busybox régénérés (évite `rpc/rpc.h` obsolète)
- Sync OpenSSL `stage/usr/local` → `stage/usr/lib` (pour curl)
- `curl/Makefile`, objets lighttpd / nfs-utils / portmap

À utiliser après modification des patches ou d’un build interrompu sur ces composants.

## Cible make

- **Modèle** : `gt-be98` (fixe dans `build.sh`)
- **SDK** : `release/src-rt-5.04behnd.4916`
- **Profil** : `96813GW` → images sous `targets/96813GW/`

Le script force `make FORCE=1` pour ignorer l’avertissement « profile modified » après restauration de fichiers.

## Préparation bwdpi

Avant `make`, `build.sh` copie les headers BCM6813 requis :

- `bcm4916-tmcfg_udb.h` → `include/udb/tmcfg_udb.h`
- `bcm4916-tmcfg.h` → `include/tdts/tmcfg.h`

Sans cela, la compilation de `httpd` échoue sur `udb/tmcfg_udb.h`.

## Logs

Chaque build écrit :

```
logs/build_YYYYMMDD_HHMMSS.log
```

En cas d’échec, chercher la **première** erreur `error:` dans le log (pas seulement la fin du make).

## Reproduire un build identique

1. Noter `UPSTREAM` et `toolchain/TOOLCHAIN_PIN` après un build réussi
2. Réinstaller avec les mêmes refs :

```bash
rm -rf vendor toolchain
TC_REF=<commit-toolchain> UPSTREAM_REF=<commit-merlin> ./tools/setup.sh
./build.sh
```

## Ce que ce dépôt ne fait pas

- Pas de choix ROG/TUF UI (build `default` Merlin)
- Pas d’autres modèles que GT-BE98 / BCM96813
- Pas de packaging automatique vers un format `.trx` Asus classique (sortie SDK `.pkgtb`)
