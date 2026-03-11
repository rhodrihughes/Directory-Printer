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
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        // Collect just the lightweight (path, name) pairs — avoids holding full FileNode copies.
        var files: [(path: String, name: String)] = []
        collectSupportedFiles(root, into: &files)
        let total = files.count

        var map: [String: String] = [:]
        let lock = NSLock()
        var completedCount = 0

        // Use fewer concurrent workers on network volumes to avoid overwhelming the
        // SMB server with simultaneous file reads. Local volumes use all CPU cores.
        let workerCount = concurrencyLimit(for: root.path)
        let semaphore = DispatchSemaphore(value: workerCount)
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for i in 0..<total {
            semaphore.wait()
            group.enter()
            queue.async {
                defer {
                    semaphore.signal()
                    group.leave()
                }
                let file = files[i]
                let ext = (file.name as NSString).pathExtension.lowercased()
                let filename = "\(abs(file.path.hashValue)).jpg"
                let dest = outputFolder.appendingPathComponent(filename)

                // Each iteration gets its own pool — AppKit objects are freed as soon as
                // the thumbnail is written, keeping per-core memory usage flat.
                autoreleasepool {
                    let success: Bool
                    if Self.imageExtensions.contains(ext) {
                        if let data = makeImageThumbnail(for: file.path, pixelSize: pixelSize) {
                            success = (try? data.write(to: dest)) != nil
                        } else {
                            success = false
                        }
                    } else {
                        success = generateQLThumbnailSync(for: file.path, saveTo: dest, pixelSize: pixelSize)
                    }

                    lock.lock()
                    if success { map[file.path] = filename }
                    completedCount += 1
                    let done = completedCount
                    lock.unlock()

                    progress?(done, total)
                }
            }
        }

        group.wait()
        return map
    }

    /// Returns the max number of concurrent thumbnail workers appropriate for the volume.
    /// Network volumes (SMB, AFP, NFS) are capped to avoid overwhelming the server.
    private static func concurrencyLimit(for path: String) -> Int {
        let url = URL(fileURLWithPath: path)
        let vals = try? url.resourceValues(forKeys: [.volumeIsLocalKey])
        let isLocal = vals?.volumeIsLocal ?? true
        return isLocal ? ProcessInfo.processInfo.activeProcessorCount : 4
    }

    // MARK: - Private walk helpers

    private static func collectSupportedFiles(_ node: FileNode, into result: inout [(path: String, name: String)]) {
        if node.isDirectory {
            for child in node.children {
                collectSupportedFiles(child, into: &result)
            }
        } else {
            let ext = (node.name as NSString).pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                result.append((path: node.path, name: node.name))
            }
        }
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

    // MARK: - Image rendering

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

    private static func generateQLThumbnailSync(for path: String, saveTo dest: URL, pixelSize: CGFloat = 64) -> Bool {
        let url = URL(fileURLWithPath: path)
        let size = CGSize(width: pixelSize, height: pixelSize)
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: 1.0, representationTypes: .thumbnail)

        var result = false
        let sema = DispatchSemaphore(value: 0)

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            defer { sema.signal() }
            guard let cgImage = thumbnail?.cgImage else { return }

            let maxPx: CGFloat = pixelSize
            let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
            let scale = min(1.0, min(maxPx / w, maxPx / h))
            let outW = Int((w * scale).rounded()), outH = Int((h * scale).rounded())
            let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(data: nil, width: outW, height: outH,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: outW, height: outH))
            guard let scaled = ctx.makeImage() else { return }
            let rep = NSBitmapImageRep(cgImage: scaled)
            guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) else { return }
            result = (try? data.write(to: dest)) != nil
        }

        sema.wait()
        return result
    }
}
