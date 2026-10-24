import Foundation

struct Contact: Identifiable, Codable, Hashable {
    let id: Int
    var name: String
    var phone: String
    var country: String?
    var notes: String?
    let createdAt: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id, name, phone, country, notes
        case createdAt = "created_at"
    }
}

struct ContactsResponse: Codable {
    let ok: Bool
    let rows: [Contact]
}

struct ContactInput: Codable {
    let name: String
    let phone: String
    let country: String?
    let notes: String?
}
