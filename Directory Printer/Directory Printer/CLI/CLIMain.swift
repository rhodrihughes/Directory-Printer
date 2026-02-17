// CLIMain.swift
// Directory Printer
//
// Provides a standalone CLI entry point for Directory Printer.
// Usage: dirprinter <root-folder> <output-file> [--include-hidden] [--link-files]
//
// This file is part of the app target but is designed to be invoked
// from a CLI context via CLIRunner.run().

import Foundation

// MARK: - CLIRunner

struct CLIRunner {

    // MARK: - Public entry point

    /// Parses CommandLine.arguments, runs the scan, writes the HTML output,
    /// and terminates the process with an appropriate exit code.
    ///
    /// Call this from a CLI harness. It never returns — it always calls exit().
    static func run() {
        let args = Array(CommandLine.arguments.dropFirst()) // drop executable name

        // Parse arguments
        let parsed: ParsedArgs
        do {
            parsed = try parseArguments(args)
        } catch let err as CLIError {
            switch err {
            case .usageError(let msg):
                printStderr(msg)
                printStderr("")
                printStderr(usage())
                exit(1)
            }
        } catch {
            printStderr("Unexpected error: \(error)")
            exit(1)
        }

        // Validate root folder
        let rootURL = URL(fileURLWithPath: parsed.rootFolder)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDir) else {
            printStderr("Error: root folder does not exist: \(parsed.rootFolder)")
            exit(1)
        }
        guard isDir.boolValue else {
            printStderr("Error: path is not a directory: \(parsed.rootFolder)")
            exit(1)
        }

        // Build scan options
        let options = ScanOptions(
            rootPath: rootURL,
            includeHidden: parsed.includeHidden,
            linkToFiles: parsed.linkFiles
        )

        // Run scan synchronously using DispatchSemaphore to bridge async → sync
        let scanner = DirectoryScanner()
        let semaphore = DispatchSemaphore(value: 0)
        var scanResult: ScanResult?
        var scanError: Error?

        Task {
            do {
                let result = try await scanner.scan(options: options) { progress in
                    print("Scanning: \(progress.currentFolder) (\(progress.filesDiscovered) files found)")
                }
                scanResult = result
            } catch {
                scanError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let err = scanError {
            printStderr("Error during scan: \(err.localizedDescription)")
            exit(1)
        }

        guard let result = scanResult else {
            printStderr("Error: scan produced no result.")
            exit(1)
        }

        // Generate HTML
        let html: String
        do {
            html = try HTMLGenerator.generate(from: result, options: options, logoBase64: nil)
        } catch {
            printStderr("Error generating HTML: \(error.localizedDescription)")
            exit(1)
        }

        // Write output file
        let outputURL = URL(fileURLWithPath: parsed.outputFile)
        do {
            try html.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            printStderr("Error writing output file '\(parsed.outputFile)': \(error.localizedDescription)")
            exit(1)
        }

        // Success
        print(outputURL.path)
        exit(0)
    }

    // MARK: - Argument parsing

    private struct ParsedArgs {
        let rootFolder: String
        let outputFile: String
        let includeHidden: Bool
        let linkFiles: Bool
    }

    private enum CLIError: Error {
        case usageError(String)
    }

    private static func parseArguments(_ args: [String]) throws -> ParsedArgs {
        var positional: [String] = []
        var includeHidden = false
        var linkFiles = false

        for arg in args {
            switch arg {
            case "--include-hidden":
                includeHidden = true
            case "--link-files":
                linkFiles = true
            case let flag where flag.hasPrefix("--"):
                throw CLIError.usageError("Unknown flag: \(flag)")
            default:
                positional.append(arg)
            }
        }

        guard positional.count >= 2 else {
            if positional.isEmpty {
                throw CLIError.usageError("Missing required arguments: <root-folder> and <output-file>")
            } else {
                throw CLIError.usageError("Missing required argument: <output-file>")
            }
        }

        if positional.count > 2 {
            throw CLIError.usageError("Too many positional arguments.")
        }

        return ParsedArgs(
            rootFolder: positional[0],
            outputFile: positional[1],
            includeHidden: includeHidden,
            linkFiles: linkFiles
        )
    }

    // MARK: - Helpers

    private static func usage() -> String {
        return """
        Usage: dirprinter <root-folder> <output-file> [--include-hidden] [--link-files]

          <root-folder>      Path to the directory to scan (required)
          <output-file>      Path for the generated HTML snapshot (required)
          --include-hidden   Include hidden files and folders (names starting with '.')
          --link-files       Embed file:// URLs in the snapshot for direct file access
        """
    }

    private static func printStderr(_ message: String) {
        var standardError = FileHandle.standardError
        let data = (message + "\n").data(using: .utf8) ?? Data()
        standardError.write(data)
    }
}

// MARK: - FileHandle + TextOutputStream

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}
