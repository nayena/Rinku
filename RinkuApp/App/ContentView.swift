import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var authService = AuthService.shared
    @State private var selectedTab: TabItem = .home

    var body: some View {
        Group {
            if !onboardingManager.hasSeenWelcome {
                // First time: show welcome pages
                OnboardingView(onboardingManager: onboardingManager, onWelcomeComplete: {
                    withAnimation {
                        onboardingManager.completeWelcome()
                    }
                })
                .transition(.opacity)
            } else if !authService.isSignedIn {
                // Not signed in: show auth
                NavigationView {
                    SetupFlowView(onboardingManager: onboardingManager)
                }
            } else if !onboardingManager.hasCompletedSetup {
                // Signed in but hasn't done role/family setup
                NavigationView {
                    SetupFlowView(onboardingManager: onboardingManager)
                }
            } else {
                // Fully setup: show main app
                mainAppView
            }
        }
        .animation(.easeInOut(duration: 0.4), value: onboardingManager.hasSeenWelcome)
        .animation(.easeInOut(duration: 0.4), value: authService.isSignedIn)
        .animation(.easeInOut(duration: 0.4), value: onboardingManager.hasCompletedSetup)
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn, let userId = authService.currentUser?.id {
                // Check this user's setup status
                onboardingManager.checkSetupStatus(for: userId)
            } else {
                // User signed out
                onboardingManager.handleSignOut()
            }
        }
        .onAppear {
            // Check setup status on launch if already signed in
            if authService.isSignedIn, let userId = authService.currentUser?.id {
                onboardingManager.checkSetupStatus(for: userId)
            }
        }
    }
    
    private var mainAppView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background that extends to all edges
                Theme.Colors.background
                    .ignoresSafeArea(.all)

                // Main Content
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView(selectedTab: $selectedTab)
                    case .lovedOnes:
                        LovedOnesView(store: store, selectedTab: $selectedTab)
                    case .add:
                        AddLovedOneView(store: store, selectedTab: $selectedTab)
                    case .recognize:
                        RecognizeView(store: store, selectedTab: $selectedTab)
                    case .profile:
                        ProfileView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Tab Bar with solid background
                TabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview("Main App") {
    let manager = OnboardingManager.shared
    manager.completeOnboarding()
    return ContentView()
}

#Preview("Onboarding") {
    OnboardingView(onboardingManager: OnboardingManager.shared, onWelcomeComplete: {})
}
