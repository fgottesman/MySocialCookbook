import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        ZStack {
            Color.clipCookBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.Layout.spacing24) {
                    Spacer(minLength: 40)

                    // Header
                    VStack(spacing: DesignTokens.Layout.spacing12) {
                        Image(systemName: isSignUp ? "person.badge.plus" : "person.crop.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(LinearGradient.roseGold)

                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(DesignTokens.Typography.headerFont(size: 28))
                            .foregroundColor(.clipCookTextPrimary)
                    }
                    .padding(.bottom, DesignTokens.Layout.spacing8)

                    // Form fields
                    VStack(spacing: DesignTokens.Layout.spacing16) {
                        AuthTextField(
                            placeholder: "Email",
                            text: $viewModel.email,
                            icon: "envelope.fill"
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                        AuthSecureField(
                            placeholder: "Password",
                            text: $viewModel.password,
                            icon: "lock.fill"
                        )
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(DesignTokens.Typography.captionFont())
                            .foregroundColor(.red)
                    }

                    // Primary action button
                    Button(action: {
                        Task {
                            if isSignUp {
                                await viewModel.signUp()
                            } else {
                                await viewModel.signIn()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.clipCookBackground)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Layout.spacing16)
                        .background(LinearGradient.roseGold)
                        .foregroundColor(.clipCookBackground)
                        .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
                    }
                    .disabled(viewModel.isLoading)

                    // Divider
                    HStack(spacing: DesignTokens.Layout.spacing12) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.clipCookTextSecondary.opacity(0.3))
                        Text("OR")
                            .font(DesignTokens.Typography.captionFont())
                            .foregroundColor(.clipCookTextSecondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.clipCookTextSecondary.opacity(0.3))
                    }
                    .padding(.vertical, DesignTokens.Layout.spacing8)

                    // Social buttons
                    VStack(spacing: DesignTokens.Layout.spacing12) {
                        // Google
                        Button(action: {
                            Task { await viewModel.signInWithGoogle() }
                        }) {
                            HStack(spacing: DesignTokens.Layout.spacing12) {
                                Image(systemName: "globe")
                                Text("Continue with Google")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Layout.spacing16)
                            .background(Color.clipCookSurface)
                            .foregroundColor(.clipCookTextPrimary)
                            .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusMedium)
                                    .stroke(Color.clipCookTextSecondary.opacity(0.3), lineWidth: 1)
                            )
                        }

                        // Apple
                        Button(action: {
                            viewModel.startAppleSignIn()
                        }) {
                            HStack(spacing: DesignTokens.Layout.spacing12) {
                                Image(systemName: "apple.logo")
                                Text("Continue with Apple")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Layout.spacing16)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
                        }
                    }

                    Spacer(minLength: 20)

                    // Toggle auth mode
                    Button(action: { isSignUp.toggle() }) {
                        Group {
                            if isSignUp {
                                Text("Already have an account? ") +
                                Text("Sign In").fontWeight(.semibold)
                            } else {
                                Text("Don't have an account? ") +
                                Text("Sign Up").fontWeight(.semibold)
                            }
                        }
                        .font(DesignTokens.Typography.captionFont())
                        .foregroundColor(.clipCookTextSecondary)
                    }
                    .padding(.bottom, DesignTokens.Layout.spacing24)
                }
                .padding(.horizontal, DesignTokens.Layout.spacing20)
                .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Custom Input Components

private struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignTokens.Layout.spacing12) {
            Image(systemName: icon)
                .foregroundColor(.clipCookTextSecondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(.clipCookTextPrimary)
        }
        .padding(DesignTokens.Layout.spacing16)
        .background(Color.clipCookSurface)
        .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusMedium)
                .stroke(Color.clipCookTextSecondary.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct AuthSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: DesignTokens.Layout.spacing12) {
            Image(systemName: icon)
                .foregroundColor(.clipCookTextSecondary)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .foregroundColor(.clipCookTextPrimary)

            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.clipCookTextSecondary)
            }
        }
        .padding(DesignTokens.Layout.spacing16)
        .background(Color.clipCookSurface)
        .cornerRadius(DesignTokens.Layout.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusMedium)
                .stroke(Color.clipCookTextSecondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView()
}
