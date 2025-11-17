import SwiftUI
import UIKit

struct ResetPasswordCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    
    private let authService = AuthService()
    
    enum Field: Hashable {
        case email, code, newPassword, confirmPassword
    }
    
    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter your reset code")
                            .font(.interTitle)
                            .foregroundColor(Color.adaptiveText)
                            .lineSpacing(4)
                        
                        Text("Check your inbox for the 6-digit code. Enter it below along with a new password.")
                            .font(.interBody)
                            .foregroundColor(Color.adaptiveMuted)
                            .lineSpacing(4)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 18) {
                        InputField(
                            title: "Email",
                            placeholder: "your@email.com",
                            text: $email,
                            keyboard: .emailAddress,
                            contentType: .emailAddress,
                            focusedField: _focusedField,
                            field: .email
                        )
                        
                        InputField(
                            title: "Reset Code",
                            placeholder: "123456",
                            text: $code,
                            keyboard: .numberPad,
                            contentType: .oneTimeCode,
                            focusedField: _focusedField,
                            field: .code
                        )
                        
                        SecureInputField(
                            title: "New Password",
                            placeholder: "At least 8 characters",
                            text: $newPassword,
                            contentType: .newPassword,
                            focusedField: _focusedField,
                            field: .newPassword
                        )
                        
                        SecureInputField(
                            title: "Confirm Password",
                            placeholder: "Re-enter new password",
                            text: $confirmPassword,
                            contentType: .newPassword,
                            focusedField: _focusedField,
                            field: .confirmPassword
                        )
                        
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
                        
                        Button(action: handleReset) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(Color.adaptiveText)
                                } else {
                                    Text("Reset Password")
                                        .font(.interBody.bold())
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || !isFormValid)
                        .opacity(isLoading || !isFormValid ? 0.6 : 1)
                    }
                    .padding(20)
                    .cardStyle()
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.adaptiveText)
                }
            }
        }
        .tint(Color.adaptiveText)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        code.count == 6 &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword
    }
    
    @MainActor
    private func handleReset() {
        guard isFormValid else {
            errorMessage = "Please complete all fields."
            return
        }
        successMessage = nil
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                try await authService.resetPassword(email: email, code: code, newPassword: newPassword)
                successMessage = "Password updated. You can log in now."
                focusedField = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription.isEmpty ? "That code is incorrect or has expired." : error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct InputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let contentType: UITextContentType
    @FocusState var focusedField: ResetPasswordCodeView.Field?
    let field: ResetPasswordCodeView.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 12)
                }
                TextField("", text: $text)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .tint(Color.adaptiveText)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .autocapitalization(.none)
                    .padding(12)
                    .focused($focusedField, equals: field)
            }
            .background(Color.adaptiveBackground)
            .cornerRadius(12)
        }
    }
}

private struct SecureInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let contentType: UITextContentType
    @FocusState var focusedField: ResetPasswordCodeView.Field?
    let field: ResetPasswordCodeView.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 12)
                }
                SecureField("", text: $text)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .tint(Color.adaptiveText)
                    .textContentType(contentType)
                    .padding(12)
                    .focused($focusedField, equals: field)
            }
            .background(Color.adaptiveBackground)
            .cornerRadius(12)
        }
    }
}

#Preview {
    ResetPasswordCodeView()
}

