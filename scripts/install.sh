#!/usr/bin/env bash
# Builds Expenses, adds the App Intents metadata and installs it on the device connected via USB.
# Use this instead of `xtool dev`, which skips the metadata step (see scripts/appintents.sh).
#
# Usage:  scripts/install.sh               # build + metadata + install
#         scripts/install.sh --no-install  # build + metadata only
#
# With a free Apple account the app expires after 7 days: run this again to reinstall (data is kept).

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install=1
case "${1:-}" in
    --no-install) install=0 ;;
    "") ;;
    *) echo "Usage: $0 [--no-install]" >&2; exit 2 ;;
esac

command -v xtool >/dev/null || { echo "xtool not found in PATH: https://github.com/xtool-org/xtool" >&2; exit 1; }

# WSL can't see USB devices directly: reach the Windows Apple Mobile Device service through
# the WSL gateway (requires a portproxy on Windows for port 27015).
if [ -z "${USBMUXD_SOCKET_ADDRESS:-}" ] && grep -qi microsoft /proc/version 2>/dev/null; then
    export USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015"
fi

product="$(awk '/^product:/ {print $2}' "$dir/xtool.yml")"

# Check the device first, so a missing device doesn't fail only after the build.
if [ "$install" = 1 ] && command -v ideviceinfo >/dev/null; then
    device="$(timeout 10 ideviceinfo -k DeviceName 2>/dev/null || true)"
    [ -n "$device" ] || { echo "No device found: connect it via USB, unlock it and trust this computer." >&2; exit 1; }
    echo "Device: $device"
fi

cd "$dir"
# The "ld64.lld: warning: ... platform iOS" lines are harmless: hide them.
set +e
xtool dev build 2>&1 | grep --line-buffered -v "ld64.lld: warning"
status="${PIPESTATUS[0]}"
set -e
[ "$status" -eq 0 ] || { echo "❌ Build failed" >&2; exit "$status"; }

"$dir/scripts/appintents.sh"

if [ "$install" = 1 ]; then
    xtool install --usb "$dir/xtool/$product.app"
    echo "✅ $product installed"
fi
