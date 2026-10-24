import Foundation

struct CallRecord: Identifiable, Codable {
    let id: Int
    let twilioSid: String?
    let toNumber: String
    let country: String?
    let status: String
    let startedAt: String?
    let duration: Int?
    let price: Double?
    let callerId: String?
    let direction: String?
    let recordingUrl: String?
    let createdAt: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id
        case twilioSid = "twilio_sid"
        case toNumber = "to_number"
        case country
        case status
        case startedAt = "started_at"
        case duration
        case price
        case callerId = "caller_id"
        case direction
        case recordingUrl = "recording_url"
        case createdAt = "created_at"
    }
    
    // Status visual badge color helper
    var isSuccess: Bool {
        let s = status.lowercased()
        return s == "completed" || s == "answered"
    }
    
    var isFailed: Bool {
        let s = status.lowercased()
        return s == "failed" || s == "busy" || s == "no-answer" || s == "canceled"
    }
}

struct CallsResponse: Codable {
    let ok: Bool
    let rows: [CallRecord]
    let total: Int?
}
