import SwiftUI
import UIKit

struct Theme {
    // MARK: - Colors (Adaptive for Light/Dark Mode)
    struct Colors {
        // Primary Purple Palette - These stay vibrant in both modes
        static let primary = Color(hex: "8B5CF6")
        static let primaryDark = Color(hex: "7C3AED")

        // Primary Light - Adapts to dark mode
        static let primaryLight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 0.2)
                : UIColor(red: 243/255, green: 232/255, blue: 255/255, alpha: 1.0)
        })

        // Secondary/Accent Colors
        static let accent = Color(hex: "A855F7")
        static let accentLight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 168/255, green: 85/255, blue: 247/255, alpha: 0.2)
                : UIColor(red: 233/255, green: 213/255, blue: 255/255, alpha: 1.0)
        })

        // Gradient Colors - Slightly brighter in dark mode for pop
        static let gradientStart = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 147/255, green: 112/255, blue: 255/255, alpha: 1.0)
                : UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 1.0)
        })
        static let gradientMiddle = Color(hex: "A855F7")
        static let gradientEnd = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 232/255, green: 90/255, blue: 255/255, alpha: 1.0)
                : UIColor(red: 217/255, green: 70/255, blue: 239/255, alpha: 1.0)
        })

        // Semantic Colors - Slightly adjusted for dark mode visibility
        static let success = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 52/255, green: 211/255, blue: 153/255, alpha: 1.0)
                : UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)
        })
        static let warning = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0)
                : UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)
        })
        static let danger = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 248/255, green: 113/255, blue: 113/255, alpha: 1.0)
                : UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)
        })

        // Text Colors - Fully adaptive
        static let textPrimary = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 249/255, green: 250/255, blue: 251/255, alpha: 1.0)
                : UIColor(red: 31/255, green: 41/255, blue: 55/255, alpha: 1.0)
        })
        static let textSecondary = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1.0)
                : UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)
        })
        static let textMuted = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0)
                : UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1.0)
        })

        // UI Colors - Adaptive backgrounds and borders
        static let border = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 55/255, green: 65/255, blue: 81/255, alpha: 1.0)
                : UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0)
        })
        static let borderLight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1.0)
                : UIColor(red: 243/255, green: 244/255, blue: 246/255, alpha: 1.0)
        })
        static let background = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 17/255, green: 24/255, blue: 39/255, alpha: 1.0)
                : UIColor(red: 250/255, green: 250/255, blue: 250/255, alpha: 1.0)
        })
        static let cardBackground = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 31/255, green: 41/255, blue: 55/255, alpha: 1.0)
                : UIColor.white
        })
        static let surfaceElevated = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1.0)
                : UIColor.white
        })

        // Light Backgrounds - Adaptive opacity
        static let successLight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15)
                : UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.1)
        })
        static let warningLight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.15)
                : UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.1)
        })
        static let dangerLight = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.15)
                : UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.1)
        })
    }

    // MARK: - Gradients (Adaptive)
    struct Gradients {
        static let primary = LinearGradient(
            colors: [Colors.gradientStart, Colors.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let primaryVertical = LinearGradient(
            colors: [Colors.gradientStart, Colors.gradientEnd],
            startPoint: .top,
            endPoint: .bottom
        )

        static let primaryHorizontal = LinearGradient(
            colors: [Colors.gradientStart, Colors.gradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let subtle = LinearGradient(
            colors: [Colors.primaryLight, Colors.accentLight.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let card = LinearGradient(
            colors: [Colors.cardBackground, Colors.primaryLight.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )

        static let headerBackground = LinearGradient(
            colors: [Colors.gradientStart.opacity(0.15), Colors.gradientEnd.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shadows (Adaptive)
    struct Shadows {
        static var small: ShadowStyle {
            ShadowStyle(
                color: Color(UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark
                        ? UIColor.black.withAlphaComponent(0.3)
                        : UIColor.black.withAlphaComponent(0.05)
                }),
                radius: 4,
                y: 2
            )
        }

        static var medium: ShadowStyle {
            ShadowStyle(
                color: Color(UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark
                        ? UIColor.black.withAlphaComponent(0.4)
                        : UIColor.black.withAlphaComponent(0.08)
                }),
                radius: 8,
                y: 4
            )
        }

        static var large: ShadowStyle {
            ShadowStyle(
                color: Color(UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark
                        ? UIColor.black.withAlphaComponent(0.5)
                        : UIColor.black.withAlphaComponent(0.1)
                }),
                radius: 16,
                y: 8
            )
        }

        static let glow = ShadowStyle(color: Colors.primary.opacity(0.4), radius: 12, y: 0)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 100
    }

    // MARK: - Font Sizes
    struct FontSize {
        static let caption: CGFloat = 13
        static let body: CGFloat = 16
        static let h3: CGFloat = 18
        static let h2: CGFloat = 22
        static let h1: CGFloat = 32
        static let display: CGFloat = 40
    }
}

// MARK: - Shadow Style Helper
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

// MARK: - View Extension for Shadows
extension View {
    func themeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }

    func cardStyle() -> some View {
        self
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .themeShadow(Theme.Shadows.small)
    }

    func elevatedCardStyle() -> some View {
        self
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .themeShadow(Theme.Shadows.medium)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
