// ScanViewModel.swift
// Directory Printer
//
// ObservableObject view model that drives the macOS GUI.
// All UI-state mutations happen on @MainActor; panel calls are dispatched
// to the main thread explicitly so they work from async contexts.

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
class ScanViewModel: ObservableObject {

    // MARK: - Published state

    @Published var rootFolder: URL?
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

    // MARK: - Folder / file pickers

    /// Opens a native macOS folder-picker panel (Req 8.1).
    func selectRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Root Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            rootFolder = url  // didSet handles outputPath suggestion
        }
    }

    /// Builds a suggested output URL: FolderName-directoryprintout-YYYY-MM-DD-HHmm.html
    /// placed next to the selected folder.
    private func suggestedOutputURL(for folder: URL) -> URL {
        let folderName = folder.lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "\(folderName)-directoryprintout-\(timestamp).html"
        return folder.deletingLastPathComponent().appendingPathComponent(filename)
    }

    /// Opens a native macOS save panel for the output HTML file (Req 8.2).
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

    /// Runs the full scan → generate → write pipeline asynchronously (Req 8.3–8.6).
    func startScan() async {
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

        // Yield so SwiftUI can render the spinner before we start work
        await Task.yield()

        let options = ScanOptions(
            rootPath: root,
            includeHidden: includeHidden,
            linkToFiles: linkToFiles
        )

        do {
            // Run the scan; progress callbacks arrive on arbitrary threads so
            // we hop back to MainActor before mutating published state.
            let result = try await scanner.scan(options: options) { [weak self] scanProgress in
                guard let self else { return }
                Task { @MainActor in
                    self.progress = scanProgress
                }
            }

            // Generate HTML off the main thread so the spinner keeps animating
            scanPhase = "Generating HTML…"
            await Task.yield()
            let logoB64 = PreferencesManager.shared.logoBase64
            let html = try await Task.detached(priority: .userInitiated) {
                try HTMLGenerator.generate(from: result, options: options, logoBase64: logoB64)
            }.value

            // Write to disk off the main thread
            scanPhase = "Writing file…"
            await Task.yield()
            try await Task.detached(priority: .userInitiated) {
                try html.write(to: output, atomically: true, encoding: .utf8)
            }.value

            // Success
            isScanning = false
            lastOutputURL = output
            showSuccessAlert = true

        } catch ScanError.cancelled {
            isScanning = false
            progress = nil
        } catch {
            isScanning = false
            errorMessage = error.localizedDescription
        }
    }

    /// Cancels an in-progress scan gracefully (Req 8.4).
    func cancelScan() {
        scanner.cancel()
        isScanning = false
    }

    // MARK: - Convenience

    /// Opens the last successfully generated snapshot in the default browser (Req 8.5).
    func openInBrowser() {
        guard let url = lastOutputURL else { return }
        NSWorkspace.shared.open(url)
    }
}
