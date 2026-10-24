import Foundation

struct CountryStat: Codable, Identifiable {
    var id: String { country }
    let country: String
    let c: Int        // count of calls
    let s: Double?    // total spend
}

struct RecentCallStat: Codable, Identifiable {
    let id: Int
    let toNumber: String
    let country: String?
    let status: String
    let durationSec: Int?
    let createdAt: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id
        case toNumber = "to_number"
        case country
        case status
        case durationSec = "duration_sec"
        case createdAt = "created_at"
    }
}

struct AnalyticsSummary: Codable {
    let total: Int
    let answered: Int
    let failed: Int
    let minutes: Double
    let avgSec: Int
    let spend: Double
    let byCountry: [CountryStat]?
    let recent: [RecentCallStat]?
    
    var answerRatePercentage: Double {
        guard total > 0 else { return 0.0 }
        return (Double(answered) / Double(total)) * 100.0
    }
}

struct AnalyticsResponse: Codable {
    let ok: Bool
    let total: Int
    let answered: Int
    let failed: Int
    let minutes: Double
    let avgSec: Int
    let spend: Double
    let byCountry: [CountryStat]?
    let recent: [RecentCallStat]?
    
    var summary: AnalyticsSummary {
        AnalyticsSummary(
            total: total,
            answered: answered,
            failed: failed,
            minutes: minutes,
            avgSec: avgSec,
            spend: spend,
            byCountry: byCountry,
            recent: recent
        )
    }
}
