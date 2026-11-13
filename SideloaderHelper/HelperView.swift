import SwiftUI

struct HelperView: View {
    let job: HelperJob

    enum Stage { case waiting, running, done }

    @State private var stage: Stage = .waiting
    @State private var lines: [String] = []
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                header
                appCard
                statusCard
                logView
                Spacer(minLength: 0)
                bottomButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task {
            // Opened from Tetherless after a (mock) decrypt: start right away.
            if job.autostart && stage == .waiting { await simulate() }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Color.clear.frame(width: 28, height: 28)
            Spacer()
            Text("Tetherless Decrypt").font(.headline).foregroundStyle(.white)
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.title3).foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
        }
        .padding(.top, 8)
    }

    private var appCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(job.color.gradient)
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: job.symbol).font(.body.weight(.semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name).font(.title3.weight(.semibold)).foregroundStyle(.white)
                Text("Version \(job.version)").font(.subheadline).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            switch stage {
            case .waiting:
                Image(systemName: "hourglass")
                Text("Waiting to start…")
            case .running:
                Image(systemName: "lock.open.rotation")
                Text("Working…")
            case .done:
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                Text("Done (mockup)").foregroundStyle(Theme.success)
            }
        }
        .font(.title3)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var logView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch stage {
        case .waiting:
            Button { Task { await simulate() } } label: {
                Text("Start Decryption").font(.title3).padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 6))
            .tint(Color(red: 0.25, green: 0.53, blue: 1.0))
        case .running:
            ProgressView().tint(.white)
        case .done:
            Button("Back to Tetherless") {
                if let url = URL(string: "sideloader://") { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
        }
    }

    // MARK: Simulation (animation only)

    private func simulate() async {
        stage = .running
        lines = []
        let script = [
            "[demo] Found embedded app: \(job.name)",
            "[demo] Copying app bundle…",
            "[demo] Processing 9 files…",
            "  [demo] PlugIns/WidgetExtension.appex",
            "  [demo] Frameworks/CoreLib.framework",
            "  [demo] Frameworks/Analytics.framework",
            "  [demo] \(job.name)",
            "[demo] Done.",
            "[demo] Packaging \(job.name).ipa…",
            "[demo] Wrote \(job.name).ipa.",
            "",
            "Placeholder text only. No files were created."
        ]
        for line in script {
            try? await Task.sleep(nanoseconds: 350_000_000)
            lines.append(line)
        }
        stage = .done
        // Hand back to Tetherless automatically when we were launched from it.
        if job.autostart {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if let url = URL(string: "sideloader://") { openURL(url) }
        }
    }
}
