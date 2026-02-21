// ThumbnailGenerator.swift
// Directory Printer
//
// Generates thumbnails for image and video files using QLThumbnailGenerator,
// the same engine used by Finder and Quick Look.

import AppKit
import Foundation
import QuickLookThumbnailing

// MARK: - ThumbnailGenerator

struct ThumbnailGenerator {

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "tif", "heic", "heif"
    ]

    static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"
    ]

    static let qlExtensions: Set<String> = videoExtensions.union([
        // PDF
        "pdf",
        // Office
        "docx", "xlsx", "pptx", "doc", "xls", "ppt",
        // iWork
        "pages", "numbers", "keynote",
        // 3D
        "usdz", "obj", "scn", "abc", "ply", "stl"
    ])

    static let supportedExtensions: Set<String> = imageExtensions.union(qlExtensions)

    /// Generates thumbnails and returns the path→filename map.
    /// - Parameter pixelSize: The max dimension in pixels. Use 64 for standard, 128 for 2× retina.
    @discardableResult
    static func generate(
        from root: FileNode,
        outputFolder: URL,
        pixelSize: CGFloat = 64,
        progress: ((Int, Int) -> Void)? = nil
    ) -> [String: String] {
        let fm = FileManager.default
        try? fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        var mediaFiles: [FileNode] = []
        collectSupportedFiles(root, into: &mediaFiles)

        var map: [String: String] = [:]
        let total = mediaFiles.count
        let group = DispatchGroup()
        let lock = NSLock()

        for (index, node) in mediaFiles.enumerated() {
            progress?(index + 1, total)
            let filename = "\(abs(node.path.hashValue)).jpg"
            let dest = outputFolder.appendingPathComponent(filename)
            let ext = (node.name as NSString).pathExtension.lowercased()

            if Self.imageExtensions.contains(ext) {
                // High-quality direct render for images
                if let data = makeImageThumbnail(for: node.path, pixelSize: pixelSize) {
                    try? data.write(to: dest)
                    map[node.path] = filename
                }
            } else {
                // QL for video, PDF, office docs, etc.
                group.enter()
                generateQLThumbnail(for: node.path, saveTo: dest, pixelSize: pixelSize) { success in
                    if success {
                        lock.lock()
                        map[node.path] = filename
                        lock.unlock()
                    }
                    group.leave()
                }
                group.wait()
            }
        }

        return map
    }

    /// Stamps thumbnail filenames from `map` back into the FileNode tree.
    static func applyThumbnailMap(_ map: [String: String], to node: inout FileNode) {
        if node.isDirectory {
            for i in node.children.indices {
                applyThumbnailMap(map, to: &node.children[i])
            }
        } else if let filename = map[node.path] {
            node.thumbFile = filename
        }
    }

    // MARK: - Private

    private static func collectSupportedFiles(_ node: FileNode, into result: inout [FileNode]) {
        if node.isDirectory {
            for child in node.children {
                collectSupportedFiles(child, into: &result)
            }
        } else {
            let ext = (node.name as NSString).pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                result.append(node)
            }
        }
    }

    private static func makeImageThumbnail(for path: String, pixelSize: CGFloat = 64) -> Data? {
        guard let image = NSImage(contentsOfFile: path),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let srcW = CGFloat(cgImage.width)
        let srcH = CGFloat(cgImage.height)
        guard srcW > 0, srcH > 0 else { return nil }

        // Work entirely in pixels — never points — so Retina scale has no effect
        let maxPx: CGFloat = pixelSize
        let scale = min(1.0, min(maxPx / srcW, maxPx / srcH))
        let outW = Int((srcW * scale).rounded())
        let outH = Int((srcH * scale).rounded())

        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: outW, height: outH,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        // Fill white so transparent PNGs don't get a black background
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: outW, height: outH))

        guard let scaled = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: scaled)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.5])
    }

    private static func generateQLThumbnail(for path: String, saveTo dest: URL, pixelSize: CGFloat = 64, completion: @escaping (Bool) -> Void) {
        let url = URL(fileURLWithPath: path)
        let size = CGSize(width: pixelSize, height: pixelSize)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 1.0,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            guard let cgImage = thumbnail?.cgImage else {
                completion(false)
                return
            }
            // Clamp to pixelSize — QL may return larger images depending on scale
            let maxPx: CGFloat = pixelSize
            let w = CGFloat(cgImage.width)
            let h = CGFloat(cgImage.height)
            let scale = min(1.0, min(maxPx / w, maxPx / h))
            let outW = Int((w * scale).rounded())
            let outH = Int((h * scale).rounded())
            let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(data: nil, width: outW, height: outH,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
                  let _ = { ctx.interpolationQuality = .high; return true }(),
                  let _ = { ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: outW, height: outH)); return true }(),
                  let scaled = ctx.makeImage() else {
                completion(false)
                return
            }
            let rep = NSBitmapImageRep(cgImage: scaled)
            guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) else {
                completion(false)
                return
            }
            do {
                try data.write(to: dest)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
}
