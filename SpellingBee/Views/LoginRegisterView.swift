import SwiftUI
import shared

struct LoginRegisterView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isRegistering = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo placeholder
            Image(systemName: "book.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
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
                
                if let error = viewModel.authError ?? errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Button(action: handleAuth) {
                if viewModel.isAuthLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isRegistering ? "Sign Up" : "Log In")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.blue)
            .cornerRadius(12)
            .disabled(viewModel.isAuthLoading)
            
            Button(action: { isRegistering.toggle() }) {
                Text(isRegistering ? "Already have an account? Log In" : "Need an account? Sign Up")
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func handleAuth() {
        viewModel.clearErrors()
        if isRegistering {
            viewModel.register(username: username, email: email, password: password)
        } else {
            viewModel.login(email: email, password: password)
        }
    }
}
