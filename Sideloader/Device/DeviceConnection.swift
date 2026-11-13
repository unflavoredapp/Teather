import Foundation
import IDeviceSwift

// Adapted from the AirShare/Ksign device-connection flow (Apache-2.0), reduced to what
// Tetherless needs: bring up the local tunnel, load or create a pairing, open the
// device connection, run one operation, then tear everything down again.

enum DeviceConnectionMode: String, CaseIterable, Identifiable {
    /// Start Tetherless's own packet-tunnel extension and pair on this device.
    case builtIn = "Built-in"
    /// Use an imported pairing file and a local VPN you run yourself.
    case manual = "Manual"
    var id: String { rawValue }
}

@MainActor
final class DeviceConnection: ObservableObject {
    static let shared = DeviceConnection()

    enum Phase: Equatable {
        case idle
        case connecting
        case pairing
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var notice: String?
    @Published private(set) var isBusy = false

    private static let modeKey = "Tetherless.connectionMode"
    private let vpn = LocalDeviceVPN()

    var mode: DeviceConnectionMode {
        get { DeviceConnectionMode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .builtIn }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.modeKey); objectWillChange.send() }
    }

    var hasSavedPairing: Bool { ((try? DevicePairingStore.load()) ?? nil) != nil }
    var hasImportedPairing: Bool { FileManager.default.fileExists(atPath: PairingStore.importedFileURL.path) }

    static var canPairOnDevice: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    // MARK: Running an operation

    /// Connects, runs `body` against the device, then disconnects. One operation at a time.
    func withDevice<T>(_ body: @MainActor () async throws -> T) async throws -> T {
        guard !isBusy else { throw DeviceSetupError("Another device operation is already running.") }
        isBusy = true
        notice = nil
        do {
            try await prepare()
            let result = try await body()
            await cleanUp()
            isBusy = false
            return result
        } catch {
            await cleanUp()
            isBusy = false
            throw error
        }
    }

    func cancel() { DevicePairingService.shared.cancel() }

    /// Forget the saved on-device pairing (an imported pairing file is left alone).
    func resetPairing() throws {
        guard !isBusy else { throw DeviceSetupError("Wait for the current device operation to finish.") }
        try DevicePairingStore.reset()
        phase = .idle
        notice = nil
    }

    // MARK: Preparation

    private func prepare() async throws {
        phase = .connecting
        do {
            await HeartbeatManager.shared.resetInstallationConnection()
            try Task.checkCancellation()
            switch mode {
            case .builtIn: try await prepareBuiltIn()
            case .manual: try await prepareManual()
            }
            phase = .ready
        } catch {
            let failure: Error = error is CancellationError
                ? DeviceSetupError("Device setup was cancelled. Try again when you're ready.")
                : error
            phase = .failed(failure.localizedDescription)
            throw failure
        }
    }

    private func prepareManual() async throws {
        vpn.disconnectIfOwned()
        guard hasImportedPairing else {
            throw DeviceSetupError("Import a pairing file on the Pair tab and turn on your local VPN, or switch to Built-in.")
        }
        HeartbeatManager.configurePairingPath(PairingStore.importedFileURL.path)
        try await HeartbeatManager.shared.prepareInstallationConnection()
    }

    private func prepareBuiltIn() async throws {
        // Validate VPN provisioning before asking for pairing consent.
        try await vpn.connect()
        try Task.checkCancellation()

        var record = try DevicePairingStore.load()
        let reusedPairing = record != nil
        if record == nil { record = try await createPairing() }
        try configurePairing(record)

        phase = .connecting
        do {
            try await HeartbeatManager.shared.prepareInstallationConnection()
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            // Retry the handshake once after restarting the tunnel.
            notice = "Restarting the local VPN to recover the device connection…"
            await HeartbeatManager.shared.resetInstallationConnection()
            try Task.checkCancellation()
            try await vpn.connect(restarting: true)
            try Task.checkCancellation()
            do {
                try await HeartbeatManager.shared.prepareInstallationConnection()
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                guard reusedPairing, Self.canPairOnDevice else {
                    throw DeviceSetupError("The saved pairing couldn't connect after restarting the local VPN. Import a fresh pairing file and use Manual mode.\n\n\(error.localizedDescription)")
                }
                notice = "The saved pairing couldn't reconnect. Pairing again…"
                await HeartbeatManager.shared.resetInstallationConnection()
                // Keep the old credentials until the replacement succeeds.
                record = try await createPairing()
                try configurePairing(record)
                phase = .connecting
                try await HeartbeatManager.shared.prepareInstallationConnection()
            }
        }
    }

    private func createPairing() async throws -> DevicePairingRecord {
        try Task.checkCancellation()
        phase = .pairing
        let record = try await DevicePairingService.shared.pair()
        try Task.checkCancellation()
        try DevicePairingStore.save(record)
        return record
    }

    private func configurePairing(_ record: DevicePairingRecord?) throws {
        if let record {
            HeartbeatManager.configurePairingPath(try DevicePairingStore.materialize(record).path)
        } else {
            HeartbeatManager.configurePairingPath(nil)
        }
    }

    private func cleanUp() async {
        await HeartbeatManager.shared.resetInstallationConnection()
        HeartbeatManager.configurePairingPath(nil)
        DevicePairingStore.removeWorkingCopy()
        _ = await vpn.finishSession()
        if case .ready = phase { phase = .idle }
    }
}
