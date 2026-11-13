import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let services: Services
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var certificates: CertificateStore
    @AppStorage("signingMethod") private var methodRaw = SigningMethod.appleID.rawValue
    @AppStorage("keepSignedCopies") private var keepSigned = true

    @State private var showSignIn = false
    @State private var showCertificate = false

    var body: some View {
        ScreenScroll(title: "Settings") {
            // Apple ID
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

            // Signing method
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Signing Method").font(.title3.weight(.medium)).foregroundStyle(.white)
                    Picker("Signing Method", selection: $methodRaw) {
                        ForEach(SigningMethod.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Text(methodRaw == SigningMethod.appleID.rawValue
                         ? "Free accounts get 7-day certificates and a small App ID limit."
                         : "Uses the certificate and provisioning profile you import below.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
            }

            // Custom certificate
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

            // Preferences
            GlassCard {
                Toggle(isOn: $keepSigned) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep signed copies").font(.title3.weight(.medium)).foregroundStyle(.white)
                        Text("Leave the signed .ipa in the Library after installing.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .tint(Theme.success)
            }
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

    var body: some View {
        NavigationStack {
            Form {
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
