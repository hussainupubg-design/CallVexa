import Foundation
import Combine

@MainActor
final class AuthSessionManager: ObservableObject {
    static let shared = AuthSessionManager()
    
    @Published var currentUser: CurrentUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isCheckingSession: Bool = true
    @Published var requiresTotp: Bool = false
    @Published var errorMessage: String? = nil
    
    private var pendingEmail: String = ""
    private var pendingPassword: String = ""
    private var presenceTimer: AnyCancellable? = nil
    
    private init() {
        // Direct Agent mode by default — no login required
        self.currentUser = .agent(
            AgentUser(
                id: "ag_mobile",
                email: "agent@callvexa.us",
                name: "Mobile Agent",
                role: "agent",
                status: "active"
            )
        )
        self.isAuthenticated = true
        self.isCheckingSession = false
        
        startAgentPresenceHeartbeat()
        
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Check Existing Session in Background (Non-blocking)
    
    func checkSession() async {
        errorMessage = nil
        
        // 1. Check if an active agent session is stored on server
        do {
            struct AgentMeResponse: Codable {
                let ok: Bool
                let agent: AgentUser
            }
            let res: AgentMeResponse = try await APIClient.shared.get("/api/agents/me")
            if res.ok {
                self.currentUser = .agent(res.agent)
                return
            }
        } catch {
            // Keep default mobile agent active
        }
    }
    
    // MARK: - Admin Login
    
    func loginAdmin(email: String, password: String, totp: String? = nil) async -> Bool {
        errorMessage = nil
        requiresTotp = false
        
        struct LoginRequest: Codable {
            let email: String
            let password: String
            let totp: String?
        }
        struct LoginResponse: Codable {
            let ok: Bool
            let user: AdminUser
        }
        
        do {
            let req = LoginRequest(email: email, password: password, totp: totp)
            let res: LoginResponse = try await APIClient.shared.post("/api/auth/login", body: req)
            if res.ok {
                self.currentUser = .admin(res.user)
                self.isAuthenticated = true
                self.pendingEmail = ""
                self.pendingPassword = ""
                return true
            }
            return false
        } catch let apiError as APIError {
            if apiError.isTotpRequired {
                self.requiresTotp = true
                self.pendingEmail = email
                self.pendingPassword = password
                self.errorMessage = "Please enter your 6-digit authenticator code."
            } else {
                self.errorMessage = apiError.localizedDescription
            }
            return false
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func submitTotpCode(_ code: String) async -> Bool {
        guard !pendingEmail.isEmpty && !pendingPassword.isEmpty else { return false }
        return await loginAdmin(email: pendingEmail, password: pendingPassword, totp: code)
    }
    
    // MARK: - Agent Login
    
    func loginAgent(email: String, password: String) async -> Bool {
        errorMessage = nil
        requiresTotp = false
        
        struct AgentLoginRequest: Codable {
            let email: String
            let password: String
        }
        struct AgentLoginResponse: Codable {
            let ok: Bool
            let agent: AgentUser
        }
        
        do {
            let req = AgentLoginRequest(email: email, password: password)
            let res: AgentLoginResponse = try await APIClient.shared.post("/api/agents/login", body: req)
            if res.ok {
                self.currentUser = .agent(res.agent)
                self.isAuthenticated = true
                startAgentPresenceHeartbeat()
                return true
            }
            return false
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Logout
    
    func logout() async {
        stopAgentPresenceHeartbeat()
        
        struct EmptyResponse: Codable {
            let ok: Bool?
        }
        
        if case .agent = currentUser {
            let _: EmptyResponse? = try? await APIClient.shared.postEmpty("/api/agents/logout")
        } else {
            let _: EmptyResponse? = try? await APIClient.shared.postEmpty("/api/auth/logout")
        }
        
        await APIClient.shared.clearCookies()
        self.currentUser = nil
        self.isAuthenticated = false
        self.requiresTotp = false
        self.pendingEmail = ""
        self.pendingPassword = ""
    }
    
    // MARK: - Agent Presence Heartbeat
    
    private func startAgentPresenceHeartbeat() {
        stopAgentPresenceHeartbeat()
        presenceTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    guard let self = self, case .agent = self.currentUser else { return }
                    struct OkResp: Codable { let ok: Bool }
                    let _: OkResp? = try? await APIClient.shared.postEmpty("/api/agent/presence")
                }
            }
    }
    
    private func stopAgentPresenceHeartbeat() {
        presenceTimer?.cancel()
        presenceTimer = nil
    }
}
