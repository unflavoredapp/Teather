import SwiftUI
import UniformTypeIdentifiers

struct PairView: View {
    let services: Services
    @EnvironmentObject private var pairing: PairingStore
    @ObservedObject private var connection = DeviceConnection.shared
    @ObservedObject private var pairingService = DevicePairingService.shared

    @State private var importing = false
    @State private var resultMessage: String?
    @State private var resultFailed = false
    @State private var showDiagnosticsHint = false

    private var mode: DeviceConnectionMode { connection.mode }
    private var isPaired: Bool {
        mode == .builtIn ? connection.hasSavedPairing : (pairing.isPaired || connection.hasImportedPairing)
    }

    var body: some View {
        ScreenScroll(title: "Tetherless") {
            VStack(spacing: 10) {
                Image(systemName: "iphone")
                    .font(.system(size: 76, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                Text("No computer. Ever.")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connection").font(.headline).foregroundStyle(.white)
                    Picker("Connection", selection: Binding(get: { connection.mode }, set: { connection.mode = $0 })) {
                        ForEach(DeviceConnectionMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(connection.isBusy)
                    Text(mode == .builtIn
                         ? "Starts Tetherless's own on-device VPN and pairs this iPhone. Needs a signing profile with the Network Extension entitlement."
                         : "Uses a pairing file you import below, plus a local VPN you turn on yourself.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
            }

            statusCard

            if mode == .builtIn {
                Button { Task { await run(startPairing: true) } } label: {
                    if connection.isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Label(isPaired ? "Pair Again" : "Start Pairing", systemImage: "dot.radiowaves.left.and.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(connection.isBusy || !DeviceConnection.canPairOnDevice)
                .opacity(DeviceConnection.canPairOnDevice ? 1 : 0.5)

                if !DeviceConnection.canPairOnDevice {
                    Text("Creating a pairing on this iPhone needs iOS 27 or later. On earlier versions, switch to Manual and import a pairing file.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }

            if isPaired {
                Button {
                    Task { await run(startPairing: false) }
                } label: {
                    if connection.isBusy { ProgressView().tint(.white) } else { Text("Test Connection") }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(connection.isBusy)
            }

            if connection.isBusy {
                Button("Cancel") { connection.cancel() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            if let resultMessage {
                GlassCard { StatusRow(kind: resultFailed ? .warning : .ok, title: resultMessage) }
            }

            // Import an existing pairing file (used by Manual mode).
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(pairing.isPaired ? "Replace pairing file" : "Already have a pairing file?")
                        .font(.headline).foregroundStyle(.white.opacity(0.7))
                    Button { importing = true } label: {
                        Label("Choose File…", systemImage: "folder")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if pairing.isPaired {
                        Text("Imported: \(pairing.fileName ?? "pairing file")")
                            .font(.footnote).foregroundStyle(.white.opacity(0.6))
                        Button("Remove imported file", role: .destructive) { pairing.remove() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            if connection.hasSavedPairing {
                Button("Forget on-device pairing", role: .destructive) {
                    do { try connection.resetPairing(); resultMessage = nil }
                    catch { resultMessage = error.localizedDescription; resultFailed = true }
                }
                .font(.footnote)
            }

            if let error = pairing.errorMessage {
                GlassCard { StatusRow(kind: .warning, title: "Import failed", subtitle: error) }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .propertyList, .item]) { result in
            if case .success(let url) = result { pairing.importFile(from: url) }
        }
    }

    // MARK: Status card

    @ViewBuilder
    private var statusCard: some View {
        GlassCard {
            switch connection.phase {
            case .connecting:
                StatusRow(kind: .busy, title: "Connecting…", subtitle: connection.notice ?? "Opening the connection to this device.")
            case .pairing:
                if let pin = pairingService.pin {
                    StatusRow(kind: .busy, title: "Enter code \(pin)",
                              subtitle: "Open Settings → Privacy & Security → Developer Mode and enter this code.")
                } else {
                    StatusRow(kind: .busy, title: "Waiting for pairing…",
                              subtitle: "On this iPhone go to Settings → Privacy & Security → Developer Mode.")
                }
            case .ready:
                StatusRow(kind: .ok, title: "Connected")
            case .failed(let message):
                StatusRow(kind: .warning, title: "Couldn't connect", subtitle: message)
            case .idle:
                if isPaired {
                    StatusRow(kind: .ok, title: "Paired",
                              subtitle: mode == .builtIn ? "Pairing saved on this iPhone." : (pairing.fileName ?? "Pairing file imported."))
                } else {
                    StatusRow(kind: .info, title: "Not paired yet",
                              subtitle: mode == .builtIn
                                ? "Tap Start Pairing below, then on this iPhone go to Settings → Privacy & Security → Developer Mode."
                                : "Import a pairing file below and turn on your local VPN.")
                }
            }
        }
    }

    // MARK: Actions

    private func run(startPairing: Bool) async {
        resultMessage = nil
        do {
            if startPairing, connection.hasSavedPairing { try connection.resetPairing() }
            try await services.installer.checkConnection()
            resultFailed = false
            resultMessage = startPairing ? "Paired and connected" : "Connection works"
        } catch {
            resultFailed = true
            resultMessage = error.localizedDescription
        }
    }
}
