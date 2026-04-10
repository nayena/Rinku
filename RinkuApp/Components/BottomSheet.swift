import SwiftUI

struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if isPresented {
                    // Backdrop
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isPresented = false
                            }
                        }

                    // Sheet
                    VStack(spacing: 0) {
                        // Handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 48, height: 4)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        // Header
                        HStack {
                            Text(title)
                                .font(.system(size: Theme.FontSize.h2, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)

                            Spacer()

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)

                        Divider()
                            .background(Theme.Colors.border)

                        // Content
                        ScrollView {
                            content
                                .padding(24)
                        }
                        .frame(maxHeight: geometry.size.height * 0.6)
                    }
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.large, corners: [.topLeft, .topRight])
                    .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.easeInOut(duration: 0.25), value: isPresented)
        }
    }
}

// Corner Radius Extension for specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        BottomSheet(isPresented: .constant(true), title: "Choose person to enroll") {
            VStack(spacing: 12) {
                Text("Sheet Content")
                Text("More content here")
            }
        }
    }
}
