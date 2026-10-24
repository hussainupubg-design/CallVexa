import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthSessionManager.shared
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isAgentMode: Bool = false
    @State private var isLoading: Bool = false
    @State private var totpCode: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 30)
                
                // Brand Logo & Heading
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cvPrimary, Color.cvCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.cvPrimary.opacity(0.4), radius: 16, x: 0, y: 8)
                        
                        Image(systemName: "phone.bubble.left.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    
                    Text("CallVexa")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.cvTextPrimary)
                    
                    Text("Cloud Call Center & Dialer")
                        .font(.system(size: 14))
                        .foregroundColor(.cvTextSecondary)
                }
                .padding(.bottom, 8)
                
                // Login Role Selector
                Picker("Account Type", selection: $isAgentMode) {
                    Text("Admin Login").tag(false)
                    Text("Agent Login").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                
                // Login Card Form
                VStack(spacing: 16) {
                    if let error = authManager.errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.cvRed)
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.cvRed)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.cvRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cvRed.opacity(0.25), lineWidth: 1)
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email Address")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.cvTextSecondary)
                        
                        CallVexaTextField(
                            placeholder: isAgentMode ? "agent@callvexa.us" : "admin@callvexa.us",
                            text: $email,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.cvTextSecondary)
                        
                        CallVexaTextField(
                            placeholder: "••••••••••••",
                            text: $password,
                            icon: "lock.fill",
                            isSecure: true
                        )
                    }
                    
                    if authManager.requiresTotp {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Authenticator 2FA Code")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.cvCyan)
                            
                            CallVexaTextField(
                                placeholder: "6-digit code",
                                text: $totpCode,
                                icon: "shield.lefthalf.filled",
                                keyboardType: .numberPad
                            )
                        }
                    }
                    
                    CallVexaButton(
                        title: authManager.requiresTotp ? "Verify & Sign In" : (isAgentMode ? "Sign In as Agent" : "Sign In to Admin"),
                        icon: "arrow.right.circle.fill",
                        variant: .primary,
                        isLoading: isLoading
                    ) {
                        handleLogin()
                    }
                    .padding(.top, 8)
                }
                .cvCard(padding: 24)
                .padding(.horizontal, 20)
                
                Spacer()
                
                AttributionFooter()
            }
        }
        .cvBackground()
    }
    
    private func handleLogin() {
        guard !email.isEmpty && !password.isEmpty else { return }
        isLoading = true
        
        Task {
            if authManager.requiresTotp {
                _ = await authManager.submitTotpCode(totpCode)
            } else if isAgentMode {
                _ = await authManager.loginAgent(email: email, password: password)
            } else {
                _ = await authManager.loginAdmin(email: email, password: password)
            }
            isLoading = false
        }
    }
}
