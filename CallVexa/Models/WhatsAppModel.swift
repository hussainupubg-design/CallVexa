import Foundation

struct WhatsAppConversation: Identifiable, Codable {
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

struct WhatsAppConversationsResponse: Codable {
    let ok: Bool
    let conversations: [WhatsAppConversation]
}

struct WhatsAppMessage: Identifiable, Codable {
    let id: Int
    let direction: String
    let fromNumber: String
    let toNumber: String
    let body: String?
    let twilioSid: String?
    let status: String?
    let at: Int64
    var mediaUrl: String?
    let mediaType: String?
    
    enum CodingKeys: String, CodingKey {
        case id, direction, body, status, at
        case fromNumber = "from_number"
        case toNumber = "to_number"
        case twilioSid = "twilio_sid"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
    }
    
    var isInbound: Bool {
        direction.lowercased() == "inbound"
    }
}

struct WhatsAppMessagesResponse: Codable {
    let ok: Bool
    let messages: [WhatsAppMessage]
}

struct WhatsAppSendRequest: Codable {
    let to: String
    let body: String?
    let mediaUrl: String?
    let mediaType: String?
}

struct WhatsAppBroadcastRequest: Codable {
    let numbers: [String]
    let body: String
    let useTemplate: Bool
}

struct WhatsAppUploadResponse: Codable {
    let ok: Bool
    let url: String
    let path: String
    let mediaType: String
    let name: String
    let size: Int
}
