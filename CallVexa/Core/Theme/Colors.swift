import SwiftUI

extension Color {
    // Brand Core
    static let cvBackground = Color(hex: "0A0F1E")
    static let cvSurface = Color(hex: "121829")
    static let cvSurfaceElevated = Color(hex: "1A233B")
    static let cvSurfaceHighlight = Color(hex: "243050")
    
    // Borders
    static let cvBorder = Color(hex: "1E2A47")
    static let cvBorderLight = Color(hex: "2D3B62")
    
    // Accents
    static let cvPrimary = Color(hex: "2563EB")       // Electric Blue
    static let cvPrimaryLight = Color(hex: "3B82F6")  // Vivid Blue
    static let cvCyan = Color(hex: "06B6D4")          // Cyan
    static let cvGreen = Color(hex: "10B981")         // Success / Connected
    static let cvGreenLight = Color(hex: "34D399")
    static let cvRed = Color(hex: "EF4444")           // Error / Hangup
    static let cvAmber = Color(hex: "F59E0B")         // Warning / Ringing
    
    // Typography
    static let cvTextPrimary = Color(hex: "F8FAFC")
    static let cvTextSecondary = Color(hex: "94A3B8")
    static let cvTextMuted = Color(hex: "64748B")
    
    // Initializer from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
