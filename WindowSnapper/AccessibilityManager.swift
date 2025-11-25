//
//  AccessibilityManager.swift
//  WindowSnapper
//
//  Created by Ben Xu on 11/24/25.
//

import ApplicationServices
import Cocoa

final class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    private init() {}
    
    // get the frontmost window
    func frontmostWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )
        
        if result == .success {
            return value as! AXUIElement?
        } else {
            return nil
        }
    }
    
    // gets location and size of the window
    func frame(of window: AXUIElement) -> CGRect? {
        
        var posValue: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &posValue
        )
        
        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        )
        
        guard posResult == .success, sizeResult == .success,
              let posAX = posValue as! AXValue?,
              let sizeAX = sizeValue as! AXValue?
            else {
                return nil
            }
        
        var origin = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(posAX, .cgPoint, &origin)
        AXValueGetValue(sizeAX, .cgSize, &size)
        
        return CGRect(origin: origin, size: size)
    }
    
    // sets the window's frame to the target frame
    func setFrame(_ targetFrame: CGRect, for window: AXUIElement) {
        var origin = targetFrame.origin
        var size = targetFrame.size
        
        guard
            let posValue = AXValueCreate(.cgPoint, &origin),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return
        }
        
        let posResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            posValue
        )
        
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        
        if posResult != .success || sizeResult != .success {
            print("Failed to set frame: posResult=\(posResult.rawValue), sizeResult=\(sizeResult.rawValue)")
        }
    }
    
    // snap helpers for left/right
    func snapFrontmostWindowLeftHalf() {
        snapFrontmostWindow { screenFrame in
            CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width/2,
                height: screenFrame.height
            )
        }
    }
    
    func snapFrontmostWindowRightHalf() {
        snapFrontmostWindow { screenFrame in
            CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.minY,
                width: screenFrame.width/2,
                height: screenFrame.height
            )
        }
    }
    
    // main snapping function
    func snapFrontmostWindow(using rectBuilder: (CGRect) -> CGRect) {
        guard
            let window = frontmostWindow(),
            let currentFrame = frame(of: window),
            let screen = screenContaining(rect: currentFrame)
        else {
            print("No frontmost window or screen")
            return
        }
        
        let screenFrame = screen.visibleFrame
            let target = rectBuilder(screenFrame)
            setFrame(target, for: window)
        }

        private func screenContaining(rect: CGRect) -> NSScreen? {
            let screens = NSScreen.screens
            return screens.max(by: { (a,b)->Bool in
                let interA = a.visibleFrame.intersection(rect).area
                let interB = b.visibleFrame.intersection(rect).area
                return interA < interB
            })
        }
    
    }

private extension CGRect {
    var area: CGFloat {
        if self.isNull || self.isEmpty {
            return 0
        }
        return self.width * self.height
    }
}
