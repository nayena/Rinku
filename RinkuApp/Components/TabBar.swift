import SwiftUI

enum TabItem: Int, CaseIterable {
    case home
    case lovedOnes
    case add
    case recognize
    case profile

    var title: String {
        switch self {
        case .home:
            return "tab_home".localized
        case .lovedOnes:
            return "tab_loved_ones".localized
        case .add:
            return "tab_add".localized
        case .recognize:
            return "tab_recognize".localized
        case .profile:
            return "tab_profile".localized
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .lovedOnes:
            return "person.2.fill"
        case .add:
            return "person.fill.badge.plus"
        case .recognize:
            return "camera.fill"
        case .profile:
            return "person.circle.fill"
        }
    }
}

struct TabBar: View {
    @Binding var selectedTab: TabItem
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Top border/shadow line
            Rectangle()
                .fill(Theme.Colors.border.opacity(0.5))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    TabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
        }
        .background(Theme.Colors.cardBackground)
        .background(
            Theme.Colors.cardBackground
                .ignoresSafeArea(edges: .bottom)
        )
        .id(languageManager.currentLanguage)
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Theme.Gradients.primary)
                            .frame(width: 44, height: 44)
                            .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 8, y: 2)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 20 : 22, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                }
                .frame(height: 44)

                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
        }
        .buttonStyle(TabButtonStyle())
    }
}

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack {
        Spacer()
        TabBar(selectedTab: .constant(.home))
    }
    .background(Color(hex: "FAFAFA"))
}
