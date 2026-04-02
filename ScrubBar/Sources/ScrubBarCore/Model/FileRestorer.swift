// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import os

public class FileRestorer {
    
    public enum RestoreError: Error {
        case fileReadFailed
        case fileWriteFailed
        case mappingNotFound
        case mappingInvalid
        case noPlaceholdersFound
    }
    
    public init() {}
    
    /// Check if a file is an obfuscated file (has _obfuscated suffix or contains placeholders)
    public func isObfuscatedFile(_ url: URL) -> Bool {
        // Check if filename contains _obfuscated
        if url.lastPathComponent.contains("_obfuscated") {
            return true
        }
        
        // Check if file contains placeholders
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }
        
        let placeholderPattern = #"<([A-Z0-9_]+)_(\d+)>"#
        if let regex = try? NSRegularExpression(pattern: placeholderPattern) {
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            return regex.firstMatch(in: content, options: [], range: range) != nil
        }
        
        return false
    }
    
    /// Get the mappings directory in Application Support
    private func getMappingsDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("ScrubBar/mappings", isDirectory: true)
    }
    
    /// Generate a hash-based filename for the mapping file (same logic as FileScrubber)
    private func mappingFilename(for obfuscatedURL: URL) -> String {
        let pathHash = obfuscatedURL.path.hash
        return "\(abs(pathHash)).json"
    }
    
    /// Find the mapping file for an obfuscated file
    private func findMappingFile(for obfuscatedURL: URL) -> URL? {
        // First try: Look in Application Support directory (new location)
        if let mappingsDir = getMappingsDirectory() {
            let mappingFilename = self.mappingFilename(for: obfuscatedURL)
            let mappingURL = mappingsDir.appendingPathComponent(mappingFilename)
            if FileManager.default.fileExists(atPath: mappingURL.path) {
                return mappingURL
            }
        }
        
        // Fallback: Try old location (for backward compatibility)
        // Try: filename_obfuscated.txt.scrubbar_mapping.json
        let mappingURL1 = obfuscatedURL.appendingPathExtension("scrubbar_mapping.json")
        if FileManager.default.fileExists(atPath: mappingURL1.path) {
            return mappingURL1
        }
        
        // Try: filename.scrubbar_mapping.json (if file doesn't have _obfuscated suffix)
        let directory = obfuscatedURL.deletingLastPathComponent()
        let filename = obfuscatedURL.deletingPathExtension().lastPathComponent
        let mappingURL2 = directory.appendingPathComponent("\(filename).scrubbar_mapping.json")
        if FileManager.default.fileExists(atPath: mappingURL2.path) {
            return mappingURL2
        }
        
        return nil
    }
    
    /// Restore an obfuscated file using its mapping
    public func restoreFile(at obfuscatedURL: URL) throws -> URL {
        // 1. Read obfuscated file
        guard let content = try? String(contentsOf: obfuscatedURL, encoding: .utf8) else {
            throw RestoreError.fileReadFailed
        }
        
        // 2. Find and load mapping file
        guard let mappingURL = findMappingFile(for: obfuscatedURL) else {
            throw RestoreError.mappingNotFound
        }
        
        guard let mappingData = try? Data(contentsOf: mappingURL),
              let mapping = try? JSONDecoder().decode(FileMapping.self, from: mappingData) else {
            throw RestoreError.mappingInvalid
        }
        
        // 3. Replace placeholders with original values
        var restoredContent = content
        var count = 0
        
        // Use regex to find placeholders
        let placeholderPattern = #"<([A-Z0-9_]+)_(\d+)>"#
        guard let regex = try? NSRegularExpression(pattern: placeholderPattern) else {
            throw RestoreError.noPlaceholdersFound
        }
        
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..<content.endIndex, in: content))
        
        // Replace in reverse order to preserve indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: content) else { continue }
            let placeholder = String(content[range])
            
            if let original = mapping.placeholderToValue[placeholder] {
                restoredContent.replaceSubrange(range, with: original)
                count += 1
            }
        }
        
        if count == 0 {
            throw RestoreError.noPlaceholdersFound
        }
        
        // 4. Write restored file
        let directory = obfuscatedURL.deletingLastPathComponent()
        let filename = obfuscatedURL.deletingPathExtension().lastPathComponent
        let extensionName = obfuscatedURL.pathExtension
        
        // Remove _obfuscated suffix if present, otherwise add _restored
        let restoredFilename: String
        if filename.contains("_obfuscated") {
            let baseFilename = filename.replacingOccurrences(of: "_obfuscated", with: "")
            restoredFilename = "\(baseFilename)_restored.\(extensionName)"
        } else {
            restoredFilename = "\(filename)_restored.\(extensionName)"
        }
        
        let outputURL = directory.appendingPathComponent(restoredFilename)
        
        do {
            try restoredContent.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            throw RestoreError.fileWriteFailed
        }
        
        // 5. Cleanup: Delete mapping file after successful restore
        // Note: We keep the obfuscated file in case user wants to share it.
        // The mapping file is deleted since restore is complete and can't be done again.
        // If user needs to restore again, they can scrub the original file again.
        do {
            try FileManager.default.removeItem(at: mappingURL)
            logger.info("Deleted mapping file: \(mappingURL.path)")
        } catch {
            // Non-fatal error - log but don't fail the restore
            logger.warning("Could not delete mapping file: \(error)")
        }
        
        return outputURL
    }
}
