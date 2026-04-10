import SwiftUI

struct PersonListItem: View {
    let name: String
    let relationship: String
    var avatarText: String? = nil
    var action: (() -> Void)? = nil

    private var initials: String {
        if let text = avatarText {
            return text
        }
        let parts = name.split(separator: " ")
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        let first = parts.first?.first ?? Character(" ")
        let last = parts.last?.first ?? Character(" ")
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                // Avatar with gradient
                ZStack {
                    Circle()
                        .fill(Theme.Gradients.subtle)
                        .frame(width: 52, height: 52)

                    Circle()
                        .stroke(Theme.Gradients.primary, lineWidth: 2)
                        .frame(width: 52, height: 52)

                    Text(initials)
                        .font(.system(size: Theme.FontSize.body, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.accent.opacity(0.6))

                        Text(relationship)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron with background
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryLight)
                        .frame(width: 32, height: 32)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(16)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .themeShadow(Theme.Shadows.small)
        }
        .buttonStyle(CardButtonStyle())
    }
}

#Preview {
    VStack(spacing: 14) {
        PersonListItem(name: "Gabriela Martinez", relationship: "Daughter")
        PersonListItem(name: "Michael Chen", relationship: "Son")
        PersonListItem(name: "John", relationship: "Friend")
    }
    .padding(20)
    .background(Color(hex: "FAFAFA"))
}
