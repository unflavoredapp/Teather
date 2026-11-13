import SwiftUI

enum Theme {
    static let top = Color(red: 0.16, green: 0.12, blue: 0.40)
    static let mid = Color(red: 0.25, green: 0.38, blue: 0.62)
    static let bottom = Color(red: 0.33, green: 0.75, blue: 0.85)
    static let accent = Color(red: 0.27, green: 0.56, blue: 0.97)
    static let success = Color(red: 0.30, green: 0.80, blue: 0.40)
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.top, Theme.mid, Theme.bottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.18 : 0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }
}

struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusRow: View {
    enum Kind { case ok, info, warning, busy }
    let kind: Kind
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                switch kind {
                case .ok: Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                case .info: Image(systemName: "info.circle").foregroundStyle(Theme.accent)
                case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                case .busy: ProgressView().tint(Theme.accent)
                }
            }
            .font(.title2)
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.medium)).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.callout).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}
