// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import ApplicationServices
import Carbon
import AppKit
import os

struct PasteHelper {
    
    /// Request Accessibility permissions (shows alert, doesn't trigger system prompt)
    static func requestAccessibilityPermissions() {
        // Only show our custom alert - never trigger system prompt
        // This is because ad-hoc signing causes the prompt to appear on every launch
        if !hasAccessibilityPermissions() {
            showAccessibilityAlert()
        }
    }
    
    /// Check if we have Accessibility permissions
    static func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Show user-friendly alert about missing permissions
    private static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        ScrubBar needs Accessibility permissions to simulate paste operations.
        
        ⚠️ Note: Due to development signing, you may need to re-grant permissions after each app rebuild.
        
        To grant permissions:
        1. Open System Settings → Privacy & Security → Accessibility
        2. Find and enable ScrubBar
        3. Restart the app
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings to Accessibility pane
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
    
    static func simulatePaste(to targetApp: NSRunningApplication?) {
        appLogger.debug("PasteHelper: starting paste simulation")
        
        // Check if we have Accessibility permissions
        let trusted = AXIsProcessTrusted()
        appLogger.debug("PasteHelper: accessibility permissions: \(trusted ? "granted" : "denied")")
        
        if !trusted {
            appLogger.error("PasteHelper: accessibility permissions required")
            
            // Show a user-friendly alert
            DispatchQueue.main.async {
                showAccessibilityAlert()
            }
            return
        }
        
        guard let targetApp = targetApp else {
            appLogger.error("PasteHelper: no target application provided")
            return
        }
        
        appLogger.debug("PasteHelper: target app: \(targetApp.localizedName ?? "unknown")")
        
        // Don't hide the app - just close the window (already done by caller)
        // Wait a bit for window close animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            appLogger.debug("PasteHelper: activating target app")
            
            // Explicitly activate the target app
            targetApp.activate(options: [.activateIgnoringOtherApps])
            
            // Wait for activation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appLogger.debug("PasteHelper: creating Cmd+V event")
                
                let source = CGEventSource(stateID: .combinedSessionState)
                
                // Create V key down with Command
                guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
                    appLogger.error("PasteHelper: could not create key down event")
                    return
                }
                vDown.flags = .maskCommand
                
                // Create V key up with Command
                guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
                    appLogger.error("PasteHelper: could not create key up event")
                    return
                }
                vUp.flags = .maskCommand
                
                // Post both events
                let location = CGEventTapLocation.cghidEventTap
                vDown.post(tap: location)
                
                // Small delay between down and up
                usleep(10000) // 10ms
                
                vUp.post(tap: location)
                
                appLogger.debug("PasteHelper: paste events posted")
            }
        }
    }
}
