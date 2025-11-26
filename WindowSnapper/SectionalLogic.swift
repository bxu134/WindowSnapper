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
            return 1 // fill screen
        }
        if approxZero(normX) && approxZero(normY) && approx(normW, 0.5) && approxOne(normH) {
            return 2 // left half
        }
        if approx(normX, 0.5) && approxZero(normY) && approx(normW, 0.5) && approxOne(normH) {
            return 3 // right half
        }
        if approxZero(normX) && approx(normY, 0.5) && approxOne(normW) && approx(normH, 0.5) {
            return 4 // top half
        }
        if approxZero(normX) && approxZero(normY) && approxOne(normW) && approx(normH, 0.5) {
            return 5 // bottom half
        }
        if approxZero(normX) && approx(normY, 0.5) && approx(normW, 0.5) && approx(normH, 0.5) {
            return 6 // top left
        }
        if approx(normX, 0.5) && approx(normY, 0.5) && approx(normW, 0.5) && approx(normH, 0.5) {
            return 7 // top right
        }
        if approxZero(normX) && approxZero(normY) && approx(normW, 0.5) && approx(normH, 0.5) {
            return 8 // bot left
        }
        if approx(normX, 0.5) && approxZero(normY) && approx(normW, 0.5) && approx(normH, 0.5) {
            return 9 // bot right
        }
        
        return 0; // doesn't match any section
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
