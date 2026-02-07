import SwiftUI
import Combine

/// Manages the complete setup flow: Auth → Role Selection → Family Setup
struct SetupFlowView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var familyService = FamilyService.shared
    
    @State private var currentStep: SetupStep = .auth
    @State private var selectedRole: UserRole?
    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdFamily: Family?
    
    enum SetupStep {
        case auth
        case roleSelection
        case familySetup  // For caregivers - create family
        case joinFamily   // For patients - enter invite code
        case addLovedOnes // Prompt caregiver to add people
        case complete
    }
    
    enum UserRole {
        case forMyself    // Patient - needs help remembering
        case forSomeone   // Caregiver - helping someone else
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Theme.Colors.primaryLight,
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Progress indicator
                if currentStep != .auth {
                    SetupProgressView(currentStep: currentStep)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                }
                
                // Content
                Group {
                    switch currentStep {
                    case .auth:
                        authStepView
                    case .roleSelection:
                        roleSelectionView
                    case .familySetup:
                        familySetupView
                    case .joinFamily:
                        joinFamilyView
                    case .addLovedOnes:
                        addLovedOnesPromptView
                    case .complete:
                        completeView
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4), value: currentStep)
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            // When user signs in and we're still on auth step, move to role selection
            if isSignedIn && currentStep == .auth {
                // Update user ID for setup tracking
                if let userId = authService.currentUser?.id {
                    onboardingManager.checkSetupStatus(for: userId)
                }
                withAnimation {
                    currentStep = .roleSelection
                }
            }
        }
        .onAppear {
            // If already signed in, skip to role selection
            if authService.isSignedIn {
                if let userId = authService.currentUser?.id {
                    onboardingManager.checkSetupStatus(for: userId)
                }
                if currentStep == .auth {
                    currentStep = .roleSelection
                }
            }
        }
    }
    
    // MARK: - Auth Step
    
    private var authStepView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryLight)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(Theme.Colors.primary)
            }
            
            VStack(spacing: 12) {
                Text("Create Your Account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Sign up to keep your data safe and sync across devices")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Auth buttons
            VStack(spacing: 12) {
                NavigationLink {
                    AuthView(authService: authService, isSignUp: true, showCancelButton: false)
                } label: {
                    Text("Create Account")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.Colors.primary)
                        .cornerRadius(16)
                }
                
                NavigationLink {
                    AuthView(authService: authService, isSignUp: false, showCancelButton: false)
                } label: {
                    Text("I Already Have an Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Role Selection
    
    private var roleSelectionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Who is Rinku for?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("This helps us personalize your experience")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            VStack(spacing: 16) {
                // For myself option
                RoleOptionCard(
                    icon: "person.fill",
                    iconColor: Theme.Colors.primary,
                    title: "For Me",
                    subtitle: "I need help remembering the faces of people I know",
                    isSelected: selectedRole == .forMyself
                ) {
                    selectedRole = .forMyself
                }
                
                // For someone else option
                RoleOptionCard(
                    icon: "heart.fill",
                    iconColor: Color(hex: "E63946"),
                    title: "For Someone I Care For",
                    subtitle: "I'm helping a family member or friend set this up",
                    isSelected: selectedRole == .forSomeone
                ) {
                    selectedRole = .forSomeone
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            VStack(spacing: 16) {
                Button {
                    withAnimation {
                        if selectedRole == .forMyself {
                            currentStep = .joinFamily
                        } else {
                            currentStep = .familySetup
                        }
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedRole != nil ? Theme.Colors.primary : Color.gray.opacity(0.3))
                        .cornerRadius(16)
                }
                .disabled(selectedRole == nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Family Setup (Caregiver)
    
    private var familySetupView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Theme.Colors.successLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.success)
            }
            
            VStack(spacing: 12) {
                Text("Create a Family Circle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("This lets you share contacts with the person you're helping")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Family name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextField("e.g., Grandma's Care Circle", text: $familyName)
                    .font(.system(size: 16))
                    .padding(16)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.danger)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Create button
            VStack(spacing: 16) {
                Button {
                    createFamily()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Family")
                        }
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(familyName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Theme.Colors.primary)
                    .cornerRadius(16)
                }
                .disabled(familyName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                
                Button {
                    // Skip family setup
                    withAnimation {
                        currentStep = .addLovedOnes
                    }
                } label: {
                    Text("Skip for Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Join Family (Patient)
    
    private var joinFamilyView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.primary)
            }
            
            VStack(spacing: 12) {
                Text("Join Your Family")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("If a family member set up Rinku for you, enter their invite code")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Invite code input
            VStack(alignment: .leading, spacing: 8) {
                Text("Invite Code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextField("ABC123", text: $inviteCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .onChange(of: inviteCode) { _, newValue in
                        inviteCode = String(newValue.uppercased().prefix(6))
                    }
            }
            .padding(.horizontal, 24)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.danger)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Join button
            VStack(spacing: 16) {
                Button {
                    joinFamily()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Join Family")
                        }
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(inviteCode.count == 6 ? Theme.Colors.primary : Color.gray.opacity(0.3))
                    .cornerRadius(16)
                }
                .disabled(inviteCode.count != 6 || isLoading)
                
                Button {
                    // Skip - no family
                    withAnimation {
                        currentStep = .complete
                    }
                } label: {
                    Text("I Don't Have a Code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Add Loved Ones Prompt (Caregiver)
    
    private var addLovedOnesPromptView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            if let family = createdFamily {
                // Show invite code prominently
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.successLight)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.Colors.success)
                    }
                    
                    Text("Family Created!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    // Invite code card
                    VStack(spacing: 8) {
                        Text("Share this code with your loved one")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text(family.inviteCode)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.primary)
                            .tracking(8)
                        
                        Button {
                            UIPasteboard.general.string = family.inviteCode
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Code")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.primary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
                }
                .padding(.horizontal, 24)
            }
            
            VStack(spacing: 12) {
                Text("Now Add Some Faces")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Add photos of family members so they can be recognized")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Continue button
            Button {
                withAnimation {
                    currentStep = .complete
                }
            } label: {
                Text("Continue to App")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.Colors.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Complete
    
    private var completeView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Theme.Colors.successLight)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.success)
            }
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(selectedRole == .forMyself
                     ? "Point your camera at someone to recognize them"
                     : "Start adding photos of people your loved one knows")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            Button {
                onboardingManager.completeSetup()
            } label: {
                Text("Start Using Rinku")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.Colors.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Actions
    
    private func createFamily() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let family = try await familyService.createFamily(
                    name: familyName.trimmingCharacters(in: .whitespaces),
                    role: .caregiver
                )
                createdFamily = family
                withAnimation {
                    currentStep = .addLovedOnes
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func joinFamily() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await familyService.joinFamily(inviteCode: inviteCode, role: .patient)
                withAnimation {
                    currentStep = .complete
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Role Option Card

struct RoleOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? iconColor : Theme.Colors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? iconColor : Theme.Colors.border, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? iconColor.opacity(0.2) : Color.clear, radius: 8, y: 4)
        }
    }
}

// MARK: - Setup Progress View

struct SetupProgressView: View {
    let currentStep: SetupFlowView.SetupStep
    
    private var stepIndex: Int {
        switch currentStep {
        case .auth: return 0
        case .roleSelection: return 1
        case .familySetup, .joinFamily: return 2
        case .addLovedOnes: return 3
        case .complete: return 4
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index <= stepIndex ? Theme.Colors.primary : Theme.Colors.border)
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SetupFlowView(onboardingManager: OnboardingManager.shared)
    }
}
