//
//  Directory_PrinterApp.swift
//  Directory Printer
//
//  Created by Rhodri on 17/02/2026.
//

import SwiftUI

@main
struct Directory_PrinterApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 420, height: 480)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Directory Printer") {
                    openWindow(id: "about")
                }
            }
            CommandGroup(replacing: .help) {
                Link("Directory Printer Help", destination: URL(string: "https://github.com/rhodrihughes/Directory-Printer")!)
            }
        }

        Window("About Directory Printer", id: "about") {
            AboutView()
                .applyAboutWindowStyle()
        }
        .windowResizability(.contentSize)
        .applyAboutSceneStyle()

        Settings {
            PreferencesView()
        }
    }
}

// MARK: - Availability-gated view modifiers

private extension View {
    @ViewBuilder
    func applyAboutWindowStyle() -> some View {
        if #available(macOS 15.0, *) {
            self
                .toolbar(removing: .title)
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.regularMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
        } else {
            self
        }
    }
}

private extension Scene {
    func applyAboutSceneStyle() -> some Scene {
        if #available(macOS 15.0, *) {
            return self
                .windowBackgroundDragBehavior(.enabled)
                .restorationBehavior(.disabled)
        } else {
            return self
        }
    }
}
