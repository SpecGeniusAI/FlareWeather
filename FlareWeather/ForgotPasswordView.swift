import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var showCodeEntry = false
    @FocusState private var isFieldFocused: Bool
    
    private let authService = AuthService()
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reset your password")
                            .font(.interTitle)
                            .foregroundColor(Color.adaptiveText)
                            .lineSpacing(4)
                        
                        Text("Enter the email tied to your account. We’ll send instructions to create a new password.")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                            .lineSpacing(4)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                            
                            ZStack(alignment: .leading) {
                                if email.isEmpty {
                                    Text("you@email.com")
                                        .font(.interBody)
                                        .foregroundColor(Color.adaptiveMuted)
                                        .padding(.horizontal, 12)
                                }
                                TextField("", text: $email)
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveText)
                                    .tint(Color.adaptiveText)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(12)
                                    .focused($isFieldFocused)
                            }
                            .background(Color.adaptiveBackground)
                            .cornerRadius(12)
                        }
                        
                        if let successMessage {
                            Text(successMessage)
                                .font(.interCaption)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.interCaption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Button(action: submit) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(Color.adaptiveText)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.interBody.bold())
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || email.isEmpty)
                        .opacity(isLoading || email.isEmpty ? 0.6 : 1)
                        
                        Button("Enter reset code") {
                            showCodeEntry = true
                        }
                        .font(.interBody.weight(.semibold))
                        .foregroundColor(Color.adaptiveText)
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .cardStyle()
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.adaptiveText)
                }
            }
            .navigationDestination(isPresented: $showCodeEntry) {
                ResetPasswordCodeView(
                    initialEmail: email,
                    onSuccess: {
                        // Dismiss this view (ForgotPasswordView) when password is reset
                        dismiss()
                    }
                )
            }
            .tint(Color.adaptiveText)
        }
    
    private func submit() {
        guard !email.isEmpty else { return }
        successMessage = nil
        errorMessage = nil
        isLoading = true
        Task { @MainActor in
            do {
                try await authService.forgotPassword(email: email)
                successMessage = "If an account exists, we've emailed a reset code. Please check your junk mail or spam folders if you don't see it."
                isFieldFocused = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ForgotPasswordView()
}

