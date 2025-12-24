import Foundation
import CryptoKit
import CommonCrypto

enum CryptoError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidPassword
}

class CryptoHelper {
    static let shared = CryptoHelper()
    private init() {}
    
    // 使用 PBKDF2 从密码和盐派生对称密钥
    private func deriveKey(password: String, salt: Data) -> SymmetricKey {
        // 使用 SHA256，迭代次数 10000，生成 32 字节 (256位) 密钥
        let keyData = PBKDF2.hash(password: password, salt: salt, iterations: 10000, keySize: 32)
        return SymmetricKey(data: keyData)
    }
    
    // 加密数据
    // 返回: (encryptedData: 包含 nonce + ciphertext + tag 的组合数据, salt: 用于派生密钥的盐)
    func encrypt(data: Data, password: String) throws -> (encryptedData: Data, salt: Data) {
        let salt = Data.random(count: 32) // 生成 32 字节随机盐
        let key = deriveKey(password: password, salt: salt)
        
        // AES.GCM 自动生成随机 Nonce
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        // sealedBox.combined 包含 nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        return (combined, salt)
    }
    
    // 解密数据
    func decrypt(encryptedData: Data, password: String, salt: Data) throws -> Data {
        let key = deriveKey(password: password, salt: salt)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let originalData = try AES.GCM.open(sealedBox, using: key)
            return originalData
        } catch {
            // CryptoKit 解密失败通常意味着 Key 错误 (密码错误) 或数据损坏
            throw CryptoError.invalidPassword
        }
    }
}

// 扩展 Data 以生成随机数据
extension Data {
    static func random(count: Int) -> Data {
        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        return result == errSecSuccess ? data : Data()
    }
}

// PBKDF2 Wrapper using CommonCrypto
class PBKDF2 {
    static func hash(password: String, salt: Data, iterations: Int, keySize: Int) -> Data {
        guard let passwordData = password.data(using: .utf8) else { return Data() }
        var derivedKey = Data(count: keySize)
        
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        size_t(keySize)
                    )
                }
            }
        }
        
        if result != kCCSuccess {
            print("PBKDF2 Error: Key derivation failed")
            return Data()
        }
        return derivedKey
    }
}
