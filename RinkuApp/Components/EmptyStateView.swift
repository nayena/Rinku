import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let ctaLabel: String
    let onCtaClick: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(Theme.Gradients.subtle)
                    .frame(width: 88, height: 88)

                Circle()
                    .stroke(Theme.Gradients.primary, lineWidth: 3)
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Theme.Gradients.primary)
            }

            // Title
            Text(title)
                .font(.system(size: Theme.FontSize.h2, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)

            // Body
            Text(message)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .lineSpacing(4)

            // CTA Button
            RinkuButton(
                title: ctaLabel,
                icon: "plus",
                variant: .primary,
                size: .large,
                action: onCtaClick
            )
            .padding(.top, 8)
        }
        .padding(36)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 2)
        )
        .themeShadow(Theme.Shadows.medium)
    }
}

#Preview {
    EmptyStateView(
        icon: "person.fill.badge.plus",
        title: "No loved ones yet",
        message: "Add people you want to recognize. Include their name, relationship, and a memory prompt.",
        ctaLabel: "Add Loved One"
    ) {
        print("CTA tapped")
    }
    .padding(24)
    .background(Color(hex: "FAFAFA"))
}
