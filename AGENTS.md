# AGENTS.md: gt-be98-firmware

Operating notes for agents. Keep it short and current; it is not a log.
The human documentation (`README.md`, `docs/`) is in French.

## What this repo is

The Asuswrt-Merlin (Linux **4.19** vendor SDK) build of the GT-BE98 stock-like
firmware: build scripts, `tools/`, and the patch series in `patches/`
(`patches/README.md` lists them). The Merlin source and the Broadcom
cross-toolchains are **not** in git:

| ignored dir | filled by | pinned in |
|---|---|---|
| `vendor/asuswrt-merlin.ng` | `tools/setup.sh` (clone, prune, apply `patches/`) | `UPSTREAM` |
| `toolchain/` | `tools/fetch-toolchain.sh` | `toolchain/TOOLCHAIN_PIN` (written at bootstrap) |

`./build.sh` produces
`vendor/asuswrt-merlin.ng/release/src-rt-5.04behnd.4916/targets/96813GW/GT-BE98_*.pkgtb`.

## Status: dormant, but a build input

Product images now come from **gt-be98-buildroot** (the mainline 7.2.9 OS).
This repo is no longer developed for the product, but the build host's
checkout `~/be98/gt-be98-firmware` (its `vendor/` and `toolchain/`, about
16 GB) is read by other builds:

- **gt-be98-open-wifi** `driver/Makefile`: the defaults of `SDK` and `TC`
  point into this checkout (the 4.19 vendor-kernel build of the driver,
  which must keep building);
- **gt-be98-buildroot** legacy packages `gt-be98-{hostapd,libshared,rc}`:
  `../gt-be98-firmware` relative to the buildroot checkout;
- **gt-be98-kernel** scripts: `FW` defaults to `~/be98/gt-be98-firmware`;
- the vendor SDK tree (`release/src-rt-5.04behnd.4916`) is also the
  reference used when reverse-engineering the stock drivers.

Therefore, on the build host:

- **never move, rename or delete** the checkout, `vendor/` or `toolchain/`;
- never run `tools/clean-vendor.sh` (deletes and re-clones `vendor/`) or
  `tools/prune-vendor.sh` there;
- `./build.sh` rebuilds inside `vendor/`, which the builds above read: run
  it only when that is intended, never while another build uses the tree.

## Branches

- `main` is the GitHub default. `fix-build-clean-clone` carries the newer
  patches on top of it and is the branch the build host's checkout is on.
  `open-enet-boot` / `open-enet-wfd` hold stock-firmware boot hooks used
  for the open Ethernet trials; `usbnet-mgmt-2026-10-05` holds the USB
  management-link notes. None of them is merged into `main`.
- New work goes on a `<topic>-<YYYY-MM-DD>` branch. Never force-push, never
  push to `main`, never `git add -A`.
- `docs/device` is a submodule (gt-be98-docs).

## Rules

- **Never build on the dev machine**; builds run on the build host through
  `rtk`.
- **Public repository.** No IP addresses, MACs, user names, host names,
  passphrases, keys, e-mail addresses, firmware images or vendor binaries in
  files or commit messages. Patches made with `git format-patch` carry a
  `From:` header: replace the author address with a placeholder before
  committing them.
- `rtk` filters output silently: use `python3` or `rtk proxy` when exact
  content or a count matters.
