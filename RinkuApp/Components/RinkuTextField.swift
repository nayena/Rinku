import SwiftUI

struct RinkuTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var helperText: String? = nil
    var errorText: String? = nil
    var isRequired: Bool = false
    var isMultiline: Bool = false
    var leadingIcon: String? = nil
    var isFocused: Bool = false
    var onTap: (() -> Void)? = nil

    @FocusState private var internalFocus: Bool

    private var hasError: Bool {
        errorText != nil && !errorText!.isEmpty
    }

    private var isActive: Bool {
        isFocused || internalFocus
    }

    private var borderColor: Color {
        if hasError {
            return Theme.Colors.danger
        }
        return isActive ? Theme.Colors.primary : Theme.Colors.borderLight
    }

    private var borderWidth: CGFloat {
        isActive || hasError ? 2 : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(isActive ? Theme.Colors.primary : Theme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if isRequired {
                    Text("*")
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                        .foregroundColor(Theme.Colors.danger)
                }
            }

            // Input Field
            HStack(spacing: 12) {
                if let icon = leadingIcon {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primaryLight)
                            .frame(width: 32, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }

                if isMultiline {
                    TextEditor(text: $text)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(minHeight: 100, maxHeight: 150)
                        .scrollContentBackground(.hidden)
                        .focused($internalFocus)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .focused($internalFocus)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isMultiline ? 14 : 0)
            .frame(minHeight: isMultiline ? nil : 52)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                internalFocus = true
                onTap?()
            }
            .animation(.easeOut(duration: 0.15), value: isActive)
            .onChange(of: isFocused) { _, newValue in
                internalFocus = newValue
            }

            // Helper/Error Text
            if let error = errorText, !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: Theme.FontSize.caption))
                }
                .foregroundColor(Theme.Colors.danger)
            } else if let helper = helperText {
                Text(helper)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            RinkuTextField(
                label: "Full Name",
                text: .constant(""),
                placeholder: "e.g., Gabriela Martinez",
                isRequired: true
            )

            RinkuTextField(
                label: "Familiar Name",
                text: .constant(""),
                placeholder: "e.g., Gabi (optional)",
                helperText: "The name you usually call them"
            )

            RinkuTextField(
                label: "Full Name",
                text: .constant(""),
                placeholder: "Required field",
                errorText: "Full name is required",
                isRequired: true
            )

            RinkuTextField(
                label: "Memory Prompt",
                text: .constant(""),
                placeholder: "e.g., She loves painting...",
                helperText: "A gentle reminder about this person (optional)",
                isMultiline: true
            )

            RinkuTextField(
                label: "Search",
                text: .constant(""),
                placeholder: "Search by name or relationship",
                leadingIcon: "magnifyingglass"
            )
        }
        .padding(24)
    }
    .background(Color(hex: "FAFAFA"))
}
