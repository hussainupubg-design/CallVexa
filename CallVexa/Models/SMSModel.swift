import Foundation

struct SMSConversation: Identifiable, Codable {
    var id: String { contact }
    let contact: String
    let lastAt: Int64
    let inboundCount: Int?
    let lastBody: String?
    
    enum CodingKeys: String, CodingKey {
        case contact
        case lastAt = "last_at"
        case inboundCount = "inbound_count"
        case lastBody = "last_body"
    }
}

struct SMSConversationsResponse: Codable {
    let ok: Bool
    let conversations: [SMSConversation]
}

struct SMSMessage: Identifiable, Codable {
    let id: Int
    let direction: String
    let fromNumber: String
    let toNumber: String
    let body: String
    let twilioSid: String?
    let status: String?
    let at: Int64
    
    enum CodingKeys: String, CodingKey {
        case id, direction, body, status, at
        case fromNumber = "from_number"
        case toNumber = "to_number"
        case twilioSid = "twilio_sid"
    }
    
    var isInbound: Bool {
        direction.lowercased() == "inbound"
    }
}

struct SMSMessagesResponse: Codable {
    let ok: Bool
    let messages: [SMSMessage]
}

struct SMSSendRequest: Codable {
    let to: String
    let body: String
}
