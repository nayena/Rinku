import SwiftUI

enum ToastType {
    case success
    case error
    case info

    var backgroundColor: Color {
        switch self {
        case .success:
            return Theme.Colors.success
        case .error:
            return Theme.Colors.danger
        case .info:
            return Theme.Colors.primary
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

struct ToastView: View {
    let type: ToastType
    let message: String
    var duration: Double = 3.0
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible = true

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))

                Text(message)
                    .font(.system(size: Theme.FontSize.body))
                    .lineLimit(2)

                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(type.backgroundColor)
            .cornerRadius(Theme.CornerRadius.medium)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .frame(minWidth: 280, maxWidth: 400)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onDismiss?()
                    }
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct ToastContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            content
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack(spacing: 16) {
            ToastView(type: .success, message: "Loved one added successfully!")
            ToastView(type: .error, message: "Something went wrong")
        }
        .padding()
    }
}
