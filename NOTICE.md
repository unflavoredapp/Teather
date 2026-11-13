# Third-party code and attribution

The on-device connection layer in this project was adapted from code you supplied
(the AirShare / "Decrypt.Team" project), which is licensed under the Apache License 2.0
(see `LICENSE`). Files derived from it were renamed for Tetherless and reduced in scope.

Derived files:

- `Sideloader/Device/DevicePairingStore.swift`, `DevicePairingService.swift`, `LocalDeviceVPN.swift`
- `TetherlessTunnel/PacketTunnelProvider.swift`, `LocalPacketReflection.swift`
- `Native/Device/*` (installation proxy overlay, RSD connection, install worker, Rust pairing bridge, pins)
- `.github/scripts/fetch_devicekit.py`, `integrate_devicekit.py`, `build_device_native.py`

Upstream projects those files build on, fetched at pinned revisions at build time:

- **idevice** by jkcoxson, built into `IDevice.xcframework` (revision pinned in `Native/Device/source.json`)
- **IDeviceKit** by khcrysalis (revision pinned in `.github/scripts/fetch_devicekit.py`)
- The Rust pairing bridge header credits Ksign.

Not taken from that code: anything related to App Store downloading, FairPlay decryption,
payments, staff or licensing gates, or the disassembler. The Decrypt tab in this project
is a mockup and is not connected to any of it.

Check each upstream project's own license before distributing a build.
