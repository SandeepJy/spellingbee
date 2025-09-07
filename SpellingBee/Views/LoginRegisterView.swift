import SwiftUI
import shared


struct LoginRegisterView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isRegistering = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 30) {
            // Game Logo
            Image("SpellingBee") // Replace with your actual logo asset
                .resizable()
                .scaledToFit()
                .frame(width: 200,height: 200)
                .padding(.top, 20)
            
            Text(isRegistering ? "Create Account" : "Welcome Back")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 20) {
                if isRegistering {
                    TextField("Username", text: $username)
                        .textFieldStyle(ModernTextFieldStyle())
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(ModernTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(ModernTextFieldStyle())
                
                if let errorMessage = viewModel.authError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if viewModel.isAuthLoading {
                    ProgressView("Please wait...")
                        .font(.caption)
                }
            }
            
            Button(action: handleAuth) {
                Text(isRegistering ? "Sign Up" : "Log In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isAuthLoading ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(viewModel.isAuthLoading)
            
            // Social Login Buttons
            VStack(spacing: 15) {
                SocialLoginButton(icon: "facebook", text: "Continue with Facebook", color: Color.blue)
                SocialLoginButton(icon: "google", text: "Continue with Google", color: Color.red)
            }
            
            Button(action: { isRegistering.toggle() }) {
                Text(isRegistering ? "Already have an account? Log In" : "Need an account? Sign Up")
                    .foregroundColor(.blue)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func handleAuth() {
        if isRegistering {
            viewModel.register(username: username, email: email, password: password)
        } else {
            viewModel.login(email: email, password: password)
        }
    }
}

// Custom TextField Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .foregroundColor(.primary)
    }
}

// Social Login Button Component
struct SocialLoginButton: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        Button(action: {
            // Implement social login later
        }) {
            HStack {
                Image(icon) // Add these assets to your project
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(text)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.9))
            .cornerRadius(12)
        }
    }
}
