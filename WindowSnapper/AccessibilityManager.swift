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
    
    private var lastMouseUpLocation: NSPoint?
    private var mouseUpMonitor: Any?
    
    private init() {
        startMouseUpTracking()
    }
    
    private func startMouseUpTracking() {
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.lastMouseUpLocation = event.locationInWindow
            print("Last mouse up at:", event.locationInWindow)
        }
    }
    
    func startMouseTrackingIfNeeded() {
        if mouseUpMonitor == nil {
            startMouseUpTracking()
        }
    }
    
    // get the frontmost window
    func frontmostWindow() -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()

        var focusedAppValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppValue
        ) == .success,
              let focusedApp = focusedAppValue as! AXUIElement? else {
            return nil
        }

        var windowValue: AnyObject?

        // Try focused window
        if AXUIElementCopyAttributeValue(
            focusedApp,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        ) == .success, let window = windowValue as! AXUIElement? {
            return window
        }

        // Try main window
        if AXUIElementCopyAttributeValue(
            focusedApp,
            kAXMainWindowAttribute as CFString,
            &windowValue
        ) == .success, let window = windowValue as! AXUIElement? {
            return window
        }

        // Try first window from array
        if AXUIElementCopyAttributeValue(
            focusedApp,
            kAXWindowsAttribute as CFString,
            &windowValue
        ) == .success,
           let windows = windowValue as? [AXUIElement],
           let firstWindow = windows.first {
            return firstWindow
        }

        return nil
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
        /*
        guard
            let window = frontmostWindow(),
            let currentFrame = frame(of: window),
            let screen = screenContaining(rect: currentFrame)
        else {
            print("No frontmost window or screen")
            return
        }
        */
        guard let window = frontmostWindow() else {
            print("DEBUG: frontmostWindow() returned nil")
            return
        }
        
        guard let currentAXFrame = frame(of: window) else {
            print("DEBUG: frame(of:) returned nil")
            return
        }
        
        //v-----debug-----v
        print ("AX frame:", currentAXFrame)
        for screen in NSScreen.screens {
            print("Screen:",screen.frame)
        }
        let convertedFrame = convertAXToAppKit(currentAXFrame)
        print("Converted frame:",convertedFrame)
        //^-----debug----^
       
        guard let screen = screenContaining(appKitRect: convertedFrame) else {
            print("DEBUG: screenContaining(rect:) returned nil")
            return
        }
        let screenFrame = screen.visibleFrame
        let targetAppKit = rectBuilder(screenFrame)
        let targetAX = convertAppKitToAX(targetAppKit)
        setFrame(targetAX, for: window)
    }

    private func screenContaining(appKitRect rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        
        //v-----debug-----v
        for screen in screens {
            let inter = screen.frame.intersection(rect)
            print("Screen frame:", screen.frame,
                  "intersection:", inter,
                  "area:", inter.width*inter.height
            )
        }
        print("ORIGIN:",rect.origin)
        //^-----debug-----^
        // TESTING mouse
        if let point = lastMouseUpLocation {
            if let mouseUpScreen = screens.first(where: { $0.frame.contains(point) }) {
                print("USING MOUSE UP SCREEN")
                return mouseUpScreen
            }
        }
        // TESTING screen
        for screen in screens {
            if screen.frame.contains(rect.origin) {
                return screen
            }
        }
        print("FALLBACK CHECK INTERSECTION")
        return screens.max { a, b in
            let interA = a.frame.intersection(rect)
            let interB = b.frame.intersection(rect)
            let areaA = interA.width*interA.height
            let areaB = interB.width*interB.height
            return areaA < areaB
        }
    }
    
    // NSScreen and AXFrame have different coordinate systems
    func convertAXToAppKit(_ axRect: CGRect) -> CGRect {
        guard let maxY = NSScreen.screens.map({ $0.frame.maxY }).max() else {
            return axRect
        }
        return CGRect(
            x: axRect.origin.x,
            y: maxY - axRect.origin.y - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
    }
    
    func convertAppKitToAX(_ appRect: CGRect) -> CGRect {
        guard let maxY = NSScreen.screens.map({ $0.frame.maxY }).max() else {
            return appRect
        }
        return CGRect(
            x: appRect.origin.x,
            y: maxY - appRect.origin.y - appRect.height,
            width: appRect.width,
            height: appRect.height
        )
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
