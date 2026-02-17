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

// MARK: - ContentView

struct ContentView: View {
    @StateObject var viewModel = ScanViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Drop zone + folder picker
            GroupBox(label: Text("Input").font(.headline)) {
                VStack(spacing: 10) {
                    // Drop zone
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

                    // Choose Folder button
                    Button("Choose Folder") {
                        viewModel.selectRootFolder()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            }

            // MARK: Output file picker
            GroupBox(label: Text("Output").font(.headline)) {
                HStack {
                    Button("Choose Output File…") {
                        viewModel.selectOutputPath()
                    }
                    Text(viewModel.outputPath?.path ?? "No output file selected")
                        .foregroundColor(viewModel.outputPath == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }

            // MARK: Options
            GroupBox(label: Text("Options").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Include hidden files", isOn: $viewModel.includeHidden)
                    Toggle("Link to files", isOn: $viewModel.linkToFiles)
                }
                .padding(.vertical, 4)
            }

            // MARK: Progress (visible during scan)
            if viewModel.isScanning {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                            Text(viewModel.scanPhase)
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
                        if let progress = viewModel.progress {
                            Text(progress.currentFolder)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(progress.filesDiscovered) files found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: Action buttons
            HStack {
                Spacer()

                if viewModel.isScanning {
                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Scan") {
                    Task { await viewModel.startScan() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.rootFolder == nil || viewModel.isScanning)
            }
        }
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
}

#Preview {
    ContentView()
}
