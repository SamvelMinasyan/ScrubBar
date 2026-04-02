// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import os

public struct FileMapping: Codable {
    public let placeholderToValue: [String: String]
    public let originalFileName: String
    public let originalFilePath: String
    
    public init(placeholderToValue: [String: String], originalFileName: String, originalFilePath: String) {
        self.placeholderToValue = placeholderToValue
        self.originalFileName = originalFileName
        self.originalFilePath = originalFilePath
    }
}

public class FileScrubber {
    
    public enum ScrubberError: Error {
        case fileReadFailed
        case fileWriteFailed
        case encodingError
        case mappingWriteFailed
        case noPIIFound
    }
    
    private var typeCounters: [String: Int] = [:]
    private var placeholderToValue: [String: String] = [:]
    private var valueToPlaceholder: [String: String] = [:] // For deduplication
    
    public init() {}
    
    /// Get the mappings directory in Application Support
    private func getMappingsDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mappingsDir = appSupport.appendingPathComponent("ScrubBar/mappings", isDirectory: true)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: mappingsDir, withIntermediateDirectories: true, attributes: nil)
        
        return mappingsDir
    }
    
    /// Generate a hash-based filename for the mapping file
    private func mappingFilename(for obfuscatedURL: URL) -> String {
        let pathHash = obfuscatedURL.path.hash
        return "\(abs(pathHash)).json"
    }
    
    public func scrubFile(
        at inputURL: URL,
        disabledTypes: Set<String> = [],
        customPatterns: [CustomPattern] = []
    ) throws -> URL {
        // Reset state for this file
        typeCounters.removeAll()
        placeholderToValue.removeAll()
        valueToPlaceholder.removeAll()
        
        // 1. Read file
        guard let content = try? String(contentsOf: inputURL, encoding: .utf8) else {
            throw ScrubberError.fileReadFailed
        }
        
        // 2. Detect PII
        let detector = PIIDetector()
        let matches = detector.detect(text: content, disabledTypes: disabledTypes, customPatterns: customPatterns)
        
        if matches.isEmpty {
            throw ScrubberError.noPIIFound
        }
        
        // 3. Replace with numbered placeholders (like clipboard)
        // Use deduplication: same values get same placeholder
        var scrubbedContent = content
        let sortedMatches = matches.sorted { $0.range.lowerBound > $1.range.lowerBound }
        
        for match in sortedMatches {
            let placeholder = getPlaceholder(for: match.entityType, value: match.value)
            scrubbedContent.replaceSubrange(match.range, with: placeholder)
        }
        
        // 4. Write obfuscated file
        let directory = inputURL.deletingLastPathComponent()
        let filename = inputURL.deletingPathExtension().lastPathComponent
        let extensionName = inputURL.pathExtension
        
        let newFilename = "\(filename)_obfuscated.\(extensionName)"
        let outputURL = directory.appendingPathComponent(newFilename)
        
        do {
            try scrubbedContent.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            throw ScrubberError.fileWriteFailed
        }
        
        // 5. Save mapping file in Application Support directory
        let mapping = FileMapping(
            placeholderToValue: placeholderToValue,
            originalFileName: inputURL.lastPathComponent,
            originalFilePath: inputURL.path
        )
        
        let mappingsDir = try getMappingsDirectory()
        let mappingFilename = self.mappingFilename(for: outputURL)
        let mappingURL = mappingsDir.appendingPathComponent(mappingFilename)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let mappingData = try encoder.encode(mapping)
            try mappingData.write(to: mappingURL)
        } catch {
            // If mapping fails, still return the scrubbed file but log error
            logger.warning("Failed to save mapping file: \(error)")
            throw ScrubberError.mappingWriteFailed
        }
        
        return outputURL
    }
    
    private func getPlaceholder(for type: String, value: String) -> String {
        // Check if we've already seen this exact value (deduplication)
        if let existingPlaceholder = valueToPlaceholder[value] {
            return existingPlaceholder
        }
        
        // Create new numbered placeholder
        let currentCount = typeCounters[type, default: 0] + 1
        typeCounters[type] = currentCount
        
        let placeholder = "<\(type)_\(currentCount)>"
        placeholderToValue[placeholder] = value
        valueToPlaceholder[value] = placeholder // Store reverse mapping for deduplication
        
        return placeholder
    }
}
