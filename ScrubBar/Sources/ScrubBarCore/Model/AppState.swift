// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import Combine
import os

public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var statusMessage: String = "Ready"
    @Published public var lastActionTime: Date?
    @Published public var clipboardHistory: [HistoryItem] = []
    
    private var placeholderToValue: [String: String] = [:]
    private var valueToPlaceholder: [String: String] = [:]
    private var typeCounters: [String: Int] = [:]
    
    private let detector = PIIDetector()
    private var expiryTimer: Timer?
    private let clipboard = ClipboardManager.shared
    private let monitor = ClipboardMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    @Published public var disabledTypes: Set<String> = []
    @Published public var customPatterns: [CustomPattern] = []
    @Published public var historyLimit: Int = 250
    
    public init() {
        loadSettings()
        startExpiryTimer()
        setupMonitor()
    }
    
    private func setupMonitor() {
        monitor.$lastItem
            .dropFirst() // Ignore initial nil
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] item in
                self?.addToHistory(item)
            }
            .store(in: &cancellables)
    }
    
    func addToHistory(_ item: HistoryItem) {
        // Check if this CONTENT already exists anywhere in history
        let existingIndex = clipboardHistory.firstIndex { existing in
            switch (existing.type, item.type) {
            case (.text(let existingText), .text(let newText)):
                return existingText == newText
            case (.image(let existingImg), .image(let newImg)):
                return existingImg.tiffRepresentation == newImg.tiffRepresentation
            default:
                return false
            }
        }
        
        if let index = existingIndex {
            if index == 0 {
                // Already at the top, skip
                logger.debug("Item already at top of history, skipping")
                return
            } else {
                // Exists elsewhere, remove it (we'll re-add at top to bubble it up)
                logger.debug("Bubbling up item from index \(index)")
                clipboardHistory.remove(at: index)
            }
        }
        
        clipboardHistory.insert(item, at: 0)
        
        // Limit size (configurable 2–1000, default 250)
        let limit = max(2, min(1000, historyLimit))
        while clipboardHistory.count > limit {
            clipboardHistory.removeLast()
        }
        
        logger.debug("History updated, \(self.clipboardHistory.count) items")
    }
    
    public func promptPaste(_ item: HistoryItem) {
        addToHistory(item)
    }
    
    public func removeFromHistory(_ item: HistoryItem) {
        clipboardHistory.removeAll { $0.id == item.id }
    }
    
    public func pauseMonitoring() {
        monitor.pause()
    }
    
    public func resumeMonitoring() {
        monitor.resume()
    }
    
    // MARK: - Actions
    
    public func scrubClipboard() {
        guard let text = clipboard.readText(), !text.isEmpty else {
            statusMessage = "Clipboard empty"
            return
        }
        
        let matches = detector.detect(text: text, disabledTypes: disabledTypes, customPatterns: customPatterns)
        if matches.isEmpty {
            statusMessage = "No PII detected"
            return
        }
        
        var newText = text
        // Process matches in reverse order to preserve indices
        let sortedMatches = matches.sorted { $0.range.lowerBound > $1.range.lowerBound }
        
        var count = 0
        
        for match in sortedMatches {
            let placeholder = getPlaceholder(for: match.entityType, value: match.value)
            newText.replaceSubrange(match.range, with: placeholder)
            count += 1
        }
        
        clipboard.writeText(newText)
        statusMessage = "Scrubbed \(count) items"
        resetExpiryTimer()
    }
    
    public func restoreClipboard() {
        guard let text = clipboard.readText(), !text.isEmpty else {
             statusMessage = "Clipboard empty"
             return
        }
        
        // Find placeholders pattern: <TYPE_NUM>
        var newText = text
        var count = 0
        
        // Use Regex to find placeholders to avoid accidental replacements
        let placeholderPattern = #"<([A-Z0-9_]+)_(\d+)>"#
        let regex = try! NSRegularExpression(pattern: placeholderPattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
        
        // Reverse order again for replacement safety
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let placeholder = String(text[range])
            
            if let original = placeholderToValue[placeholder] {
                newText.replaceSubrange(range, with: original)
                count += 1
            }
        }
        
        if count > 0 {
            clipboard.writeText(newText)
            statusMessage = "Restored \(count) items"
        } else {
            statusMessage = "Nothing to restore"
        }
    }
    
    public func clearCache() {
        placeholderToValue.removeAll()
        valueToPlaceholder.removeAll()
        typeCounters.removeAll()
        statusMessage = "Cache cleared"
    }
    
    // MARK: - Hotkey Persistence
    
    private let hotkeyKeys: [HotkeyManager.HotkeyId: String] = [
        .scrub: "HotkeyScrub",
        .restore: "HotkeyRestore",
        .history: "HotkeyHistory"
    ]
    
    public func hotkeyConfig(for id: HotkeyManager.HotkeyId) -> HotkeyConfig {
        let key = hotkeyKeys[id]!
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(HotkeyConfig.self, from: data) else {
            return defaultHotkey(for: id)
        }
        return decoded
    }
    
    public func saveHotkey(_ config: HotkeyConfig, for id: HotkeyManager.HotkeyId) {
        let key = hotkeyKeys[id]!
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .reapplyHotkeys, object: nil)
    }
    
    private func defaultHotkey(for id: HotkeyManager.HotkeyId) -> HotkeyConfig {
        switch id {
        case .scrub: return HotkeyConfig(keyCode: KeyCodes.s, modifiers: UInt32(Modifiers.cmdShift))
        case .restore: return HotkeyConfig(keyCode: KeyCodes.r, modifiers: UInt32(Modifiers.cmdShift))
        case .history: return HotkeyConfig(keyCode: KeyCodes.v, modifiers: UInt32(Modifiers.cmdShift))
        }
    }
    
    // MARK: - Settings Persistence
    
    public func saveSettings() {
        UserDefaults.standard.set(Array(disabledTypes), forKey: "DisabledTypes")
        UserDefaults.standard.set(historyLimit, forKey: "HistoryLimit")
        
        if let data = try? JSONEncoder().encode(customPatterns) {
            UserDefaults.standard.set(data, forKey: "CustomPatterns")
        }
    }
    
    private func loadSettings() {
        if let savedDisabled = UserDefaults.standard.array(forKey: "DisabledTypes") as? [String] {
            disabledTypes = Set(savedDisabled)
        }
        let savedLimit = UserDefaults.standard.integer(forKey: "HistoryLimit")
        if savedLimit >= 2 && savedLimit <= 1000 {
            historyLimit = savedLimit
        }
        
        if let data = UserDefaults.standard.data(forKey: "CustomPatterns"),
           let savedPatterns = try? JSONDecoder().decode([CustomPattern].self, from: data) {
            customPatterns = savedPatterns
        }
    }
    
    // MARK: - Helpers
    
    private func getPlaceholder(for type: String, value: String) -> String {
        // Check existing
        if let existing = valueToPlaceholder[value] {
            return existing
        }
        
        // Create new
        let currentCount = typeCounters[type, default: 0] + 1
        typeCounters[type] = currentCount
        
        let placeholder = "<\(type)_\(currentCount)>"
        
        valueToPlaceholder[value] = placeholder
        placeholderToValue[placeholder] = value
        
        return placeholder
    }
    
    private func startExpiryTimer() {
        resetExpiryTimer()
    }
    
    private func resetExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: false) { [weak self] _ in
            self?.clearCache()
            self?.statusMessage = "Cache expired"
        }
    }
}

public struct CustomPattern: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var regex: String
    
    public init(id: UUID = UUID(), name: String, regex: String) {
        self.id = id
        self.name = name
        self.regex = regex
    }
}
