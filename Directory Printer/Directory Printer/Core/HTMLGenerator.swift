// HTMLGenerator.swift
// Directory Printer
//
// Produces a self-contained HTML snapshot by injecting encoded scan data
// and configuration into the HTML template.

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

    /// Generates a self-contained HTML snapshot from a scan result.
    ///
    /// - Parameters:
    ///   - result: The completed scan result containing the file tree and metadata.
    ///   - options: The scan options used (e.g. `linkToFiles`).
    /// - Returns: A complete HTML string ready to be written to disk.
    /// - Throws: `HTMLGeneratorError.placeholderNotFound` if a required template
    ///           placeholder is missing, or a JSON encoding error if serialization fails.
    static func generate(
        from result: ScanResult,
        options: ScanOptions,
        logoBase64: String? = nil,
        thumbnailsFolder: String? = nil
    ) throws -> String {
        var html = HTMLTemplate.template

        // 1. Encode ScanResult to JSON
        let jsonData = try DataEncoder.encodeToJSON(result)

        // 2. Build config JSON
        var configDict: [String: Any] = ["linkToFiles": options.linkToFiles]
        if let folder = thumbnailsFolder {
            configDict["thumbnailsFolder"] = folder
        }
        guard let configData = try? JSONSerialization.data(withJSONObject: configDict),
              let configJSON = String(data: configData, encoding: .utf8) else {
            throw HTMLGeneratorError.placeholderNotFound("CONFIG serialization failed")
        }

        // 3. Inject SNAPSHOT_DATA
        let dataPlaceholder = "/*SNAPSHOT_DATA*/"
        guard html.contains(dataPlaceholder) else {
            throw HTMLGeneratorError.placeholderNotFound(dataPlaceholder)
        }

        if options.compressData {
            guard let jsonRaw = jsonData.data(using: .utf8) else {
                throw HTMLGeneratorError.placeholderNotFound("JSON UTF-8 encoding failed")
            }
            let gzipData = try gzipCompress(jsonRaw)
            let b64 = gzipData.base64EncodedString()
            html = html.replacingOccurrences(of: dataPlaceholder, with: "\"\(b64)\"")
        } else {
            html = html.replacingOccurrences(of: dataPlaceholder, with: jsonData)
        }

        // 4. Inject SNAPSHOT_CONFIG
        let configPlaceholder = "/*SNAPSHOT_CONFIG*/"
        guard html.contains(configPlaceholder) else {
            throw HTMLGeneratorError.placeholderNotFound(configPlaceholder)
        }
        var configDict2 = configDict
        configDict2["compressed"] = options.compressData
        guard let configData2 = try? JSONSerialization.data(withJSONObject: configDict2),
              let configJSON2 = String(data: configData2, encoding: .utf8) else {
            throw HTMLGeneratorError.placeholderNotFound("CONFIG serialization failed")
        }
        html = html.replacingOccurrences(of: configPlaceholder, with: configJSON2)

        // 5. Inject logo (optional)
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
