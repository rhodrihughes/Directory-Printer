// PreferencesView.swift
// Directory Printer

import SwiftUI

struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Section(header: Text("Branding").font(.headline)) {
                HStack(spacing: 16) {
                    // Preview
                    Group {
                        if let b64 = prefs.logoBase64,
                           let data = Data(base64Encoded: b64),
                           let img = NSImage(data: data) {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 32)
                                .cornerRadius(4)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 60, height: 32)
                                .overlay(
                                    Text("No logo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logo image (max 32px height)")
                            .font(.subheadline)
                        Text("Embedded as base64 in the HTML snapshot header.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Button("Choose Image…") { prefs.selectLogo() }
                            if prefs.logoBase64 != nil {
                                Button("Remove", role: .destructive) { prefs.clearLogo() }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 180)
        .padding()
    }
}
