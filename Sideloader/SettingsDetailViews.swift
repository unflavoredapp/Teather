import SwiftUI

// MARK: - Shared pushed-screen chrome

/// A full-screen detail page with the app gradient and a custom glass back button,
/// matching the "Developer Account" / "Store Access" screens in the design.
struct DetailScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) { content }
                    .padding(.horizontal, 20)
                    .padding(.top, 84)
                    .padding(.bottom, 140)
            }

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                Spacer()
                Text(title).font(.headline).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 46, height: 46)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// A labelled card header used across the detail screens (title on the left, count on the right).
private struct SectionHeader: View {
    let title: String
    var trailing: String?
    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            if let trailing {
                Text(trailing).font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

private struct Divider1: View {
    var body: some View { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
}

// MARK: - Developer Account (live data from the Apple ID account)

struct DeveloperAccountView: View {
    @EnvironmentObject private var apple: AppleIDAccountService
    @EnvironmentObject private var account: AccountStore
    @State private var loadError: String?
    @State private var busy = false

    var body: some View {
        DetailScreen(title: "Developer Account") {
            if apple.team == nil {
                GlassCard {
                    StatusRow(kind: .info, title: "Not signed in",
                              subtitle: "Sign in with your Apple ID in Settings to load your certificates, App IDs and devices.")
                }
            } else {
                accountCard
                certificatesCard
                appIDsCard
                devicesCard
            }
            if let loadError {
                GlassCard { Text(loadError).font(.footnote).foregroundStyle(.yellow) }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        guard apple.team != nil else { return }
        busy = true; defer { busy = false }
        do { try await apple.refresh() } catch { loadError = error.localizedDescription }
    }

    private var accountCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill").font(.title).foregroundStyle(Theme.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.email ?? "Apple ID").font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Text("Apple ID").font(.callout).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }
            Divider1().padding(.vertical, 6)
            HStack {
                Text("Team").font(.callout).foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let team = apple.team {
                    Text("\(team.name) · \(team.id)").font(.callout.weight(.medium)).foregroundStyle(.white)
                }
            }
        }
    }

    private var certificatesCard: some View {
        GlassCard {
            SectionHeader(title: "Signing certificates", trailing: "\(apple.certificates.count)")
            Text("Certificates are shared across tools on your account — one slot each for Tetherless, Xcode, other signers. Revoking one breaks whatever it signed.")
                .font(.footnote).foregroundStyle(.white.opacity(0.55))
            ForEach(apple.certificates) { cert in
                Divider1().padding(.vertical, 4)
                HStack {
                    Text(cert.name).font(.callout.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    Text("Tetherless").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                if let expiry = cert.expiry {
                    Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote).foregroundStyle(.white.opacity(0.5))
                }
                Text("Serial \(cert.serialNumber)").font(.footnote).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                Button {
                    Task { busy = true; defer { busy = false }
                        do { try await apple.revoke(certificate: cert) } catch { loadError = error.localizedDescription } }
                } label: {
                    Label("Revoke", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(busy)
                .padding(.top, 4)
            }
        }
    }

    private var appIDsCard: some View {
        GlassCard {
            SectionHeader(title: "App IDs", trailing: "\(apple.appIDs.count)")
            Text("Apple lets a free account register about 10 new identifiers every 7 days — deleting one frees the name, not that weekly allowance.")
                .font(.footnote).foregroundStyle(.white.opacity(0.55))
            ForEach(apple.appIDs) { item in
                Divider1().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.callout.weight(.medium)).foregroundStyle(.white)
                    Text(item.identifier).font(.footnote).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var devicesCard: some View {
        GlassCard {
            SectionHeader(title: "Devices", trailing: "\(apple.devices.count)")
            ForEach(apple.devices) { device in
                Divider1().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).font(.callout.weight(.medium)).foregroundStyle(.white)
                    Text(device.udid).font(.footnote).foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Store Access (mock)

struct StoreAccessView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        DetailScreen(title: "Store Access") {
            GlassCard {
                SectionHeader(title: "Store accounts", trailing: "1")
                Text("The active account is used for every download and decrypt. Switch any time; the Decrypt tab shows a quick switcher once you have two or more.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.55))
                Divider1().padding(.vertical, 4)
                HStack {
                    Text("airc0re@icloud.com").font(.callout.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text("Active").font(.caption.weight(.semibold)).foregroundStyle(Theme.success)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.success.opacity(0.18), in: Capsule())
                }
                Button { } label: {
                    Label("Sign Out", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
            }

            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.plus").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Account").font(.title3.weight(.semibold)).foregroundStyle(.white)
                        Text("Sign in another Apple ID for Store downloads. It becomes the active one.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.55))
                    }
                }
                TextField("", text: $email, prompt: Text("Apple ID email").foregroundStyle(.white.opacity(0.4)))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                SecureField("", text: $password, prompt: Text("Password").foregroundStyle(.white.opacity(0.4)))
                    .padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                Button("Add Account") { }
                    .buttonStyle(SecondaryButtonStyle())
            }

            GlassCard {
                StatusRow(kind: .info, title: "About decrypt",
                          subtitle: "Decrypt works for an Apple ID only if it has signed into this iPhone's App Store at least once (ever). Downloads work for any added account.")
            }
        }
    }
}

// MARK: - Default Signing Config (mock)

struct DefaultSigningConfigView: View {
    @AppStorage("cfgRemovePlugins") private var removePlugins = false
    @AppStorage("cfgForceProMotion") private var proMotion = false
    @AppStorage("cfgFileSharing") private var fileSharing = true
    @AppStorage("cfgNewBundleID") private var changeBundleID = false

    var body: some View {
        DetailScreen(title: "Default Signing Config") {
            GlassCard {
                Text("Applied to every app you sign, unless you override it at install time.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.55))
            }
            GlassCard {
                MockToggle(title: "Enable file sharing", subtitle: "Adds UIFileSharingEnabled so the app's Documents show in Files.", isOn: $fileSharing)
                Divider1().padding(.vertical, 6)
                MockToggle(title: "Remove app extensions", subtitle: "Strips PlugIns that a free account can't co-sign.", isOn: $removePlugins)
                Divider1().padding(.vertical, 6)
                MockToggle(title: "Force ProMotion", subtitle: "Adds the 120 Hz Info.plist key.", isOn: $proMotion)
                Divider1().padding(.vertical, 6)
                MockToggle(title: "Randomize bundle ID", subtitle: "Lets you install alongside the App Store copy.", isOn: $changeBundleID)
            }
        }
    }
}

// MARK: - Automate Refresh (mock)

struct AutomateRefreshView: View {
    var body: some View {
        DetailScreen(title: "Automate Refresh") {
            GlassCard {
                StatusRow(kind: .info, title: "Keep apps alive",
                          subtitle: "Free-account signatures expire after 7 days. A Shortcuts automation can re-sign your installed apps on a schedule so they keep launching.")
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup").font(.title3.weight(.semibold)).foregroundStyle(.white)
                    StepLine(n: 1, text: "Open Shortcuts and add the Tetherless \"Refresh All\" action.")
                    StepLine(n: 2, text: "Create a Personal Automation set to run daily.")
                    StepLine(n: 3, text: "Turn off \"Ask Before Running\".")
                }
            }
            Button("Add to Shortcuts") { }.buttonStyle(PrimaryButtonStyle())
        }
    }
    private struct StepLine: View {
        let n: Int; let text: String
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Text("\(n)").font(.callout.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26).background(Theme.accent, in: Circle())
                Text(text).font(.callout).foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Diagnostics (mock)

struct DiagnosticsView: View {
    var body: some View {
        DetailScreen(title: "Diagnostics") {
            GlassCard {
                SectionHeader(title: "Environment")
                Divider1().padding(.vertical, 4)
                InfoLine("App version", "1.2.1 (120)")
                InfoLine("iOS", "26.1")
                InfoLine("Device", "iPhone 15 Pro")
                InfoLine("Pairing", "Connected")
                InfoLine("Tunnel", "10.7.0.1 → 10.7.0.2")
            }
            GlassCard {
                SectionHeader(title: "Last run")
                Divider1().padding(.vertical, 4)
                Text("No errors recorded.").font(.callout).foregroundStyle(.white.opacity(0.7))
            }
            Button("Export Logs…") { }.buttonStyle(SecondaryButtonStyle())
        }
    }
    private struct InfoLine: View {
        let k: String; let v: String
        init(_ k: String, _ v: String) { self.k = k; self.v = v }
        var body: some View {
            HStack { Text(k).foregroundStyle(.white.opacity(0.6)); Spacer(); Text(v).foregroundStyle(.white) }
                .font(.callout)
        }
    }
}

// MARK: - About (mock)

struct AboutView: View {
    var body: some View {
        DetailScreen(title: "About") {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "lock.open.fill").font(.title).foregroundStyle(Theme.accent).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tetherless").font(.title3.weight(.semibold)).foregroundStyle(.white)
                        Text("Version 1.2.1").font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            GlassCard {
                Text("An on-device sideloader for your own apps. Pairing, signing and install run entirely on this iPhone.")
                    .font(.callout).foregroundStyle(.white.opacity(0.75))
            }
            GlassCard {
                LinkLine(icon: "doc.text", title: "Acknowledgements")
                Divider1().padding(.vertical, 6)
                LinkLine(icon: "hand.raised", title: "Privacy")
                Divider1().padding(.vertical, 6)
                LinkLine(icon: "curlybraces", title: "Open-source licenses")
            }
        }
    }
    private struct LinkLine: View {
        let icon: String; let title: String
        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 28)
                Text(title).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.white.opacity(0.4))
            }
            .font(.callout)
        }
    }
}

// MARK: - Reusable mock toggle

struct MockToggle: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.medium)).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .tint(Theme.success)
    }
}
