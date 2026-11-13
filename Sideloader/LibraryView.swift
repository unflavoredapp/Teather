import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    let services: Services
    @EnvironmentObject private var library: LibraryStore
    @AppStorage("signingMethod") private var methodRaw = SigningMethod.appleID.rawValue
    @State private var importing = false
    @State private var importError: String?

    private var method: SigningMethod { SigningMethod(rawValue: methodRaw) ?? .appleID }

    var body: some View {
        ScreenScroll(title: "Library") {
            GlassCard {
                VStack(spacing: 12) {
                    Button { importing = true } label: {
                        Label("Import IPA…", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("Signing with: \(method.rawValue)")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
            }

            if let importError {
                GlassCard { StatusRow(kind: .warning, title: "Import failed", subtitle: importError) }
            }

            if library.items.isEmpty {
                GlassCard {
                    StatusRow(kind: .info, title: "No apps yet",
                              subtitle: "Import an .ipa you built or own the rights to. It will be signed and installed from here.")
                }
            }

            ForEach(library.items) { item in
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName).font(.title3.weight(.semibold)).foregroundStyle(.white)
                                Text(item.bundleID).font(.footnote).foregroundStyle(.white.opacity(0.6))
                                Text("v\(item.version) · \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))")
                                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            badge(for: item.state)
                        }

                        if library.busyID == item.id {
                            ProgressView().tint(.white)
                        } else {
                            VStack(spacing: 10) {
                            HStack {
                                Button("Sign & Install") {
                                    Task { await library.signAndInstall(item, method: method, services: services) }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(library.busyID != nil)

                                if item.state != .unsigned {
                                    ShareLink(item: library.signedURL(for: item)) {
                                        Image(systemName: "square.and.arrow.up")
                                            .padding(14)
                                            .background(.white.opacity(0.1), in: Circle())
                                    }
                                }
                                Button(role: .destructive) { library.delete(item) } label: {
                                    Image(systemName: "trash")
                                        .padding(14)
                                        .background(.white.opacity(0.1), in: Circle())
                                }
                            }
                            Button("Install as-is (already signed)") {
                                Task { await library.installAsIs(item, services: services) }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(library.busyID != nil)
                            }
                        }
                    }
                }
            }

            if !library.log.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(library.log.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(.footnote, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            importError = nil
            for url in urls {
                do { try library.importIPA(from: url) }
                catch { importError = "\(url.lastPathComponent): \(error.localizedDescription)" }
            }
        }
    }

    @ViewBuilder
    private func badge(for state: IPAItem.State) -> some View {
        let (text, color): (String, Color) = {
            switch state {
            case .unsigned: return ("Unsigned", .gray)
            case .signed: return ("Signed", .orange)
            case .installed: return ("Installed", Theme.success)
            }
        }()
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.25), in: Capsule())
            .foregroundStyle(color == .gray ? .white.opacity(0.8) : color)
    }
}
