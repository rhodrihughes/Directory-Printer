import Foundation

// MARK: - Protocol

protocol DirectoryScannerProtocol {
    func scan(options: ScanOptions, progress: @escaping (ScanProgress) -> Void) throws -> ScanResult
    func cancel()
}

// MARK: - Errors

enum ScanError: Error, LocalizedError {
    case rootNotFound(String)
    case rootNotDirectory(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .rootNotFound(let path):   return "Root folder not found: \(path)"
        case .rootNotDirectory(let path): return "Path is not a directory: \(path)"
        case .cancelled:                return "Scan was cancelled."
        }
    }
}

// MARK: - DirectoryScanner

class DirectoryScanner: DirectoryScannerProtocol {

    private var isCancelled = false

    // Resource keys to pre-fetch in bulk — avoids per-item round-trips on SMB/AFP.
    private static let resourceKeys: Set<URLResourceKey> = [
        .nameKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .contentModificationDateKey
    ]

    func cancel() {
        isCancelled = true
    }

    func scan(options: ScanOptions, progress: @escaping (ScanProgress) -> Void) throws -> ScanResult {
        isCancelled = false

        let rootURL = options.rootPath
        let fm = FileManager.default

        // Already running off MainActor (called from a detached task in ScanViewModel).
        // Validate root, then scan directly on this background thread.
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir) else {
            throw ScanError.rootNotFound(rootURL.path)
        }
        guard isDir.boolValue else {
            throw ScanError.rootNotDirectory(rootURL.path)
        }

        var totalFiles = 0
        var totalFolders = 0
        var warnings: [String] = []

        let root = try buildTree(
            url: rootURL,
            options: options,
            fm: fm,
            totalFiles: &totalFiles,
            totalFolders: &totalFolders,
            warnings: &warnings,
            progress: progress
        )

        return ScanResult(
            root: root,
            totalFiles: totalFiles,
            totalFolders: totalFolders,
            scanDate: Date(),
            rootPath: rootURL.path,
            warnings: warnings
        )
    }

    // MARK: - Private

    /// Builds a FileNode tree using FileManager.enumerator with pre-fetched resource keys.
    /// The enumerator lets the OS batch metadata requests, which is critical for SMB performance.
    private func buildTree(
        url: URL,
        options: ScanOptions,
        fm: FileManager,
        totalFiles: inout Int,
        totalFolders: inout Int,
        warnings: inout [String],
        progress: @escaping (ScanProgress) -> Void
    ) throws -> FileNode {

        // Emit initial progress
        progress(ScanProgress(currentFolder: url.path, filesDiscovered: 0, foldersDiscovered: 0))

        // Flat list of all descendants with pre-fetched metadata.
        // skipDescendants is called on symlinks to avoid following them.
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: options.includeHidden ? [] : [.skipsHiddenFiles]
        ) else {
            throw ScanError.rootNotFound(url.path)
        }

        // Build a path → node map so we can attach children to parents in one pass.
        var nodeMap: [String: FileNode] = [:]
        var childMap: [String: [String]] = [:]  // parent path → ordered child paths

        // Seed root
        let rootVals = try url.resourceValues(forKeys: Self.resourceKeys)
        nodeMap[url.path] = FileNode(
            name: url.lastPathComponent,
            path: url.path,
            isDirectory: true,
            size: 0,
            dateModified: rootVals.contentModificationDate ?? Date(),
            isSymlink: false,
            children: []
        )
        childMap[url.path] = []

        // Throttle progress by wall-clock time so the UI gets steady ~4 updates/sec
        // regardless of how fast or slow the scan is. This avoids flooding MainActor
        // with thousands of queued tasks on large directories.
        var lastProgressTime = CFAbsoluteTimeGetCurrent()
        let progressInterval: CFAbsoluteTime = 0.25  // seconds

        for case let itemURL as URL in enumerator {
            if isCancelled { throw ScanError.cancelled }

            let vals: URLResourceValues
            do {
                vals = try itemURL.resourceValues(forKeys: Self.resourceKeys)
            } catch {
                warnings.append("Cannot access \(itemURL.path): \(error.localizedDescription)")
                continue
            }

            let isSymlink = vals.isSymbolicLink ?? false
            let isDirectory = !isSymlink && (vals.isDirectory ?? false)
            let name = vals.name ?? itemURL.lastPathComponent
            let dateModified = vals.contentModificationDate ?? Date()
            let size = isDirectory ? 0 : Int64(vals.fileSize ?? 0)
            let parentPath = itemURL.deletingLastPathComponent().path

            // Don't descend into symlinks
            if isSymlink { enumerator.skipDescendants() }

            let node = FileNode(
                name: name,
                path: itemURL.path,
                isDirectory: isDirectory,
                size: size,
                dateModified: dateModified,
                isSymlink: isSymlink,
                children: []
            )

            nodeMap[itemURL.path] = node
            childMap[itemURL.path] = isDirectory ? [] : nil
            childMap[parentPath, default: []].append(itemURL.path)

            if isDirectory {
                totalFolders += 1
            } else {
                totalFiles += 1
            }

            let now = CFAbsoluteTimeGetCurrent()
            if now - lastProgressTime >= progressInterval {
                lastProgressTime = now
                progress(ScanProgress(
                    currentFolder: itemURL.path,
                    filesDiscovered: totalFiles,
                    foldersDiscovered: totalFolders
                ))
            }
        }

        // Final progress update
        progress(ScanProgress(
            currentFolder: url.path,
            filesDiscovered: totalFiles,
            foldersDiscovered: totalFolders
        ))

        // Roll up directory sizes: sum each folder's descendant file sizes.
        // Walk childMap bottom-up so parent sizes include nested children.
        computeDirectorySizes(rootPath: url.path, nodeMap: &nodeMap, childMap: childMap)

        // Assemble tree bottom-up: attach children to their parents.
        return assembleTree(rootPath: url.path, nodeMap: &nodeMap, childMap: childMap)
    }

    /// Computes directory sizes by summing children recursively (bottom-up).
    /// Mutates nodeMap in place so directory nodes have their total size set.
    @discardableResult
    private func computeDirectorySizes(
        rootPath: String,
        nodeMap: inout [String: FileNode],
        childMap: [String: [String]]
    ) -> Int64 {
        guard var node = nodeMap[rootPath] else { return 0 }

        guard node.isDirectory, let childPaths = childMap[rootPath] else {
            return node.size
        }

        var total: Int64 = 0
        for childPath in childPaths {
            total += computeDirectorySizes(rootPath: childPath, nodeMap: &nodeMap, childMap: childMap)
        }

        node.size = total
        nodeMap[rootPath] = node
        return total
    }

    /// Recursively assembles the FileNode tree from the flat nodeMap + childMap.
    private func assembleTree(
        rootPath: String,
        nodeMap: inout [String: FileNode],
        childMap: [String: [String]]
    ) -> FileNode {
        guard var node = nodeMap[rootPath] else {
            return FileNode(name: "", path: rootPath, isDirectory: true, size: 0,
                            dateModified: Date(), isSymlink: false, children: [])
        }

        if let childPaths = childMap[rootPath] {
            node.children = childPaths.map { childPath in
                assembleTree(rootPath: childPath, nodeMap: &nodeMap, childMap: childMap)
            }
        }

        return node
    }
}
