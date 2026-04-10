import SwiftUI

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    var onWelcomeComplete: (() -> Void)?
    
    @State private var currentPage = 0
    @State private var animateContent = false
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "heart.circle.fill",
            iconColors: [Color(hex: "FF6B6B"), Color(hex: "EE5A5A")],
            title: "Welcome to Rinku",
            subtitle: "A gentle companion for remembering the faces of those you love",
            detail: "Designed with care for those living with memory challenges"
        ),
        OnboardingPage(
            icon: "faceid",
            iconColors: [Theme.Colors.primary, Theme.Colors.primaryDark],
            title: "Recognize Loved Ones",
            subtitle: "Point your camera at someone and Rinku will help you remember who they are",
            detail: "Using advanced face recognition technology"
        ),
        OnboardingPage(
            icon: "person.crop.circle.badge.plus",
            iconColors: [Color(hex: "00B894"), Color(hex: "00997A")],
            title: "Add Your People",
            subtitle: "Add photos of family and friends along with helpful memory prompts",
            detail: "\"This is Mom - she loves gardening and makes the best cookies\""
        ),
        OnboardingPage(
            icon: "speaker.wave.2.fill",
            iconColors: [Color(hex: "9B59B6"), Color(hex: "8E44AD")],
            title: "Audio Reminders",
            subtitle: "Rinku can speak the person's name and your memory notes aloud",
            detail: "Helpful when you need a gentle reminder"
        ),
        OnboardingPage(
            icon: "checkmark.shield.fill",
            iconColors: [Color(hex: "3498DB"), Color(hex: "2980B9")],
            title: "Private & Secure",
            subtitle: "Your photos and data stay on your device and in your private cloud",
            detail: "We never share your information"
        )
    ]
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    pages[currentPage].iconColors[0].opacity(0.15),
                    pages[currentPage].iconColors[1].opacity(0.05),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 50)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            isActive: currentPage == index
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Bottom section
                VStack(spacing: 24) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? pages[currentPage].iconColors[0] : Color.gray.opacity(0.3))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Action button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage += 1
                            }
                        } else {
                            // Welcome pages done - proceed to setup flow
                            if let onComplete = onWelcomeComplete {
                                onComplete()
                            } else {
                                // Fallback for backwards compatibility
                                onboardingManager.completeOnboarding()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: pages[currentPage].iconColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: pages[currentPage].iconColors[0].opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 24)
                    
                    // Back button (if not first page)
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    let detail: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    
    @State private var animateIcon = false
    @State private var animateText = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animated background
            ZStack {
                // Pulsing background circles
                ForEach(0..<3) { i in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    page.iconColors[0].opacity(0.2 - Double(i) * 0.05),
                                    page.iconColors[1].opacity(0.1 - Double(i) * 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160 + CGFloat(i * 40), height: 160 + CGFloat(i * 40))
                        .scaleEffect(animateIcon ? 1.0 : 0.9)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: animateIcon
                        )
                }
                
                // Main icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: page.iconColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: page.iconColors[0].opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: page.icon)
                        .font(.system(size: 56, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(animateIcon ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animateIcon)
                }
            }
            .padding(.bottom, 16)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                
                Text(page.subtitle)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: animateText)
                
                // Detail text in a card
                Text(page.detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(page.iconColors[0])
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(page.iconColors[0].opacity(0.1))
                    )
                    .padding(.horizontal, 40)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: animateText)
            }
            
            Spacer()
            Spacer()
        }
        .onChange(of: isActive) { _, active in
            if active {
                animateIcon = false
                animateText = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6)) {
                        animateIcon = true
                    }
                    withAnimation(.easeOut(duration: 0.5)) {
                        animateText = true
                    }
                }
            }
        }
        .onAppear {
            if isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6)) {
                        animateIcon = true
                    }
                    withAnimation(.easeOut(duration: 0.5)) {
                        animateText = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onboardingManager: OnboardingManager.shared, onWelcomeComplete: {})
}
