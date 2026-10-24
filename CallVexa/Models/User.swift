import Foundation

enum UserRole: String, Codable {
    case admin = "admin"
    case agent = "agent"
    case supervisor = "supervisor"
}

struct AdminUser: Codable, Identifiable {
    var id: String { email }
    let email: String
    let totp: Bool?
}

struct AgentUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    let status: String?
    
    var isSupervisor: Bool {
        role.lowercased() == "supervisor"
    }
}

enum CurrentUser {
    case admin(AdminUser)
    case agent(AgentUser)
    
    var displayName: String {
        switch self {
        case .admin(let user):
            return user.email
        case .agent(let agent):
            return agent.name.isEmpty ? agent.email : agent.name
        }
    }
    
    var email: String {
        switch self {
        case .admin(let user): return user.email
        case .agent(let agent): return agent.email
        }
    }
    
    var isAdmin: Bool {
        if case .admin = self { return true }
        return false
    }
    
    var roleBadge: String {
        switch self {
        case .admin: return "Admin"
        case .agent(let a): return a.role.capitalized
        }
    }
}
