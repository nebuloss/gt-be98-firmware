# Migration depuis un clone `asuswrt-merlin.ng` monolithique

Si vous aviez travaillé dans un gros clone Merlin (avec milliers de fichiers modifiés par le build) et que vous passez **uniquement** à `gt-be98-firmware/`, voici comment migrer proprement.

## Ce que vous pouvez supprimer

Après avoir validé que le nouveau dépôt build correctement :

- L’ancien répertoire `asuswrt-merlin.ng/` (ou tout clone Merlin utilisé uniquement pour GT-BE98)
- Les logs Docker / `.cursor/` de debug dans l’ancien tree
- Un éventuel doublon `asuswrt-merlin.ng/gt-be98-firmware/` (déjà retiré lors de la migration)

**Conserver** jusqu’à validation :

- Une copie des images `.pkgtb` déjà compilées si vous en avez besoin
- Ce dépôt `gt-be98-firmware/` (source de vérité pour patches + scripts)

## Ce qui ne migre pas automatiquement

| Ancien emplacement | Nouveau emplacement |
|-------------------|---------------------|
| Patches dans `asuswrt-merlin.ng/patches/gt-be98-hnd-glibc32/` | Déjà dans `gt-be98-firmware/patches/` |
| `build.sh` à la racine Merlin | `gt-be98-firmware/build.sh` (natif, pas Docker) |
| Build tree entier versionné par erreur | **Ne pas** committer — `vendor/` est recréé par `setup.sh` |
| Toolchain Docker `/opt/toolchains` | `toolchain/am-toolchains/` via `fetch-toolchain.sh` |

## Repartir de zéro (recommandé)

```bash
cd /chemin/vers/gt-be98-firmware
rm -rf vendor toolchain logs
./setup.sh
./build.sh
```

Pas besoin de l’ancien clone si le réseau permet de re-cloner.

## Réutiliser un vendor existant (gain de temps)

Si l’ancien clone est sain et déjà patché :

```bash
# Exemple : ancien clone à côté
ln -s /chemin/vers/asuswrt-merlin.ng gt-be98-firmware/vendor/asuswrt-merlin.ng
# ou cp -a si vous préférez une copie indépendante

cd gt-be98-firmware
./tools/fetch-toolchain.sh
./tools/prune-vendor.sh
./tools/apply-patches.sh
./build.sh
```

Vérifier que les patches ne sont pas appliqués deux fois (`apply-patches.sh` gère le cas « déjà appliqué »).

## GitHub : un seul dépôt

Poussez **seulement** `gt-be98-firmware/` :

```bash
cd gt-be98-firmware
git remote add origin git@github.com:<vous>/gt-be98-firmware.git
git push -u origin main
```

Ne poussez pas l’ancien monorepo Merlin sauf si vous maintenez volontairement un fork complet.

## Checklist avant de « dégager » l’ancien clone

- [ ] `./setup.sh` OK sur une machine fraîche (ou après `rm -rf vendor toolchain`)
- [ ] `./build.sh` exit 0
- [ ] `GT-BE98_*.pkgtb` présent dans `targets/96813GW/`
- [ ] Remote Git configuré sur `gt-be98-firmware` uniquement
- [ ] Sauvegarde des images firmware si nécessaire
