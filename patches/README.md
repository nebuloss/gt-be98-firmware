# Patches GT-BE98 (HND / glibc 2.32 / GCC 10)

Correctifs pour compiler **gnuton/asuswrt-merlin.ng** sur **BCM96813 / GT-BE98** avec la toolchain **arm softfp GCC 10.3** de [RMerl/am-toolchains](https://github.com/RMerl/am-toolchains) (build natif, sans Docker).

## Application automatique

```bash
./build.sh
# ou, si vendor/ existe déjà :
./tools/apply-patches.sh
```

Les patches sont appliqués dans `vendor/asuswrt-merlin.ng/` avec `patch -p1` depuis la racine du clone Merlin.

## Application manuelle

Depuis `vendor/asuswrt-merlin.ng/` :

```bash
patch -p1 < ../../patches/0001-router-Makefile-tirpc-openssl-nfs-portmap.patch
patch -p1 < ../../patches/0002-lighttpd-embedded-build.patch
patch -p1 < ../../patches/0003-nfs-utils-gcc10-tirpc.patch
patch -p1 < ../../patches/0004-portmap-portmap.c.patch
patch -p1 < ../../patches/0005-portmap-tirpc_compat.h.patch
patch -p1 < ../../patches/0006-router-config-ncurses-host-check.patch
patch -p1 < ../../patches/0007-platform-native-toolchain-root.patch
patch -p1 < ../../patches/0008-router-uboot-toolchain-root.patch
patch -p1 < ../../patches/0009-router-host-ld-library-path.patch
patch -p1 < ../../patches/0010-neon-cross-libxml2.patch
patch -p1 < ../../patches/0011-ipset-cross-libmnl.patch
patch -p1 < ../../patches/0012-ipset-pkg-config-optional.patch
patch -p1 < ../../patches/0013-lldpd-cross-libxml2.patch
patch -p1 < ../../patches/0014-cmake-policy-minimum.patch
patch -p1 < ../../patches/0015-flac-cross-libogg.patch
patch -p1 < ../../patches/0016-extralfags-cross-libgcc.patch
patch -p1 < ../../patches/0017-pcre-stage-no-relink.patch
patch -p1 < ../../patches/0018-accel-pptpd-plugins-cross.patch
patch -p1 < ../../patches/0019-strongswan-skip-autoreconf.patch
patch -p1 < ../../patches/0020-strongswan-autotools-bootstrap.patch
patch -p1 < ../../patches/0021-nfs-utils-host-rpcgen.patch
patch -p1 < ../../patches/0022-cjson-cmake-libcreduction.patch
patch -p1 < ../../patches/0023-coovachilli-gengetopt-optional.patch
patch -p1 < ../../patches/0024-infosvr-disable-by-default.patch
patch -p1 < ../../patches/0025-mainfh-exclude-ifnames-from-hapd.patch
patch -p1 < ../../patches/0026-envrams-disable-by-default.patch
# Variante lldpd 1.0.11 (si le profil l’active) :
# patch -p1 < ../../patches/0013b-lldpd-1.0.11-libxml2.patch
```

**Total : 26 fichiers** dans `patches/` (`0001`–`0026`, plus `0013b` pour lldpd 1.0.11).
Note : `0001`–`0023` sont des correctifs **de build** (toolchain/cross). `0024`+ sont
**fonctionnels** (modif du comportement runtime du firmware). Voir aussi [docs/architecture/01-host-and-build.md](../docs/architecture/01-host-and-build.md) et [04-packages.md](../docs/architecture/04-packages.md) pour le mapping patches ↔ étapes de build.

## Résumé

| Patch | Fichiers | Problème | Correction |
|-------|----------|----------|------------|
| 0001 | `release/src/router/Makefile` | Busybox NFS + tirpc ; OpenSSL stage ; nfs-utils ; portmap | tirpc ; copie ssl **si** `usr/local/lib` existe (`--prefix=/usr` sinon déjà dans `usr/lib`) |
| 0002 | `lighttpd-1.4.39/src/server.c`, `fdevent_poll.c` | `EMBEDDED_EANBLE` sans handlers autoconf | `embedded_signal_handler()` ; stub poll sans `srv` |
| 0003 | `nfs-utils-1.3.4` mountd/statd | Duplicates GCC 10 `v4root_needed`, `SM_stat_chge` | Une définition ; `extern` dans header |
| 0004–0005 | `portmap/portmap.c`, `tirpc_compat.h` | libtirpc `sockaddr_in6` / `sin6_port` | Shim vers API `sockaddr_in` |
| 0006 | `release/src/router/config/Makefile` | Test ncurses avec `main(){}` (GCC Arch) | `int main(void) { return 0; }` |
| 0007 | `release/src-rt/platform.mak` | Chemins `/opt/toolchains` (Docker) | `GTBE98_TC_ROOT` (obligatoire, fourni par `./build.sh`) |
| 0008 | `router/Makefile` (ebtables), `options_6813_nand.conf` | Idem pour ebtables / U-Boot GT-BE98 | `$(GTBE98_TC_ROOT)/...` |
| 0009 | `router/Makefile` | `LD_LIBRARY_PATH:=$(TOOLCHAIN)/lib` casse host `cc1` | Pas de `LD_LIBRARY_PATH` si `GTBE98_TC_ROOT` défini |
| 0010 | `router/Makefile` (neon) | `-lxml2` résout `/usr/lib` hôte (x86_64) | Liens explicites vers `$(STAGEDIR)/usr/lib/*.so` |
| 0011 | `router/Makefile` (ipset-7.6) | `-lmnl` résout `/usr/lib` hôte | `$(TOP)/libmnl-1.0.4/src/.libs/libmnl.so` |
| 0012 | `ipset-7.6/configure.ac` | `PKG_CONFIG=false` / pkg-config absent | `PKG_PROG_PKG_CONFIG` optionnel ; `libmnl_*` en configure |
| 0013 | `router/Makefile` (lldpd) | `-lxml2` → `/usr/lib` hôte | `XML2_LIBS` + sed → `$(STAGEDIR)/usr/lib/libxml2.so` |
| 0014 | `router/Makefile` (cmake) | CMake 4.x + `VERSION 2.6` | `$(CMAKE)` avec `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` si `GTBE98_TC_ROOT` |
| 0015 | `router/Makefile` (flac) | `-L/lib -logg` (prefix vide) | `--with-ogg-includes` / `--with-ogg-libraries` |
| 0016 | `router/Makefile` (`EXTRALDFLAGS`) | `-lgcc_s` → `/usr/lib` | chemin explicite `$(TOOLCHAIN)/arm-.../libgcc_s.so` |
| 0017 | `router/Makefile` (pcre stage) | libtool relink → `/usr/lib/libc.a` | `pcre-8.31-stage` copie `.libs/` vers `$(STAGEDIR)` |
| 0018 | `accel-pptpd` plugins | host `gcc` + C23 → `typedef bool` | cross `CC` + `-std=gnu99` dans `plugins/Makefile` |
| 0019 | `router/Makefile` + `tools/strongswan-ensure-aux.sh` | autoreconf / aux manquants | pas d’`autoreconf` systématique ; copie `config.guess` etc. depuis automake |
| 0020 | `strongswan/configure.ac` | `Makefile.in` absent / `AC_LIB_PREFIX` | retire `AC_LIB_PREFIX` ; `autoreconf -ifi` si pas de `Makefile.in` |
| 0021 | `router/Makefile`, `nfs-utils-1.3.4` | `rpcgen`: cannot execute binary file (ARM rpcgen sur hôte x86_64) | pas de `CC_FOR_BUILD=$(CC)` ; build hôte `rpcgen` + ne pas le reconstruire en cross |
| 0022 | `router-sysdep.gt-be98/cjson`, `router/Makefile` | `libcreduction`: Missing `libcjson.so.1` (`bp3` sans lib installée) | CMake 4.x + `install` cassé (`.libs`) ; erreurs `cjson` non ignorées si `GTBE98_TC_ROOT` |
| 0023 | `coovachilli` | `gengetopt` absent sur hôte Arch | Ne régénère pas `cmdline.c` si le fichier existe déjà |
| 0013b | `router/Makefile` (lldpd-1.0.11) | Même problème libxml2 que 0013 | Liens vers `$(STAGEDIR)/usr/lib/libxml2.so` (profil alternatif) |
| 0024 | `rc/services.c`, `rc/watchdog.c` | **Fonctionnel** : infosvr (découverte ASUS, UDP 9999) tourne par défaut — surface d'attaque inutile | `start_infosvr`/`infosvr_check` retournent tôt sauf si `nvram infosvr_enable=1` (désactivé par défaut, réactivable sans reflash) |
| 0025 | `shared/wlif_utils_ax.c` | **Fonctionnel** : MAINFH (`wl3.1`/MyPrivateNetwork) forcé par le générateur hostapd closed, ingouvernable par nvram | `get_all_lanifnames_list` (seule source de la liste BSS du générateur) retire les ifaces de `nvram hapd_exclude_ifnames`. Vide par défaut ; `="wl3.1"` supprime MAINFH à la source (BSS + bridge) → retire les watchdogs |
| 0026 | `rc/ate.c` | **Fonctionnel** : envrams (serveur NVRAM distant, TCP 5152) tourne par défaut — surface d'attaque | `start_envrams` retourne tôt sauf si `nvram envrams_enable=1` (désactivé par défaut). Plan de contrôle = webui uniquement |
| 0027 | `rc/services.c`, `rc/natnl_api.c` | **Fonctionnel** : daemons cloud/télémétrie ASUS (awsiot/AWS-IoT, mastiff/AAE, asd, conn_diag, networkmap) tournent par défaut et sont respawnés par `watchdog.c` — surface d'attaque + télémétrie inutiles (mode AP) | Garde `gtbe98_<daemon>` en tête de chaque `start_*` (réactiver: `nvram set gtbe98_awsiot=1`, etc.). Désactivés par défaut. envrams traité par 0026 (rebuild). |
| 0028 | `rc/services.c`, `rc/watchdog.c` | **Fonctionnel** : cfg_server (coordinateur AiMesh/Guest-Pro) non porteur sur AP autonome | Garde `cfgmnt_enable` dans `start_cfgsync`/`cfgsync_check` (désactivé par défaut, réactiver: `nvram set cfgmnt_enable=1`) |
| 0029 | `rc/services.c` | **Fonctionnel** : daemons coordinateurs AiMesh (wlc_nt, amas_lanctrl, …) tournent par défaut sur AP autonome | Gardes nvram `*_enable` en tête des `start_*` (modèle 0024/0028), désactivés par défaut |
| 0030 | `rc/services.c` | **Fonctionnel** : daemons band-steering/roaming (bsd, roamast, …) tournent par défaut | Gardes nvram `*_enable` en tête des `start_*` (modèle 0024/0028), désactivés par défaut |
| 0031 | `rc/ssh.c`, `rc/watchdog.c` | **Fonctionnel (inverse)** : dropbear :2222 = seule voie d'admin (pas de console série) ; un nvram cassé (`sshd_enable=0`, `sshd_port` invalide) brique l'accès | Garde-fou **toujours actif**, indépendant de tout nvram : `start_sshd` garantit une écoute :2222 (mode secours durci si `sshd_enable=0`) + `sshd_check` (watchdog) respawn dropbear. Voir `gt-be98-docs/plans/patch-0031-dropbear-failsafe.md` |
| 0032 | `router/Makefile` (envram_bin-install) | **Fonctionnel** : malgré 0026, envrams tournait encore sur l'image 0031. Cause : pour GT-BE98 `rc` lie les prebuilts closed-source `rc/prebuild/GT-BE98/ate.o` + `ate-broadcom.o` (rc/Makefile copie `prebuild/ate.o` au lieu de compiler `ate.c`) → le gate source de 0026 n'est **jamais compilé** ; `start_envrams` (prebuilt, non gaté) est appelé au boot via `init.c sysinit → init_asusctrl` (asusctrl), et httpd le respawne à la demande via le prebuilt `web_hook.o` (`system("/usr/sbin/envrams &> /dev/null")`) | Gate au niveau rootfs (seul point patchable en texte) : le vrai daemon est installé en `/usr/sbin/envrams.real`, `/usr/sbin/envrams` devient un wrapper sh désactivé par défaut (réactiver: `nvram set envrams_enable=1` ; mode mfg bootloader = bypass). Couvre tous les sites de lancement (rc prebuilt, httpd, hndmfg.sh). 0026 conservé (inerte aujourd'hui, redeviendrait utile si un futur merge compile ate.c). Voir `gt-be98-docs/plans/patch-0032-envrams-real-start.md` |
| 0033 | `rc/services.c`, `rc/watchdog.c` | **Fonctionnel** : httpd (UI web ASUS, :80) tourne par défaut ; le webui ouvert (`/usr/br`, rail S29) doit posséder l'admin. **Danger flash** : `httpd_check` (watchdog.c:8018-8020) fait `nvram_set`×2 + `nvram_commit()` à CHAQUE période de watchdog tant que httpd est absent → usure NAND si on retire l'UI sans gate | Garde `gtbe98_httpd` en tête de `start_httpd` (avant `notify_rc`) ET de `httpd_check` (AU-DESSUS du bloc commit). Désactivé par défaut. Réactiver: `nvram set gtbe98_httpd=1 ; nvram commit`. Prérequis des slices webui br-0047/br-0048. Voir `gt-be98-docs/device/plans/patch-0033-0034-notes.md` |
| 0034 | `rc/services.c`, `rc/watchdog.c` | **Fonctionnel** : sched_daemon (ordonnanceur de tâches ASUS) tourne par défaut ; son respawn watchdog (`sched_daemon_check`) est **NON gaté** en stock → retirer le binaire sans gate boucle un échec de relance à chaque période | Garde `gtbe98_sched_daemon` en tête de `start_sched_daemon` (avant `notify_rc`) ET de `sched_daemon_check`. Désactivé par défaut. Réactiver: `nvram set gtbe98_sched_daemon=1 ; nvram commit`. Voir `gt-be98-docs/device/plans/patch-0033-0034-notes.md` |
| 0035 | `rc/watchdog.c` | **Fonctionnel** : sur AP autonome le webui-go (`EnsureRadio`) peut posséder tout le bring-up wifi (wl-ioctls + hostapd from-source ; la config radio persiste dans le driver, jamais ré-appliquée par wlconf). Le seul point qui court-circuite un hostapd contrôlé par le webui est le superviseur stock : `debug_monitor` (dhd_monitor) respawn un hostapd primaire tué en ~10s (hostapd seul, jamais wlconf). Sur la plateforme `RTCONFIG_HND_ROUTER_BE_4916` (GT-BE98), le **seul** site rc qui ressuscite ce superviseur est le bloc `watchdog()` (`start_dhd_monitor()` + `SIGUSR2` hostapd) ; l'autre site hostapd (`wpasupp_hapd_check`) est gardé `RPBE58/RTBE58_GO` + client_mode → non compilé ici | Garde `gtbe98_wifi_extsup` repliée dans la condition du bloc debug_monitor de `watchdog()` (pas un `return` : on est dans le tick `watchdog(int sig)`). Désactivé par défaut (flag absent/0 ⇒ chemin stock verbatim). `=1` ⇒ le watchdog ne relance plus `debug_monitor`, le contrôleur webui-go reste l'unique superviseur hostapd. Compagnon de `webui_radio_init=1` (sole-supervisor wifi). Réactiver le superviseur stock : `nvram unset gtbe98_wifi_extsup ; nvram commit` |

## Notes

- **`v4root_needed`** : doit rester défini dans `support/export/xtab.c` (libexport). Le patch ne retire que le doublon dans `utils/mountd/v4root.c`.
- **lighttpd** : seuls `src/server.c` et `src/fdevent_poll.c` sont requis ; patch idempotent (`GTBE98_LIGHTTPD_EMBEDDED_SIG`). Si `redefinition of embedded_signal_handler` : supprimer les blocs dupliqués dans `server.c` ou `git checkout -- release/src/router/lighttpd-1.4.39/src/server.c` puis `./tools/apply-patches.sh`.
- **Vérifié** : build complet `make FORCE=1 gt-be98` exit 0 (2026-05-31), images sous `targets/96813GW/`.

## Après modification d’un patch

```bash
./build.sh clean
```

Voir [../docs/troubleshooting.md](../docs/troubleshooting.md).
