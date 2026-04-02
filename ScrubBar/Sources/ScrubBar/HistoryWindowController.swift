// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import SwiftUI
import ScrubBarCore
import Carbon
import AppKit
import os

class HistoryWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryWindowController()
    
    private var window: NSPanel?
    private var isVisible = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var previousApp: NSRunningApplication?
    
    override init() {
        super.init()
    }
    
    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }
    
    func show() {
        // Capture the current frontmost app BEFORE we show our window
        previousApp = NSWorkspace.shared.frontmostApplication
        appLogger.debug("Captured previous app: \(self.previousApp?.localizedName ?? "unknown")")
        
        if window == nil {
            setupWindow()
        }
        
        // Setup global monitor for clicking away
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.close()
            }
        }
        
        // Position at mouse
        if let screen = NSScreen.main {
            let mouseLoc = NSEvent.mouseLocation
            // Mouse location is in screen coordinates (bottom-left origin)
            
            let windowWidth: CGFloat = 500
            let windowHeight: CGFloat = 400
            
            // Calculate position below cursor (default)
            var newOrigin = NSPoint(
                x: mouseLoc.x - (windowWidth / 2),
                y: mouseLoc.y - windowHeight
            )
            
            // Check if window would go below bottom of screen
            let screenFrame = screen.visibleFrame
            if newOrigin.y < screenFrame.minY {
                // Flip to open above cursor instead
                newOrigin.y = mouseLoc.y + 20 // 20px above cursor
                appLogger.debug("History window: flipping to open above cursor")
            }
            
            if newOrigin.x < screenFrame.minX {
                newOrigin.x = screenFrame.minX + 10
            } else if newOrigin.x + windowWidth > screenFrame.maxX {
                newOrigin.x = screenFrame.maxX - windowWidth - 10
            }
            
            if newOrigin.y + windowHeight > screenFrame.maxY {
                newOrigin.y = screenFrame.maxY - windowHeight - 10
            }
            
            window?.setFrameOrigin(newOrigin)
        } else {
             window?.center()
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func close() {
        window?.orderOut(nil)
        isVisible = false
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
    
    private func setupWindow() {
        let historyView = HistoryView { [weak self] item, scrubbed in
            self?.paste(item: item, scrubbed: scrubbed)
        }
        .environmentObject(AppState.shared)
        
        let hostingController = NSHostingController(rootView: historyView)
        
        // Create custom panel that CAN become key
        let panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating // Keep floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.contentViewController = hostingController
        panel.delegate = self
        
        // Handle Escape and arrow keys
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
             guard let self = self, let window = self.window, window.isVisible else { return event }
             
             if event.keyCode == 53 { // Escape
                 self.close()
                 return nil
             }
             if event.keyCode == 126 { // Up
                 NotificationCenter.default.post(name: .historyArrowUp, object: nil)
                 return nil
             }
             if event.keyCode == 125 { // Down
                 NotificationCenter.default.post(name: .historyArrowDown, object: nil)
                 return nil
             }
             if event.keyCode == 36 || event.keyCode == 76 { // Return or Enter
                 NotificationCenter.default.post(name: .historyPasteSelected, object: nil)
                 return nil
             }
             return event
        }
        
        self.window = panel
    }
}

// Custom Panel to allow input (canBecomeKey = true) even with .nonactivatingPanel style
class SearchPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

extension HistoryWindowController {
    
    private func paste(item: HistoryItem, scrubbed: Bool) {
        appLogger.debug("History: pasting item")
        close()
        
        AppState.shared.pauseMonitoring()
        
        AppState.shared.promptPaste(item)
        
        let clipboard = ClipboardManager.shared
        switch item.type {
        case .text(let str):
             if scrubbed {
                 clipboard.writeText(str)
             } else {
                 appLogger.debug("Writing text to clipboard")
                 clipboard.writeText(str)
             }
        case .image(let img):
            appLogger.debug("Writing image to clipboard")
            clipboard.writeImage(img)
        }
        
        PasteHelper.simulatePaste(to: previousApp)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AppState.shared.resumeMonitoring()
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if isVisible {
             close()
        }
    }
}
