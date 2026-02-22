// ZipWriter.swift
// Directory Printer
//
// Minimal ZIP archive writer with deflate compression.
// Uses zlib raw deflate (windowBits = -15) which is what the ZIP format requires.
// Falls back to store for files where deflate doesn't help (e.g. already-compressed images).
// No external dependencies — uses Foundation + the zlib C library already imported by the app.

import Foundation
import zlib

struct ZipWriter {

    // MARK: - Public API

    /// Creates a .zip archive at `destination` containing all files under `sourceFolder`.
    /// Entries are relative to `sourceFolder`'s parent so the folder appears as the
    /// top-level entry (e.g. "MySnapshot/index.html").
    static func zip(folder sourceFolder: URL, to destination: URL) throws {
        var centralDirectory: [CentralDirectoryRecord] = []
        var archiveData = Data()

        let baseName = sourceFolder.lastPathComponent
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: sourceFolder,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ZipError.enumerationFailed
        }

        // Root folder entry
        addEntry(name: baseName + "/", fileData: nil,
                 archiveData: &archiveData, centralDirectory: &centralDirectory)

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let relativePath = fileURL.path.replacingOccurrences(
                of: sourceFolder.deletingLastPathComponent().path + "/", with: "")

            if resourceValues.isDirectory == true {
                addEntry(name: relativePath + "/", fileData: nil,
                         archiveData: &archiveData, centralDirectory: &centralDirectory)
            } else if resourceValues.isRegularFile == true {
                let fileData = try Data(contentsOf: fileURL)
                addEntry(name: relativePath, fileData: fileData,
                         archiveData: &archiveData, centralDirectory: &centralDirectory)
            }
        }

        // Central directory
        let centralDirOffset = UInt32(archiveData.count)
        var centralDirData = Data()
        for record in centralDirectory { centralDirData.append(record.bytes) }
        archiveData.append(centralDirData)

        // End of central directory
        archiveData.append(endOfCentralDirectory(
            entryCount: UInt16(centralDirectory.count),
            centralDirSize: UInt32(centralDirData.count),
            centralDirOffset: centralDirOffset
        ))

        try archiveData.write(to: destination)
    }

    // MARK: - Errors

    enum ZipError: Error, LocalizedError {
        case enumerationFailed
        var errorDescription: String? { "Failed to enumerate folder contents for zipping." }
    }

    // MARK: - Internal types

    private struct CentralDirectoryRecord { let bytes: Data }

    // MARK: - Entry builder

    private static func addEntry(
        name: String,
        fileData: Data?,
        archiveData: inout Data,
        centralDirectory: inout [CentralDirectoryRecord]
    ) {
        let nameData = name.data(using: .utf8) ?? Data()
        let isDirectory = fileData == nil
        let offset = UInt32(archiveData.count)

        let crc: UInt32
        let compressedData: Data
        let compressionMethod: UInt16
        let uncompressedSize: UInt32

        if isDirectory {
            crc = 0
            compressedData = Data()
            compressionMethod = 0  // store
            uncompressedSize = 0
        } else {
            let raw = fileData!
            uncompressedSize = UInt32(raw.count)
            crc = crc32Value(raw)

            // Try deflate; fall back to store if it doesn't help
            if let deflated = deflateCompress(raw), deflated.count < raw.count {
                compressedData = deflated
                compressionMethod = 8  // deflate
            } else {
                compressedData = raw
                compressionMethod = 0  // store
            }
        }

        let compressedSize = UInt32(compressedData.count)

        // Local file header
        var localHeader = Data()
        localHeader.append(littleEndian32: 0x04034b50)
        localHeader.append(littleEndian16: 20)
        localHeader.append(littleEndian16: 0)
        localHeader.append(littleEndian16: compressionMethod)
        localHeader.append(littleEndian16: 0)  // mod time
        localHeader.append(littleEndian16: 0)  // mod date
        localHeader.append(littleEndian32: crc)
        localHeader.append(littleEndian32: compressedSize)
        localHeader.append(littleEndian32: uncompressedSize)
        localHeader.append(littleEndian16: UInt16(nameData.count))
        localHeader.append(littleEndian16: 0)  // extra field length
        localHeader.append(nameData)

        archiveData.append(localHeader)
        archiveData.append(compressedData)

        // Central directory record
        var cdRecord = Data()
        cdRecord.append(littleEndian32: 0x02014b50)
        cdRecord.append(littleEndian16: 20)  // version made by
        cdRecord.append(littleEndian16: 20)  // version needed
        cdRecord.append(littleEndian16: 0)
        cdRecord.append(littleEndian16: compressionMethod)
        cdRecord.append(littleEndian16: 0)  // mod time
        cdRecord.append(littleEndian16: 0)  // mod date
        cdRecord.append(littleEndian32: crc)
        cdRecord.append(littleEndian32: compressedSize)
        cdRecord.append(littleEndian32: uncompressedSize)
        cdRecord.append(littleEndian16: UInt16(nameData.count))
        cdRecord.append(littleEndian16: 0)  // extra field length
        cdRecord.append(littleEndian16: 0)  // file comment length
        cdRecord.append(littleEndian16: 0)  // disk number start
        cdRecord.append(littleEndian16: 0)  // internal attributes
        cdRecord.append(littleEndian32: 0)  // external attributes
        cdRecord.append(littleEndian32: offset)
        cdRecord.append(nameData)

        centralDirectory.append(CentralDirectoryRecord(bytes: cdRecord))
    }

    // MARK: - Deflate (raw, windowBits = -15 — required by ZIP format)

    private static func deflateCompress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        // windowBits = -15: raw deflate with no zlib/gzip wrapper
        let initResult = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                                       -15, 8, Z_DEFAULT_STRATEGY,
                                       ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else { return nil }
        defer { deflateEnd(&stream) }

        let bufferSize = Int(deflateBound(&stream, UInt(data.count)))
        var output = Data(count: bufferSize)

        let result: Int32 = data.withUnsafeBytes { srcPtr in
            output.withUnsafeMutableBytes { dstPtr in
                stream.next_in = UnsafeMutablePointer(
                    mutating: srcPtr.bindMemory(to: UInt8.self).baseAddress!)
                stream.avail_in = uInt(data.count)
                stream.next_out = dstPtr.bindMemory(to: UInt8.self).baseAddress!
                stream.avail_out = uInt(bufferSize)
                return deflate(&stream, Z_FINISH)
            }
        }

        guard result == Z_STREAM_END else { return nil }
        output.count = Int(stream.total_out)
        return output
    }

    // MARK: - End of central directory

    private static func endOfCentralDirectory(
        entryCount: UInt16, centralDirSize: UInt32, centralDirOffset: UInt32
    ) -> Data {
        var data = Data()
        data.append(littleEndian32: 0x06054b50)
        data.append(littleEndian16: 0)
        data.append(littleEndian16: 0)
        data.append(littleEndian16: entryCount)
        data.append(littleEndian16: entryCount)
        data.append(littleEndian32: centralDirSize)
        data.append(littleEndian32: centralDirOffset)
        data.append(littleEndian16: 0)
        return data
    }

    // MARK: - CRC-32

    private static func crc32Value(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func append(littleEndian16 value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }
    mutating func append(littleEndian32 value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
