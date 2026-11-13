import SwiftUI

// MARK: - MOCKUP ONLY
// Everything in this file is demo UI with fake data. Nothing here signs in,
// contacts a server, downloads, or decrypts anything. Buttons only advance
// simulated state so the layout can be reviewed.

struct MockApp: Identifiable {
    let id = UUID()
    let name: String
    let publisher: String
    let version: String
    let symbol: String
    let colorName: String
    let sizeMB: Double

    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        default: return .blue
        }
    }

    /// Deep link into the mockup helper app.
    var helperURL: URL? {
        var c = URLComponents()
        c.scheme = "sideloaderhelper"
        c.host = "decrypt"
        c.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "version", value: String(version.dropFirst())),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "color", value: colorName)
        ]
        return c.url
    }
}

private let mockCatalog: [MockApp] = [
    MockApp(name: "Sample Racer", publisher: "Example Studios", version: "v2.7.1", symbol: "car.fill", colorName: "red", sizeMB: 3100),
    MockApp(name: "Block Builder", publisher: "Demo Games Ltd", version: "v4.3.0", symbol: "cube.fill", colorName: "blue", sizeMB: 171),
    MockApp(name: "Arena Royale", publisher: "Placeholder Interactive", version: "v1.9.4", symbol: "scope", colorName: "orange", sizeMB: 2400),
    MockApp(name: "Tactics Online", publisher: "Mockup Mobile Intl.", version: "v4.7.0", symbol: "shield.fill", colorName: "green", sizeMB: 1800),
    MockApp(name: "Rhythm Strike", publisher: "Sample Audio Co.", version: "v3.2.2", symbol: "music.note", colorName: "purple", sizeMB: 640)
]

@MainActor
final class DecryptMock: ObservableObject {
    enum Stage { case setup, signedOut, signedIn }

    @Published var stage: Stage = .setup
    @Published var query = ""
    @Published var activeID: UUID?
    @Published var progress: Double = 0
    @Published var phase: String?
    @Published var finished: Set<UUID> = []
    @Published var logApp: MockApp?

    var results: [MockApp] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? mockCatalog : mockCatalog.filter { $0.name.lowercased().contains(q) }
    }

    /// Pure animation: ticks a progress bar and cycles placeholder status text.
    func simulate(_ app: MockApp) async {
        guard activeID == nil else { return }
        activeID = app.id
        progress = 0
        phase = nil
        for step in 1...20 {
            try? await Task.sleep(nanoseconds: 120_000_000)
            progress = Double(step) / 20
        }
        for text in ["Contacting server…", "Extracting bundle…",
                     "Uploading to iPhone · \(Int(app.sizeMB * 0.05)) / \(Int(app.sizeMB * 0.05)) MB"] {
            phase = text
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
        phase = nil
        activeID = nil
        finished.insert(app.id)
    }
}

