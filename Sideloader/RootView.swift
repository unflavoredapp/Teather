import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case pair = "Pair"
    case files = "Files"
    case library = "Library"
    case decrypt = "Decrypt"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .pair: return "iphone.radiowaves.left.and.right"
        case .files: return "folder.fill"
        case .library: return "square.stack.3d.up.fill"
        case .decrypt: return "lock.open.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    let services: Services
    @State private var tab: AppTab = .library

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            Group {
                switch tab {
                case .pair: PairView(services: services)
                case .files: FilesView()
                case .library: LibraryView(services: services)
                case .decrypt: DecryptMockView()
                case .settings: SettingsView(services: services)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $tab)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.title2)
                        Text(tab.rawValue).font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(selection == tab ? Color.cyan : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == tab {
                            Capsule().fill(.black.opacity(0.22))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }
}

/// Shared scroll container: title + stacked cards, with room for the tab bar.
struct ScreenScroll<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenTitle(text: title)
                    .padding(.top, 40)
                    .padding(.bottom, 8)
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
}
