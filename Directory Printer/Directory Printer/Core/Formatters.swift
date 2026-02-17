import Foundation

// MARK: - File Size Formatter

/// Formats a raw byte count into a human-readable string.
///
/// Rules (from design doc):
/// - < 1024            → "N bytes"
/// - < 1_048_576       → "N.N KB"
/// - < 1_073_741_824   → "N.N MB"
/// - >= 1_073_741_824  → "N.N GB"
func formatFileSize(_ bytes: Int64) -> String {
    switch bytes {
    case ..<1_024:
        return "\(bytes) bytes"
    case ..<1_048_576:
        let kb = Double(bytes) / 1_024.0
        return String(format: "%.1f KB", kb)
    case ..<1_073_741_824:
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    default:
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}
