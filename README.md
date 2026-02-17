<p align="center">
  <img src="Directory Printer/Directory Printer/Assets.xcassets/AppIcon.appiconset/Logo for App-iOS-Default-256x256@1x.png" width="128" alt="Directory Printer icon">
</p>

<h1 align="center">Directory Printer</h1>

<p align="center">A macOS app that scans a folder and generates a self-contained HTML snapshot of its contents. The output is a single HTML file with an interactive file browser — a collapsible directory tree on the left and a sortable file listing on the right.</p>

## Features

- Drag and drop a folder or use the folder picker to select a root directory
- Generates a single, portable HTML file with no external dependencies
- Interactive tree navigation with folder expand/collapse
- Sortable file listing by name, date modified, or size
- Full-text search across all files in the snapshot
- Optional inclusion of hidden files
- Optional file:// links for direct file access from the snapshot
- Custom logo support via Preferences

## Usage

Open the app, select a folder, choose an output path, and click Scan. Once complete, the snapshot can be opened in any web browser.

## CLI

A command-line interface is also available:

```
dirprinter <root-folder> <output-file> [--include-hidden] [--link-files]
```

## Requirements

- macOS 13 or later
- Xcode 15 or later (to build from source)

## License

See LICENSE.txt.
