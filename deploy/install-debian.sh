#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v swift >/dev/null || { echo "Swift 6 toolchain is required" >&2; exit 1; }
sudo apt-get update
sudo apt-get install -y usbmuxd libimobiledevice-utils unzip zip coreutils openssl
swift build -c release
sudo useradd --system --home /var/lib/tetherless-helper --create-home --shell /usr/sbin/nologin tetherless 2>/dev/null || true
sudo install -d -o tetherless -g tetherless -m 0750 /var/lib/tetherless-helper
if getent group plugdev >/dev/null; then sudo usermod -aG plugdev tetherless; fi
sudo install -d -o root -g root -m 0755 /opt/tetherless-helper
sudo install -m 0755 .build/release/tetherless-helper /opt/tetherless-helper/tetherless-helper
sudo install -m 0644 deploy/tetherless-helper.service /etc/systemd/system/tetherless-helper.service
if [ ! -f /etc/tetherless-helper.env ]; then
  TOKEN="$(openssl rand -hex 32)"
  printf 'TETHERLESS_API_TOKEN=%s\nTETHERLESS_DATA_DIR=/var/lib/tetherless-helper\n' "$TOKEN" | sudo tee /etc/tetherless-helper.env >/dev/null
  sudo chmod 0600 /etc/tetherless-helper.env
  echo "Generated API token in /etc/tetherless-helper.env. Retrieve it securely before configuring your client."
fi
sudo systemctl daemon-reload
sudo systemctl enable --now tetherless-helper
sudo systemctl --no-pager --full status tetherless-helper
