import SwiftUI

enum CallState: Equatable {
    case idle
    case authorizing
    case connecting
    case ringing
    case connected
    case disconnecting
    case completed(summary: String?)
    case busy
    case noAnswer
    case failed(message: String)
    
    var displayText: String {
        switch self {
        case .idle: return "Ready"
        case .authorizing: return "Authorizing…"
        case .connecting: return "Connecting…"
        case .ringing: return "Ringing…"
        case .connected: return "Connected"
        case .disconnecting: return "Ending call…"
        case .completed: return "Call Completed"
        case .busy: return "Line Busy"
        case .noAnswer: return "No Answer"
        case .failed(let msg): return msg.isEmpty ? "Call Failed" : msg
        }
    }
    
    var statusColor: Color {
        switch self {
        case .idle: return .cvTextMuted
        case .authorizing, .connecting: return .cvCyan
        case .ringing: return .cvAmber
        case .connected: return .cvGreen
        case .disconnecting: return .cvAmber
        case .completed: return .cvPrimary
        case .busy, .noAnswer, .failed: return .cvRed
        }
    }
    
    var isInCall: Bool {
        switch self {
        case .authorizing, .connecting, .ringing, .connected, .disconnecting:
            return true
        default:
            return false
        }
    }
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
