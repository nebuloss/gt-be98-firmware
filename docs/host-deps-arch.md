# Dépendances hôte — Arch Linux

Build **100 % natif** : pas de Docker. La cross-compilation ARM vient de `toolchain/am-toolchains/`, **pas** de `pacman arm-linux-gnueabihf-gcc`.

## Installation recommandée

```bash
sudo pacman -S --needed \
    base-devel git perl python flex bison bc rsync patch unzip \
    texinfo gettext openssl ncurses autoconf automake libtool autoconf-archive \
    pkgconf gperf gengetopt cpio xz zlib gawk subversion intltool

# pkgconf → commande pkg-config (vérifiée par ./build.sh)
command -v pkg-config autoreconf
```

## Multilib 32 bits (requis pour ce build)

`www-install` exécute `tools/Lnx_AsusWrtDictPrep/LnxDictPrep` (binaire **i386** précompilé). Sans chargeur 32 bits, Make affiche `LnxDictPrep: No such file or directory` (exit 127) même si le fichier est présent.

```bash
sudo pacman -S --needed lib32-glibc lib32-gcc-libs lib32-zlib
```

Vérification :

```bash
file vendor/asuswrt-merlin.ng/release/src/router/tools/Lnx_AsusWrtDictPrep/LnxDictPrep
# → Intel 80386
test -f /lib/ld-linux.so.2 || test -f /usr/lib32/ld-linux.so.2 && echo "32-bit loader OK"
```

Certains binaires de la **toolchain** Buildroot utilisent aussi des libs 32 bits (`lib32-gcc-libs`, `lib32-zlib`).

## Vérification

Avant et pendant le build, `./build.sh` exécute `tools/check-host-deps.sh` (échec rapide si un outil manque). Contrôle manuel :

```bash
./tools/check-host-deps.sh --quick
./tools/check-host-deps.sh
```

Après le premier `./build.sh` ou `./tools/fetch-toolchain.sh` :

```bash
cd /chemin/vers/gt-be98-firmware
export GTBE98_ROOT="$(pwd)"
source tools/env.sh
arm-buildroot-linux-gnueabi-gcc --version
which arm-buildroot-linux-gnueabi-ld
```

Sortie attendue : **gcc 10.3.x**, préfixe `arm-buildroot-linux-gnueabi-`.

## Autres distributions

Non testées officiellement dans ce dépôt. Équivalents probables :

- Debian/Ubuntu : `build-essential`, `git`, `perl`, `python3`, `flex`, `bison`, `bc`, `rsync`, `patch`, `texinfo`, `gettext`, `libssl-dev`, `libncurses-dev`, `autoconf`, `automake`, `libtool`, `pkg-config`, `gperf`, `cpio`, `xz-utils`, `zlib1g-dev`
- Utiliser la même toolchain locale via `./tools/fetch-toolchain.sh` (pas la cross de la distro)

## PATH hôte vs toolchain

`tools/env.sh` place **`/usr/bin:/bin` avant** les `crosstools-*/usr/bin` :

- **bison**, **flex**, **gcc** hôte → système (Arch)
- **arm-buildroot-linux-gnueabi-gcc** → toolchain Merlin

Ne pas mettre les `usr/lib` des crosstools dans `LD_LIBRARY_PATH` (`cc1: undefined symbol: mpfr_asinpi`).

## Ce qui n’est pas une dépendance

| Paquet | Pourquoi |
|--------|----------|
| `docker` | Non utilisé |
| `arm-linux-gnueabihf-gcc` | Mauvaise ABI / mauvais sysroot pour ce firmware |
| SDK Merlin dans pacman | Récupéré via `vendor/` au bootstrap (`tools/setup.sh`) |
