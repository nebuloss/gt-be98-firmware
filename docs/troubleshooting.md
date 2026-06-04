# Dépannage

Erreurs rencontrées lors du port GT-BE98 sur toolchain **ARM glibc 2.32 / GCC 10** (build natif). Les patches dans `patches/` visent ces problèmes.

## SDK `src-rt-5.04behnd.4916` absent / bootstrap

**Cause :** un clone shallow de `master` sur gnuton ne contient pas toujours l’arborescence `release/src-rt-5.04behnd.4916` (SDK HND du GT-BE98). `vendor/` peut exister sans ce répertoire.

**Fix :**

```bash
rm -rf vendor
./build.sh
./build.sh
```

`tools/setup.sh` épingle par défaut le commit `ad42d5e81a…` (voir `UPSTREAM`). Pour réutiliser votre ancien clone :

```bash
rm -rf vendor
ln -s /chemin/vers/asuswrt-merlin.ng vendor/asuswrt-merlin.ng
./tools/prune-vendor.sh
./tools/apply-patches.sh
./build.sh
```

## `/opt/toolchains/.../arm-buildroot-linux-gnueabi-gcc: No such file or directory`

**Cause :** le SDK Merlin référence **`/opt/toolchains`** (Docker). Ce dépôt **ne crée pas** de lien sous `/opt`.

**Fix :** patches `0007`–`0008` + `./build.sh` (exporte `GTBE98_TC_ROOT` vers `toolchain/am-toolchains/brcm-arm-hnd`, sans `/opt`) :

```bash
./tools/apply-patches.sh
./build.sh
```

## `bison: libreadline.so.6: cannot open shared object file`

**Cause :** le `bison` des **crosstools** (dans `PATH` avant `/usr/bin`) est lié contre une vieille `libreadline.so.6` absente sur Arch.

**Fix :** `tools/env.sh` met `/usr/bin:/bin` avant les binaires toolchain. Relancer `./build.sh`. Vérifier :

```bash
source tools/env.sh   # après export GTBE98_ROOT=$(pwd)
which bison           # → /usr/bin/bison
which arm-buildroot-linux-gnueabi-gcc   # → toolchain/.../usr/bin/...
```

Paquets hôte si besoin : `sudo pacman -S --needed bison flex readline`.

## `cc1: undefined symbol: mpfr_asinpi` (U-Boot, busybox / `fixdep`)

**Cause :** le Makefile Merlin fait `export LD_LIBRARY_PATH := $(TOOLCHAIN)/lib` (vieille `libmpfr` des crosstools). Le **GCC hôte** Arch charge cette lib au lieu de `/usr/lib/libmpfr.so.6`.

**Fix :** `./build.sh` gère ça (`tools/sanitize-host-env.sh` + `env -u LD_LIBRARY_PATH make …`). Patch `0009` recommandé. Relancer :

```bash
cd ~/gt-be98-firmware   # ajuster selon votre clone
./tools/apply-patches.sh   # inclut 0009 si pas déjà fait
./build.sh
```

Ne pas exporter `LD_LIBRARY_PATH` dans le shell avant `./build.sh`.

Vérification :

```bash
unset LD_LIBRARY_PATH
ldd /usr/lib/gcc/x86_64-pc-linux-gnu/16.1.1/cc1 | grep mpfr
# → /usr/lib/libmpfr.so.6
```

## `Unable to find the Ncurses libraries` (config / `make menuconfig`)

**Cause fréquente sur Arch (GCC récent) :** le test dans `release/src/router/config/Makefile` compile `main(){}`, refusé par GCC (`-Wimplicit-int`). Le message parle de ncurses alors que le lien `-lncurses` n’est jamais testé correctement.

**Fix :** patch `0006` (via `./tools/apply-patches.sh`). Puis relancer `./build.sh`.

```bash
sudo pacman -S --needed ncurses
echo 'int main(void){return 0;}' | gcc -x c - -lncurses -o /dev/null && echo ncurses OK
```

## Avant de chercher plus loin

