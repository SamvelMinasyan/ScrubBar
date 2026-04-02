// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import AppKit

public class ClipboardManager {
    public static let shared = ClipboardManager()
    
    private let pasteboard = NSPasteboard.general
    
    public init() {}
    
    public func readText() -> String? {
        return pasteboard.string(forType: .string)
    }
    
    public func writeText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    public func writeImage(_ image: NSImage) {
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}
