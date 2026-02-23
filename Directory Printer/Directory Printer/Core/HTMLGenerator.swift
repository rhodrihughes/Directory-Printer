// HTMLGenerator.swift
// Directory Printer
//
// Produces a self-contained HTML snapshot by injecting encoded scan data
// and configuration into the HTML template.

import CommonCrypto
import CryptoKit
import Foundation
import zlib

// MARK: - HTMLGeneratorError

enum HTMLGeneratorError: Error, LocalizedError {
    case placeholderNotFound(String)

    var errorDescription: String? {
        switch self {
        case .placeholderNotFound(let placeholder):
            return "HTML template placeholder '\(placeholder)' was not found. The template may be corrupted."
        }
    }
}

// MARK: - HTMLGenerator

struct HTMLGenerator {
    
    /// Gets the app version from the bundle's marketing version.
    static var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0"
    }

    /// Compresses data using zlib's deflate with gzip wrapping (windowBits = 15+16).
    /// Returns valid gzip output that browsers can decompress with DecompressionStream('gzip').
    private static func gzipCompress(_ data: Data) throws -> Data {
        var stream = z_stream()
        // windowBits 31 = 15 (max window) + 16 (gzip wrapper)
        let initResult = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                                        MAX_WBITS + 16, 8, Z_DEFAULT_STRATEGY,
                                        ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else {
            throw HTMLGeneratorError.placeholderNotFound("gzip init failed (\(initResult))")
        }
        defer { deflateEnd(&stream) }

        let bufferSize = deflateBound(&stream, UInt(data.count))
        var output = Data(count: Int(bufferSize))

        try data.withUnsafeBytes { srcPtr in
            try output.withUnsafeMutableBytes { dstPtr in
                stream.next_in = UnsafeMutablePointer(mutating: srcPtr.bindMemory(to: UInt8.self).baseAddress!)
                stream.avail_in = uInt(data.count)
                stream.next_out = dstPtr.bindMemory(to: UInt8.self).baseAddress!
                stream.avail_out = uInt(bufferSize)

                let result = deflate(&stream, Z_FINISH)
                guard result == Z_STREAM_END else {
                    throw HTMLGeneratorError.placeholderNotFound("gzip deflate failed (\(result))")
                }
            }
        }

        output.count = Int(stream.total_out)
        return output
    }

    // MARK: - AES-256-GCM encryption

    /// Derives a 256-bit key from a password using PBKDF2-SHA256.
    private static func deriveKey(password: String, salt: Data, iterations: Int = 200_000) -> Data {
        var derivedKey = Data(count: 32)
        let passwordData = password.data(using: .utf8)!
        derivedKey.withUnsafeMutableBytes { derivedKeyPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, passwordData.count,
                    saltPtr.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    derivedKeyPtr.bindMemory(to: UInt8.self).baseAddress!, 32
                )
            }
        }
        return derivedKey
    }

    /// Encrypts data with AES-256-GCM using CryptoKit. Returns (ciphertext+tag, nonce, salt).
    private static func aesGCMEncrypt(data: Data, password: String) throws -> (ciphertext: Data, nonce: Data, salt: Data) {
        var saltBytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes) == errSecSuccess else {
            throw HTMLGeneratorError.placeholderNotFound("Random bytes generation failed")
        }
        let salt = Data(saltBytes)
        let keyData = deriveKey(password: password, salt: salt)

        let symmetricKey = SymmetricKey(data: keyData)
        let nonce = try AES.GCM.Nonce()  // random 12-byte nonce
        let sealed = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)

        // CryptoKit separates ciphertext and tag — concatenate them to match JS expectation
        let nonceData = Data(nonce)
        let ciphertextPlusTag = sealed.ciphertext + sealed.tag
        return (ciphertextPlusTag, nonceData, salt)
    }


    // MARK: - HTML generation

    /// Generates a self-contained HTML snapshot from a scan result.
    ///
    /// - Parameters:
    ///   - result: The completed scan result containing the file tree and metadata.
    ///   - options: The scan options used (e.g. `linkToFiles`, `compressData`, `encryptionPassword`).
    ///   - logoBase64: Optional base64-encoded PNG logo to embed in the header.
    ///   - thumbnailsFolder: Optional relative path to the thumbnails folder.
    /// - Returns: A complete HTML string ready to be written to disk.
    /// - Throws: `HTMLGeneratorError` or a JSON encoding error.
    static func generate(
        from result: ScanResult,
        options: ScanOptions,
        logoBase64: String? = nil,
        thumbnailsFolder: String? = nil
    ) throws -> String {
        var html = HTMLTemplate.template

        // 1. Encode ScanResult to JSON bytes
        let jsonString = try DataEncoder.encodeToJSON(result)
        guard let jsonRaw = jsonString.data(using: .utf8) else {
            throw HTMLGeneratorError.placeholderNotFound("JSON UTF-8 encoding failed")
        }

        // 2. Optionally compress, then optionally encrypt.
        //    Order: JSON → [gzip] → [AES-256-GCM] → base64
        //    Compressing before encrypting is intentional: encrypted data is
        //    high-entropy and won't compress, so we compress the plaintext first.
        let dataPlaceholder = "/*SNAPSHOT_DATA*/"
        guard html.contains(dataPlaceholder) else {
            throw HTMLGeneratorError.placeholderNotFound(dataPlaceholder)
        }

        var configDict: [String: Any] = [
            "linkToFiles": options.linkToFiles,
            "compressed": options.compressData,
            "encrypted": options.encryptionPassword != nil,
            "appVersion": appVersion
        ]
        if let folder = thumbnailsFolder {
            configDict["thumbnailsFolder"] = folder
        }

        if let password = options.encryptionPassword, !password.isEmpty {
            // Compress first if requested, then encrypt
            let payloadToEncrypt: Data
            if options.compressData {
                payloadToEncrypt = try gzipCompress(jsonRaw)
            } else {
                payloadToEncrypt = jsonRaw
            }
            let (ciphertext, nonce, salt) = try aesGCMEncrypt(data: payloadToEncrypt, password: password)
            // Embed as a JSON object so JS can unpack the fields cleanly
            let encryptedPayload: [String: String] = [
                "ct": ciphertext.base64EncodedString(),
                "iv": nonce.base64EncodedString(),
                "salt": salt.base64EncodedString()
            ]
            guard let payloadData = try? JSONSerialization.data(withJSONObject: encryptedPayload),
                  let payloadJSON = String(data: payloadData, encoding: .utf8) else {
                throw HTMLGeneratorError.placeholderNotFound("Encrypted payload serialization failed")
            }
            html = html.replacingOccurrences(of: dataPlaceholder, with: payloadJSON)
        } else if options.compressData {
            let gzipData = try gzipCompress(jsonRaw)
            html = html.replacingOccurrences(of: dataPlaceholder, with: "\"\(gzipData.base64EncodedString())\"")
        } else {
            html = html.replacingOccurrences(of: dataPlaceholder, with: jsonString)
        }

        // 3. Inject SNAPSHOT_CONFIG
        let configPlaceholder = "/*SNAPSHOT_CONFIG*/"
        guard html.contains(configPlaceholder) else {
            throw HTMLGeneratorError.placeholderNotFound(configPlaceholder)
        }
        guard let configData = try? JSONSerialization.data(withJSONObject: configDict),
              let configJSON = String(data: configData, encoding: .utf8) else {
            throw HTMLGeneratorError.placeholderNotFound("CONFIG serialization failed")
        }
        html = html.replacingOccurrences(of: configPlaceholder, with: configJSON)

        // 4. Inject logo (optional)
        let logoPlaceholder = "/*SNAPSHOT_LOGO*/"
        if html.contains(logoPlaceholder) {
            let logoHTML: String
            if let b64 = logoBase64, !b64.isEmpty {
                logoHTML = "<img id=\"header-logo\" src=\"data:image/png;base64,\(b64)\" alt=\"Logo\">"
            } else {
                logoHTML = ""
            }
            html = html.replacingOccurrences(of: logoPlaceholder, with: logoHTML)
        }

        return html
    }
}
