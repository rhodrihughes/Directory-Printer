import XCTest
@testable import Directory_Printer

final class Directory_PrinterTests: XCTestCase {

    // MARK: - formatFileSize

    func testFormatFileSize_bytes() {
        XCTAssertEqual(formatFileSize(0), "0 bytes")
        XCTAssertEqual(formatFileSize(1), "1 bytes")
        XCTAssertEqual(formatFileSize(1023), "1023 bytes")
    }

    func testFormatFileSize_kilobytes() {
        XCTAssertEqual(formatFileSize(1024), "1.0 KB")
        XCTAssertEqual(formatFileSize(1536), "1.5 KB")
        XCTAssertEqual(formatFileSize(1_047_552), "1023.0 KB")
    }

    func testFormatFileSize_megabytes() {
        XCTAssertEqual(formatFileSize(1_048_576), "1.0 MB")
        XCTAssertEqual(formatFileSize(10_485_760), "10.0 MB")
        XCTAssertEqual(formatFileSize(1_072_693_248), "1023.0 MB")
    }

    func testFormatFileSize_gigabytes() {
        XCTAssertEqual(formatFileSize(1_073_741_824), "1.0 GB")
        XCTAssertEqual(formatFileSize(2_147_483_648), "2.0 GB")
    }

    // MARK: - searchFiles

    private func makeTree() -> FileNode {
        let now = Date()
        let file1 = FileNode(name: "README.md", path: "/root/README.md", isDirectory: false, size: 100, dateModified: now, isSymlink: false, children: [])
        let file2 = FileNode(name: "main.swift", path: "/root/src/main.swift", isDirectory: false, size: 200, dateModified: now, isSymlink: false, children: [])
        let file3 = FileNode(name: "Notes.txt", path: "/root/docs/Notes.txt", isDirectory: false, size: 50, dateModified: now, isSymlink: false, children: [])
        let src = FileNode(name: "src", path: "/root/src", isDirectory: true, size: 200, dateModified: now, isSymlink: false, children: [file2])
        let docs = FileNode(name: "docs", path: "/root/docs", isDirectory: true, size: 50, dateModified: now, isSymlink: false, children: [file3])
        return FileNode(name: "root", path: "/root", isDirectory: true, size: 350, dateModified: now, isSymlink: false, children: [file1, src, docs])
    }

