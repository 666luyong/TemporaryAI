import Foundation
import WebKit

struct CookieData: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let isSecure: Bool
    let isHTTPOnly: Bool
    let expires: Date?
}

struct CookieExportContainer: Codable {
    let isEncrypted: Bool
    let data: String // JSON string if unencrypted, Base64 string if encrypted
    let salt: String? // Base64 string
}

class CookieManager {
    static let shared = CookieManager()
    
    private init() {}
    
    /// Exports cookies. 
    /// - expiryDuration: If set, overrides the cookie's expiration date to Date() + duration. nil keeps original expiry.
    func exportCookies(for domains: [String], password: String?, expiryDuration: TimeInterval?, completion: @escaping (Result<String, Error>) -> Void) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        store.getAllCookies { cookies in
            let filteredCookies = cookies.filter { cookie in
                domains.contains { domainSuffix in
                    cookie.domain.contains(domainSuffix)
                }
            }
            
            let cookieDataList = filteredCookies.map { cookie -> CookieData in
                let finalExpires: Date?
                if let duration = expiryDuration {
                    finalExpires = Date().addingTimeInterval(duration)
                } else {
                    finalExpires = cookie.expiresDate
                }
                
                return CookieData(
                    name: cookie.name,
                    value: cookie.value,
                    domain: cookie.domain,
                    path: cookie.path,
                    isSecure: cookie.isSecure,
                    isHTTPOnly: cookie.isHTTPOnly,
                    expires: finalExpires
                )
            }
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                // Ensure dates are encoded in a standard format (ISO8601 is default for JSONEncoder in some contexts, but let's be explicit or default)
                // Default JSONEncoder date strategy is .deferredToDate (timeInterval since ref). 
                // Let's stick to default as long as decoder matches.
                
                let rawData = try encoder.encode(cookieDataList)
                
                var container: CookieExportContainer
                
                if let pwd = password, !pwd.isEmpty {
                    // Encrypt
                    let (encryptedData, salt) = try CryptoHelper.shared.encrypt(data: rawData, password: pwd)
                    container = CookieExportContainer(
                        isEncrypted: true,
                        data: encryptedData.base64EncodedString(),
                        salt: salt.base64EncodedString()
                    )
                } else {
                    // Plain Text
                    guard let jsonString = String(data: rawData, encoding: .utf8) else {
                        throw NSError(domain: "CookieManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Encoding failed"])
                    }
                    container = CookieExportContainer(
                        isEncrypted: false,
                        data: jsonString,
                        salt: nil
                    )
                }
                
                let finalData = try encoder.encode(container)
                if let finalString = String(data: finalData, encoding: .utf8) {
                    completion(.success(finalString))
                } else {
                    throw NSError(domain: "CookieManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Final encoding failed"])
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // ... parseContainer, importCookies, clearCookies unchanged ...
    
    func parseContainer(from jsonString: String) -> Result<CookieExportContainer, Error> {
        guard let data = jsonString.data(using: .utf8) else {
            return .failure(NSError(domain: "CookieManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"]))
        }
        do {
            let container = try JSONDecoder().decode(CookieExportContainer.self, from: data)
            return .success(container)
        } catch {
            if let _ = try? JSONDecoder().decode([CookieData].self, from: data) {
                return .success(CookieExportContainer(isEncrypted: false, data: jsonString, salt: nil))
            }
            return .failure(error)
        }
    }
    
    func importCookies(from container: CookieExportContainer, password: String?, completion: @escaping (Result<Int, Error>) -> Void) {
        do {
            var cookieDataList: [CookieData]
            let decoder = JSONDecoder()
            
            if container.isEncrypted {
                guard let pwd = password, !pwd.isEmpty else {
                    throw NSError(domain: "CookieManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Password required"])
                }
                guard let saltString = container.salt,
                      let salt = Data(base64Encoded: saltString),
                      let encryptedData = Data(base64Encoded: container.data) else {
                    throw NSError(domain: "CookieManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Corrupted encrypted data"])
                }
                
                let decryptedData = try CryptoHelper.shared.decrypt(encryptedData: encryptedData, password: pwd, salt: salt)
                cookieDataList = try decoder.decode([CookieData].self, from: decryptedData)
            } else {
                guard let data = container.data.data(using: .utf8) else {
                    throw NSError(domain: "CookieManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "Invalid data encoding"])
                }
                cookieDataList = try decoder.decode([CookieData].self, from: data)
            }
            
            let store = WKWebsiteDataStore.default().httpCookieStore
            let group = DispatchGroup()
            var successCount = 0
            
            for cookieData in cookieDataList {
                group.enter()
                var properties: [HTTPCookiePropertyKey: Any] = [
                    .name: cookieData.name,
                    .value: cookieData.value,
                    .domain: cookieData.domain,
                    .path: cookieData.path,
                    .secure: cookieData.isSecure ? "TRUE" : "FALSE"
                ]
                if let expires = cookieData.expires {
                    properties[.expires] = expires
                }
                
                if let cookie = HTTPCookie(properties: properties) {
                    store.setCookie(cookie) {
                        successCount += 1
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                completion(.success(successCount))
            }
            
        } catch {
            completion(.failure(error))
        }
    }
    
    func clearCookies(for domains: [String], completion: @escaping () -> Void) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        store.getAllCookies { cookies in
            let filteredCookies = cookies.filter { cookie in
                domains.contains { domainSuffix in
                    cookie.domain.contains(domainSuffix)
                }
            }
            let group = DispatchGroup()
            for cookie in filteredCookies {
                group.enter()
                store.delete(cookie) { group.leave() }
            }
            group.notify(queue: .main) { completion() }
        }
    }
}