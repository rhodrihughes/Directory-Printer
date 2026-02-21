// PreferencesManager.swift
// Directory Printer
//
// Persists user preferences (logo image) via UserDefaults.

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
class PreferencesManager: ObservableObject {

    static let shared = PreferencesManager()

    private let logoKey = "logoBase64"
    private let retinaThumbsKey = "retinaThumnails"
    private let maxHeight: CGFloat = 32

    /// Base64-encoded PNG of the (possibly resized) logo, or nil if none set.
    @Published var logoBase64: String? {
        didSet { UserDefaults.standard.set(logoBase64, forKey: logoKey) }
    }

    /// When true, thumbnails are generated at 128×128 (2× retina) instead of 64×64.
    @Published var retinaThumnails: Bool {
        didSet { UserDefaults.standard.set(retinaThumnails, forKey: retinaThumbsKey) }
    }

    private init() {
        logoBase64 = UserDefaults.standard.string(forKey: logoKey)
        retinaThumnails = UserDefaults.standard.bool(forKey: retinaThumbsKey)
    }

    // MARK: - Image selection

    func selectLogo() {
        let panel = NSOpenPanel()
        panel.title = "Choose Logo Image"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url) else { return }

        logoBase64 = resizeAndEncode(image)
    }

    func clearLogo() {
        logoBase64 = nil
    }

    // MARK: - Helpers

    private func resizeAndEncode(_ image: NSImage) -> String? {
        let originalSize = image.size
        let targetHeight = min(originalSize.height, maxHeight)
        let scale = targetHeight / originalSize.height
        let targetSize = NSSize(width: originalSize.width * scale, height: targetHeight)

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }

        return png.base64EncodedString()
    }
}
