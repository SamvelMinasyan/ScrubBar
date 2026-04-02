// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import AppKit
import Carbon

public extension Notification.Name {
    static let startHotkeyRecording = Notification.Name("startHotkeyRecording")
    static let hotkeyRecorded = Notification.Name("hotkeyRecorded")
    static let reapplyHotkeys = Notification.Name("reapplyHotkeys")
}

/// Converts NSEvent modifier flags to Carbon modifier bits
public func carbonModifiers(from event: NSEvent) -> UInt32 {
    var mod: UInt32 = 0
    if event.modifierFlags.contains(.command) { mod |= UInt32(cmdKey) }
    if event.modifierFlags.contains(.shift) { mod |= UInt32(shiftKey) }
    if event.modifierFlags.contains(.option) { mod |= UInt32(optionKey) }
    if event.modifierFlags.contains(.control) { mod |= UInt32(controlKey) }
    return mod
}

/// Returns a short display string for a hotkey (e.g. "⌘⇧S")
public func hotkeyDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
    var parts: [String] = []
    if (modifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
    if (modifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
    if (modifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
    if (modifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
    
    let keyName = keyCodeToString(keyCode)
    parts.append(keyName)
    return parts.joined()
}

private func keyCodeToString(_ keyCode: UInt32) -> String {
    // Common virtual key codes to character
    let map: [UInt32: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
        0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
        0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1",
        0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
        0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
        0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P", 0x25: "L",
        0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",",
        0x2C: "/", 0x2D: "N", 0x2E: "M", 0x2F: ".", 0x30: "⇥", 0x31: "␣",
        0x24: "↵", 0x33: "⌫", 0x35: "⎋", 0x36: "⌘", 0x37: "⌃", 0x38: "⇧",
        0x39: "⇪", 0x3A: "⌥", 0x41: ".",
    ]
    return map[keyCode] ?? "Key\(keyCode)"
}
