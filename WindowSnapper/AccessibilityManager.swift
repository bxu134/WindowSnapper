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
//        startMouseUpTracking()
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

        // get frontmost application, not focused
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // try getting window from focused UI element (to allow for Chrome functionality)
        var focusedElementValue: AnyObject?
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        ) == .success,
           let focusedElement = focusedElementValue as! AXUIElement? {

            var windowValue: AnyObject?
            if AXUIElementCopyAttributeValue(
                focusedElement,
                kAXWindowAttribute as CFString,
                &windowValue
            ) == .success, let window = windowValue as! AXUIElement? {
                return window
            }
        }

        var windowValue: AnyObject?

        // try focused window
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        ) == .success, let window = windowValue as! AXUIElement? {
            return window
        }

        // try main window
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &windowValue
        ) == .success, let window = windowValue as! AXUIElement? {
            return window
        }

        // try first window from array
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowValue
        ) == .success,
           let windows = windowValue as? [AXUIElement] {

            // logic for regular windows (basically non-chrome)
            for window in windows {
                var roleValue: AnyObject?
                if AXUIElementCopyAttributeValue(
                    window,
                    kAXSubroleAttribute as CFString,
                    &roleValue
                ) == .success,
                   let role = roleValue as? String,
                   role == kAXStandardWindowSubrole as String {
                    return window
                }
            }

            // fallback: return first window
            if let firstWindow = windows.first {
                return firstWindow
            }
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
    
    // snap helpers
    func snapFrontmostWindowBreak() {
        snapFrontmostWindow { screenFrame in
            let width = screenFrame.width * 0.4
            let height = screenFrame.height * 0.4
            let originX = screenFrame.midX - width / 2
            let originY = screenFrame.midY - height / 2
            return CGRect(
                x: originX,
                y: originY,
                width: width,
                height: height
            )
        }
    }
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
    
    // snap using sectional logic
    func snapSectionalLogic(on command: UInt32) {
        guard let window = frontmostWindow() else {
            print("DEBUG: frontmostWindow() returned nil:")
            return
        }
        
        guard let currentAXFrame = frame(of: window) else {
            print("DEBUG: frame(of:) returned nil")
            return
        }
        let convertedFrame = convertAXToAppKit(currentAXFrame)
        
        guard let screen = screenContaining(appKitRect: convertedFrame) else {
            print("DEBUG: screenContaining(rect:) returned nil")
            return
        }
        let screenFrame = screen.visibleFrame
        
        if let targetRect = SectionalLogic.shared.snapLogicController(for: command, appRect: convertedFrame, on: screenFrame) {
            snapFrontmostWindow(
                screen: screen,
                window: window,
                on: screenFrame
            ) {_ in
                    targetRect
                }
        } else {
            minimize(window: window)
        }
    }
    
    func minimize(window: AXUIElement) {
        var minimized = true as CFBoolean
        let result = AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            minimized
        )
    }
    
    // overloaded function with more inputs --> keep continuity on window, screenframe, screen etc.
    func snapFrontmostWindow(screen: NSScreen, window: AXUIElement,  on screenFrame: CGRect, using rectBuilder: (CGRect) -> CGRect) {
        let targetAppKit = rectBuilder(screenFrame)
        print("Target AppKit:", targetAppKit)
        let targetAX = convertAppKitToAX(targetAppKit, screen: screen)
        print("Target AX:", targetAX)
        setFrame(targetAX, for: window)
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
        print("Screen visibleFrame:", screenFrame)
        
        //v-----testing sectiondetect-----v
        let section = SectionalLogic.shared.detectSection(appRect: convertedFrame, on: screenFrame)
        print("Current section:", section)
        //^-----testing sectiondetect-----^
        
        let targetAppKit = rectBuilder(screenFrame)
        print("Target AppKit:", targetAppKit)
        let targetAX = convertAppKitToAX(targetAppKit, screen: screen)
        print("Target AX:", targetAX)
        setFrame(targetAX, for: window)
        
        
        // verify what was actually set
        if let newFrame = frame(of: window) {
            print("Window frame after setFrame (AX):", newFrame)
            let newFrameAppKit = convertAXToAppKit(newFrame)
            print("Window frame after setFrame (AppKit):", newFrameAppKit)
            print("Expected: window should fill from y=\(screenFrame.minY) to y=\(screenFrame.maxY) in AppKit")
        }
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
//        if let point = lastMouseUpLocation {
//            if let mouseUpScreen = screens.first(where: { $0.frame.contains(point) }) {
//                print("USING MOUSE UP SCREEN")
//                return mouseUpScreen
//            }
//        }
        // TESTING screen
//        for screen in screens {
//            if screen.frame.contains(rect.origin) {
//                return screen
//            }
//        }
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
    // AX uses the main screen as reference with (0,0) at its top-left corner
    func convertAXToAppKit(_ axRect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first else {
            return axRect
        }
        let mainHeight = mainScreen.frame.height
        return CGRect(
            x: axRect.origin.x,
            y: mainHeight - axRect.origin.y - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
    }

    func convertAppKitToAX(_ appRect: CGRect, screen: NSScreen) -> CGRect {
        // AX uses the main screen (with menu bar) as reference
        // NSScreen.main can change based on focus, so find the screen with menu bar
        guard let mainScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first else {
            return appRect
        }
        let mainHeight = mainScreen.frame.height
        print("DEBUG: Using main screen height: \(mainHeight) from screen at \(mainScreen.frame)")
        return CGRect(
            x: appRect.origin.x,
            y: mainHeight - appRect.origin.y - appRect.height,
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
