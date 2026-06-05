#!/usr/bin/env bash
#
# Populate Chirpset/tools/ with the redistributable flashing CLIs so they get
# bundled into Contents/Resources/tools/ (the file-system-synchronized group
# auto-includes anything under Chirpset/). ToolLocator prefers these over any
# system install.
#
# Licensing (verify & attribute before shipping):
#   esptool   — GPLv2          (Espressif)
#   avrdude   — GPLv2          (avrdude project)
#   bossac    — BSD-3-Clause   (Arduino / Scott Shawcroft)
#   dfu-util  — GPLv2          (dfu-util project)
#   teensy_loader_cli — GPLv3  (PJRC)
# These are invoked as separate executables (subprocess), i.e. mere aggregation —
# but still confirm redistribution terms and include attributions in the app.
#
# This script fetches the official macOS universal esptool standalone build from
# GitHub releases as the worked example; add the others the same way. It is NOT
# run automatically by the build — run it intentionally.
#
# Usage:  ESPTOOL_VERSION=v4.8.1 Scripts/fetch-tools.sh

set -euo pipefail
cd "$(dirname "$0")/.."   # repo root
DEST="Chirpset/tools"
mkdir -p "$DEST"

ESPTOOL_VERSION="${ESPTOOL_VERSION:-v4.8.1}"
ARCH="$(uname -m)"   # arm64 | x86_64
case "$ARCH" in
  arm64)  ESP_ASSET="esptool-${ESPTOOL_VERSION}-macos-arm64.zip" ;;
  x86_64) ESP_ASSET="esptool-${ESPTOOL_VERSION}-macos-amd64.zip" ;;
  *) echo "Unknown arch $ARCH"; exit 1 ;;
esac

echo "==> Fetching esptool $ESPTOOL_VERSION ($ARCH)"
URL="https://github.com/espressif/esptool/releases/download/${ESPTOOL_VERSION}/${ESP_ASSET}"
TMP="$(mktemp -d)"
curl -fL "$URL" -o "$TMP/esptool.zip"
unzip -o "$TMP/esptool.zip" -d "$TMP/esptool"
# The archive contains an 'esptool' executable (possibly in a subdir).
BIN="$(find "$TMP/esptool" -name esptool -type f -perm +111 | head -1)"
if [[ -z "$BIN" ]]; then echo "esptool binary not found in archive"; exit 1; fi
cp "$BIN" "$DEST/esptool"
chmod +x "$DEST/esptool"
rm -rf "$TMP"

echo "==> Done. Bundled tools in $DEST:"
ls -la "$DEST"
echo
echo "Next: add avrdude / bossac / dfu-util / teensy_loader_cli the same way,"
echo "then rebuild — ToolLocator will report them as 'Bundled' in Settings → Tools."
