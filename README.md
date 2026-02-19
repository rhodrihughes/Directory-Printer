<p align="center">
  <img src="Directory Printer/Directory Printer/Assets.xcassets/AppIcon.appiconset/Logo for App-iOS-Default-256x256@1x.png" width="128" alt="Directory Printer icon">
</p>

<h1 align="center">Directory Printer</h1>

<p align="center">
  <a href="https://github.com/rhodrihughes/Directory-Printer/releases/latest">
    <img src="https://img.shields.io/github/v/release/rhodrihughes/Directory-Printer?label=Download%20Latest&style=for-the-badge&color=brightgreen&logo=github&logoColor=white" alt="Download latest release">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square&logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift" alt="Swift 5.0">
  <img src="https://img.shields.io/badge/License-GPLv3-green?style=flat-square" alt="GPLv3 License">
</p>

<p align="center">A macOS app that scans a folder and generates a self-contained HTML snapshot of its contents.
The output is a single HTML file with an interactive file browser — a collapsible directory tree on the left and a sortable file listing on the right.
Basically <a href="https://github.com/rlv-dan/Snap2HTML">Snap2HTML</a> for Mac.</p>

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

## Changelog

### v1.2.1

 - Ventura saving fix

### v1.2

**Faster scanning**
- Scanning is much faster, especially on network drives
- The app stays responsive while a scan is running

**Progress view**
- Clicking Scan now shows a full-screen progress view with a live count of files and folders found
- Fixed a freeze that could occur right when a scan started

**HTML output**
- Folder sizes now reflect the total size of everything inside them
- Folders in the file list are no longer shown in bold
- Large snapshots now show a loading indicator when opened in a browser, instead of a blank screen

**Other fixes**
- The output filename now updates automatically when you drag in a new folder
- If the app can't write to the suggested output location, it will ask you to pick one before scanning starts
- Fixed a bug where clicking an open folder in the sidebar would re-expand it instead of closing it