1. Le bootstrap a bien tourné (premier `./build.sh` ou `./tools/setup.sh`) ?
2. `test -d vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916` → doit exister
3. `arm-buildroot-linux-gnueabi-gcc --version` fonctionne après `source tools/env.sh` ?
4. Regarder la **première** ligne `error:` dans `logs/build_*.log`

Après modification des patches :

```bash
./build.sh clean
```

## `libcreduction FATAL: Missing 32-bit libraries: libcjson.so.1`

**Cause :** `bin/bp3` dépend de `libcjson.so.1`, mais le build `cjson` a échoué silencieusement (`-$(MAKE)` + `install` ne compilait pas avec CMake 4.x / mauvaise cible `.libs`).

**Fix :** patch `0022` ou `./tools/ensure-cjson-makefile.sh` (appelé par `apply-patches.sh` et `./build.sh`). Si un ancien `cjson/` existe sans `CMAKE_POLICY_VERSION_MINIMUM`, le Makefile le supprime automatiquement ; sinon :

```bash
rm -rf vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/router-sysdep/cjson/cjson
./build.sh
```

CMake 4.x : le patch passe `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` et `-DENABLE_CJSON_TEST=Off` (évite la cible `unity` en cross).

Vérifier : `ls targets/96813GW/fs.install/lib/libcjson.so*`

## `LnxDictPrep: No such file or directory` (www-install)

**Cause :** `LnxDictPrep` est un exécutable **32-bit i386** ; sur Arch x86_64 sans multilib, le noyau ne trouve pas `/lib/ld-linux.so.2` → erreur 127 (souvent confondue avec « fichier absent »).

**Fix :** installer le **multilib 32 bits** complet (chargeur + C++ runtime) :

```bash
sudo pacman -S --needed lib32-glibc lib32-gcc-libs
ldd vendor/asuswrt-merlin.ng/release/src/router/tools/Lnx_AsusWrtDictPrep/LnxDictPrep
# ne doit plus lister « not found » (souvent libstdc++.so.6, libgcc_s.so.1)
./build.sh
```

`./build.sh` vérifie aussi cet outil au démarrage (`gtbe98_check_lnxdictprep`).

## `rpcgen: cannot execute binary file` (nfs-utils-1.3.4)

**Cause :** `CC_FOR_BUILD=$(CC)` dans la configure nfs-utils compile `tools/rpcgen/rpcgen` pour ARM ; le build hôte x86_64 ne peut pas l’exécuter (erreur 126).

**Fix :** patch `0021` (via `./tools/apply-patches.sh`). Dépendance hôte : `libtirpc` (Arch : `pacman -S libtirpc`). Puis :

```bash
rm -f vendor/asuswrt-merlin.ng/release/src/router/nfs-utils-1.3.4/stamp-h1
./build.sh
```

## `rpc/rpc.h: No such file or directory` (busybox / mount)

**Cause :** Le sysroot n’a que `tirpc/rpc/rpc.h`, pas `rpc/rpc.h`. Parfois un vieux `busybox/include/autoconf.h` active NFS alors que la config modèle ne l’a pas.

**Fix :** Patch `0001` (Makefile busybox + tirpc). En local : `./build.sh clean` pour régénérer les headers busybox.

## `cp: cannot stat .../stage/usr/local/lib/libssl*` (openssl-1.1-stage)

**Cause :** OpenSSL est configuré avec `--prefix=/usr` : `install_sw` installe déjà dans `stage/usr/lib/`. Le patch ne doit copier depuis `usr/local/` que si ce répertoire existe (autres profils).

**Fix :** patch `0001` à jour (copie conditionnelle). Relancer `./build.sh`.

## `libxml2.so: file not recognized` (neon)

**Cause :** le link croise `-lxml2` et prend `/usr/lib/libxml2.so` (x86_64) au lieu de `$(STAGEDIR)/usr/lib/libxml2.so` (ARM).

**Fix :** patch `0010`. Puis reconfigurer neon :

