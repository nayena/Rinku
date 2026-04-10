import SwiftUI

struct StatusBarView: View {
    let type: StatusType
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(type.foregroundColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: type.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(type.foregroundColor)
            }

            Text(message)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(type.foregroundColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(type.backgroundColor)
        .cornerRadius(Theme.CornerRadius.pill)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                .stroke(type.foregroundColor.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBarView(type: .info, message: "Loading models...")
        StatusBarView(type: .success, message: "Ready to recognize")
        StatusBarView(type: .warning, message: "Person not recognized")
        StatusBarView(type: .danger, message: "Error occurred")
    }
    .padding(24)
    .background(Color(hex: "FAFAFA"))
}