struct DecryptMockView: View {
    @StateObject private var model = DecryptMock()
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    @State private var showDemoNote = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScreenScroll(title: "Decrypt") {
                header
                switch model.stage {
                case .setup: setupCard
                case .signedOut: signedOutCards
                case .signedIn: signedInContent
                }
                demoFooter
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .padding(.top, 8).padding(.trailing, 20)
        }
        .sheet(isPresented: $showSettings) { DecryptSettingsMockSheet() }
        .sheet(item: $model.logApp) { app in MockLogSheet(app: app) }
        .alert("Demo only", isPresented: $showDemoNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This screen is a mockup. Nothing is connected to this button.")
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.open").font(.system(size: 64, weight: .regular)).foregroundStyle(.white)
            Text("Get a DRM-free app").font(.title.weight(.semibold)).foregroundStyle(.white)
            Text("Search for an app you own, and Tetherless downloads and decrypts it — fully on-device, no Mac, no jailbreak.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 8)
    }

    private var setupCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "arrow.down.circle").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("One-time setup needed").font(.title3.weight(.medium)).foregroundStyle(.white)
                        Text("Needed once before you can sign in and download.")
                            .font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                }
                Button("Begin Setup") { withAnimation { model.stage = .signedOut } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var signedOutCards: some View {
        GlassCard { StatusRow(kind: .info, title: "Not signed in") }
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrowshape.turn.up.right").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in via Settings").font(.title3.weight(.medium)).foregroundStyle(.white)
                    Text("Sign in with your Apple ID in the Settings tab — one sign-in covers everything.")
                        .font(.callout).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Already have an encrypted IPA?").font(.headline).foregroundStyle(.white.opacity(0.6))
                Button { showDemoNote = true } label: {
                    Label("Pick an Encrypted IPA…", systemImage: "folder")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                StatusRow(kind: .ok, title: "Signed in", subtitle: "demo@example.com")
                Button("Sign Out") { withAnimation { model.stage = .signedOut } }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }

        GlassCard {
            HStack(spacing: 10) {
                TextField("Search apps", text: $model.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                Image(systemName: "magnifyingglass")
                    .font(.title3).foregroundStyle(.white)
                    .frame(width: 56, height: 50)
                    .background(Theme.accent, in: Capsule())
            }
        }

        ForEach(model.results) { app in
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(app.color.gradient)
                            .frame(width: 58, height: 58)
                            .overlay(Image(systemName: app.symbol).font(.title2).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name).font(.title3.weight(.semibold)).foregroundStyle(.white)
                            Text(app.publisher).font(.callout).foregroundStyle(.white.opacity(0.7))
                            if model.activeID == app.id {
                                Text(String(format: "%.0f MB of %.0f MB", app.sizeMB * model.progress, app.sizeMB))
                                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
                            } else if model.finished.contains(app.id) {
                                Text("Downloaded").font(.footnote).foregroundStyle(.white.opacity(0.6))
                            } else {
                                Text(app.version).font(.footnote).foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        trailing(for: app)
                    }

                    if model.activeID == app.id, let phase = model.phase {
                        Divider().overlay(.white.opacity(0.2))
                        StatusRow(kind: .busy, title: "Preparing \(app.name)…", subtitle: phase)
                    }
                    if model.finished.contains(app.id) && model.activeID != app.id {
                        // Jumps to the mockup helper app (iOS shows its own "Open in …?"
                        // prompt). If the helper isn't installed, fall back to the
                        // in-app placeholder log sheet.
                        Button("Done") {
                            guard let url = app.helperURL else { model.logApp = app; return }
                            openURL(url) { accepted in
                                if !accepted { model.logApp = app }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trailing(for app: MockApp) -> some View {
        if model.activeID == app.id && model.phase == nil {
            ProgressView(value: model.progress).tint(.white).frame(width: 110)
        } else if model.finished.contains(app.id) {
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(Theme.success)
        } else if model.activeID == nil {
            Button { Task { await model.simulate(app) } } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 64, height: 50)
                    .background(.white.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            }
        }
    }

    private var demoFooter: some View {
        VStack(spacing: 8) {
            if model.stage == .signedOut {
                Button("Preview signed-in state") { withAnimation { model.stage = .signedIn } }
                    .font(.footnote)
            }
            Text("Mockup — fake data, not connected to anything.")
                .font(.footnote).foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 8)
    }
}

// MARK: - Settings sheet (local state only)

struct DecryptSettingsMockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keepEncrypted = true
    @State private var nonPairing = false
    @State private var installMethod = 0
    @State private var diagnostics = 0

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Text("Decrypt Settings").font(.title3.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        Button("Done") { dismiss() }
                            .font(.title3.weight(.medium)).foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 24)

                    GlassCard {
                        Toggle("Keep encrypted files after downloading", isOn: $keepEncrypted)
                            .font(.title3).foregroundStyle(.white).tint(Theme.success)
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Non-Pairing Mode", isOn: $nonPairing)
                                .font(.title3).foregroundStyle(.white).tint(Theme.success)
                            Text("Tetherless installs the decrypt helper onto your device itself, over the pairing tunnel — needs the Pair tab connected.")
                                .font(.callout).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Decrypt Helper Install Method").font(.title3.weight(.semibold)).foregroundStyle(.white)
                            Picker("", selection: $installMethod) {
                                Text("Separate App (default)").tag(0)
                                Text("Overwrite Main App").tag(1)
                            }
                            .pickerStyle(.segmented)
                            Text(installMethod == 0
                                 ? "Installs the helper as its own app, alongside Tetherless."
                                 : "Replaces this app with the helper while it runs.")
                                .font(.callout).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emulator Diagnostics").font(.title3.weight(.semibold)).foregroundStyle(.white)
                            Picker("", selection: $diagnostics) {
                                Text("Fast (recommended)").tag(0)
                                Text("Detailed").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    Text("Mockup — these controls change nothing.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Fake log screen

struct MockLogSheet: View {
    let app: MockApp
    @Environment(\.dismiss) private var dismiss

    private var lines: String {
        """
        [demo] Found embedded app: \(app.name)
        [demo] Copying app bundle…
        [demo] Processing 9 files…
          [demo] PlugIns/WidgetExtension.appex
          [demo] Frameworks/CoreLib.framework
          [demo] Frameworks/Analytics.framework
          [demo] \(app.name)
        [demo] Done.
        [demo] Packaging \(app.name).ipa…
        [demo] Wrote \(app.name).ipa.

        This is placeholder text. No files were created.
        """
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Tetherless Decrypt").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button("Close") { dismiss() }
                }
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(app.color.gradient)
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: app.symbol).foregroundStyle(.white))
                    VStack(alignment: .leading) {
                        Text(app.name).font(.title3.weight(.semibold)).foregroundStyle(.white)
                        Text("Version \(app.version.dropFirst())").foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(16)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))

                StatusRow(kind: .ok, title: "Done (mockup)")
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))

                Text(lines).font(.system(.footnote, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
