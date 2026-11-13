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

            VStack(spacing: 20) {
                header
                appCard
                statusCard
                logView
                Spacer(minLength: 0)
                bottomButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(job.color.gradient)
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: job.symbol).font(.title2).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name).font(.title2.weight(.semibold)).foregroundStyle(.white)
                Text("Version \(job.version)").font(.callout).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .font(.title2)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            Button("Start") { Task { await simulate() } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)
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
    }
}