```bash
rm -f vendor/asuswrt-merlin.ng/release/src/router/neon/Makefile
./build.sh
```

## `configure: error: pkg-config not found` (ipset-7.6)

**Cause :** `PKG_CONFIG=false` ne suffit pas (configure teste quand même la version). Sans `pkg-config` installé, ipset échoue.

**Fix :**

```bash
sudo pacman -S --needed pkgconf   # fournit /usr/bin/pkg-config
```

Et patch `0012` (pkg-config optionnel — `libmnl_CFLAGS`/`libmnl_LIBS` sont passés à la main). Puis :

```bash
rm -f vendor/asuswrt-merlin.ng/release/src/router/ipset-7.6/configure
rm -rf vendor/asuswrt-merlin.ng/release/src/router/ipset-7.6/Makefile
./tools/apply-patches.sh
./build.sh
```

`./build.sh` vérifie aussi la présence de `pkg-config` et `autoreconf`.

## CMake : `Compatibility with CMake < 3.5 has been removed` (usbmode, …)

**Cause :** CMake récent sur Arch refuse les projets avec `cmake_minimum_required(VERSION 2.6)`.

**Fix :** patch `0014` — `make` avec `GTBE98_TC_ROOT` utilise `cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5`.

```bash
rm -rf vendor/.../router/usbmode/CMakeCache.txt vendor/.../router/usbmode/CMakeFiles
./build.sh
```

## `libc.a: file format not recognized` (pcre-8.31 install / relink)

**Cause :** `make install` relink `libpcreposix.la` avec `-rpath /usr/lib` → libc hôte.

**Fix :** patch `0017` — stage manuel depuis `pcre-8.31/.libs/` (pas `make install`).

## `libgcc_s.so.1: file not recognized` (pcre, libtool relink, …)

**Cause :** `EXTRALDFLAGS=-lgcc_s` sans `-L` cross quand `LD_LIBRARY_PATH` est vidé (patch 0009).

**Fix :** patch `0016` — lien explicite vers `$(TOOLCHAIN)/arm-buildroot-linux-gnueabi/lib/libgcc_s.so`.

```bash
rm -f vendor/.../router/pcre-8.31/stamp-h1
./build.sh
```

## `libgcc_s.so` / `-L/lib` (flac, …)

**Cause :** `configure --prefix=''` → `OGG_LIBS=-L/lib -logg` pointe vers le système hôte.

**Fix :** patch `0015`. Reconfigurer :

```bash
rm -f vendor/.../router/flac/stamp-h1
rm -rf vendor/.../router/flac/src/libFLAC/.libs
./build.sh
```

## `undefined macro: AC_LIB_PREFIX` (strongswan autoreconf)

**Cause :** `router/Makefile` lance toujours `autoreconf` ; la macro vient de **autoconf-archive** (souvent absente sur Arch).

**Fix :** patches `0019`–`0020` + `tools/strongswan-ensure-aux.sh` (aux files + `autoreconf -ifi` si `Makefile.in` absent). Patch `0020` retire `AC_LIB_PREFIX` (évite `autoconf-archive`). Deps : `autoconf automake libtool`.

```bash
rm -f vendor/.../router/strongswan/Makefile vendor/.../router/strongswan/configure.stamp
./build.sh
```

## `cannot find input file: Makefile.in` (strongswan)

**Cause :** le snapshot vendor n’inclut pas les `Makefile.in` générés par automake.

**Fix :** idem — le script lance `autoreconf -ifi` une fois (après patch `0020`).

## `bool cannot be defined via typedef` (accel-pptpd / pppd.h)

**Cause :** sous-répertoire `plugins/` compile avec le `gcc` hôte (C23 par défaut sur Arch) ; `pppd.h` fait `typedef unsigned char bool`.

**Fix :** patch `0018` — passer `CC=$(CC)` et `-std=gnu99` dans `plugins/Makefile`.

```bash
rm -f vendor/.../accel-pptpd/pptpd-1.3.3/plugins/pptpd-logwtmp.so
./build.sh
```

