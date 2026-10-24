import Foundation

enum PhoneNumberFormatter {
    /// Cleans and formats input into an E.164 compliant string (e.g. +14155552671)
    static func normalizeE164(_ input: String, defaultCountryDialCode: String = "+1") -> String {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        let digitsAndPlus = trimmed.filter { $0.isNumber || $0 == "+" }
        if digitsAndPlus.hasPrefix("+") {
            let digitsOnly = digitsAndPlus.filter { $0.isNumber }
            return "+" + digitsOnly
        }
        
        // Remove leading international access prefix 00 or 011
        if trimmed.hasPrefix("00") {
            let without = trimmed.dropFirst(2).filter { $0.isNumber }
            return "+" + without
        }
        
        // Default country prefix fallback
        let digitsOnly = trimmed.filter { $0.isNumber }
        let dialClean = defaultCountryDialCode.filter { $0.isNumber }
        if digitsOnly.hasPrefix(dialClean) {
            return "+" + digitsOnly
        }
        return defaultCountryDialCode + digitsOnly
    }
    
    /// Checks whether an E.164 string is structurally valid (7 to 15 digits)
    static func isValidE164(_ number: String) -> Bool {
        guard number.hasPrefix("+") else { return false }
        let digits = number.dropFirst().filter { $0.isNumber }
        return digits.count >= 7 && digits.count <= 15
    }
    
    /// Formats a phone number for attractive visual presentation
    static func formatForDisplay(_ number: String) -> String {
        let clean = number.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("+1") && clean.count == 12 {
            // US / Canada format: +1 (XXX) XXX-XXXX
            let digits = clean.dropFirst(2)
            let area = digits.prefix(3)
            let mid = digits.dropFirst(3).prefix(3)
            let last = digits.suffix(4)
            return "+1 (\(area)) \(mid)-\(last)"
        }
        if clean.hasPrefix("+44") && clean.count >= 12 {
            // UK format
            let digits = clean.dropFirst(3)
            let area = digits.prefix(4)
            let rest = digits.dropFirst(4)
            return "+44 \(area) \(rest)"
        }
        return clean
    }
}
