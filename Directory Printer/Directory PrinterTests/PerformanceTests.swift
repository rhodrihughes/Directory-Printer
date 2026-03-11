// PerformanceTests.swift
// Directory Printer
//
// XCTest performance benchmarks for the core scan/generate pipeline.
// Run via Product > Test or `xcodebuild test`.
// Each measure{} block runs 10 iterations; Xcode tracks the baseline
// and flags regressions automatically.

import XCTest
@testable import Directory_Printer

final class PerformanceTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a temp directory tree with `fileCount` files spread across `folderCount` subdirectories.
    private func makeTempTree(fileCount: Int, folderCount: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dp-perf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let filesPerFolder = max(1, fileCount / max(1, folderCount))
        var created = 0

        for f in 0..<folderCount {
            let folder = root.appendingPathComponent("folder_\(f)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for i in 0..<filesPerFolder {
                guard created < fileCount else { break }
                let content = "file content \(f)-\(i) " + String(repeating: "x", count: 200)
                try content.write(to: folder.appendingPathComponent("file_\(i).txt"),
                                  atomically: true, encoding: .utf8)
                created += 1
            }
        }
        // Remaining files in root
        while created < fileCount {
            try "extra".write(to: root.appendingPathComponent("extra_\(created).txt"),
                              atomically: true, encoding: .utf8)
            created += 1
        }
        return root
    }

    private func scanOptions(_ root: URL, compress: Bool = false) -> ScanOptions {
        ScanOptions(rootPath: root, includeHidden: false, linkToFiles: false,
                    generateThumbnails: false, compressData: compress, encryptionPassword: nil)
    }

    // MARK: - DirectoryScanner performance

    /// Baseline: scan a flat directory of 1 000 files.
    func testPerf_scan_1k_files() throws {
        let root = try makeTempTree(fileCount: 1_000, folderCount: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        let scanner = DirectoryScanner()
        let opts = scanOptions(root)

        measure {
            _ = try? scanner.scan(options: opts, progress: { _ in })
        }
    }

    /// Stress: scan 5 000 files across 50 folders — exercises the stack-based tree builder.
    func testPerf_scan_5k_files() throws {
        let root = try makeTempTree(fileCount: 5_000, folderCount: 50)
        defer { try? FileManager.default.removeItem(at: root) }

        let scanner = DirectoryScanner()
        let opts = scanOptions(root)

        measure {
            _ = try? scanner.scan(options: opts, progress: { _ in })
        }
    }

    /// Deep nesting: 500 files in a 20-level deep chain — stresses stack pop/push logic.
    func testPerf_scan_deep_nesting() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dp-deep-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var current = root
        for depth in 0..<20 {
            current = current.appendingPathComponent("level_\(depth)")
            try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
            for i in 0..<25 {
                try "data".write(to: current.appendingPathComponent("f\(i).txt"),
                                 atomically: true, encoding: .utf8)
            }
        }

        let scanner = DirectoryScanner()
        let opts = scanOptions(root)

        measure {
            _ = try? scanner.scan(options: opts, progress: { _ in })
        }
    }

    // MARK: - HTMLGenerator performance

    /// Measures HTML generation time for a 1 000-file scan result (uncompressed).
    func testPerf_htmlGenerate_1k_uncompressed() throws {
        let root = try makeTempTree(fileCount: 1_000, folderCount: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })
        let opts = scanOptions(root, compress: false)

        measure {
            _ = try? HTMLGenerator.generate(from: result, options: opts)
        }
    }

    /// Measures HTML generation time for a 1 000-file scan result (gzip compressed).
    func testPerf_htmlGenerate_1k_compressed() throws {
        let root = try makeTempTree(fileCount: 1_000, folderCount: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })
        let opts = scanOptions(root, compress: true)

        measure {
            _ = try? HTMLGenerator.generate(from: result, options: opts)
        }
    }

    /// Measures HTML generation for a 5 000-file result — the placeholder-split path
    /// should be noticeably faster than the old replacingOccurrences approach at this scale.
    func testPerf_htmlGenerate_5k_uncompressed() throws {
        let root = try makeTempTree(fileCount: 5_000, folderCount: 50)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })
        let opts = scanOptions(root, compress: false)

        measure {
            _ = try? HTMLGenerator.generate(from: result, options: opts)
        }
    }

    // MARK: - JSON encoding performance

    /// Measures DataEncoder.encodeToJSON for a large tree — this is the hot path
    /// inside HTMLGenerator before any compression/encryption.
    func testPerf_jsonEncode_5k_nodes() throws {
        let root = try makeTempTree(fileCount: 5_000, folderCount: 50)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })

        measure {
            _ = try? DataEncoder.encodeToJSON(result)
        }
    }

    // MARK: - End-to-end pipeline

    /// Full pipeline: scan → generate HTML → write to disk (1 000 files, uncompressed).
    func testPerf_endToEnd_1k_uncompressed() throws {
        let root = try makeTempTree(fileCount: 1_000, folderCount: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dp-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outDir) }

        let scanner = DirectoryScanner()
        let opts = scanOptions(root)

        measure {
            guard let result = try? scanner.scan(options: opts, progress: { _ in }),
                  let html = try? HTMLGenerator.generate(from: result, options: opts) else { return }
            let out = outDir.appendingPathComponent("\(UUID().uuidString).html")
            try? html.write(to: out, atomically: true, encoding: .utf8)
        }
    }

    /// Full pipeline: scan → generate HTML → write to disk (1 000 files, compressed).
    func testPerf_endToEnd_1k_compressed() throws {
        let root = try makeTempTree(fileCount: 1_000, folderCount: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dp-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outDir) }

        let scanner = DirectoryScanner()
        let opts = scanOptions(root, compress: true)

        measure {
            guard let result = try? scanner.scan(options: opts, progress: { _ in }),
                  let html = try? HTMLGenerator.generate(from: result, options: opts) else { return }
            let out = outDir.appendingPathComponent("\(UUID().uuidString).html")
            try? html.write(to: out, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Memory footprint (heuristic)

    /// Verifies that scanning 2 000 files doesn't produce a tree whose in-memory
    /// JSON representation exceeds a reasonable ceiling (~10 MB for 2K nodes).
    /// This is a proxy for the stack-based scanner's memory efficiency.
    func testMemory_jsonSize_2k_files() throws {
        let root = try makeTempTree(fileCount: 2_000, folderCount: 20)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })
        let json = try DataEncoder.encodeToJSON(result)
        let byteCount = json.utf8.count

        // Each node is ~200 bytes of JSON on average; 2 000 nodes ≈ 400 KB.
        // Allow 5× headroom for long paths/dates → 2 MB ceiling.
        let maxBytes = 2 * 1024 * 1024
        XCTAssertLessThan(byteCount, maxBytes,
            "JSON for 2K nodes is \(byteCount) bytes — exceeds \(maxBytes) byte ceiling")
    }

    /// Verifies directory size roll-up is correct after the stack-based rewrite.
    func testCorrectness_directorySizeRollup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dp-size-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sub = root.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

        let d1 = Data(repeating: 0x41, count: 512)
        let d2 = Data(repeating: 0x42, count: 1024)
        try d1.write(to: root.appendingPathComponent("a.bin"))
        try d2.write(to: sub.appendingPathComponent("b.bin"))

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })
        XCTAssertEqual(result.root.size, 512 + 1024)
        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.totalFolders, 1)
    }

    /// Verifies children are sorted: directories before files, both alphabetically.
    func testCorrectness_childrenSortOrder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dp-sort-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Create in reverse-alpha order to confirm sorting
        try "z".write(to: root.appendingPathComponent("z_file.txt"), atomically: true, encoding: .utf8)
        try "a".write(to: root.appendingPathComponent("a_file.txt"), atomically: true, encoding: .utf8)
        let dirZ = root.appendingPathComponent("z_dir")
        let dirA = root.appendingPathComponent("a_dir")
        try FileManager.default.createDirectory(at: dirZ, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)

        let result = try DirectoryScanner().scan(options: scanOptions(root), progress: { _ in })
        let children = result.root.children

        // Directories come first
        let dirs = children.filter { $0.isDirectory }
        let files = children.filter { !$0.isDirectory }
        XCTAssertFalse(dirs.isEmpty)
        XCTAssertFalse(files.isEmpty)
        let lastDirIndex = children.lastIndex(where: { $0.isDirectory })!
        let firstFileIndex = children.firstIndex(where: { !$0.isDirectory })!
        XCTAssertLessThan(lastDirIndex, firstFileIndex, "All directories should precede all files")

        // Alphabetical within each group
        XCTAssertEqual(dirs.map { $0.name }, dirs.map { $0.name }.sorted())
        XCTAssertEqual(files.map { $0.name }, files.map { $0.name }.sorted())
    }
}
