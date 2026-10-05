# Lien d'administration USB Ethernet

Le routeur est administré via un adaptateur USB Ethernet (ASIX AX88179A, pilote
`ax88179_178a`, MAC `f8:e4:3b:26:c6:1b`) plutôt que via son Ethernet intégré.
On peut ainsi décharger, recharger ou planter le pilote Ethernet intégré pendant
qu'on travaille dessus, sans perdre l'accès au routeur.

| lien | adresse | rôle |
|---|---|---|
| adaptateur USB | `10.0.0.18` (DHCP) | route par défaut dès qu'il est branché et actif |
| `br0` intégré | `10.0.0.95` | secours |

## Fichiers

| dépôt | sur le routeur | rôle |
|---|---|---|
| `usbnet.sh` | `/data/usbnet/usbnet.sh` | superviseur : `start`, `stop`, `status` |
| `udhcpc.hook` | `/data/usbnet/udhcpc.hook` | pose l'adresse, enregistre le bail |
| `init-start` | `/jffs/scripts/init-start` | lance `usbnet.sh start` au démarrage |

`/data` est commun à tous les slots d'image. L'état d'exécution et le journal
sont dans `/tmp/usbnet/`.

## Fonctionnement

Toutes les 5 secondes, le superviseur vérifie l'adaptateur :

- branché, lien actif, bail DHCP → routage via USB
- sinon → il retire ses règles et le routage d'origine (`br0`) reprend la main

Il n'ajoute que des règles de routage (`ip rule`) et sa propre table (177). La
table `main` reste telle que le firmware l'a configurée.

| priorité | règle | rôle |
|---|---|---|
| 17 | `from <adresse br0> lookup main` | les réponses depuis `br0` restent sur `br0` |
| 18 | `from <adresse USB> lookup 177` | les réponses depuis l'USB restent sur l'USB |
| 19 | `to <LAN> lookup 177` | le trafic LAN passe par l'USB |
| 20 | `lookup 8437` | règle d'origine (LAN via `br0`), laissée telle quelle |
| 95 | `lookup main suppress_prefixlength 0` | les autres routes spécifiques restent valables (sous-réseaux WiFi de test) |
| 96 | `lookup 177` | route par défaut via l'USB |

Le superviseur règle aussi `arp_ignore=1` et `arp_announce=2` : les deux
interfaces sont sur le même LAN, et chacune ne doit répondre en ARP que pour sa
propre adresse.

## Utilisation

```sh
ssh -p 2222 admin@10.0.0.18 /data/usbnet/usbnet.sh status
ssh -p 2222 admin@10.0.0.18 cat /tmp/usbnet/log
```

Déployer via `br0`, car le lien USB tombe pendant le redémarrage du
superviseur :

```sh
B="ssh -p 2222 admin@10.0.0.95"
$B 'mkdir -p /data/usbnet && cat > /data/usbnet/usbnet.sh.new' < device/usbnet/usbnet.sh
$B 'cat > /data/usbnet/udhcpc.hook'    < device/usbnet/udhcpc.hook
$B 'cat > /jffs/scripts/init-start'    < device/usbnet/init-start
$B 'cd /data/usbnet && ./usbnet.sh stop; mv usbnet.sh.new usbnet.sh; chmod +x * /jffs/scripts/init-start; ./usbnet.sh start'
```

## Testé (2026-10-05)

- Redémarrage (sysrq) : revient en routage USB sans intervention. Route par
  défaut et LAN passent par `eth4`.
- Débranchement (unbind du pilote USB) : `br0` reprend la main en moins de 2 s.
- Rebranchement (bind) : retour sur l'USB en 10 s environ.
- Une session SSH sur `10.0.0.95` survit à tout ce qui précède.
- Les sous-réseaux WiFi de test (`bcawl3`, `br20`, `br70`) ne sont pas affectés.

Pas encore testé : débranchement physique du câble (retour sur `br0` attendu
en 5 s au plus), le slot de banc `ubi.block=0,4`, et l'arrêt de `br0`.

Réserver `10.0.0.18` pour la MAC de l'adaptateur sur le routeur DHCP, pour que
l'adresse reste fixe.
