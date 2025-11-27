//
//  SectionalLogic.swift
//  WindowSnapper
//
//  Created by Ben Xu on 11/25/25.
//

import ApplicationServices
import Cocoa

final class SectionalLogic {
    static let shared = SectionalLogic()
    private let tolerance: CGFloat = 0.02
    
    func detectSection(window: AXUIElement, on screen: NSScreen) -> Int {
        guard let axFrame = AccessibilityManager.shared.frame(of: window) else {
            return 0
        }
        
        let appRect = AccessibilityManager.shared.convertAXToAppKit(axFrame)
        let screenFrame = screen.visibleFrame
        
        return detectSection(appRect: appRect, on: screenFrame)
    }
    
    /*
     detects the section a window is in, returns int 0-9
     0: no section the window is not in a defined section
     1: the section where the window fills the screen
     2: left half
     3: right half
     4: top half
     5: bottom half
     6: top left (6-9 are quadrants)
     7: top right
     8: bottom left
     9: bottom right
     */
    func detectSection(appRect: CGRect, on screenFrame: CGRect) -> Int {
        let normX = (appRect.minX - screenFrame.minX) / screenFrame.width
        let normY = (appRect.minY - screenFrame.minY) / screenFrame.height
        let normW = appRect.width / screenFrame.width
        let normH = appRect.height / screenFrame.height
        
        print ("NORM_X:",normX,"NORM_Y:",normY,"NORM_W:",normW,"NORM_H:",normH)
        
        if approxZero(normX) && approxZero(normY) && approxOne(normW) && approxOne(normH) {
            print("FILL SCREEN SECTION")
            return 1 // fill screen
        }
        if approxZero(normX) && approxZero(normY) && approx(normW, 0.5) && approxOne(normH) {
            print("LEFT HALF SECTION")
            return 2 // left half
        }
        if approx(normX, 0.5) && approxZero(normY) && approx(normW, 0.5) && approxOne(normH) {
            print("RIGHT HALF SECTION")
            return 3 // right half
        }
        if approxZero(normX) && approx(normY, 0.5) && approxOne(normW) && approx(normH, 0.5) {
            print("TOP HALF SECTION")
            return 4 // top half
        }
        if approxZero(normX) && approxZero(normY) && approxOne(normW) && approx(normH, 0.5) {
            print("BOTTOM HALF SECTION")
            return 5 // bottom half
        }
        if approxZero(normX) && approx(normY, 0.5) && approx(normW, 0.5) && approx(normH, 0.5) {
            print("TOP LEFT SECTION")
            return 6 // top left
        }
        if approx(normX, 0.5) && approx(normY, 0.5) && approx(normW, 0.5) && approx(normH, 0.5) {
            print("TOP RIGHT SECTION")
            return 7 // top right
        }
        if approxZero(normX) && approxZero(normY) && approx(normW, 0.5) && approx(normH, 0.5) {
            print("BOT LEFT SECTION")
            return 8 // bot left
        }
        if approx(normX, 0.5) && approxZero(normY) && approx(normW, 0.5) && approx(normH, 0.5) {
            print("BOT RIGHT SECTION")
            return 9 // bot right
        }
        
        return 0; // doesn't match any section
    }
    
    // returns a CGRect for the corresponding section
    func rect(for section: Int, on screenFrame: CGRect) -> CGRect {
        switch section {
        case 1: // full screen
            return screenFrame
        case 2: // left half
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )
        case 3: // right half
            return CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )
        case 4: // top half
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY + screenFrame.height / 2,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )
        case 5: // bottom half
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )
        case 6: // top left
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY + screenFrame.height / 2,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
        case 7: // top right
            return CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.minY + screenFrame.height / 2,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        case 8: // bottom left
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        case 9: // bottom right
            return CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        default: // break case
            let height = screenFrame.height * 0.4
            let width = screenFrame.width * 0.4
            return CGRect (
                x: screenFrame.midX - width / 2,
                y: screenFrame.midY -  height / 2,
                width: width,
                height: height
            )
        }
    }
    
    // returns the CGRect for a command depending on what section it is in
    func snapLogicController (for command: UInt32, appRect: CGRect, on screenFrame: CGRect) -> CGRect? {
        let section = detectSection(appRect: appRect, on: screenFrame)
        
        switch command {
        case 1: // snap left
            switch section {
            case 3: // right half -> break
                print("RIGHT HALF w INPUT snap left")
                return rect(for: 0, on: screenFrame)
            case 4, 6, 7: // top left, top right -> top left
                return rect(for: 6, on: screenFrame)
            case 5, 8, 9: // bot half, bot left, bot right -> bot left
                return rect(for: 8, on: screenFrame)
            default: // 0,1,2 go to left half
                return rect(for: 2, on: screenFrame)
            }
        case 2: // snap right
            switch section {
            case 2: // left half -> break
                return rect(for: 0, on: screenFrame)
            case 4, 6, 7: // top half, top left, top right -> top right
                return rect(for: 7, on: screenFrame)
            case 5, 8, 9: // bot half, bot left, bot right -> bot right
                return rect(for: 9, on: screenFrame)
            default: // 0,1,3
                return rect(for: 3, on: screenFrame)
            }
        case 3: // snap up
            switch section {
            case 2: // left half -> top left
                return rect(for: 6, on: screenFrame)
            case 3: // right half -> top right
                return rect(for: 7, on: screenFrame)
            case 1, 4: // fill, top half -> top half
                return rect(for: 4, on: screenFrame)
            case 0, 6, 7: // break, top left, top right -> fill
                return rect(for: 1, on: screenFrame)
            case 8: // bot left -> left half
                return rect(for: 2, on: screenFrame)
            case 9: // bot right -> right half
                return rect(for: 3, on: screenFrame)
            default: // default, bot half -> break
                return rect(for: 0, on: screenFrame)
            }
        case 4: // snap down
            switch section {
            case 0, 1: // break, fill -> bot half
                return rect(for: 5, on: screenFrame)
            case 2: // left half -> bot left
                return rect(for: 8, on: screenFrame)
            case 3: // right half -> bot right
                return rect(for: 9, on: screenFrame)
            case 4: // top half -> break
                return rect(for: 0, on: screenFrame)
            case 6: // top left -> left half
                return rect(for: 2, on: screenFrame)
            case 7: // top right -> right half
                return rect(for: 3, on: screenFrame)
            default: // bot half, bot left, bot right -> minimize
                return nil
            }
        default: // return break rect
            return rect(for: 0, on: screenFrame)
        }
                
        
    }
    
    func approx(_ value: CGFloat, _ target: CGFloat) -> Bool {
        return abs(value - target) <= tolerance
    }
    
    func approxZero(_ value: CGFloat) -> Bool {
        return value <= tolerance
    }
    
    func approxOne(_ value: CGFloat) -> Bool {
        return abs(1.0 - value) <= tolerance
    }
}
