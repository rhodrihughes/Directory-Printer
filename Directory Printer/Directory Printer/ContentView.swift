//
//  ContentView.swift
//  Directory Printer
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop delegate

struct FolderDropDelegate: DropDelegate {
    @Binding var rootFolder: URL?
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) { isTargeted = true }
    func dropExited(info: DropInfo)  { isTargeted = false }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  isDir.boolValue else { return }
            DispatchQueue.main.async { rootFolder = url }
        }
        return true
    }
}

// MARK: - Progress View

struct ScanProgressView: View {
    let phase: String
    let progress: ScanProgress?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
            Text(phase)
                .font(.headline)
                .foregroundColor(.primary)
            if let progress {
                VStack(spacing: 6) {
                    Text("\(progress.filesDiscovered) files")
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                        .foregroundColor(.primary)
                    Text("\(progress.foldersDiscovered) folders")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundColor(.secondary)
                }
                .animation(.none, value: progress.filesDiscovered)
            }
            Spacer()
            Button("Cancel") { onCancel() }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject var viewModel = ScanViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if viewModel.isScanning {
                ScanProgressView(
                    phase: viewModel.scanPhase,
                    progress: viewModel.progress,
                    onCancel: { viewModel.cancelScan() }
                )
                .transition(.opacity)
            } else {
                setupView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isScanning)
        .padding(20)
        .frame(width: 480)

        // MARK: Success alert
        .alert("Directory Report Created", isPresented: $viewModel.showSuccessAlert) {
            let isZip = viewModel.lastOutputURL?.pathExtension.lowercased() == "zip"
            Button(isZip ? "Show in Finder" : "Open in Browser") { viewModel.openInBrowser() }
            Button("OK", role: .cancel) {}
        } message: {
            if let url = viewModel.lastOutputURL {
                Text("Directory Report saved to \(url.lastPathComponent)")
            }
        }

        // MARK: Error alert
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Setup view

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Folder drop zone
            dropZone

            Divider()

            // Output row
            outputRow

            Divider()

            // Options
            optionsSection

            // Scan button
            HStack {
                Spacer()
                Button("Scan") { viewModel.startScan() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.rootFolder == nil || viewModel.outputPath == nil && !viewModel.generateThumbnails)
            }
        }
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTargeted
                    ? Color.accentColor.opacity(0.1)
                    : Color(NSColor.controlBackgroundColor))
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.5, dash: isDropTargeted ? [] : [6])
                )

            if let folder = viewModel.rootFolder {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                        Text(folder.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Change") { viewModel.selectRootFolder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(isDropTargeted ? .accentColor : .secondary)
                    Text("Drop a folder here")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Button("Choose Folder…") { viewModel.selectRootFolder() }
                        .buttonStyle(.bordered)
                        .padding(.top, 2)
                }
                .padding(.vertical, 20)
            }
        }
        .frame(height: viewModel.rootFolder == nil ? 130 : 70)
        .onDrop(of: [.fileURL], delegate: FolderDropDelegate(
            rootFolder: $viewModel.rootFolder,
            isTargeted: $isDropTargeted
        ))
        .animation(.easeInOut(duration: 0.15), value: viewModel.rootFolder == nil)
    }

    // MARK: - Output row

    private var outputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.arrow.up")
                .foregroundColor(.secondary)
                .frame(width: 20)

            let displayPath = viewModel.generateThumbnails
                ? viewModel.outputFolderURL?.path
                : viewModel.outputPath?.path

            if let path = displayPath {
                Text(path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No output location selected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(viewModel.generateThumbnails ? "Choose Folder…" : "Choose File…") {
                viewModel.selectOutputPath()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Options section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Options")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include hidden files", isOn: $viewModel.includeHidden)
                Toggle("Link to files", isOn: $viewModel.linkToFiles)
                Toggle("Generate image thumbnails", isOn: $viewModel.generateThumbnails)
                if viewModel.generateThumbnails {
                    indented {
                        Toggle("Save as .zip", isOn: $viewModel.zipThumbnailOutput)
                            .font(.callout)
                    }
                    caption("Generating thumbnails of large directories will increase generation time.")
                }
                Toggle("Compress Directory Report", isOn: $viewModel.compressData)
                if !viewModel.generateThumbnails {
                    Toggle("Encrypt Directory Report", isOn: $viewModel.encryptionEnabled)
                    if viewModel.encryptionEnabled {
                        indented {
                            SecureField("Password", text: $viewModel.encryptionPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                        indented {
                            caption("AES-256 encrypted. Keep this password safe — it cannot be recovered.")
                        }
                    }
                } else {
                    caption("Encryption is unavailable when thumbnails are enabled.")
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func indented<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 22)
            content()
        }
    }

    private func caption(_ text: String) -> some View {
        indented {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ContentView()
}
