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

// MARK: - Developer Account (mock, read-only placeholder data)

struct DeveloperAccountView: View {
    // Placeholder data only — this screen does not talk to Apple.
    var body: some View {
        DetailScreen(title: "Developer Account") {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill").font(.title).foregroundStyle(Theme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("airc0re@icloud.com").font(.title3.weight(.semibold)).foregroundStyle(.white)
                        Text("Apple ID").font(.callout).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
                Divider1().padding(.vertical, 6)
                HStack {
                    Text("Team").font(.callout).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("Rodger Williams · GVZJWHFTS9").font(.callout.weight(.medium)).foregroundStyle(.white)
                }
            }

            GlassCard {
                SectionHeader(title: "Signing certificates", trailing: "1")
                Text("Certificates are shared across tools on your account — one slot each for Tetherless, Xcode, other signers. Revoking one breaks whatever it signed.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.55))
                Divider1().padding(.vertical, 4)
                HStack {
                    Text("iOS Development: Rodger Will…").font(.callout.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    Text("Tetherless").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                Text("Expires Nov 13, 2027").font(.footnote).foregroundStyle(.white.opacity(0.5))
                Text("Serial 2507C38BDFB4474E13549031D30362D3").font(.footnote).foregroundStyle(.white.opacity(0.5))
                Button { } label: {
                    Label("Revoke", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
            }

            GlassCard {
                SectionHeader(title: "App IDs", trailing: "5")
                Text("5 registered. Apple lets a free account register about 10 new identifiers every 7 days — deleting one frees the name, not that weekly allowance.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.55))
                ForEach(Self.appIDs, id: \.0) { item in
                    Divider1().padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0).font(.callout.weight(.medium)).foregroundStyle(.white)
                        Text(item.1).font(.footnote).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassCard {
                SectionHeader(title: "Devices", trailing: "1")
                Divider1().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tetherless device").font(.callout.weight(.medium)).foregroundStyle(.white)
                    Text("00008110-000209003C60E01E").font(.footnote).foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private static let appIDs: [(String, String)] = [
        ("Tetherless Decrypt", "com.tetherless.decrypthelper.GVZJWHFTS9"),
        ("Tetherless App 1", "com.roblox.robloxmobile.GVZJWHFTS9.RBWidgetExtension"),
        ("Tetherless App", "com.roblox.robloxmobile.GVZJWHFTS9"),
        ("Tetherless App", "com.ipaside.tetherless.GVZJWHFTS9"),
        ("Tetherless App 2", "com.roblox.robloxmobile.GV…BNotificationServiceExtension")
    ]
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
