# Tetherless (UI clone) — Xcode project name: Sideloader

A SwiftUI iOS app for importing and installing your own `.ipa` files, with tabs **Pair**, **Files**, **Library**, **Decrypt** and **Settings**, in the glass-on-gradient look of your screenshots.

The device connection (local VPN tunnel, on-device pairing, install) is real and adapted from the AirShare device layer you supplied. IPA signing and Apple ID login are still stubs. The Decrypt tab is a mockup. This project does **not** include App Store downloading or FairPlay decryption.

## Build

Requires a Mac with Xcode 16.4+, [rustup](https://rustup.rs), python3 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
./scripts/bootstrap.sh     # fetch pinned IDeviceKit, apply overlays, build IDevice.xcframework, run xcodegen
open Sideloader.xcodeproj
```

The first bootstrap compiles Rust for device and simulator, so it is slow. Then set your team on all three targets (Sideloader, TetherlessTunnel, SideloaderHelper) and run Sideloader, then SideloaderHelper.

No Mac? `.github/workflows/build.yml` builds unsigned IPAs on a GitHub macOS runner (`scripts/package-ipa.sh`); sign them with your own certificate afterwards.

## Requirements for the device connection

- **Built-in mode** starts the `TetherlessTunnel` packet-tunnel extension. The app and the extension must both be signed with a profile that authorizes the Network Extension entitlement `packet-tunnel-provider` (paid developer account, or a custom certificate whose profile includes it). A free Apple ID cannot get this entitlement.
- **On-device pairing** needs iOS 27 or later, Developer Mode, Local Network permission, and a one-time code entered under Settings → Privacy & Security → Developer Mode.
- **Manual mode** works on earlier iOS: import a pairing file on the Pair tab and run your own local VPN.
- Apps must be **signed** with a certificate this device trusts before install. Signing is not implemented yet (see below); use **Install as-is** in the Library for IPAs that are already signed.

## What works now

- **Pair:** Built-in or Manual connection, Start Pairing with the code prompt, Test Connection, import/remove a pairing file, forget on-device pairing.
- **Library:** import `.ipa` files (reads name, ID, version), **Install as-is** over the device connection, delete, share.
- **Files:** browse the app's Documents folder, import, share, delete, add an `.ipa` to the Library.
- **Settings:** Apple ID card and two-factor prompt flow (UI only), signing-method picker, custom certificate import (`.p12` validated, password in Keychain, `.mobileprovision` name and expiry parsed).

## Still to plug in (`Services.swift`)

| Protocol | State | Needs |
|---|---|---|
| `DeviceInstaller` | **Real** (`NativeDeviceInstaller`) | |
| `IPASigner` | Stub | Re-sign Mach-O binaries with a cert + profile (zsign or similar) |
| `AppleAccountService` | Stub | Apple developer-services login, 2FA, free-account cert / App ID / profile (AltSign or similar) |

Check each library's license before bundling it. Some are AGPL.

## Decrypt tab and helper app (mockups only)

`DecryptMockView.swift` and `SideloaderHelper/` reproduce the Decrypt tab, Decrypt Settings, and the "Tetherless Decrypt" helper app screens with invented apps and fake data. Nothing in them signs in, connects to a server, downloads or decrypts anything; buttons only advance local animation state. After a simulated download, **Done** opens `sideloaderhelper://…` and the helper has a **Back to Tetherless** button (`sideloader://`).

## Not included

- Store login, app purchase/download, and decryption logic.
- Payments, staff/licensing gates and the disassembler from the supplied code.
- The "Store Access" and "Software Update" cards from the original Settings tab.
- Restoring your own VPN after a built-in session (AirShare's Shortcuts handoff), batch/queued installs, and the installed-apps manager.

## Attribution

See `NOTICE.md` and `LICENSE` (Apache-2.0).

## Status

Written without Xcode or a device, so **none of it has been compiled or run**. Expect a few fixes on first build, especially around the IDeviceKit overlays and the package product names (`IDeviceSwift`, `IDevice`). The device layer needs testing on a real iPhone.
