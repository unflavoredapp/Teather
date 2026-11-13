import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let services: Services
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var certificates: CertificateStore
    @AppStorage("disableNotifications") private var disableNotifications = false
    @AppStorage("continueBackgrounded") private var continueBackgrounded = false

    @State private var showSignIn = false
    @State private var showCertificate = false

    var body: some View {
        NavigationStack {
            ScreenScroll(title: "Settings") {
                appleIDCard
                storeAccessCard
                softwareUpdateCard
                customCertificateCard

                // Preferences
                GlassCard {
                    MockToggle(title: "Disable Notifications",
                               subtitle: "Turns off every notification this app sends, including the pairing PIN.",
                               isOn: $disableNotifications)
                }
                GlassCard {
                    MockToggle(title: "Continue Sideloading when Backgrounded",
                               subtitle: "Keeps a sideload running after you leave the app — shows as a silent Now Playing entry while active.",
                               isOn: $continueBackgrounded)
                }

                NavRow(icon: "slider.horizontal.3", title: "Default Signing Config") { DefaultSigningConfigView() }
                NavRow(icon: "arrow.triangle.2.circlepath", title: "Automate Refresh",
                       subtitle: "Keep sideloaded apps from expiring with a Shortcuts automation.") { AutomateRefreshView() }
                NavRow(icon: "doc.text.magnifyingglass", title: "Diagnostics") { DiagnosticsView() }
                NavRow(icon: "info.circle", title: "About") { AboutView() }
            }
            .sheet(isPresented: $showSignIn) { AppleIDSheet(services: services) }
            .sheet(isPresented: $showCertificate) { CertificateSheet() }
            .alert("Verification code", isPresented: .constant(account.needsCode)) {
                CodeField { account.submitCode($0) }
            } message: {
                Text("Enter the code Apple sent to your trusted device.")
            }
        }
    }

    // MARK: Cards

    private var appleIDCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple ID").font(.title3.weight(.medium)).foregroundStyle(.white)
                        Text("Signs your apps with your free Apple ID.")
                            .font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                }
                if account.isSignedIn {
                    StatusRow(kind: .ok, title: "Signed in", subtitle: account.email)
                    NavigationLink { DeveloperAccountView() } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "checkmark.seal").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Developer Account").font(.title3.weight(.medium)).foregroundStyle(.white)
                                Text("View your certificates, App IDs and devices — and free up a certificate slot.")
                                    .font(.callout).foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                    Button("Sign Out") { Task { await account.signOut(service: services.account) } }
                        .buttonStyle(SecondaryButtonStyle())
                } else {
                    StatusRow(kind: .info, title: "Not signed in")
                    Button("Sign In") { showSignIn = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
                if let error = account.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.yellow)
                }
            }
        }
    }

    // Store Access is a UI-only mock: it never downloads or decrypts anything.
    private var storeAccessCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "bag").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Store Access").font(.title3.weight(.medium)).foregroundStyle(.white)
                        Text("Used by Decrypt to buy/download apps.")
                            .font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                }
                if account.isSignedIn {
                    StatusRow(kind: .ok, title: "Signed in for Store access", subtitle: account.email)
                } else {
                    StatusRow(kind: .info, title: "Not signed in")
                }
                NavigationLink { StoreAccessView() } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "person.2").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Store Accounts").font(.title3.weight(.medium)).foregroundStyle(.white)
                            Text("Add another Apple ID for downloads, or switch accounts.")
                                .font(.callout).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var softwareUpdateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                StatusRow(kind: .ok, title: "Software Update", subtitle: "You're on the latest version (1.2.1).")
                Button("Check for Updates") { }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var customCertificateCard: some View {
        Button { showCertificate = true } label: {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "key.horizontal.fill").font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Certificate").font(.title3.weight(.medium)).foregroundStyle(.white)
                        Text(certificates.isReady
                             ? (certificates.certificateName ?? "Ready")
                             : "Sign with your own paid certificate")
                            .font(.callout).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// A single tappable glass row that pushes a detail screen.
private struct NavRow<Destination: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink { destination } label: {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: icon).font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.title3.weight(.medium)).foregroundStyle(.white)
                        if let subtitle {
                            Text(subtitle).font(.callout).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CodeField: View {
    @State private var code = ""
    let submit: (String?) -> Void
    var body: some View {
        TextField("6-digit code", text: $code).keyboardType(.numberPad)
        Button("Submit") { submit(code) }
        Button("Cancel", role: .cancel) { submit(nil) }
    }
}

// MARK: - Apple ID sheet

struct AppleIDSheet: View {
    let services: Services
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Apple ID", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                } footer: {
                    Text("Your credentials are sent only to Apple to create a signing certificate. Use an account you control.")
                }
                if let error = account.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if account.isBusy {
                        ProgressView()
                    } else {
                        Button("Sign In") {
                            Task {
                                await account.signIn(email: email, password: password, service: services.account)
                                if account.isSignedIn { dismiss() }
                            }
                        }
                        .disabled(email.isEmpty || password.isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - Certificate sheet

struct CertificateSheet: View {
    @EnvironmentObject private var certificates: CertificateStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var pickingP12 = false
    @State private var pickingProfile = false
    @AppStorage("signingMethod") private var methodRaw = SigningMethod.appleID.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Signing method", selection: $methodRaw) {
                        ForEach(SigningMethod.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(methodRaw == SigningMethod.customCertificate.rawValue
                         ? "Signing uses the certificate and profile below (zsign, on device)."
                         : "Apple ID signing isn't available yet — choose Custom Certificate to sign.")
                }
                Section("Certificate (.p12)") {
                    if let name = certificates.certificateName {
                        Label(name, systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                    SecureField("P12 password", text: $password)
                    Button("Choose .p12…") { pickingP12 = true }
                }
                Section("Provisioning profile") {
                    if let name = certificates.profileName {
                        Label(name, systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        if let expiry = certificates.profileExpiry {
                            Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Button("Choose .mobileprovision…") { pickingProfile = true }
                }
                if let error = certificates.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
                if certificates.certificateName != nil || certificates.profileName != nil {
                    Section {
                        Button("Remove Certificate & Profile", role: .destructive) { certificates.clear() }
                    }
                }
            }
            .navigationTitle("Custom Certificate")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $pickingP12, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result { certificates.importP12(from: url, password: password) }
            }
            .fileImporter(isPresented: $pickingProfile, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result { certificates.importProfile(from: url) }
            }
        }
    }
}
