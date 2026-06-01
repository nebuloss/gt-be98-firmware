# Deploy and test custom GT-BE98 firmware

Guide for flashing **self-built** firmware from this repo, validating it on hardware, **restoring stock Asus firmware**, and recovering from a bad flash.

This tree builds **Broadcom `.pkgtb`** images (HND / SDK `5.04behnd`), not legacy **`.trx`**. The Web GUI accepts `.pkgtb` on Wi‑Fi 7 platforms such as GT-BE98 (same as official Asus and [gnuton Merlin](https://github.com/gnuton/asuswrt-merlin.ng) releases).

**Official Asus references (verified June 2026):**

| Topic | Link |
|--------|------|
| Manual firmware update (Web GUI) | [FAQ 1008000](https://www.asus.com/support/faq/1008000/) |
| Rescue mode + Firmware Restoration | [FAQ 1000814](https://www.asus.com/support/faq/1000814/) (also [ROG](https://rog.asus.com/us/support/faq/1000814/)) |
| Abnormal power LED → rescue | [FAQ 1030642](https://www.asus.com/us/support/faq/1030642/) |
| GT-BE98 stock firmware downloads | [Asus support – BIOS & Firmware](https://www.asus.com/supportonly/gt-be98/helpdesk_bios/) · [ROG download](https://rog.asus.com/networking/rog-rapture-gt-be98-model/helpdesk_bios/) |

---

## Risks (read first)

- Wrong image or interrupted flash can leave the router **unreachable** (no web UI, no Wi‑Fi).
- A standard **update** `.pkgtb` does **not** reflash the entire NAND bootstrap/CFE; it replaces the **firmware bundle** (kernel + rootfs, etc.). See [architecture/03-firmware-formats.md](architecture/03-firmware-formats.md).
- **Custom builds are unsupported** by Asus. Keep **stock firmware**, a **working PC with Ethernet**, and rescue steps ready before testing.
- On some **hardware/software combinations**, very new **stock** Asus builds refuse **downgrades** or third-party images via the Web GUI; you may need **Firmware Restoration** with an **older stock** file first ([gnuton issue #697](https://github.com/gnuton/asuswrt-merlin.ng/issues/697)).

---

## Before you flash

### On the build host

1. Successful build:

   ```bash
   ./build.sh
   ```

2. Confirm artifacts (also run automatically at end of `build.sh`):

   ```bash
   ./tools/verify-artifact.sh
   ls -lh vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*.pkgtb
   ```

3. Archive what you will flash (checksum for later):

   ```bash
   PKGTB=$(ls -1 vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*_nand_squashfs.pkgtb | grep -v loader | head -1)
   sha256sum "$PKGTB" | tee flash-$(date +%Y%m%d).sha256
   cp -a "$PKGTB" ~/firmware-backups/
   ```

4. Keep `logs/build_*.log` from that build.

### Which file to upload

| File pattern | Use when |
|--------------|----------|
| `GT-BE98_*_nand_squashfs.pkgtb` | **Normal firmware update** (use this first) |
| `GT-BE98_*_nand_squashfs_loader.pkgtb` | Larger bundle with **loader** — only if docs/recovery require it; not for routine tests |
| `bcm96813GW_*` (no `GT-BE98` prefix) | **Do not use** — other profile/capacity |

Do **not** upload `rootfs.img` or `.itb` alone through the Web GUI; upload the **`.pkgtb`** produced for GT-BE98.

### On the router (stock baseline)

1. Download and save **current stock** firmware ZIP from [Asus GT-BE98 support](https://www.asus.com/supportonly/gt-be98/helpdesk_bios/) (unzip; keep the `.pkgtb` inside).
2. Note **hardware version** (label / box, e.g. HW v2) and **current firmware version** (Web GUI → Administration).
3. Download **ASUS Firmware Restoration** for Windows from the same support page (**Driver & Utility** → **ASUS Firmware Restoration**). See [FAQ 1000814](https://www.asus.com/support/faq/1000814/).
4. Use a **wired** Ethernet link from PC to a **LAN** port for flashing and recovery (not Wi‑Fi-only).
5. Optional but recommended: export settings (Administration → Restore/Save/Upload Setting) if you may want to restore configuration later.

---

## Deploy custom firmware (normal path)

### 1. Web GUI manual update

Matches Asus [FAQ 1008000 – Method 3](https://www.asus.com/support/faq/1008000/):

1. Connect PC to router **LAN**.
2. Open `http://www.asusrouter.com` or `http://192.168.50.1` / `http://192.168.1.1` (depends on your LAN setup).
3. Sign in (admin account).
4. Go to **Administration** → **Firmware Upgrade** (or **Advanced Settings** → **Administration** → **Firmware Upgrade**).
5. Click **Upload**, select your built file:

   `vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*_nand_squashfs.pkgtb`

6. Confirm and **wait until the router reboots** (several minutes). **Do not power off** during the update.
7. After reboot, sign in again and check **firmware version** (should reflect your Merlin/build string if shown).

If the UI reports **upgrade unsuccessful** on very new stock, see [Downgrade / Merlin path](#downgrade--merlin-path) below.

### 2. Factory reset after major firmware change

Asus **recommends** a factory reset after firmware updates ([FAQ 1008000](https://www.asus.com/support/faq/1008000/)):

- **GUI:** Administration → Restore/Save/Upload Setting → **Factory default** → Restore, **or**
- **Button:** with router powered on, press and hold **Reset** ~5–10 s until LEDs indicate reset/reboot (see user manual for your revision).

Then run **QIS** (quick setup) again if needed.

### 3. Functional test checklist

After the router is back online:

| Check | Pass criteria |
|--------|----------------|
| Web UI | Login, dashboard loads |
| LAN | Wired clients get IP and Internet (if WAN was configured) |
| WAN | Internet works on primary WAN |
| Wi‑Fi | SSIDs visible; client can associate (may take a few minutes after first boot) |
| Logs | Administration → System Log (if available); no continuous reboot loop |
| SSH | If enabled in your build: `ssh admin@<router-ip>` then `dmesg \| tail` |

Allow **5–15 minutes** after first boot; Wi‑Fi can lag while services start ([community reports](https://www.snbforums.com/threads/asus-gt-be98-firmware-version-3-0-0-6-102_34372-2024-04-23.89772/) after Asus updates).

### 4. If the custom build misbehaves (but UI still works)

1. Note symptoms and firmware file + `sha256sum`.
2. **Factory reset** (above).
3. Re-flash **stock** `.pkgtb` via Web GUI (next section).
4. If still broken → [Rescue mode](#rescue-mode-firmware-restoration).

---

## Restore stock Asus firmware

### Via Web GUI (router still reachable)

1. Download latest **GT-BE98** firmware ZIP from [Asus support](https://www.asus.com/supportonly/gt-be98/helpdesk_bios/).
2. Unzip; use the **`.pkgtb`** inside (name like `GT-BE98_3.0.0.6.102_xxxxx_nand_squashfs.pkgtb`).
3. Administration → **Firmware Upgrade** → **Upload** → select stock `.pkgtb`.
4. Wait for reboot; verify version in GUI.
5. **Factory reset** recommended after returning to stock.

### Via Rescue mode (GUI unreachable or Web update fails)

Use the same `.pkgtb` stock file in **Firmware Restoration** — see next section.

---

## Rescue mode (Firmware Restoration)

Official procedure: [FAQ 1000814](https://www.asus.com/support/faq/1000814/) · [FAQ 1030642](https://www.asus.com/us/support/faq/1030642/) (abnormal power LED).

**Requirements:** Windows PC, Ethernet cable, **Firmware Restoration** utility installed, firmware file **already unzipped** (`.pkgtb`).

### Enter rescue mode

1. Unplug router power.
2. Press and **hold Reset**.
3. Plug power back in **while still holding Reset**.
4. Keep holding until the **power LED blinks slowly** (rescue mode). Then release.
5. If unsure, repeat; do **not** release Reset too early.

### PC network settings

On the Ethernet adapter used for the router ([FAQ 1000814](https://www.asus.com/support/faq/1000814/)):

| Setting | Value |
|---------|--------|
| IPv4 address | `192.168.1.10` |
| Subnet mask | `255.255.255.0` |
| Gateway / DNS | leave empty or unused |

### Upload firmware

1. Start **ASUS Firmware Restoration** (Start → ASUS Utility → Firmware Restoration).
2. **Browse** → select **stock** or **custom** `.pkgtb` (unzipped path).
3. Click **Upload**; wait ~1–3 minutes.
4. **Steady power LED** = upload finished; router reboots.
5. Restore PC to **Obtain IP address automatically** (DHCP).
6. Open `http://www.asusrouter.com` or `http://192.168.1.1` / your LAN IP.

### “Router is not in rescue mode”

From Asus FAQ:

- Confirm PC is `192.168.1.10` / `255.255.255.0`.
- Repeat power-off → hold Reset → power on → **slow blink** before upload.
- Try another Ethernet port / cable.

---

## Downgrade / Merlin path

Reported for **GT-BE98** (especially newer stock, HW v2): Web GUI may **reject** downgrades or first install of third-party `.pkgtb`.

Workaround used by community ([gnuton #697](https://github.com/gnuton/asuswrt-merlin.ng/issues/697)):

1. Obtain an **older stock** GT-BE98 `.pkgtb` (from Asus archives or support; exact version varies by HW revision).
2. Flash **older stock** via **Firmware Restoration** (rescue mode), not Web GUI.
3. After boot, flash target firmware (e.g. gnuton Merlin or **your** `GT-BE98_*_nand_squashfs.pkgtb`) via Web GUI **or** restoration again if GUI is unreachable.
4. Some users flashed **twice in rescue** (old stock, then new) if the GUI was not reachable after the first reboot.

Plan extra time and keep **stock** files before experimenting with **custom** builds.

---

## Brick? Recovery ladder

Use the **lowest** step that fixes the symptom.

```text
Level 0 — Soft failure (UI works, odd behavior)
  → Factory reset → re-flash stock or known-good .pkgtb via Web GUI

Level 1 — UI dead, power LED slow-blink achievable
  → Rescue mode + Firmware Restoration + stock .pkgtb
  → Then custom or stock via GUI if desired

Level 2 — Web update always fails; rescue works
  → Older stock via restoration → then desired firmware
  → See Downgrade / Merlin path

Level 3 — No slow-blink rescue; LED dead / boot loop / no link
  → Repeat rescue timing (Reset + power, hold longer)
  → Try stock .pkgtb only (smaller risk than custom)
  → Serial console (if hardware available) to see U-Boot/kernel panic
  → Asus support / RMA if no boot ROM activity at all

Level 4 — `_loader.pkgtb` (advanced)
  → Only if you know you need loader recovery; use
    GT-BE98_*_nand_squashfs_loader.pkgtb from the same build
  → Wrong loader flash can worsen brick — avoid unless documented need
```

**“Brick” does not always mean dead hardware:** many cases are **bad firmware** still recoverable with **rescue + stock**.

---

## Serial console (optional, for debug)

Software on GT-BE98 (BCM6813 SDK) is configured for serial debug:

- **115200** baud, **8N1**
- Linux: `console=ttyAMA0,115200` (device tree `stdout-path = "serial0:115200n8"`)
- Early shell may use Broadcom **`consoled`** (`BUILD_CONSOLED=y` in profile)

**Hardware:** Asus does **not** expose a user-facing UART port on the case. Debug UART is typically an **unpopulated 3.3 V TTL** header on the PCB (TX/RX/GND). Opening the device may void warranty; use a **3.3 V** USB‑TTL adapter (not 5 V).

**When serial helps:**

- Boot stops in **U-Boot** or **kernel panic**
- Rescue works but OS crashes immediately
- Custom image suspected corrupt before flash

**Capture on Linux PC:**

```bash
screen /dev/ttyUSB0 115200
# or: minicom -D /dev/ttyUSB0 -b 115200
```

Save a log while reproducing the failure; compare with last successful boot.

---

## Host-side debug (no router)

If hardware is fine but you suspect a **bad build**:

```bash
./tools/verify-artifact.sh
grep -m1 'error:' logs/build_*.log   # first compile error, not last line
```

Compare `sha256sum` of your `.pkgtb` with the file you actually uploaded.

---

## Quick reference

| Goal | Action |
|------|--------|
| Flash custom build | Web GUI → Upload `GT-BE98_*_nand_squashfs.pkgtb` |
| Validate build on PC | `./tools/verify-artifact.sh` |
| Restore stock | Download Asus `.pkgtb` → Web GUI or Rescue |
| UI dead / bad flash | Rescue mode + Firmware Restoration + stock `.pkgtb` |
| GUI blocks downgrade | Older stock via restoration, then target firmware |
| Deep boot debug | 3.3 V serial @ 115200 on `ttyAMA0` (PCB header) |

---

## Related docs

- [flashing.md](flashing.md) — artifact paths and `.pkgtb` format summary  
- [build-guide.md](build-guide.md) — build logs and clean rebuild  
- [architecture/03-firmware-formats.md](architecture/03-firmware-formats.md) — what is inside `.pkgtb`  
- [architecture/05-runtime-os.md](architecture/05-runtime-os.md) — boot chain after flash  
