# Dépannage

Erreurs rencontrées lors du port GT-BE98 sur toolchain **ARM glibc 2.32 / GCC 10** (build natif). Les patches dans `patches/` visent ces problèmes.

## Avant de chercher plus loin

1. `./setup.sh` a bien été exécuté ?
2. `arm-buildroot-linux-gnueabi-gcc --version` fonctionne après `source tools/env.sh` ?
3. Regarder la **première** ligne `error:` dans `logs/build_*.log`

Après modification des patches :

```bash
./build.sh clean
```

## `rpc/rpc.h: No such file or directory` (busybox / mount)

**Cause :** Le sysroot n’a que `tirpc/rpc/rpc.h`, pas `rpc/rpc.h`. Parfois un vieux `busybox/include/autoconf.h` active NFS alors que la config modèle ne l’a pas.

**Fix :** Patch `0001` (Makefile busybox + tirpc). En local : `./build.sh clean` pour régénérer les headers busybox.

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
rm -rf ../vendor && ./setup.sh
```

`apply-patches.sh` saute les patches déjà présents.
