//
//  AppDelegate.swift
//  WindowSnapper
//
//  Created by Ben Xu on 11/25/25.
//

import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var leftHotKey: EventHotKeyRef?
    var rightHotKey: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotKeys()
    }

    func registerHotKeys() {
        // SNAP LEFT → ⌘ + ⌥ + ←
        registerHotKey(keyCode: 123, modifiers: cmdOpt, handlerID: 1)

        // SNAP RIGHT → ⌘ + ⌥ + →
        registerHotKey(keyCode: 124, modifiers: cmdOpt, handlerID: 2)

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(),
                            hotKeyCallback,
                            1,
                            &eventSpec,
                            nil,
                            nil)
    }

    let cmdOpt: UInt32 = UInt32(cmdKey | optionKey)

    func registerHotKey(keyCode: UInt32, modifiers: UInt32, handlerID: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        var eventHotKeyID = EventHotKeyID(
            signature: OSType(FOUR_CHAR_CODE(from: "WSNP")),
            id: handlerID
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if handlerID == 1 { leftHotKey = hotKeyRef }
        if handlerID == 2 { rightHotKey = hotKeyRef }
    }
}

// helper to build a 4-char OSType signature
func FOUR_CHAR_CODE(from: String) -> Int {
    var result: Int = 0
    for char in from.utf16 {
        result = (result << 8) + Int(char)
    }
    return result
}

// global callback for hotkeys
let hotKeyCallback: EventHandlerUPP = { _, event, _ in
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    switch hotKeyID.id {
    case 1:
        // snap left
        AccessibilityManager.shared.snapFrontmostWindowLeftHalf()
    case 2:
        // snap right
        AccessibilityManager.shared.snapFrontmostWindowRightHalf()
    default:
        break
    }

    return noErr
}
