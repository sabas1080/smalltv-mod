#!/usr/bin/env bash
# Provision WiFi on an ESP32-C2 SmallTV without the captive portal, by injecting
# /config.json straight into the LittleFS partition over USB. Handy when the
# device is headless or you want to flash a device fleet.
#
#   ./tools/provision-wifi-c2.sh "MyWiFi" "MyPassword" [/dev/ttyUSB0]
#
# The password is only ever written to a local data/config.json that this script
# deletes right after building the image. Run from the repo root (needs pio +
# esptool on PATH). The config.json schema matches Settings.cpp (root "wifi"[]).
set -euo pipefail

SSID="${1:?Usage: provision-wifi-c2.sh SSID PASSWORD [port]}"
PASS="${2:?Usage: provision-wifi-c2.sh SSID PASSWORD [port]}"
PORT="${3:-/dev/ttyUSB0}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

echo "==> Writing data/config.json for SSID: $SSID"
mkdir -p data
cat > data/config.json <<EOF
{
  "wifi": [
    { "ssid": "$(esc "$SSID")", "pass": "$(esc "$PASS")" }
  ]
}
EOF

echo "==> Building LittleFS image (mklittlefs via pio)..."
pio run -e smalltv_c2 -t buildfs >/dev/null
FS=".pio/build/smalltv_c2/littlefs.bin"
[ -f "$FS" ] || { echo "LittleFS image not produced ($FS)"; rm -f data/config.json; exit 1; }

echo "==> Flashing LittleFS to 0x310000 on $PORT (does NOT touch the firmware)..."
python3 -m esptool --chip esp32c2 --port "$PORT" --baud 921600 \
    --before default_reset --after hard_reset write_flash 0x310000 "$FS"

rm -f data/config.json
echo "Done. The device rebooted and should join '$SSID'. Check the screen for its IP."
