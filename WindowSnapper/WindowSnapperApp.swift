//
//  WindowSnapperApp.swift
//  WindowSnapper
//
//  Created by Ben Xu on 11/24/25.
//

import SwiftUI
import ApplicationServices

@main
struct WindowSnapperApp: App {
     
    init() {
        let options: CFDictionary = [
                kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
            ] as CFDictionary

        let trusted = AXIsProcessTrustedWithOptions(options)
        print("Accessibility trusted: \(trusted)")
        if trusted {
            _ = AccessibilityManager.shared
        }
    }
    
    var body: some Scene {
       
        MenuBarExtra("WindowSnapper", systemImage: "rectangle.split.3x1.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("WindowSnapper").font(.headline)
                
                Button("Snap Left") {
                    AccessibilityManager.shared.snapFrontmostWindowLeftHalf()
                }
                
                Button("Snap Right") {
                    AccessibilityManager.shared.snapFrontmostWindowRightHalf()
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}
