import Foundation

actor APIClient {
    static let shared = APIClient()
    
    let baseURL = URL(string: "https://callvexa.us")!
    private let session: URLSession
    
    // Cookie persistence keys
    private let cookiesStorageKey = "us.callvexa.app.saved_cookies"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        
        restorePersistedCookies()
    }
    
    // MARK: - Cookie Persistence
    
    private func persistCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) else { return }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: cookiesStorageKey)
        } catch {
            print("[APIClient] Failed to persist cookies: \(error)")
        }
    }
    
    private func restorePersistedCookies() {
        guard let data = UserDefaults.standard.data(forKey: cookiesStorageKey) else { return }
        do {
            if let cookies = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: data) as? [HTTPCookie] {
                for cookie in cookies {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        } catch {
            print("[APIClient] Failed to restore cookies: \(error)")
        }
    }
    
    func clearCookies() {
        if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        UserDefaults.standard.removeObject(forKey: cookiesStorageKey)
    }
    
    // MARK: - Core Request Builder
    
    private func makeRequest(
        path: String,
        method: String,
        query: [String: String]? = nil,
        body: Data? = nil,
        contentType: String? = "application/json"
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        if let query = query, !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }
    
    // MARK: - Execution
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        
        // Save updated cookies on every network response
        persistCookies()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        
        // Parse error body if non-2xx
        if httpResponse.statusCode == 401 {
            var errorCode = "unauthorized"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String {
                errorCode = err
            }
            if errorCode == "totp" {
                throw APIError.totpRequired
            }
            throw APIError.unauthorized(code: errorCode)
        }
        
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            var errorCode = "http_\(httpResponse.statusCode)"
            var message = ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let err = json["error"] as? String {
                    errorCode = err
                }
                if let msg = json["message"] as? String {
                    message = msg
                }
            }
            throw APIError.serverError(status: httpResponse.statusCode, code: errorCode, message: message)
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // MARK: - Public API Methods
    
    func get<T: Decodable>(_ path: String, query: [String: String]? = nil) async throws -> T {
        let req = try makeRequest(path: path, method: "GET", query: query)
        return try await execute(req)
    }
    
    func post<T: Decodable, B: Encodable>(_ path: String, body: B?) async throws -> T {
        var bodyData: Data? = nil
        if let body = body {
            bodyData = try JSONEncoder().encode(body)
        }
        let req = try makeRequest(path: path, method: "POST", body: bodyData)
        return try await execute(req)
    }
    
    func postEmpty<T: Decodable>(_ path: String) async throws -> T {
        let req = try makeRequest(path: path, method: "POST", body: "{}".data(using: .utf8))
        return try await execute(req)
    }
    
    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let req = try makeRequest(path: path, method: "PUT", body: bodyData)
        return try await execute(req)
    }
    
    func delete<T: Decodable>(_ path: String) async throws -> T {
        let req = try makeRequest(path: path, method: "DELETE")
        return try await execute(req)
    }
    
    // Multipart form upload for WhatsApp media
    func uploadMedia<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = try makeRequest(
            path: path,
            method: "POST",
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        req.httpBody = body
        return try await execute(req)
    }
    
    func downloadRaw(_ path: String) async throws -> Data {
        let req = try makeRequest(path: path, method: "GET", contentType: nil)
        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError(status: (response as? HTTPURLResponse)?.statusCode ?? 500, code: "download_failed", message: "Failed to download file.")
        }
        return data
    }
}
