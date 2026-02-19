// ScanViewModel.swift
// Directory Printer

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
class ScanViewModel: ObservableObject {

    // MARK: - Published state

    @Published var rootFolder: URL? {
        didSet { outputPath = rootFolder.map { suggestedOutputURL(for: $0) } }
    }
    @Published var outputPath: URL?
    @Published var includeHidden: Bool = false
    @Published var linkToFiles: Bool = false
    @Published var isScanning: Bool = false
    @Published var progress: ScanProgress?
    @Published var scanPhase: String = ""
    @Published var errorMessage: String?
    @Published var showSuccessAlert: Bool = false
    @Published var lastOutputURL: URL?

    // MARK: - Private

    private let scanner = DirectoryScanner()
    private let workQueue = DispatchQueue(label: "DirectoryPrinter.scan", qos: .userInitiated)

    // MARK: - Security-scoped resource access

    private var rootFolderBookmark: Data?

    private func startAccessingRootFolder(_ url: URL) {
        // Stop accessing any previously held resource
        stopAccessingRootFolder()
        // On Ventura the sandbox requires explicit startAccessingSecurityScopedResource
        // for URLs obtained from NSOpenPanel before we can derive sibling paths.
        _ = url.startAccessingSecurityScopedResource()
        rootFolderBookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func stopAccessingRootFolder() {
        guard let bookmark = rootFolderBookmark else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }
        url.stopAccessingSecurityScopedResource()
        rootFolderBookmark = nil
    }

    // MARK: - Folder / file pickers

    func selectRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Root Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            startAccessingRootFolder(url)
            rootFolder = url
        }
    }

    private func suggestedOutputURL(for folder: URL) -> URL {
        let folderName = folder.lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "\(folderName)-directoryprintout-\(timestamp).html"
        return folder.deletingLastPathComponent().appendingPathComponent(filename)
    }

    func selectOutputPath() {
        let panel = NSSavePanel()
        panel.title = "Save Snapshot As"
        panel.nameFieldStringValue = outputPath?.lastPathComponent
            ?? rootFolder.map { suggestedOutputURL(for: $0).lastPathComponent }
            ?? "snapshot.html"
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK {
            outputPath = panel.url
        }
    }

    // MARK: - Scan lifecycle

    func startScan() {
        guard let root = rootFolder else {
            errorMessage = "Please select a root folder before scanning."
            return
        }
        guard let output = outputPath else {
            errorMessage = "Please choose an output file path before scanning."
            return
        }

        // Reset state
        errorMessage = nil
        showSuccessAlert = false
        lastOutputURL = nil
        isScanning = true
        progress = nil
        scanPhase = "Scanning…"

        let options = ScanOptions(
            rootPath: root,
            includeHidden: includeHidden,
            linkToFiles: linkToFiles
        )

        // Capture scanner reference before dispatching to avoid @MainActor access from GCD.
        let scanner = self.scanner
        let logoB64 = PreferencesManager.shared.logoBase64

        // Use GCD to guarantee a real background thread — no actor inference,
        // no cooperative thread pool ambiguity. The main thread stays completely free.
        workQueue.async { [weak self] in
            do {
                // 1. Scan
                let result = try scanner.scan(options: options) { scanProgress in
                    DispatchQueue.main.async { [weak self] in
                        self?.progress = scanProgress
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.scanPhase = "Generating HTML…"
                }

                // 2. Generate HTML
                let html = try HTMLGenerator.generate(
                    from: result, options: options, logoBase64: logoB64
                )

                DispatchQueue.main.async { [weak self] in
                    self?.scanPhase = "Writing file…"
                }

                // 3. Write to disk — if this fails due to sandbox permissions,
                // surface a clear error so the user can pick a different location.
                do {
                    try html.write(to: output, atomically: true, encoding: .utf8)
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.isScanning = false
                        self?.errorMessage = "Could not write to the selected location. Please use \"Choose Output File\" to pick a writable destination.\n\n(\(error.localizedDescription))"
                    }
                    return
                }

                // 4. Done
                DispatchQueue.main.async { [weak self] in
                    self?.isScanning = false
                    self?.lastOutputURL = output
                    self?.showSuccessAlert = true
                }

            } catch ScanError.cancelled {
                DispatchQueue.main.async { [weak self] in
                    self?.isScanning = false
                    self?.progress = nil
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isScanning = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelScan() {
        scanner.cancel()
        isScanning = false
    }

    // MARK: - Convenience

    func openInBrowser() {
        guard let url = lastOutputURL else { return }
        NSWorkspace.shared.open(url)
    }
}
