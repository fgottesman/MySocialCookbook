import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isSignUp = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Email", text: $viewModel.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                Task {
                    if isSignUp {
                        await viewModel.signUp()
                    } else {
                        await viewModel.signIn()
                    }
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(viewModel.isLoading)

            // Social Login Divider
            HStack {
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                Text("OR").font(.caption).foregroundColor(.gray)
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
            }
            .padding(.vertical, 10)

            // Google Sign In
            Button(action: {
                Task { await viewModel.signInWithGoogle() }
            }) {
                HStack {
                    Image(systemName: "globe") // Placeholder for Google Logo
                     Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                .foregroundColor(.black)
            }
            
            // Apple Sign In (Simplified Native Button)
            Button(action: {
                viewModel.startAppleSignIn()
            }) {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Sign in with Apple")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                isSignUp.toggle()
            }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .frame(maxWidth: horizontalSizeClass == .regular ? 400 : .infinity)
        .frame(maxWidth: .infinity)
    }
}
