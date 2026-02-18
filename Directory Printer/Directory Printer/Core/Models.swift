import Foundation

// MARK: - FileNode

/// Represents a single file or folder in the scanned directory tree.
struct FileNode: Codable, Equatable {
    let name: String
    let path: String
    let isDirectory: Bool
    var size: Int64           // bytes; sum of children for directories
    let dateModified: Date
    let isSymlink: Bool
    var children: [FileNode] // empty for files
}

// MARK: - ScanOptions

/// Configuration for a scan operation.
struct ScanOptions {
    let rootPath: URL
    let includeHidden: Bool
    let linkToFiles: Bool
}

// MARK: - ScanResult

/// Output of a completed scan.
struct ScanResult: Codable {
    let root: FileNode
    let totalFiles: Int
    let totalFolders: Int
    let scanDate: Date
    let rootPath: String
    let warnings: [String]  // permission errors, skipped items
}

// MARK: - ScanProgress

/// Progress update emitted during a scan.
struct ScanProgress {
    let currentFolder: String
    let filesDiscovered: Int
    let foldersDiscovered: Int
}
