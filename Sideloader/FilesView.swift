import SwiftUI
import UniformTypeIdentifiers

/// Browser for the app's own Documents folder (also exposed in the Files app
/// via UIFileSharingEnabled). Tapping an .ipa adds it to the Library.
struct FilesView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var entries: [URL] = []
    @State private var importing = false
    @State private var message: String?

    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    var body: some View {
        ScreenScroll(title: "Files") {
            GlassCard {
                Button { importing = true } label: {
                    Label("Import Files…", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if let message {
                GlassCard { StatusRow(kind: .info, title: message) }
            }

            if entries.isEmpty {
                GlassCard {
                    StatusRow(kind: .info, title: "Nothing here yet",
                              subtitle: "Import files, or drop them into this app's folder in the Files app.")
                }
            } else {
                ForEach(entries, id: \.self) { url in
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: icon(for: url)).font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent).font(.headline).foregroundStyle(.white).lineLimit(1)
                                Text(sizeString(url)).font(.caption).foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            if url.pathExtension.lowercased() == "ipa" {
                                Button("Add") { addToLibrary(url) }
                                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                            }
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                            Button(role: .destructive) { delete(url) } label: { Image(systemName: "trash") }
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls { copyIn(url) }
            reload()
        }
    }

    private func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: docs, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        entries = urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func copyIn(_ source: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let dest = docs.appendingPathComponent(source.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: source, to: dest)
    }

    private func addToLibrary(_ url: URL) {
        do {
            try library.importIPA(from: url)
            message = "Added \(url.lastPathComponent) to Library"
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reload()
    }

    private func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "ipa": return "app.gift.fill"
        case "p12", "mobileprovision": return "key.fill"
        case "plist": return "doc.text.fill"
        default: return "doc.fill"
        }
    }

    private func sizeString(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
