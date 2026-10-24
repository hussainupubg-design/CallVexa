import Foundation

struct VoiceTokenResponse: Codable {
    let ok: Bool
    let token: String
    let ttl: Int?
}

struct VoiceAuthRequest: Codable {
    let to: String
}

struct VoiceAuthResponse: Codable {
    let ok: Bool
    let authId: String
    let callId: Int?
    let to: String
    let country: String?
}

struct VoiceLastNumberResponse: Codable {
    let ok: Bool
    let number: String?
}

enum VoiceErrorMapper {
    static func friendlyMessage(for code: String) -> String {
        switch code.lowercased() {
        case "invalid_number":
            return "Invalid phone number. Check the number and country code."
        case "country_blocked":
            return "This destination country is not in your allowed list. Enable it in Voice Settings."
        case "call_in_progress":
            return "A call is already in progress."
        case "daily_limit":
            return "Daily call limit reached. See Voice Settings."
        case "daily_spend_limit", "spend_limit":
            return "Daily spending limit reached. See Voice Settings."
        case "emergency_stop":
            return "Emergency stop is ON. Disable it in Voice Settings to place calls."
        case "unauthorized":
            return "Session expired. Please log in again."
        case "queue_empty":
            return "No callers waiting in the queue."
        default:
            return "Call request failed: \(code)"
        }
    }
}
