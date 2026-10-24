import Foundation

struct Voicemail: Identifiable, Codable {
    let id: Int
    let fromNumber: String?
    let recordingUrl: String?
    let recordingSid: String?
    let durationSec: Int?
    let createdAt: Int64
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromNumber = "from_number"
        case recordingUrl = "recording_url"
        case recordingSid = "recording_sid"
        case durationSec = "duration_sec"
        case createdAt = "created_at"
    }
    
    var audioStreamURL: URL? {
        guard let urlStr = recordingUrl, !urlStr.isEmpty else { return nil }
        if urlStr.hasSuffix(".mp3") {
            return URL(string: urlStr)
        }
        return URL(string: "\(urlStr).mp3")
    }
}

struct VoicemailsResponse: Codable {
    let ok: Bool
    let voicemails: [Voicemail]
}

struct QueueStatusResponse: Codable {
    let ok: Bool
    let size: Int?
    let waiting: Int?
    let calls: [QueueCallItem]?
}

struct QueueCallItem: Identifiable, Codable {
    var id: String { callSid ?? UUID().uuidString }
    let callSid: String?
    let from: String?
    let waitTimeSec: Int?
    
    enum CodingKeys: String, CodingKey {
        case callSid = "call_sid"
        case from
        case waitTimeSec = "wait_time_sec"
    }
}
