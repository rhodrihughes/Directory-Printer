import Foundation

// MARK: - DataEncoder

/// Handles serialization of ScanResult and FileNode data to various formats.
struct DataEncoder {

    // MARK: - JSON encode/decode for ScanResult

    private static var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Encodes a ScanResult to a JSON string.
    static func encodeToJSON(_ result: ScanResult) throws -> String {
        let data = try jsonEncoder.encode(result)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(result, .init(codingPath: [], debugDescription: "Failed to convert JSON data to UTF-8 string"))
        }
        return string
    }

    /// Decodes a ScanResult from a JSON string.
    static func decodeFromJSON(_ json: String) throws -> ScanResult {
        guard let data = json.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Input string is not valid UTF-8"))
        }
        return try jsonDecoder.decode(ScanResult.self, from: data)
    }

    // MARK: - Export formats

    /// Exports a flat list of FileNodes as tab-separated plain text.
    /// Columns: name, path, size (bytes), dateModified (ISO 8601)
    static func exportAsPlainText(_ files: [FileNode]) -> String {
        let isoFormatter = ISO8601DateFormatter()
        var lines = ["Name\tPath\tSize\tDate Modified"]
        for file in files {
            let date = isoFormatter.string(from: file.dateModified)
            lines.append("\(file.name)\t\(file.path)\t\(file.size)\t\(date)")
        }
        return lines.joined(separator: "\n")
    }

    /// Exports a flat list of FileNodes as CSV with a header row and proper escaping.
    static func exportAsCSV(_ files: [FileNode]) -> String {
        let isoFormatter = ISO8601DateFormatter()
        var lines = [csvEscape("Name") + "," + csvEscape("Path") + "," + csvEscape("Size") + "," + csvEscape("Date Modified")]
        for file in files {
            let date = isoFormatter.string(from: file.dateModified)
            lines.append([file.name, file.path, String(file.size), date].map { csvEscape($0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Exports a flat list of FileNodes as a JSON array.
    static func exportAsJSON(_ files: [FileNode]) -> String {
        let isoFormatter = ISO8601DateFormatter()
        let objects: [[String: Any]] = files.map { file in
            [
                "name": file.name,
                "path": file.path,
                "size": file.size,
                "dateModified": isoFormatter.string(from: file.dateModified)
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    // MARK: - Private helpers

    /// Wraps a CSV field in quotes and escapes internal quotes by doubling them.
    private static func csvEscape(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
