# Images de sortie et flash

## Où sont les fichiers

Après un build réussi :

```
vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/
```

Fichiers utiles pour le **GT-BE98** (noms avec version Merlin, ex. `3006_102.6_0`) :

| Fichier (exemple) | Rôle typique |
|-------------------|--------------|
| `GT-BE98_*_nand_squashfs.pkgtb` | Image firmware principale (mise à jour) |
| `GT-BE98_*_nand_squashfs_loader.pkgtb` | Variante avec loader |
| `bcm96813GW_uboot_linux.itb` | Image U-Boot / FIT Linux |

Les noms exacts dépendent de la version Merlin compilée. Utiliser `ls -lh targets/96813GW/GT-BE98_*` après `./build.sh`.

## Format `.pkgtb`

Format **Broadcom / Asus SDK** (BCM96813), pas un `.trx` classique généré par les vieux builds Merlin sur routeurs MIPS.

Pour flasher :

- Suivre la procédure **Asus / Merlin** pour les modèles HND récents (recovery, outil officiel, ou méthode documentée pour votre variante NAND/eMMC).
- Ce dépôt **ne fournit pas** d’outil de flash ; il ne produit que les binaires du SDK.

## Vérifier le build

```bash
./build.sh
# exit code 0
ls -lh vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*.pkgtb
```

## Attention

- Flasher une image incompatible (mauvais modèle / mauvaise variante) peut bricker le routeur.
- Garder une sauvegarde du firmware d’usine ou une méthode de recovery connue avant test.
