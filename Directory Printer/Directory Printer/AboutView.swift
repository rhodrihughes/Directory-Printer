//
//  AboutView.swift
//  Directory Printer
//

import SwiftUI

struct AboutView: View {
    private var appVersionAndBuild: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        return "Version \(version)"
    }

    private var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) Rhodri Hughes"
    }

    private let developerWebsite = URL(string: "https://www.rhodrihughes.co.uk")!

    var body: some View {
        VStack(spacing: 14) {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
            }
            Text("Directory Printer")
                .font(.title)
            VStack(spacing: 6) {
                Text(appVersionAndBuild)
                Text(copyright)
            }
            .font(.callout)
            Link("Developer Website", destination: developerWebsite)
                .foregroundStyle(.blue)
        }
        .padding(30)
        .frame(minWidth: 360, minHeight: 260)
    }
}
