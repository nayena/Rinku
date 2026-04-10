import SwiftUI

struct AuthView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    // Allow external control of initial mode and completion callback
    var isSignUp: Bool = false
    var onComplete: (() -> Void)?
    var showCancelButton: Bool = true
    
    @State private var isSignUpMode: Bool = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    init(authService: AuthService, isSignUp: Bool = false, onComplete: (() -> Void)? = nil, showCancelButton: Bool = true) {
        self.authService = authService
        self.isSignUp = isSignUp
        self.onComplete = onComplete
        self.showCancelButton = showCancelButton
        self._isSignUpMode = State(initialValue: isSignUp)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.primary)
                    
                    Text(isSignUpMode ? "Create Account" : "Welcome Back")
                        .font(.system(size: Theme.FontSize.h1, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text(isSignUpMode ? "Sign up to backup your loved ones" : "Sign in to sync your data")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.top, 32)
                
                // Form
                VStack(spacing: 16) {
                    if isSignUpMode {
                        RinkuTextField(
                            label: "Full Name",
                            text: $fullName,
                            placeholder: "Your name",
                            isRequired: true
                        )
                    }
                    
                    RinkuTextField(
                        label: "Email",
                        text: $email,
                        placeholder: "your@email.com",
                        isRequired: true
                    )
                    
                    SecureTextField(
                        label: "Password",
                        text: $password,
                        placeholder: isSignUpMode ? "At least 6 characters" : "Your password"
                    )
                    
                    if isSignUpMode {
                        SecureTextField(
                            label: "Confirm Password",
                            text: $confirmPassword,
                            placeholder: "Re-enter password"
                        )
                    }
                }
                
                // Success message
                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.success)
                        Text(successMessage)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.success)
                        Spacer()
                    }
                    .padding(12)
                    .background(Theme.Colors.successLight)
                    .cornerRadius(8)
                }
                
                // Error message
                if showError {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(Theme.Colors.danger)
                        Text(errorMessage)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.Colors.danger)
                        Spacer()
                    }
                    .padding(12)
                    .background(Theme.Colors.dangerLight)
                    .cornerRadius(8)
                }
                
                // Submit Button
                RinkuButton(
                    title: isSignUpMode ? "Create Account" : "Sign In",
                    variant: .primary,
                    size: .large,
                    isLoading: authService.isLoading,
                    isDisabled: !isFormValid
                ) {
                    Task {
                        await handleSubmit()
                    }
                }
                
                // Toggle auth mode
                HStack {
                    Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Button(isSignUpMode ? "Sign In" : "Sign Up") {
                        withAnimation {
                            isSignUpMode.toggle()
                            showError = false
                        }
                    }
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCancelButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                if let onComplete = onComplete {
                    onComplete()
                } else {
                    dismiss()
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if isSignUpMode {
            return !email.isEmpty && !password.isEmpty && !fullName.isEmpty && 
                   password == confirmPassword && password.count >= 6
        }
        return !email.isEmpty && !password.isEmpty
    }
    
    private func handleSubmit() async {
        showError = false
        showSuccess = false
        
        do {
            if isSignUpMode {
                try await authService.signUp(email: email, password: password, fullName: fullName)
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch AuthError.emailConfirmationRequired {
            // Show success message and switch to sign-in mode
            successMessage = "Account created! Check your email to confirm, then sign in."
            showSuccess = true
            isSignUpMode = false
        } catch let error as AuthError {
            errorMessage = error.errorDescription ?? "An error occurred"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Secure Text Field

struct SecureTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("*")
                    .foregroundColor(Theme.Colors.danger)
            }
            
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
                
                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(16)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
        }
    }
}

#Preview {
    AuthView(authService: AuthService.shared)
}
