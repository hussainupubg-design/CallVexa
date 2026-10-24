import Foundation

struct Lead: Identifiable, Codable {
    let id: Int
    let name: String
    let phone: String
    let city: String?
    let niche: String?
    let address: String?
    let rating: Double?
    let reviews: Int?
    let contacted: Int? // 1 or 0
    let createdAt: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id, name, phone, city, niche, address, rating, reviews, contacted
        case createdAt = "created_at"
    }
    
    var isContacted: Bool {
        contacted == 1
    }
}

struct LeadsResponse: Codable {
    let ok: Bool
    let leads: [Lead]
}

struct LeadNichesResponse: Codable {
    let ok: Bool
    let niches: [String]
}

struct LeadSearchRequest: Codable {
    let niche: String
    let city: String
    let max: Int
}

struct LeadJobStatusResponse: Codable {
    let ok: Bool
    let running: Bool?
    let progress: Int?
    let total: Int?
    let currentNiche: String?
    let currentCity: String?
    
    enum CodingKeys: String, CodingKey {
        case ok, running, progress, total
        case currentNiche = "current_niche"
        case currentCity = "current_city"
    }
}