## `redefinition of embedded_signal_handler` (lighttpd)

**Cause :** patch `0002` appliqué plusieurs fois (même contexte `#endif` / `#ifdef HAVE_FORK`).

**Fix :** patch `0002` mis à jour avec garde `GTBE98_LIGHTTPD_EMBEDDED_SIG` ; `apply-patches.sh` saute si déjà présent. Nettoyer `server.c` puis :

```bash
rm -f vendor/.../lighttpd-1.4.39/src/server.o
./build.sh
```

## `libxml2.so: file not recognized` (lldpd, neon, …)

**Cause :** `-lxml2` avec linker cross → `/usr/lib/libxml2.so` (x86_64) au lieu du stage ARM.

**Fix :** patches `0010` (neon), `0013` (lldpd). Reconfigurer le paquet :

```bash
rm -rf vendor/asuswrt-merlin.ng/release/src/router/lldpd-0.9.8/Makefile
./build.sh
```

## `libmnl.so: file not recognized` (ipset-7.6)

**Cause :** comme neon — `-lmnl` lie `/usr/lib/libmnl.so` (hôte) au lieu de la lib ARM.

**Fix :** patch `0011`. Reconfigurer ipset :

```bash
rm -rf vendor/asuswrt-merlin.ng/release/src/router/ipset-7.6/Makefile
./build.sh
```

## `cannot find -lssl` (curl)

**Cause :** OpenSSL 1.1 `install_sw` installe sous `stage/usr/local`, curl cherche `stage/usr/lib`.

**Fix :** Patch `0001` (copie openssl vers `stage/usr/lib` dans le Makefile). `build.sh clean` supprime `curl/Makefile` pour reconfigure.

## lighttpd : `signal_handler` / `srv` undefined

**Cause :** Build embarqué `-DEMBEDDED_EANBLE=1` sans `HAVE_SIGACTION` dans `config.h`.

**Fix :** Patch `0002` (`embedded_signal_handler` dans `server.c`, stub `fdevent_poll.c`).

## nfs-utils : `libtirpc not found` ou `rpc/rpc.h`

**Cause :** Configure avec `--disable-tirpc` alors que seul tirpc existe dans le sysroot.

**Fix :** Patch `0001` (TI-RPC activé pour `HND_ROUTER`, `-I.../tirpc`).

## nfs-utils : `multiple definition of v4root_needed`

**Cause :** GCC 10 `-fno-common` — symbole défini dans un header et dans plusieurs `.c`.

**Fix :** Patch `0003` (définition unique dans `xtab.c`, pas dans `v4root.c`).

## nfs-utils : `multiple definition of SM_stat_chge`

**Fix :** Patch `0003` (`extern` dans `statd.h`, définition dans `statd.c`).

## portmap : `sin6_port` / `sockaddr_in6` vs `sockaddr_in`

**Cause :** libtirpc expose les appelants en IPv6 ; le code legacy attend `sockaddr_in`.

**Fix :** Patches `0004` + `0005` (`tirpc_compat.h`, macro `svc_getcaller`).

## `The specified profile has been modified` / `make clean` demandé

```bash
# build.sh utilise déjà FORCE=1 ; si vous lancez make à la main :
cd vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916
make FORCE=1 gt-be98
```

## `arm-buildroot-linux-gnueabi-gcc: command not found`

```bash
./tools/fetch-toolchain.sh
export GTBE98_ROOT="$(pwd)"
source tools/env.sh
```

## Erreur linker / lib32 sur Arch

Installer [host-deps-arch.md](host-deps-arch.md) — section multilib (`lib32-gcc-libs`).

## Build très long / machine qui swap

Normal pour un premier build complet. Builds suivants sont incrémentaux. Allouer au moins 8–16 Go RAM si possible.

## Patches déjà appliqués / `patch failed`

```bash
cd vendor/asuswrt-merlin.ng
# inspecter l'état, puis si besoin :
rm -rf ../vendor && ./build.sh
```

`apply-patches.sh` saute les patches déjà présents.
