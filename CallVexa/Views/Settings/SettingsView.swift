import SwiftUI

struct SettingsView: View {
    @ObservedObject var authManager = AuthSessionManager.shared
    @ObservedObject var pushManager = PushKitManager.shared
    
    @State private var settings: [String: String] = [:]
    @State private var twilioAccount: TwilioAccountResponse? = nil
    @State private var emergencyStop: Bool = false
    @State private var dailyCallLimit: String = "50"
    @State private var dailySpendLimit: String = "10"
    @State private var callerId: String = ""
    @State private var isSaving: Bool = false
    @State private var showSavedToast: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PageHeaderView(title: "Settings", subtitle: "Telephony engine & account controls")
                
                // Account Profile Card
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.cvPrimary.opacity(0.2))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: authManager.currentUser?.isAdmin == true ? "crown.fill" : "person.fill")
                                .foregroundColor(.cvPrimaryLight)
                                .font(.system(size: 22))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.currentUser?.displayName ?? "User")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cvTextPrimary)
                        
                        HStack(spacing: 8) {
                            StatusPill(
                                text: authManager.currentUser?.roleBadge ?? "Member",
                                color: .cvCyan
                            )
                            Text(authManager.currentUser?.email ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.cvTextSecondary)
                        }
                    }
                    Spacer()
                }
                .cvCard(padding: 16)
                .padding(.horizontal, 16)
                
                // Twilio Account Status Card
                if let tw = twilioAccount {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Carrier Connection (Twilio)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.cvTextPrimary)
                        
                        HStack {
                            Text("Account Status")
                                .foregroundColor(.cvTextSecondary)
                                .font(.system(size: 13))
                            Spacer()
                            StatusPill(text: (tw.status ?? "Active").uppercased(), color: .cvGreen)
                        }
                        
                        if let bal = tw.balance?.amount {
                            HStack {
                                Text("Carrier Balance")
                                    .foregroundColor(.cvTextSecondary)
                                    .font(.system(size: 13))
                                Spacer()
                                Text("$\(bal) \(tw.balance?.currency ?? "USD")")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cvGreenLight)
                            }
                        }
                    }
                    .cvCard(padding: 16)
                    .padding(.horizontal, 16)
                }
                
                // Voice Protection Controls (Admin only)
                if authManager.currentUser?.isAdmin == true {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Calling & Spending Limits")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.cvTextPrimary)
                        
                        // Emergency Stop Toggle
                        Toggle(isOn: $emergencyStop) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Emergency Stop")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(emergencyStop ? .cvRed : .cvTextPrimary)
                                Text("Immediately halts all outbound dialing.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.cvTextSecondary)
                            }
                        }
                        .tint(.cvRed)
                        
                        Divider().background(Color.cvBorder)
                        
                        // Caller ID field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Default Caller ID (+15551234567)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                            CallVexaTextField(placeholder: "+1...", text: $callerId, icon: "phone.fill")
                        }
                        
                        // Daily Call Limit
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Daily Call Limit")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                            CallVexaTextField(placeholder: "50", text: $dailyCallLimit, icon: "number", keyboardType: .numberPad)
                        }
                        
                        // Daily Spend Limit
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Daily Spend Limit (USD)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                            CallVexaTextField(placeholder: "10.00", text: $dailySpendLimit, icon: "dollarsign.circle", keyboardType: .decimalPad)
                        }
                        
                        CallVexaButton(
                            title: showSavedToast ? "Saved!" : "Save Voice Settings",
                            icon: showSavedToast ? "checkmark" : "square.and.arrow.down.fill",
                            variant: showSavedToast ? .success : .primary,
                            isLoading: isSaving
                        ) {
                            saveVoiceSettings()
                        }
                        .padding(.top, 4)
                    }
                    .cvCard(padding: 16)
                    .padding(.horizontal, 16)
                }
                
                // VoIP Push & Phase 2 Diagnostic Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.cvCyan)
                        Text("Phase 2 — VoIP Push Status")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.cvTextPrimary)
                        Spacer()
                    }
                    
                    Text("Incoming calls over PushKit require an APNs VoIP Services certificate uploaded to Twilio Console.")
                        .font(.system(size: 12))
                        .foregroundColor(.cvTextSecondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PushKit Code:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                            Spacer()
                            Text("Complete & Integrated")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cvGreen)
                        }
                        
                        HStack {
                            Text("VoIP Token:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                            Spacer()
                            Text(pushManager.voipPushToken != nil ? "Captured" : "Pending Device APNs")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(pushManager.voipPushToken != nil ? .cvGreen : .cvAmber)
                        }
                        
                        HStack {
                            Text("Twilio Push Credential:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                            Spacer()
                            Text("Waiting on Owner Cert")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.cvAmber)
                        }
                    }
                    .padding(12)
                    .background(Color.cvSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .cvCard(padding: 16)
                .padding(.horizontal, 16)
                
                // Sign Out Button
                CallVexaButton(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    variant: .danger
                ) {
                    Task {
                        await authManager.logout()
                    }
                }
                .padding(.horizontal, 16)
                
                AttributionFooter()
            }
        }
        .cvBackground()
        .task {
            await loadSettings()
        }
    }
    
    private func loadSettings() async {
        do {
            let res: SettingsResponse = try await APIClient.shared.get("/api/settings")
            self.settings = res.settings
            self.emergencyStop = res.settings["emergency_stop"] == "1"
            self.dailyCallLimit = res.settings["daily_call_limit"] ?? "50"
            self.dailySpendLimit = res.settings["daily_spend_limit_usd"] ?? "10"
            self.callerId = res.settings["caller_id"] ?? ""
        } catch {
            print("Failed to load settings: \(error)")
        }
        
        do {
            let tw: TwilioAccountResponse = try await APIClient.shared.get("/api/twilio/account")
            self.twilioAccount = tw
        } catch {
            print("Failed to load Twilio account: \(error)")
        }
    }
    
    private func saveVoiceSettings() {
        isSaving = true
        Task {
            do {
                var payload: [String: String] = [:]
                payload["emergency_stop"] = emergencyStop ? "1" : "0"
                payload["daily_call_limit"] = dailyCallLimit
                payload["daily_spend_limit_usd"] = dailySpendLimit
                if !callerId.isEmpty {
                    payload["caller_id"] = callerId
                }
                
                // CRITICAL RULE: Never overwrite masked secrets like ••••••••
                struct SaveResp: Codable { let ok: Bool }
                let _: SaveResp = try await APIClient.shared.put("/api/settings", body: payload)
                showSavedToast = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSavedToast = false
            } catch {
                print("Failed to save settings: \(error)")
            }
            isSaving = false
        }
    }
}
