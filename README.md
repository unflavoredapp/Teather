# TetherlessHelper (Debian / Swift 6)

A small, dependency-light helper service for the Tetherless project. It provides iOS device discovery/pairing adapters, public App Store metadata lookup, IPA inspection, safe-path extraction, IPA packaging, diagnostics, and an authenticated JSON API.

## Scope and security boundary

This project does **not** log in to Apple accounts, collect Apple passwords, import Apple session cookies/DSIDs, extract FairPlay keys, decrypt App Store DRM, or claim to verify account ownership. Apple's private FairPlay keys are not exposed through a public server API. The helper deliberately handles public App Store metadata and ordinary IPA container operations only. Any DRM-protected processing must remain within Apple's supported authorization mechanisms.

No third-party Swift packages are used. The Linux device adapter invokes the standard `libimobiledevice` command-line tools; Swift owns the orchestration and API.

## Build on Debian

```bash
sudo apt update
sudo apt install -y usbmuxd libimobiledevice-utils unzip zip coreutils openssl
# Swift 6 is required; install the official Swift toolchain from swift.org if `swift` is not already present.
swift build -c release
.build/release/tetherless-helper doctor
```

If the iPhone is connected to the Debian host by USB, unlock it, accept **Trust This Computer**, then:

```bash
sudo systemctl enable --now usbmuxd
.build/release/tetherless-helper devices
.build/release/tetherless-helper pair YOUR_DEVICE_UDID
```

Pairing may display a trust prompt on the iPhone. `devices` reports no devices when `idevice_id` is unavailable or no device is attached.

## CLI

```bash
.build/release/tetherless-helper help
.build/release/tetherless-helper lookup com.example.app us
.build/release/tetherless-helper inspect /path/to/app.ipa
.build/release/tetherless-helper extract /path/to/app.ipa /tmp/app-work
.build/release/tetherless-helper package /tmp/app-work/Payload/App.app /tmp/repacked.ipa
```

`lookup` uses Apple's public iTunes Lookup endpoint. It returns catalog metadata, not purchase ownership or a private download ticket.

## API service

The API binds to loopback by default. Set a random bearer token of at least 32 characters:

```bash
export TETHERLESS_API_TOKEN="$(openssl rand -hex 32)"
export TETHERLESS_DATA_DIR=/var/lib/tetherless-helper
.build/release/tetherless-helper serve --host 127.0.0.1 --port 8787
```

Copy input IPAs into `TETHERLESS_DATA_DIR` (default `/var/lib/tetherless-helper`) before calling the API. API file operations are confined to that directory. Keep the API on loopback and put it behind Apache with TLS if it must be reached remotely; do not expose the plain HTTP listener directly to the Internet.

### Routes

- `GET /health` — public liveness response.
- `GET /v1/doctor` — dependency checks (Bearer token required).
- `GET /v1/devices` — connected device list.
- `GET /v1/apps/lookup?term=com.example.app&country=us` — public App Store metadata.
- `POST /v1/ipa/inspect` — JSON body: `{"path":"/var/lib/tetherless-helper/app.ipa"}`.
- `POST /v1/ipa/extract` — JSON body: `{"path":"/var/lib/tetherless-helper/app.ipa","destination":"/var/lib/tetherless-helper/work"}`.
- `POST /v1/ipa/package` — JSON body: `{"appDirectory":"/var/lib/tetherless-helper/work/Payload/App.app","output":"/var/lib/tetherless-helper/repacked.ipa"}`.
- `POST /v1/devices/{UDID}/pair` — starts the libimobiledevice pairing command.

All `/v1/*` routes require `Authorization: Bearer $TETHERLESS_API_TOKEN`.

Example:

```bash
curl http://127.0.0.1:8787/health
curl -H "Authorization: Bearer $TETHERLESS_API_TOKEN" \
  'http://127.0.0.1:8787/v1/apps/lookup?term=com.example.app&country=us'
```

## systemd

Copy `deploy/tetherless-helper.service` to `/etc/systemd/system/`, create `/etc/tetherless-helper.env` with the token and data directory, then enable the service. The sample unit runs as a dedicated unprivileged `tetherless` user and binds only to localhost.

## Notes

- Linux USB device access depends on usbmuxd, udev permissions, cable quality, and the iPhone's trust/pairing state.
- A Debian server cannot see an iPhone that is physically connected to a different computer unless a supported transport/tunnel is separately provided.
- IPA inspection reads both XML and binary Info.plist files and computes SHA-256.
- Extraction rejects absolute paths and `..` archive path components. Treat unknown IPA files as untrusted input and run the service unprivileged.
