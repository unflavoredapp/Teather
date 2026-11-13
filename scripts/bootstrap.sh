#!/usr/bin/env bash
#
# bootstrap.sh — prepare the native device layer, then generate the Xcode project.
# Run once on a Mac (and again after changing anything under Native/Device).
#
# Needs: Xcode 16.4 or newer, rustup, python3, git, xcodegen (brew install xcodegen).
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TOOLCHAIN="$(python3 -c 'import json;print(json.load(open("Native/Device/source.json"))["rust_toolchain"])')"

command -v rustup >/dev/null || { echo "rustup not found. Install it from https://rustup.rs"; exit 1; }
command -v xcodegen >/dev/null || { echo "xcodegen not found. Run: brew install xcodegen"; exit 1; }

echo "==> Rust toolchain $TOOLCHAIN"
rustup toolchain install "$TOOLCHAIN" --profile minimal

echo "==> Fetching pinned IDeviceKit"
python3 .github/scripts/fetch_devicekit.py

echo "==> Applying device overlays"
python3 .github/scripts/integrate_devicekit.py

echo "==> Building IDevice.xcframework (slow the first time)"
python3 .github/scripts/build_device_native.py

echo "==> Generating Xcode project"
xcodegen generate

echo
echo "Done. Open Sideloader.xcodeproj, set your team on all three targets, and run."
