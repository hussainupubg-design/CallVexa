import Foundation

struct CountryItem: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let dialCode: String
    let flag: String
}

enum CountryDirectory {
    static let all: [CountryItem] = [
        CountryItem(code: "US", name: "United States", dialCode: "+1", flag: "🇺🇸"),
        CountryItem(code: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦"),
        CountryItem(code: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧"),
        CountryItem(code: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺"),
        CountryItem(code: "DE", name: "Germany", dialCode: "+49", flag: "🇩🇪"),
        CountryItem(code: "FR", name: "France", dialCode: "+33", flag: "🇫🇷"),
        CountryItem(code: "IT", name: "Italy", dialCode: "+39", flag: "🇮🇹"),
        CountryItem(code: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸"),
        CountryItem(code: "NL", name: "Netherlands", dialCode: "+31", flag: "🇳🇱"),
        CountryItem(code: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭"),
        CountryItem(code: "SE", name: "Sweden", dialCode: "+46", flag: "🇸🇪"),
        CountryItem(code: "NO", name: "Norway", dialCode: "+47", flag: "🇳🇴"),
        CountryItem(code: "DK", name: "Denmark", dialCode: "+45", flag: "🇩🇰"),
        CountryItem(code: "IE", name: "Ireland", dialCode: "+353", flag: "🇮🇪"),
        CountryItem(code: "NZ", name: "New Zealand", dialCode: "+64", flag: "🇳🇿"),
        CountryItem(code: "SG", name: "Singapore", dialCode: "+65", flag: "🇸🇬"),
        CountryItem(code: "JP", name: "Japan", dialCode: "+81", flag: "🇯🇵"),
        CountryItem(code: "AE", name: "United Arab Emirates", dialCode: "+971", flag: "🇦🇪"),
        CountryItem(code: "SA", name: "Saudi Arabia", dialCode: "+966", flag: "🇸🇦"),
        CountryItem(code: "IN", name: "India", dialCode: "+91", flag: "🇮🇳"),
        CountryItem(code: "PK", name: "Pakistan", dialCode: "+92", flag: "🇵🇰"),
        CountryItem(code: "BR", name: "Brazil", dialCode: "+55", flag: "🇧🇷"),
        CountryItem(code: "MX", name: "Mexico", dialCode: "+52", flag: "🇲🇽"),
        CountryItem(code: "ZA", name: "South Africa", dialCode: "+27", flag: "🇿🇦")
    ]
    
    static func defaultCountry() -> CountryItem {
        all.first(where: { $0.code == "US" }) ?? all[0]
    }
    
    static func country(forCode code: String) -> CountryItem? {
        all.first(where: { $0.code.uppercased() == code.uppercased() })
    }
    
    static func country(forNumber number: String) -> CountryItem? {
        let clean = number.replacingOccurrences(of: " ", with: "")
        for item in all.sorted(by: { $0.dialCode.count > $1.dialCode.count }) {
            if clean.hasPrefix(item.dialCode) {
                return item
            }
        }
        return nil
    }
}
