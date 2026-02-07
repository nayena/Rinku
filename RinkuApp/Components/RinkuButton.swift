import SwiftUI

enum ButtonVariant {
    case primary
    case secondary
    case destructive
    case ghost
}

enum ButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small:
            return 36
        case .medium:
            return 48
        case .large:
            return 56
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 12
        case .medium:
            return 20
        case .large:
            return 28
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small:
            return 14
        case .medium:
            return 16
        case .large:
            return 17
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small:
            return 16
        case .medium:
            return 20
        case .large:
            return 22
        }
    }
}

struct RinkuButton: View {
    let title: String
    var icon: String? = nil
    var variant: ButtonVariant = .primary
    var size: ButtonSize = .medium
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    let action: () -> Void

    private var useGradient: Bool {
        variant == .primary
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return Theme.Colors.primary
        case .secondary:
            return Theme.Colors.cardBackground
        case .destructive:
            return Theme.Colors.danger
        case .ghost:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive:
            return .white
        case .secondary:
            return Theme.Colors.primary
        case .ghost:
            return Theme.Colors.primary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary:
            return Theme.Colors.primary.opacity(0.3)
        case .ghost:
            return .clear
        default:
            return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.85)
                }

                if let icon = icon, !isLoading {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: size.fontSize, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, fullWidth ? 0 : size.horizontalPadding)
            .background(
                Group {
                    if useGradient {
                        Theme.Gradients.primary
                    } else {
                        backgroundColor
                    }
                }
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: variant == .secondary ? 1.5 : 0)
            )
            .themeShadow(useGradient ? Theme.Shadows.glow : Theme.Shadows.small)
        }
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? 0.6 : 1.0)
        .buttonStyle(RinkuButtonStyle(variant: variant, useGradient: useGradient))
    }
}

struct RinkuButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let useGradient: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        RinkuButton(title: "Primary Button", variant: .primary, size: .large) {}
        RinkuButton(title: "Secondary Button", variant: .secondary, size: .large) {}
        RinkuButton(title: "Ghost Button", variant: .ghost, size: .medium) {}
        RinkuButton(title: "Destructive", variant: .destructive, size: .medium) {}
        RinkuButton(title: "With Icon", icon: "person.fill.badge.plus", variant: .primary) {}
        RinkuButton(title: "Small Button", variant: .secondary, size: .small) {}
        RinkuButton(title: "Loading", isLoading: true) {}
        RinkuButton(title: "Disabled", isDisabled: true) {}
    }
    .padding(24)
    .background(Color(hex: "FAFAFA"))
}
