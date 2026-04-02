// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import AppKit
import Combine
import os

public class ClipboardMonitor: ObservableObject {
    @Published public var lastItem: HistoryItem?
    
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private var isPaused = false // Prevent detecting our own writes
    private let piiDetector = PIIDetector()
    
    public init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }
    
    public func startMonitoring() {
        // Poll every 100ms instead of 500ms to catch rapid copying
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func pause() {
        isPaused = true
    }
    
    public func resume() {
        isPaused = false
        lastChangeCount = pasteboard.changeCount // Update to current to avoid detecting the paste we just did
    }
    
    @objc private func checkClipboard() {
        // Skip if paused (we're currently pasting)
        if isPaused {
            return
        }

        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else {
            return
        }

        logger.debug("Clipboard change detected")
        lastChangeCount = currentChangeCount
        
        if let str = NSPasteboard.general.string(forType: .string) {
            logger.debug("Detected text change")
            // Check for PII
            let matches = piiDetector.detect(text: str)
            let item = HistoryItem(type: .text(str), piiMatches: matches)
            
            DispatchQueue.main.async {
                self.lastItem = item
            }
            return
        }
        
        if let img = NSImage(pasteboard: NSPasteboard.general) {
            logger.debug("Detected image change")
            let item = HistoryItem(type: .image(img))
            DispatchQueue.main.async {
                self.lastItem = item
            }
            return
        }
    }
}
