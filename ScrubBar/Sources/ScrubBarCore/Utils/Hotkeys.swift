// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import Carbon

public struct HotkeyConfig: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    
    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public class HotkeyManager {
    public static let shared = HotkeyManager()
    
    public enum HotkeyId: UInt32 {
        case scrub = 1
        case restore = 2
        case history = 3
    }
    
    private var hotkeys: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    
    init() {
        installEventHandler()
    }
    
    public func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, action: @escaping () -> Void) {
        unregister(id: id)
        
        hotkeys[id] = action
        
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 0x53505354, id: id)
        
        let err = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs[id] = ref
        }
    }
    
    public func unregister(id: UInt32) {
        if let ref = hotKeyRefs[id] {
            UnregisterEventHotKey(ref)
            hotKeyRefs.removeValue(forKey: id)
        }
        hotkeys.removeValue(forKey: id)
    }
    
    private func installEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let _ = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if let action = HotkeyManager.shared.hotkeys[hotKeyID.id] {
                DispatchQueue.main.async {
                    action()
                }
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, nil, &eventHandler)
    }
}

// Default key codes (virtual key codes)
public struct KeyCodes {
    public static let s: UInt32 = 0x01
    public static let r: UInt32 = 0x0F
    public static let v: UInt32 = 0x09
}

public struct Modifiers {
    public static let cmdShift = cmdKey | shiftKey
}
