# Dépendances hôte — Arch Linux

Build **100 % natif** : pas de Docker. La cross-compilation ARM vient de `toolchain/am-toolchains/`, **pas** de `pacman arm-linux-gnueabihf-gcc`.

## Installation recommandée

```bash
sudo pacman -S --needed \
    base-devel git perl python flex bison bc rsync patch unzip \
    texinfo gettext openssl ncurses autoconf automake libtool \
    pkgconf gperf cpio xz zlib gawk subversion intltool
```

## Multilib (si le linker cross se plaint)

Certains binaires de la toolchain Buildroot sont liés contre des libs 32 bits :

```bash
sudo pacman -S --needed lib32-gcc-libs lib32-zlib
```

## Vérification

Après `./setup.sh` ou `./tools/fetch-toolchain.sh` :

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

## Ce qui n’est pas une dépendance

| Paquet | Pourquoi |
|--------|----------|
| `docker` | Non utilisé |
| `arm-linux-gnueabihf-gcc` | Mauvaise ABI / mauvais sysroot pour ce firmware |
| SDK Merlin dans pacman | Récupéré via `vendor/` dans `setup.sh` |
