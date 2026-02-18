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

    // MARK: - Folder / file pickers

    func selectRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Root Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
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

        // Verify the output directory is writable before starting a potentially long scan.
        // If not (common with auto-suggested paths outside the sandboxed input folder),
        // prompt the user with a save panel to grant write access.
        let outputDir = output.deletingLastPathComponent()
        if !FileManager.default.isWritableFile(atPath: outputDir.path) {
            let panel = NSSavePanel()
            panel.title = "Choose Output Location"
            panel.message = "Confirm where to save the snapshot to grant access."
            panel.nameFieldStringValue = output.lastPathComponent
            panel.allowedContentTypes = [.html]
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let newOutput = panel.url else {
                return  // user cancelled
            }
            outputPath = newOutput
            return startScan()  // retry with the new path
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

                // 3. Write to disk
                try html.write(to: output, atomically: true, encoding: .utf8)

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
