import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(status: Int, code: String, message: String)
    case unauthorized(code: String)
    case totpRequired
    case decodingError(Error)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .networkError(let error):
            return "Network connection issue: \(error.localizedDescription)"
        case .serverError(let status, let code, let message):
            let friendly = VoiceErrorMapper.friendlyMessage(for: code)
            return friendly != "Call request failed: \(code)" ? friendly : (message.isEmpty ? "Server error (\(status): \(code))" : message)
        case .unauthorized(let code):
            return code == "totp" ? "Two-factor authentication code required." : "Session expired. Please log in again."
        case .totpRequired:
            return "Two-factor authentication required."
        case .decodingError(let error):
            return "Data processing error: \(error.localizedDescription)"
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    var isUnauthorized: Bool {
        if case .unauthorized(let code) = self, code != "totp" {
            return true
        }
        return false
    }
    
    var isTotpRequired: Bool {
        if case .totpRequired = self { return true }
        if case .unauthorized(let code) = self, code == "totp" { return true }
        return false
    }
    
    var errorCode: String {
        switch self {
        case .serverError(_, let code, _): return code
        case .unauthorized(let code): return code
        default: return "unknown"
        }
    }
}
