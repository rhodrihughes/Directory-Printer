import Foundation

// MARK: - Search

/// Recursively searches a FileNode tree for files whose names contain the query string.
///
/// - Parameters:
///   - root: The root FileNode to search within.
///   - query: The search string (case-insensitive).
/// - Returns: All matching file (non-directory) nodes whose names contain the query.
func searchFiles(in root: FileNode, query: String) -> [FileNode] {
    var results: [FileNode] = []
    searchRecursive(node: root, query: query, results: &results)
    return results
}

private func searchRecursive(node: FileNode, query: String, results: inout [FileNode]) {
    if !node.isDirectory {
        if node.name.localizedCaseInsensitiveContains(query) {
            results.append(node)
        }
    }
    for child in node.children {
        searchRecursive(node: child, query: query, results: &results)
    }
}
