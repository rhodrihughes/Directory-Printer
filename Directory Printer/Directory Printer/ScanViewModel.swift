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
        didSet {
            outputPath = rootFolder.map { suggestedOutputURL(for: $0) }
            outputFolderURL = nil
            outputPathConfirmed = false
        }
    }
    @Published var outputPath: URL?
    /// When thumbnails are enabled the user picks a folder instead of a file.
    /// This holds the chosen folder URL so we can display it and use it at scan time.
    @Published var outputFolderURL: URL?
    /// True only when the user explicitly confirmed a path via panel.
    private var outputPathConfirmed = false

    @Published var includeHidden: Bool = false
    @Published var linkToFiles: Bool = false
    @Published var generateThumbnails: Bool = false {
        didSet {
            // Reset output selection when switching modes so the user picks again
            // with the correct panel type.
            outputPathConfirmed = false
            outputFolderURL = nil
        }
    }
    /// When true and thumbnails are enabled, the output folder is zipped and the
    /// unzipped folder is deleted, leaving a single .zip ready to share.
    @Published var zipThumbnailOutput: Bool = false
    @Published var compressData: Bool = false
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
    private var outputBookmark: Data?

    private func startAccessingRootFolder(_ url: URL) {
        // Stop accessing any previously held resource
        stopAccessingRootFolder()
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

    private func startAccessingOutputFolder(_ url: URL) {
        stopAccessingOutputFolder()
        let folderURL = url.deletingLastPathComponent()
        _ = folderURL.startAccessingSecurityScopedResource()
        outputBookmark = try? folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func stopAccessingOutputFolder() {
        guard let bookmark = outputBookmark else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }
        url.stopAccessingSecurityScopedResource()
        outputBookmark = nil
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
        if generateThumbnails {
            // Thumbnail mode: pick a folder — we'll create a named subfolder inside it.
            let panel = NSOpenPanel()
            panel.title = "Choose Output Folder"
            panel.message = "Select a folder to save the snapshot and thumbnails into."
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                _ = url.startAccessingSecurityScopedResource()
                outputFolderURL = url
                outputPathConfirmed = true
            }
        } else {
            // Normal mode: pick a file via save panel.
            let panel = NSSavePanel()
            panel.title = "Save Snapshot As"
            panel.nameFieldStringValue = outputPath?.lastPathComponent
                ?? rootFolder.map { suggestedOutputURL(for: $0).lastPathComponent }
                ?? "snapshot.html"
            panel.allowedContentTypes = [.html]
            panel.canCreateDirectories = true
            if panel.runModal() == .OK {
                outputPath = panel.url
                outputPathConfirmed = true
                if let url = panel.url {
                    startAccessingOutputFolder(url)
                }
            }
        }
    }

    /// Shows a folder picker and returns the selected directory URL with sandbox access.
    /// The caller is responsible for calling stopAccessingSecurityScopedResource() on the returned URL.
    private func selectOutputFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.message = "Select a folder to save the snapshot and thumbnails into."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let folderURL = panel.url else { return nil }
        _ = folderURL.startAccessingSecurityScopedResource()
        return folderURL
    }

    // MARK: - Scan lifecycle

    func startScan() {
        guard let root = rootFolder else {
            errorMessage = "Please select a root folder before scanning."
            return
        }

        if !outputPathConfirmed {
            selectOutputPath()
            guard outputPathConfirmed else { return }
        }

        guard let output = outputPath else {
            errorMessage = "Please choose an output file path before scanning."
            return
        }

        // When thumbnails are enabled the user already picked a folder via selectOutputPath().
        // Use that folder URL directly — it already has security-scoped access started.
        let resolvedOutput: URL
        let thumbnailFolderURL: URL?  // held to keep security-scoped access alive
        if generateThumbnails {
            guard let folder = outputFolderURL else {
                errorMessage = "Please choose an output folder before scanning."
                return
            }
            let filename = suggestedOutputURL(for: root).lastPathComponent
            resolvedOutput = folder.appendingPathComponent(filename)
            thumbnailFolderURL = folder
        } else {
            resolvedOutput = output
            thumbnailFolderURL = nil
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
            linkToFiles: linkToFiles,
            generateThumbnails: generateThumbnails,
            compressData: compressData
        )

        // Capture scanner reference before dispatching to avoid @MainActor access from GCD.
        let scanner = self.scanner
        let logoB64 = PreferencesManager.shared.logoBase64
        let thumbPixelSize: CGFloat = PreferencesManager.shared.retinaThumnails ? 128 : 64
        let zipOutput = self.zipThumbnailOutput

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

                // 2. Optionally generate thumbnails
                var thumbnailsFolderName: String? = nil
                var resultWithThumbs = result
                let htmlOutput: URL
                if options.generateThumbnails {
                    let stem = resolvedOutput.deletingPathExtension().lastPathComponent
                    let containingFolder = resolvedOutput.deletingLastPathComponent()
                        .appendingPathComponent(stem)
                    do {
                        try FileManager.default.createDirectory(
                            at: containingFolder, withIntermediateDirectories: true)
                    } catch {
                        DispatchQueue.main.async { [weak self] in
                            thumbnailFolderURL?.stopAccessingSecurityScopedResource()
                            self?.isScanning = false
                            self?.errorMessage = "Could not create output folder: \(error.localizedDescription)"
                        }
                        return
                    }
                    htmlOutput = containingFolder.appendingPathComponent(resolvedOutput.lastPathComponent)

                    DispatchQueue.main.async { [weak self] in
                        self?.scanPhase = "Generating thumbnails…"
                    }
                    let thumbFolder = containingFolder.appendingPathComponent("thumbnails")
                    let thumbMap = ThumbnailGenerator.generate(from: result.root, outputFolder: thumbFolder, pixelSize: thumbPixelSize) { done, total in
                        DispatchQueue.main.async { [weak self] in
                            self?.scanPhase = "Thumbnails: \(done)/\(total)…"
                        }
                    }
                    ThumbnailGenerator.applyThumbnailMap(thumbMap, to: &resultWithThumbs.root)
                    thumbnailsFolderName = "thumbnails"
                } else {
                    htmlOutput = resolvedOutput
                }

                DispatchQueue.main.async { [weak self] in
                    self?.scanPhase = "Generating HTML…"
                }

                // 3. Generate HTML
                let html = try HTMLGenerator.generate(
                    from: resultWithThumbs, options: options, logoBase64: logoB64,
                    thumbnailsFolder: thumbnailsFolderName
                )

                DispatchQueue.main.async { [weak self] in
                    self?.scanPhase = "Writing file…"
                }

                // 4. Write to disk — if this fails due to sandbox permissions,
                // surface a clear error so the user can pick a different location.
                do {
                    try html.write(to: htmlOutput, atomically: true, encoding: .utf8)
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        thumbnailFolderURL?.stopAccessingSecurityScopedResource()
                        self?.isScanning = false
                        self?.errorMessage = "Could not write to the selected location. Please use \"Choose Output File\" to pick a writable destination.\n\n(\(error.localizedDescription))"
                    }
                    return
                }

                // 5. Optionally zip the output folder and delete the unzipped copy.
                let finalOutputURL: URL
                if options.generateThumbnails && zipOutput {
                    DispatchQueue.main.async { [weak self] in self?.scanPhase = "Zipping…" }
                    let containingFolder = htmlOutput.deletingLastPathComponent()
                    let zipURL = containingFolder.deletingLastPathComponent()
                        .appendingPathComponent(containingFolder.lastPathComponent + ".zip")
                    do {
                        try ZipWriter.zip(folder: containingFolder, to: zipURL)
                        try FileManager.default.removeItem(at: containingFolder)
                        finalOutputURL = zipURL
                    } catch {
                        DispatchQueue.main.async { [weak self] in
                            thumbnailFolderURL?.stopAccessingSecurityScopedResource()
                            self?.isScanning = false
                            self?.errorMessage = "Could not create zip archive: \(error.localizedDescription)"
                        }
                        return
                    }
                } else {
                    finalOutputURL = htmlOutput
                }

                // 6. Done
                DispatchQueue.main.async { [weak self] in
                    thumbnailFolderURL?.stopAccessingSecurityScopedResource()
                    self?.isScanning = false
                    self?.lastOutputURL = finalOutputURL
                    self?.showSuccessAlert = true
                }

            } catch ScanError.cancelled {
                DispatchQueue.main.async { [weak self] in
                    thumbnailFolderURL?.stopAccessingSecurityScopedResource()
                    self?.isScanning = false
                    self?.progress = nil
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    thumbnailFolderURL?.stopAccessingSecurityScopedResource()
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
        if url.pathExtension.lowercased() == "zip" {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
