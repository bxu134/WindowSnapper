//
//  WindowSnapperApp.swift
//  WindowSnapper
//
//  Created by Ben Xu on 11/24/25.
//

import SwiftUI

@main
struct WindowSnapperApp: App {
    var body: some Scene {
        MenuBarExtra("WindowSnapper", systemImage: "rectangle.split.3x1.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("WindowSnapper").font(.headline)
                
                Button("Snap Left") {
                    // Todo
                }
                
                Button("Snap Right") {
                    // Todo
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}
