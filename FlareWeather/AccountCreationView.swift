import SwiftUI

struct AccountCreationView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var onSignupSuccess: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create your account")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("We’ll save your preferences and personalize your insights.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                
                VStack(spacing: 20) {
                    inputField(title: "Name (optional)", placeholder: "Your name", text: $name, contentType: .name)
                    inputField(title: "Email", placeholder: "you@email.com", text: $email, contentType: .emailAddress, keyboardType: .emailAddress)
                    secureField(title: "Password", placeholder: "Create a password", text: $password)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.interCaption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: createAccount) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(Color.adaptiveText)
                            } else {
                                Text("Create Account")
                                    .font(.interBody.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity(isLoading || email.isEmpty || password.isEmpty ? 0.6 : 1)
                }
                .padding(20)
                .cardStyle()
                .padding(.horizontal, 20)
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Account Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, contentType: UITextContentType, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 12)
                }
                TextField("", text: text)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .tint(Color.adaptiveText)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .autocapitalization(contentType == .emailAddress ? .none : .words)
                    .padding(12)
            }
            .background(Color.adaptiveBackground)
            .cornerRadius(12)
        }
    }
    
    private func secureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 12)
                }
                SecureField("", text: text)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .tint(Color.adaptiveText)
                    .textContentType(.password)
                    .padding(12)
            }
            .background(Color.adaptiveBackground)
            .cornerRadius(12)
        }
    }
    
    private func createAccount() {
        guard !email.isEmpty, !password.isEmpty else { return }
        errorMessage = nil
        isLoading = true
        
        Task { @MainActor in
            do {
                try await authManager.signup(email: email, password: password, name: name.isEmpty ? nil : name)
                let resolvedName = name.isEmpty ? "User" : name
                onSignupSuccess(resolvedName)
                dismiss()
            } catch {
                errorMessage = (error as? AuthError)?.localizedDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationView {
        AccountCreationView(onSignupSuccess: { _ in })
            .environmentObject(AuthManager())
    }
}

