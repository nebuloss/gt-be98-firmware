# Dépendances hôte — Arch Linux / Debian

Build **100 % natif** : pas de Docker. La cross-compilation ARM vient de `toolchain/am-toolchains/`, **pas** d'une cross de la distro (`arm-linux-gnueabihf-gcc`).

Testé sur **Arch Linux** et **Debian 13 (trixie)**. Section Arch ci-dessous ; voir [Debian / Ubuntu](#debian--ubuntu) plus bas.

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

## Debian / Ubuntu

Testé sur **Debian 13 (trixie)**. Build natif identique (toolchain locale via `tools/fetch-toolchain.sh`, **pas** la cross de la distro).

```bash
sudo apt-get install -y \
    build-essential git perl python3 flex bison bc rsync patch unzip \
    texinfo gettext openssl libssl-dev libncurses-dev autoconf automake libtool \
    autoconf-archive pkgconf gperf cpio xz-utils zlib1g-dev gawk subversion intltool \
    cmake gengetopt
```

> **libtool :** sur Debian, le paquet `libtool` ne fournit que `/usr/bin/libtoolize` (pas `/usr/bin/libtool`). C'est `libtoolize` qu'utilise `autoreconf` ; `tools/check-host-deps.sh` accepte l'un ou l'autre.

### Multilib 32 bits (i386) — requis pour LnxDictPrep

Même raison que la section Arch (binaire **i386** `LnxDictPrep`). Sur Debian il faut activer l'architecture i386 :

```bash
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y libc6:i386 libstdc++6:i386 zlib1g:i386
```

Vérification :

```bash
test -f /lib/ld-linux.so.2 || test -f /lib/i386-linux-gnu/ld-linux.so.2 && echo "32-bit loader OK"
```

## Autres distributions

Non testées. Utiliser les équivalents des paquets ci-dessus et la toolchain locale via `./tools/fetch-toolchain.sh` (pas la cross de la distro).

## PATH hôte vs toolchain

`tools/env.sh` place **`/usr/bin:/bin` avant** les `crosstools-*/usr/bin` :

- **bison**, **flex**, **gcc** hôte → système (Arch / Debian)
- **arm-buildroot-linux-gnueabi-gcc** → toolchain Merlin

Ne pas mettre les `usr/lib` des crosstools dans `LD_LIBRARY_PATH` (`cc1: undefined symbol: mpfr_asinpi`).

## Ce qui n’est pas une dépendance

| Paquet | Pourquoi |
|--------|----------|
| `docker` | Non utilisé |
| `arm-linux-gnueabihf-gcc` | Mauvaise ABI / mauvais sysroot pour ce firmware |
| SDK Merlin dans pacman | Récupéré via `vendor/` au bootstrap (`tools/setup.sh`) |
