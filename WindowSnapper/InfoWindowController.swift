//
//  InfoWindowController.swift
//  WindowSnapper
//
//  Created by Ben Xu on 11/27/25.
//

import SwiftUI
import AppKit

struct InfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WindowSnapper")
                .font(.title2)
                .bold()
            Text("Window snapping for macOS.")
            Text("Shortcuts:")
                .font(.headline)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text("⌘⌥←  Snap left / cycle left sections")
                Text("⌘⌥→  Snap right / cycle right sections")
                Text("⌘⌥↑  Break layout")
                Text("⌘⌥↓  Snap down / minimize / bottom logic")
            }
            HStack(spacing: 6) {
                Text("Created by Ben Xu")
                Link("GitHub", destination: URL(string: "https://github.com/bxu134")!)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(width: 320, height: 230)
    }
}

final class InfoWindowController: NSWindowController {
    static let shared = InfoWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "About WindowSnapper"
        window.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: InfoView())
        window.contentView = hostingView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = self.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
