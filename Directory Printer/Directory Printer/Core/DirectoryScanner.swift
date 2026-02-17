import Foundation

// MARK: - Protocol

protocol DirectoryScannerProtocol {
    func scan(options: ScanOptions, progress: @escaping (ScanProgress) -> Void) async throws -> ScanResult
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

    func cancel() {
        isCancelled = true
    }

    func scan(options: ScanOptions, progress: @escaping (ScanProgress) -> Void) async throws -> ScanResult {
        isCancelled = false

        let rootPath = options.rootPath.path
        let fm = FileManager.default

        // Validate root
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootPath, isDirectory: &isDir) else {
            throw ScanError.rootNotFound(rootPath)
        }
        guard isDir.boolValue else {
            throw ScanError.rootNotDirectory(rootPath)
        }

        var totalFiles = 0
        var totalFolders = 0
        var warnings: [String] = []

        let root = try scanDirectory(
            path: rootPath,
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
            rootPath: rootPath,
            warnings: warnings
        )
    }

    // MARK: - Private

    private func scanDirectory(
        path: String,
        options: ScanOptions,
        fm: FileManager,
        totalFiles: inout Int,
        totalFolders: inout Int,
        warnings: inout [String],
        progress: @escaping (ScanProgress) -> Void
    ) throws -> FileNode {

        // Emit progress for this directory
        progress(ScanProgress(
            currentFolder: path,
            filesDiscovered: totalFiles,
            foldersDiscovered: totalFolders
        ))

        // Attributes for the directory itself
        let dirAttrs = (try? fm.attributesOfItem(atPath: path)) ?? [:]
        let dirDate = dirAttrs[.modificationDate] as? Date ?? Date()
        let dirName = (path as NSString).lastPathComponent

        // Enumerate contents (shallow — we recurse manually)
        let contents: [String]
        do {
            contents = try fm.contentsOfDirectory(atPath: path)
        } catch {
            warnings.append("Cannot read directory \(path): \(error.localizedDescription)")
            return FileNode(
                name: dirName,
                path: path,
                isDirectory: true,
                size: 0,
                dateModified: dirDate,
                isSymlink: false,
                children: []
            )
        }

        var children: [FileNode] = []

        for itemName in contents {
            if isCancelled { throw ScanError.cancelled }

            // Hidden file filter
            if !options.includeHidden && itemName.hasPrefix(".") { continue }

            let itemPath = (path as NSString).appendingPathComponent(itemName)

            // Detect symlink without following it
            let isSymlink = isSymbolicLink(at: itemPath, fm: fm)

            // Collect attributes (lstat — does not follow symlinks)
            let attrs: [FileAttributeKey: Any]
            do {
                attrs = try fm.attributesOfItem(atPath: itemPath)
            } catch {
                warnings.append("Cannot access \(itemPath): \(error.localizedDescription)")
                continue
            }

            let dateModified = attrs[.modificationDate] as? Date ?? Date()
            let fileType = attrs[.type] as? FileAttributeType

            if isSymlink {
                // Record symlink as-is, never follow
                let size = attrs[.size] as? Int64 ?? 0
                children.append(FileNode(
                    name: itemName,
                    path: itemPath,
                    isDirectory: false,
                    size: size,
                    dateModified: dateModified,
                    isSymlink: true,
                    children: []
                ))
                totalFiles += 1
            } else if fileType == .typeDirectory {
                totalFolders += 1
                let child = try scanDirectory(
                    path: itemPath,
                    options: options,
                    fm: fm,
                    totalFiles: &totalFiles,
                    totalFolders: &totalFolders,
                    warnings: &warnings,
                    progress: progress
                )
                children.append(child)
            } else {
                let size = attrs[.size] as? Int64 ?? 0
                children.append(FileNode(
                    name: itemName,
                    path: itemPath,
                    isDirectory: false,
                    size: size,
                    dateModified: dateModified,
                    isSymlink: false,
                    children: []
                ))
                totalFiles += 1
            }
        }

        return FileNode(
            name: dirName,
            path: path,
            isDirectory: true,
            size: 0,
            dateModified: dirDate,
            isSymlink: false,
            children: children
        )
    }

    /// Returns true if the item at `path` is a symbolic link (does not follow the link).
    private func isSymbolicLink(at path: String, fm: FileManager) -> Bool {
        // Use lstat via FileManager's destinationOfSymbolicLink — if it succeeds the item is a symlink.
        // More reliably: check the file type from attributesOfItem which uses lstat on macOS.
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let type_ = attrs[.type] as? FileAttributeType {
            return type_ == .typeSymbolicLink
        }
        return false
    }
}
