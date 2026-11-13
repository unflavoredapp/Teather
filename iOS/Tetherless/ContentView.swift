import SwiftUI
import UniformTypeIdentifiers

struct APIEnvelope<T: Decodable>: Decodable { let ok: Bool?; let data: T?; let error: String? }
struct Health: Decodable { let name: String; let version: String; let platform: String; let capabilities: [String] }
struct Device: Decodable, Identifiable { var id: String { udid }; let udid: String; let name: String?; let productType: String?; let paired: Bool?; let connection: String? }
struct AppResult: Decodable, Identifiable { var id: String { appID }; let appID: String; let bundleID: String; let name: String; let version: String?; let seller: String? }

@MainActor final class HelperModel: ObservableObject {
    @Published var baseURL = UserDefaults.standard.string(forKey: "backendURL") ?? "http://127.0.0.1:8787"
    @Published var token = ""
    @Published var status = "Not connected"
    @Published var devices: [Device] = []
    @Published var appResults: [AppResult] = []
    @Published var query = ""
    @Published var busy = false
    @Published var error: String?

    func request<T: Decodable>(_ path: String, body: [String: String]? = nil) async throws -> T {
        guard let root = URL(string: baseURL), let url = URL(string: path, relativeTo: root) else { throw URLError(.badURL) }
        var req = URLRequest(url: url); req.timeoutInterval = 30
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type"); req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw NSError(domain: "Tetherless", code: 1, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Backend request failed"]) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func connect() async {
        busy = true; defer { busy = false }; UserDefaults.standard.set(baseURL, forKey: "backendURL")
        do { let _: Health = try await request("/health"); status = "Connected"; error = nil; await loadDevices() }
        catch { status = "Offline"; self.error = error.localizedDescription }
    }
    func loadDevices() async {
        do { let result: [Device] = try await request("/v1/devices"); devices = result }
        catch { self.error = error.localizedDescription }
    }
    func lookup() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }
        busy = true; defer { busy = false }
        do { let result: [AppResult] = try await request("/v1/apps/lookup?term=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"); appResults = result; error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct ContentView: View {
    @StateObject private var model = HelperModel()
    @State private var selectedTab = 0
    @State private var selectedIPA: URL?
    @State private var showingImporter = false
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.05).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Image(systemName: "lock.shield.fill").foregroundStyle(.orange); Text("TETHERLESS").font(.system(.headline, design: .rounded).weight(.black)).tracking(2); Spacer(); Circle().fill(model.status == "Connected" ? .green : .gray).frame(width: 8,height: 8); Text(model.status).font(.caption).foregroundStyle(.secondary) }.padding()
                TabView(selection: $selectedTab) {
                    dashboard.tag(0).tabItem { Label("Home", systemImage: "square.grid.2x2") }
                    apps.tag(1).tabItem { Label("Apps", systemImage: "apps.iphone") }
                    settings.tag(2).tabItem { Label("Backend", systemImage: "server.rack") }
                }.tint(.orange)
            }
        }.preferredColorScheme(.dark).alert("Tetherless", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK", role: .cancel) { model.error = nil } } message: { Text(model.error ?? "") }
    }
    var dashboard: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            Text("DEVICE BRIDGE").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            HStack(spacing: 12) { stat("Devices", "\(model.devices.count)", "iphone") ; stat("Backend", model.status == "Connected" ? "Online" : "Offline", "dot.radiowaves.left.and.right") }
            panel { VStack(alignment: .leading, spacing: 12) { Label("Debian helper", systemImage: "server.rack").font(.headline); Text("Connect this iPhone client to your self-hosted Tetherless service.").font(.subheadline).foregroundStyle(.secondary); Button { Task { await model.connect() } } label: { Label(model.busy ? "Connecting…" : "Connect", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.orange).disabled(model.busy) } }
            panel { VStack(alignment: .leading, spacing: 10) { Label("Connected devices", systemImage: "iphone.gen3.radiowaves.left.and.right").font(.headline); if model.devices.isEmpty { Text("No devices reported by backend yet.").font(.subheadline).foregroundStyle(.secondary) } else { ForEach(model.devices) { d in HStack { Image(systemName: "iphone").foregroundStyle(.orange); VStack(alignment: .leading) { Text(d.name ?? "iPhone"); Text(d.udid).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(d.paired == true ? "Paired" : "Seen").font(.caption).foregroundStyle(.secondary) } } } } }
            panel { VStack(alignment: .leading, spacing: 10) { Label("IPA workspace", systemImage: "shippingbox").font(.headline); Text("Inspect and package app archives through the Debian helper API.").font(.subheadline).foregroundStyle(.secondary); Button { showingImporter = true } label: { Label(selectedIPA?.lastPathComponent ?? "Choose IPA", systemImage: "doc.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(.bordered); if selectedIPA != nil { Text("Selected locally. Upload and inspection are not wired into this client yet.").font(.caption).foregroundStyle(.secondary) } } }
        }.padding() }.fileImporter(isPresented: $showingImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data], allowsMultipleSelection: false) { result in if case .success(let urls) = result { selectedIPA = urls.first } }
    }
    var apps: some View {
        NavigationStack { VStack(spacing: 12) { HStack { TextField("Bundle ID or App Store ID", text: $model.query).textInputAutocapitalization(.never).autocorrectionDisabled().padding(12).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12)); Button { Task { await model.lookup() } } label: { Image(systemName: "magnifyingglass").padding(13).background(.orange, in: RoundedRectangle(cornerRadius: 12)) } }
            List(model.appResults) { app in VStack(alignment: .leading, spacing: 4) { Text(app.name).font(.headline); Text(app.bundleID).font(.caption).foregroundStyle(.secondary); Text("Version \(app.version ?? "Unknown") · \(app.seller ?? "")").font(.caption2).foregroundStyle(.secondary) }.listRowBackground(Color.white.opacity(0.04)) }.scrollContentBackground(.hidden)
        }.padding().background(Color(red: 0.035, green: 0.04, blue: 0.05)).navigationTitle("App lookup") }
    }
    var settings: some View {
        Form { Section("Debian backend") { TextField("Base URL", text: $model.baseURL).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled(); SecureField("API bearer token", text: $model.token); Button("Save and connect") { Task { await model.connect() } }.tint(.orange) }; Section("About") { LabeledContent("Client", value: "Tetherless iOS"); LabeledContent("Build", value: "Unsigned CI") } }.scrollContentBackground(.hidden)
    }
    func stat(_ title: String, _ value: String, _ symbol: String) -> some View { panel { VStack(alignment: .leading, spacing: 8) { Image(systemName: symbol).foregroundStyle(.orange); Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }
    func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View { content().padding(16).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.07))) }
}
