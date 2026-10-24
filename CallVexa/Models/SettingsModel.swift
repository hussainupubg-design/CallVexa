import Foundation

struct SettingsResponse: Codable {
    let ok: Bool
    let settings: [String: String]
}

struct TwilioBalance: Codable {
    let amount: String?
    let currency: String?
}

struct TwilioAccountResponse: Codable {
    let ok: Bool
    let status: String?
    let friendlyName: String?
    let type: String?
    let balance: TwilioBalance?
    let numbers: [String]?
}

struct AuditRow: Identifiable, Codable {
    let id: Int
    let adminId: Int?
    let action: String
    let details: String?
    let ip: String?
    let createdAt: Int64
    
    enum CodingKeys: String, CodingKey {
        case id, action, details, ip
        case adminId = "admin_id"
        case createdAt = "created_at"
    }
}

struct AuditResponse: Codable {
    let ok: Bool
    let rows: [AuditRow]
}

struct ManagedAgent: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let role: String
    let status: String
    let createdAt: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, role, status
        case createdAt = "created_at"
    }
}

struct AgentsListResponse: Codable {
    let ok: Bool
    let rows: [ManagedAgent]
}
