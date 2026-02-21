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
        .padding()
        .frame(width: 380)
        .frame(minHeight: 380)

        // MARK: Success alert
        .alert(
            "Snapshot Created",
            isPresented: $viewModel.showSuccessAlert
        ) {
            Button("Open in Browser") { viewModel.openInBrowser() }
            Button("OK", role: .cancel) {}
        } message: {
            if let url = viewModel.lastOutputURL {
                Text("Snapshot saved to \(url.lastPathComponent)")
            }
        }

        // MARK: Error alert
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Setup view

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Drop zone + folder picker
            GroupBox(label: Text("Input").font(.headline)) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                                style: StrokeStyle(lineWidth: 2, dash: [6])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                            )
                        VStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(isDropTargeted ? .accentColor : .secondary)
                            if let folder = viewModel.rootFolder {
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Drop a folder here")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    .frame(minHeight: 100)
                    .onDrop(of: [.fileURL], delegate: FolderDropDelegate(
                        rootFolder: $viewModel.rootFolder,
                        isTargeted: $isDropTargeted
                    ))
                    Button("Choose Folder") { viewModel.selectRootFolder() }
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            }

            // Output file picker
            GroupBox(label: Text("Output").font(.headline)) {
                HStack {
                    Button("Choose Output File…") { viewModel.selectOutputPath() }
                    Text(viewModel.outputPath?.path ?? "No output file selected")
                        .foregroundColor(viewModel.outputPath == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }

            // Options
            GroupBox(label: Text("Options").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Include hidden files", isOn: $viewModel.includeHidden)
                    Toggle("Link to files", isOn: $viewModel.linkToFiles)
                    Toggle("Generate image thumbnails", isOn: $viewModel.generateThumbnails)
                    if viewModel.generateThumbnails {
                        Text("Note: generating thumbnails of large directories will increase generation times.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Scan button
            HStack {
                Spacer()
                Button("Scan") {
                    viewModel.startScan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.rootFolder == nil)
            }
        }
    }
}

#Preview {
    ContentView()
}
