// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import SwiftUI
import ScrubBarCore
import UserNotifications
import os

extension Notification.Name {
    static let scrub = Notification.Name("scrub")
    static let restore = Notification.Name("restore")
}

@main
struct ScrubBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    init() {
        ScrubBarApp.applyHotkeys()
    }
    
    static func applyHotkeys() {
        let state = AppState.shared
        let scrub = state.hotkeyConfig(for: .scrub)
        let restore = state.hotkeyConfig(for: .restore)
        let history = state.hotkeyConfig(for: .history)
        
        HotkeyManager.shared.register(keyCode: scrub.keyCode, modifiers: scrub.modifiers, id: HotkeyManager.HotkeyId.scrub.rawValue) {
            NotificationCenter.default.post(name: .scrub, object: nil)
        }
        HotkeyManager.shared.register(keyCode: restore.keyCode, modifiers: restore.modifiers, id: HotkeyManager.HotkeyId.restore.rawValue) {
            NotificationCenter.default.post(name: .restore, object: nil)
        }
        HotkeyManager.shared.register(keyCode: history.keyCode, modifiers: history.modifiers, id: HotkeyManager.HotkeyId.history.rawValue) {
            HistoryWindowController.shared.toggle()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("ScrubBar", systemImage: "lock.shield") {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .reapplyHotkeys)) { _ in
                    ScrubBarApp.applyHotkeys()
                }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            Text(appState.statusMessage)
            
            Divider()
            
            Button("Scrub Clipboard") {
                appState.scrubClipboard()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            
            Button("Restore Original") {
                appState.restoreClipboard()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Preferences...") {
                SettingsWindowController.shared.showWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button("Clear Cache") {
                appState.clearCache()
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrub)) { _ in
            appState.scrubClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: .restore)) { _ in
            appState.restoreClipboard()
        }
    }
}

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    
    func showWindow() {
        appLogger.debug("Settings window: showWindow called")
        if window == nil {
            appLogger.debug("Settings window: creating new window")
            let settingsView = SettingsView()
                .environmentObject(AppState.shared)
            
            let hostingController = NSHostingController(rootView: settingsView)
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            
            window?.contentViewController = hostingController
            window?.title = "ScrubBar Preferences"
            window?.center()
            window?.isReleasedWhenClosed = false
            window?.delegate = self
        }
        
        // Force window to front even if app is in background (accessory mode)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        appLogger.debug("Settings window: ordered front")
    }
    
    func windowWillClose(_ notification: Notification) {
        appLogger.debug("Settings window: closing")
        // We don't set window = nil because we reuse it.
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyRecordingMonitor: Any?
    
    // MARK: - Service Handler
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startHotkeyRecording(_:)),
            name: .startHotkeyRecording,
            object: nil
        )
    }
    
    @objc private func startHotkeyRecording(_ notification: Notification) {
        guard let raw = notification.userInfo?["hotkeyIdRaw"] as? UInt32,
              let _ = HotkeyManager.HotkeyId(rawValue: raw) else { return }
        
        if let m = hotkeyRecordingMonitor {
            NSEvent.removeMonitor(m)
            hotkeyRecordingMonitor = nil
        }
        
        // Use LOCAL monitor so keys are captured when Preferences window is focused (no Accessibility needed)
        hotkeyRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async {
                if event.keyCode == 53 { // Escape - cancel
                    NotificationCenter.default.post(name: .hotkeyRecorded, object: nil, userInfo: ["cancelled": true, "hotkeyIdRaw": raw])
                } else {
                    let mod = carbonModifiers(from: event)
                    let config = HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: mod)
                    if let data = try? JSONEncoder().encode(config) {
                        NotificationCenter.default.post(name: .hotkeyRecorded, object: nil, userInfo: ["configData": data, "hotkeyIdRaw": raw])
                    }
                }
                if let m = self?.hotkeyRecordingMonitor {
                    NSEvent.removeMonitor(m)
                    self?.hotkeyRecordingMonitor = nil
                }
            }
            return nil // Consume the event so the shortcut doesn't trigger while recording
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        appLogger.info("Open with URLs: \(urls)")
        guard let fileURL = urls.first else { return }
        
        handleFileScrub(fileURL)
    }
    
    func handleFileScrub(_ fileURL: URL) {
        appLogger.info("Scrubbing file: \(fileURL.path)")
        Task {
            do {
                let appState = AppState.shared
                let scrubber = FileScrubber()
                let outputURL = try scrubber.scrubFile(
                    at: fileURL,
                    disabledTypes: appState.disabledTypes,
                    customPatterns: appState.customPatterns
                )
                appLogger.info("File scrubbed to: \(outputURL.path)")
                
                DispatchQueue.main.async {
                    self.showNotification(
                        title: "ScrubBar",
                        message: "Scrubbed: \(fileURL.lastPathComponent) -> \(outputURL.lastPathComponent)"
                    )
                }
            } catch {
                appLogger.error("Error scrubbing file: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Scrub Failed"
                    alert.informativeText = "Failed to scrub file: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
    
    func handleFileRestore(_ fileURL: URL) {
        appLogger.info("Restoring file: \(fileURL.path)")
        Task {
            do {
                let restorer = FileRestorer()
                let outputURL = try restorer.restoreFile(at: fileURL)
                appLogger.info("File restored to: \(outputURL.path)")
                
                DispatchQueue.main.async {
                    self.showNotification(
                        title: "ScrubBar",
                        message: "Restored: \(fileURL.lastPathComponent) -> \(outputURL.lastPathComponent)"
                    )
                }
            } catch FileRestorer.RestoreError.mappingNotFound {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Restore Failed"
                    alert.informativeText = "Mapping file not found. This file may not have been scrubbed by ScrubBar."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            } catch FileRestorer.RestoreError.noPlaceholdersFound {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Restore Failed"
                    alert.informativeText = "No placeholders found in this file."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            } catch {
                appLogger.error("Error restoring file: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Restore Failed"
                    alert.informativeText = "Failed to restore file: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    @objc func handleScrubFile(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        appLogger.debug("Service: handleScrubFile called")
        
        guard let fileURLs = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let fileURL = fileURLs.first else {
            appLogger.warning("Service: no file URL found for scrub")
            return
        }

        appLogger.info("Service: scrubbing file: \(fileURL.path)")
        handleFileScrub(fileURL)
    }
    
    @objc func handleRestoreFile(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        appLogger.debug("Service: handleRestoreFile called")
        
        guard let fileURLs = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let fileURL = fileURLs.first else {
            appLogger.warning("Service: no file URL found for restore")
            return
        }

        // Check if file is obfuscated before attempting restore
        let restorer = FileRestorer()
        guard restorer.isObfuscatedFile(fileURL) else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Not an Obfuscated File"
                alert.informativeText = "This file doesn't appear to be an obfuscated file created by ScrubBar."
                alert.alertStyle = .informational
                alert.runModal()
            }
            return
        }
        
        appLogger.info("Service: restoring file: \(fileURL.path)")
        handleFileRestore(fileURL)
    }
}
