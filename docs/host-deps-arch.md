# Dépendances hôte — Arch Linux

Build **natif** (sans Docker). La cross-compilation ARM vient de `toolchain/am-toolchains`, pas des paquets Arch `arm-linux-gnueabihf-gcc`.

## Paquets recommandés

```bash
sudo pacman -S --needed \
    base-devel git perl python flex bison bc rsync patch unzip \
    texinfo gettext openssl ncurses autoconf automake libtool \
    pkgconf gperf cpio xz zlib
```

Optionnel (certains paquets Merlin) :

```bash
sudo pacman -S --needed gawk subversion intltool gtk-doc
```

## Multilib

Si le linker du cross-GCC se plaint de libs 32 bits manquantes :

```bash
sudo pacman -S --needed lib32-gcc-libs lib32-zlib
```

## Vérifier la toolchain

Après `./setup.sh` :

```bash
source /dev/null
export GTBE98_ROOT="$(pwd)"
source tools/env.sh
arm-buildroot-linux-gnueabi-gcc --version
```

## Docker

Non requis pour `setup.sh` ni `build.sh`. L’image `gnuton/asuswrt-merlin-toolchains-docker` n’est plus utilisée par ce dépôt.
