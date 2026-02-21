// HTMLGenerator.swift
// Directory Printer
//
// Produces a self-contained HTML snapshot by injecting encoded scan data
// and configuration into the HTML template.

import Foundation

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
        html = html.replacingOccurrences(of: dataPlaceholder, with: jsonData)

        // 4. Inject SNAPSHOT_CONFIG
        let configPlaceholder = "/*SNAPSHOT_CONFIG*/"
        guard html.contains(configPlaceholder) else {
            throw HTMLGeneratorError.placeholderNotFound(configPlaceholder)
        }
        html = html.replacingOccurrences(of: configPlaceholder, with: configJSON)

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