    func testSearchFiles_exactMatch() {
        let results = searchFiles(in: makeTree(), query: "README.md")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "README.md")
    }

    func testSearchFiles_caseInsensitive() {
        let results = searchFiles(in: makeTree(), query: "readme")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "README.md")
    }

    func testSearchFiles_partialMatch() {
        // "main" matches main.swift
        let results = searchFiles(in: makeTree(), query: "main")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "main.swift")
    }

    func testSearchFiles_noMatch() {
        let results = searchFiles(in: makeTree(), query: "nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchFiles_matchesAcrossSubfolders() {
        // ".swift" and ".md" and ".txt" — query "." matches all files
        let results = searchFiles(in: makeTree(), query: ".")
        XCTAssertEqual(results.count, 3)
    }

    func testSearchFiles_doesNotReturnDirectories() {
        // "src" is a directory name — should not appear in results
        let results = searchFiles(in: makeTree(), query: "src")
        XCTAssertTrue(results.allSatisfy { !$0.isDirectory })
    }

    func testSearchFiles_emptyQuery_returnsNothing() {
        // localizedCaseInsensitiveContains("") returns false in Swift — empty query matches nothing
        let results = searchFiles(in: makeTree(), query: "")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - DataEncoder JSON roundtrip

    private func makeScanResult() -> ScanResult {
        let now = Date()
        let file = FileNode(name: "file.txt", path: "/tmp/file.txt", isDirectory: false, size: 42, dateModified: now, isSymlink: false, children: [])
        let root = FileNode(name: "tmp", path: "/tmp", isDirectory: true, size: 42, dateModified: now, isSymlink: false, children: [file])
        return ScanResult(root: root, totalFiles: 1, totalFolders: 0, scanDate: now, rootPath: "/tmp", warnings: [])
    }

    func testDataEncoder_jsonRoundtrip() throws {
        let original = makeScanResult()
        let json = try DataEncoder.encodeToJSON(original)
        let decoded = try DataEncoder.decodeFromJSON(json)
        XCTAssertEqual(decoded.totalFiles, original.totalFiles)
        XCTAssertEqual(decoded.rootPath, original.rootPath)
        XCTAssertEqual(decoded.root.name, original.root.name)
        XCTAssertEqual(decoded.root.children.count, original.root.children.count)
    }

    func testDataEncoder_invalidJSONThrows() {
        XCTAssertThrowsError(try DataEncoder.decodeFromJSON("not json"))
    }

    // MARK: - DataEncoder CSV export

    func testExportAsCSV_hasHeader() {
        let now = Date()
        let file = FileNode(name: "a.txt", path: "/a.txt", isDirectory: false, size: 10, dateModified: now, isSymlink: false, children: [])
        let csv = DataEncoder.exportAsCSV([file])
        XCTAssertTrue(csv.hasPrefix("\"Name\",\"Path\",\"Size\",\"Date Modified\""))
    }

    func testExportAsCSV_escapesQuotes() {
        let now = Date()
        let file = FileNode(name: "say \"hello\".txt", path: "/say \"hello\".txt", isDirectory: false, size: 0, dateModified: now, isSymlink: false, children: [])
        let csv = DataEncoder.exportAsCSV([file])
        XCTAssertTrue(csv.contains("\"say \"\"hello\"\".txt\""))
    }

    func testExportAsCSV_rowCount() {
        let now = Date()
        let files = (1...5).map { i in
            FileNode(name: "file\(i).txt", path: "/file\(i).txt", isDirectory: false, size: Int64(i), dateModified: now, isSymlink: false, children: [])
        }
        let lines = DataEncoder.exportAsCSV(files).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 6) // 1 header + 5 rows
    }

    // MARK: - DataEncoder plain text export

    func testExportAsPlainText_hasHeader() {
        let txt = DataEncoder.exportAsPlainText([])
        XCTAssertEqual(txt, "Name\tPath\tSize\tDate Modified")
    }

    func testExportAsPlainText_rowCount() {
        let now = Date()
        let files = (1...3).map { i in
            FileNode(name: "f\(i)", path: "/f\(i)", isDirectory: false, size: 0, dateModified: now, isSymlink: false, children: [])
        }
        let lines = DataEncoder.exportAsPlainText(files).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4) // header + 3
    }

    // MARK: - DirectoryScanner

    func testDirectoryScanner_scansRealTempDir() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Create a small tree: 2 files + 1 subfolder with 1 file
        try "hello".write(to: tmp.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "world".write(to: tmp.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let sub = tmp.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "nested".write(to: sub.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)

        let options = ScanOptions(rootPath: tmp, includeHidden: false, linkToFiles: false, generateThumbnails: false, compressData: false)
        let result = try DirectoryScanner().scan(options: options, progress: { _ in })

        XCTAssertEqual(result.totalFiles, 3)
        XCTAssertEqual(result.totalFolders, 1)
        XCTAssertEqual(result.warnings, [])
    }

    func testDirectoryScanner_excludesHiddenFiles() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try "visible".write(to: tmp.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: tmp.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

        let options = ScanOptions(rootPath: tmp, includeHidden: false, linkToFiles: false, generateThumbnails: false, compressData: false)
        let result = try DirectoryScanner().scan(options: options, progress: { _ in })

        XCTAssertEqual(result.totalFiles, 1)
        XCTAssertFalse(result.root.children.contains(where: { $0.name == ".hidden" }))
    }

    func testDirectoryScanner_includesHiddenFiles() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try "visible".write(to: tmp.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: tmp.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

        let options = ScanOptions(rootPath: tmp, includeHidden: true, linkToFiles: false, generateThumbnails: false, compressData: false)
        let result = try DirectoryScanner().scan(options: options, progress: { _ in })

        XCTAssertEqual(result.totalFiles, 2)
    }

    func testDirectoryScanner_throwsForMissingRoot() {
        let missing = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        let options = ScanOptions(rootPath: missing, includeHidden: false, linkToFiles: false, generateThumbnails: false, compressData: false)
        XCTAssertThrowsError(try DirectoryScanner().scan(options: options, progress: { _ in })) { error in
            XCTAssertTrue(error is ScanError)
        }
    }

    func testDirectoryScanner_throwsForFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try "data".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let options = ScanOptions(rootPath: tmp, includeHidden: false, linkToFiles: false, generateThumbnails: false, compressData: false)
        XCTAssertThrowsError(try DirectoryScanner().scan(options: options, progress: { _ in })) { error in
            XCTAssertTrue(error is ScanError)
        }
    }

    func testDirectoryScanner_directorySizeIsSum() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Write known-size content
        let data1 = Data(repeating: 0x41, count: 100)
        let data2 = Data(repeating: 0x42, count: 200)
        try data1.write(to: tmp.appendingPathComponent("a.bin"))
        try data2.write(to: tmp.appendingPathComponent("b.bin"))

        let options = ScanOptions(rootPath: tmp, includeHidden: false, linkToFiles: false, generateThumbnails: false, compressData: false)
        let result = try DirectoryScanner().scan(options: options, progress: { _ in })

        XCTAssertEqual(result.root.size, 300)
    }
}
