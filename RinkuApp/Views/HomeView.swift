import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: TabItem
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen gradient background that extends into safe area
            LinearGradient(
                colors: [
                    Theme.Colors.primaryLight.opacity(0.6),
                    Theme.Colors.background,
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Gradient Header Section
                    VStack(spacing: 16) {
                        // App Icon/Logo Area
                        ZStack {
                            Circle()
                                .fill(Theme.Gradients.primary)
                                .frame(width: 80, height: 80)
                                .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 20, y: 8)

                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 32)

                        VStack(spacing: 8) {
                            Text("app_name".localized)
                                .font(.system(size: Theme.FontSize.display, weight: .bold))
                                .foregroundStyle(Theme.Gradients.primary)

                            Text("app_tagline".localized)
                                .font(.system(size: Theme.FontSize.body))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)

                // Main CTAs Section
                VStack(spacing: 16) {
                    // Featured Action Card
                    FeaturedActionCard(
                        title: "home_recognize_button".localized,
                        subtitle: "home_info_card".localized,
                        icon: "camera.viewfinder",
                        gradientColors: [Theme.Colors.gradientStart, Theme.Colors.gradientEnd]
                    ) {
                        selectedTab = .recognize
                    }

                    // Secondary Actions
                    HStack(spacing: 12) {
                        QuickActionCard(
                            title: "home_loved_ones_button".localized,
                            icon: "person.2.fill",
                            color: Theme.Colors.primary
                        ) {
                            selectedTab = .lovedOnes
                        }

                        QuickActionCard(
                            title: "home_add_button".localized,
                            icon: "person.fill.badge.plus",
                            color: Theme.Colors.accent
                        ) {
                            selectedTab = .add
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Tips Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("home_getting_started".localized)
                        .font(.system(size: Theme.FontSize.h3, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 32)

                    VStack(spacing: 12) {
                        TipCard(
                            number: 1,
                            title: "home_tip1_title".localized,
                            description: "home_tip1_description".localized,
                            icon: "person.fill.badge.plus"
                        )

                        TipCard(
                            number: 2,
                            title: "home_tip2_title".localized,
                            description: "home_tip2_description".localized,
                            icon: "camera.fill"
                        )

                        TipCard(
                            number: 3,
                            title: "home_tip3_title".localized,
                            description: "home_tip3_description".localized,
                            icon: "heart.fill"
                        )
                    }
                    .padding(.horizontal, 20)
                }

                }
                .padding(.bottom, 100) // Space for tab bar
            }
            .scrollContentBackground(.hidden)
        }
        .id(languageManager.currentLanguage)
    }
}

// MARK: - Featured Action Card

struct FeaturedActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradientColors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: Theme.FontSize.h2, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(Theme.CornerRadius.xl)
            .shadow(color: gradientColors[0].opacity(0.4), radius: 16, y: 8)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .themeShadow(Theme.Shadows.small)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Tip Card

struct TipCard: View {
    let number: Int
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.Gradients.subtle)
                    .frame(width: 48, height: 48)

                Text("\(number)")
                    .font(.system(size: Theme.FontSize.h3, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(description)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.primary.opacity(0.5))
        }
        .padding(16)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
}
