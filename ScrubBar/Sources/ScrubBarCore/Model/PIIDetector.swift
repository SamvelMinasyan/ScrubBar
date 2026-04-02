// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import os

public struct PIIMatch: Identifiable, Equatable {
    public let id = UUID()
    public let entityType: String
    public let value: String
    public let range: Range<String.Index>
}

public class PIIDetector {
    
    // Entity Constants
    public static let IPV4 = "IP"
    public static let IPV6 = "IPV6"
    public static let MAC = "MAC"
    public static let URL = "URL"
    public static let EMAIL = "EMAIL"
    public static let PHONE = "PHONE"
    public static let CREDIT_CARD = "CC"
    public static let SSN = "SSN"
    public static let API_KEY = "APIKEY"
    public static let PRIVATE_KEY = "PRIVKEY"
    public static let JWT = "JWT"
    public static let AWS_ACCESS_KEY = "AWSKEY"
    public static let AWS_SECRET_KEY = "AWSSECRET"
    public static let ANTHROPIC_KEY = "ANTHROPIC"
    public static let GOOGLE_KEY = "GOOGLEKEY"
    public static let AZURE_KEY = "AZUREKEY"
    public static let SLACK_TOKEN = "SLACK"
    public static let TWILIO_KEY = "TWILIO"
    public static let SENDGRID_KEY = "SENDGRID"
    public static let PASSWORD = "PASSWORD"
    
    // New Types
    public static let DATE = "DATE"
    public static let PASSPORT = "PASSPORT"
    public static let DRIVER_LICENSE = "LICENSE"
    public static let VIN = "VIN"
    public static let LICENSE_PLATE = "PLATE"

    private var patterns: [(String, NSRegularExpression)] = []
    
    public init() {
        self.compilePatterns()
    }
    
    private func compilePatterns() {
        // Network
        addPattern(type: PIIDetector.IPV4, regex: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#)
        
        // IPv6 (Simplified)
        let ipv6 = #"\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b|\b(?:[0-9a-fA-F]{1,4}:){1,7}:\b|\b(?:[0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}\b|\b(?:[0-9a-fA-F]{1,4}:){1,5}(?::[0-9a-fA-F]{1,4}){1,2}\b|\b(?:[0-9a-fA-F]{1,4}:){1,4}(?::[0-9a-fA-F]{1,4}){1,3}\b|\b(?:[0-9a-fA-F]{1,4}:){1,3}(?::[0-9a-fA-F]{1,4}){1,4}\b|\b(?:[0-9a-fA-F]{1,4}:){1,2}(?::[0-9a-fA-F]{1,4}){1,5}\b|\b[0-9a-fA-F]{1,4}:(?::[0-9a-fA-F]{1,4}){1,6}\b|\b:(?::[0-9a-fA-F]{1,4}){1,7}\b|\b::(?:[fF]{4}:)?(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#
        addPattern(type: PIIDetector.IPV6, regex: ipv6)
        
        addPattern(type: PIIDetector.MAC, regex: #"\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b"#)
        
        // Contact
        addPattern(type: PIIDetector.EMAIL, regex: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#)
        addPattern(type: PIIDetector.PHONE, regex: #"(?:\+?1[-.\s]?)?\(?[2-9]\d{2}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"#)
        
        // Identity
        addPattern(type: PIIDetector.CREDIT_CARD, regex: #"\b(?:4[0-9]{3}|5[1-5][0-9]{2}|6(?:011|5[0-9]{2})|3[47][0-9]{2})[-\s]?[0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{1,4}\b"#)
        addPattern(type: PIIDetector.SSN, regex: #"\b(?!000|666|9\d{2})\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b"#)
        
        // New Patterns from openredaction
        
        // Date (simple formats like MM/DD/YYYY, YYYY-MM-DD)
        addPattern(type: PIIDetector.DATE, regex: #"\b(?:\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})|(?:\d{4}[\/\-.]\d{1,2}[\/\-.]\d{1,2})\b"#)
        
        // Passport (US & UK)
        // US: 6-9 alphanumeric
        addPattern(type: PIIDetector.PASSPORT, regex: #"\b(?:PASSPORT|PASS)[:\s]*([A-Z0-9]{6,9})\b"#)
        
        // Driver License (New Zealand example, generic format for now)
        addPattern(type: PIIDetector.DRIVER_LICENSE, regex: #"\b(?:LICENSE|LIC)[:\s]*([A-Z0-9]{6,12})\b"#)
        
        // VIN
        addPattern(type: PIIDetector.VIN, regex: #"\b[A-HJ-NPR-Z0-9]{17}\b"#)
        
        // License Plate (Simplified generic)
        addPattern(type: PIIDetector.LICENSE_PLATE, regex: #"\b(?:PLATE|REG)[:\s]*([A-Z0-9]{2,8})\b"#)
        
        
        // Secrets
        addPattern(type: PIIDetector.PRIVATE_KEY, regex: #"-----BEGIN\s+(?:RSA\s+|EC\s+|DSA\s+|OPENSSH\s+|ENCRYPTED\s+)?PRIVATE\s+KEY-----"#)
        addPattern(type: PIIDetector.JWT, regex: #"\beyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\b"#)
        addPattern(type: PIIDetector.AWS_ACCESS_KEY, regex: #"\b(?:AKIA|ABIA|ACCA|AIPA|ANPA|ANVA|AROA|ASCA|ASIA)[0-9A-Z]{16}\b"#)
        addPattern(type: PIIDetector.AWS_SECRET_KEY, regex: #"(?:aws_secret_access_key|AWS_SECRET_ACCESS_KEY|secret_access_key)\s*[=:]\s*["']?([A-Za-z0-9/+=]{40})["']?"#)
        addPattern(type: PIIDetector.ANTHROPIC_KEY, regex: #"\bsk-ant-[a-zA-Z0-9_-]{20,}\b"#)
        addPattern(type: PIIDetector.GOOGLE_KEY, regex: #"\bAIza[0-9A-Za-z_-]{35}\b"#)
        addPattern(type: PIIDetector.AZURE_KEY, regex: #"\b[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}\b"#)
        addPattern(type: PIIDetector.SLACK_TOKEN, regex: #"\bxox[baprs]-[0-9a-zA-Z]{10,48}\b"#)
        addPattern(type: PIIDetector.TWILIO_KEY, regex: #"\bAC[a-f0-9]{32}\b"#)
        addPattern(type: PIIDetector.SENDGRID_KEY, regex: #"\bSG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}\b"#)
        
        // Generic API Keys
        let genericKeys = [
            #"\bsk-[a-zA-Z0-9_-]{20,}\b"#,
            #"\bsk-proj-[a-zA-Z0-9_-]{20,}\b"#,
            #"\b[sr]k_(?:live|test)_[a-zA-Z0-9]{20,}\b"#,
            #"\bpk_(?:live|test)_[a-zA-Z0-9]{20,}\b"#,
            #"\bghp_[a-zA-Z0-9]{36}\b"#,
            #"\bgho_[a-zA-Z0-9]{36}\b"#,
            #"\bghu_[a-zA-Z0-9]{36}\b"#,
            #"\bghs_[a-zA-Z0-9]{36}\b"#,
            #"\bghr_[a-zA-Z0-9]{36}\b"#,
            #"\bglpat-[a-zA-Z0-9_-]{20,}\b"#,
            #"\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b"#, // Heroku/Generic GUID
            #"\bnpm_[a-zA-Z0-9]{36}\b"#,
            #"\bpypi-[a-zA-Z0-9_-]{50,}\b"#,
            #"\b[MN][a-zA-Z0-9_-]{23,}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27,}\b"#,
            #"\bBearer\s+[a-zA-Z0-9_-]{20,}\b"#,
            #"\b[a-zA-Z0-9_-]{32,}\b"#
        ]
        
        for p in genericKeys {
            addPattern(type: PIIDetector.API_KEY, regex: p, options: [.caseInsensitive])
        }
        
        // Password
        let passwordPatterns = [
            #"(?:password|passwd|pwd|secret|token|api_key|apikey|auth_token|access_token)\s*[=:]\s*["']([^"']{8,})["']"#,
            #"(?:PASSWORD|PASSWD|PWD|SECRET|TOKEN|API_KEY|APIKEY|AUTH_TOKEN|ACCESS_TOKEN)\s*[=:]\s*["']([^"']{8,})["']"#
        ]
        for p in passwordPatterns {
            addPattern(type: PIIDetector.PASSWORD, regex: p, options: [.caseInsensitive])
        }
        
        // URL
        addPattern(type: PIIDetector.URL, regex: #"https?://[^\s<>"'{}|\\^`\[\]]{10,}"#)
    }
    
    private func addPattern(type: String, regex: String, options: NSRegularExpression.Options = []) {
        do {
            let re = try NSRegularExpression(pattern: regex, options: options)
            patterns.append((type, re))
        } catch {
            logger.error("Failed to compile pattern for \(type): \(error)")
        }
    }
    
    public func detect(text: String, disabledTypes: Set<String> = [], customPatterns: [CustomPattern] = []) -> [PIIMatch] {
        var matches: [PIIMatch] = []
        var seenRanges: [Range<String.Index>] = []
        
        var allPatterns = self.patterns
        
        for custom in customPatterns {
             if let regex = try? NSRegularExpression(pattern: custom.regex, options: []) {
                 allPatterns.append((custom.name, regex))
             }
        }
        
        for (type, regex) in allPatterns {
            // Check if disabled
            if disabledTypes.contains(type) {
                continue
            }
            
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.enumerateMatches(in: text, options: [], range: nsRange) { (match, _, _) in
                guard let match = match, let range = Range(match.range, in: text) else { return }
                
                var finalRange = range
                var value = String(text[range])
                
                // Handle capture groups
                if match.numberOfRanges > 1 {
                    // Use first capture group if available
                    if let groupRange = Range(match.range(at: 1), in: text) {
                        finalRange = groupRange
                        value = String(text[groupRange])
                    }
                }
                
                // Overlap check
                if isOverlapping(finalRange, in: seenRanges) {
                    return
                }
                
                // Extra validations
                if type == PIIDetector.API_KEY {
                    if !isLikelyApiKey(value) { return }
                }
                if type == PIIDetector.URL {
                    if !isSensitiveUrl(value) { return }
                }
                
                seenRanges.append(finalRange)
                matches.append(PIIMatch(entityType: type, value: value, range: finalRange))
            }
        }
        
        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
    
    private func isOverlapping(_ range: Range<String.Index>, in seen: [Range<String.Index>]) -> Bool {
        for s in seen {
            if range.overlaps(s) { return true }
        }
        return false
    }
    
    private func isLikelyApiKey(_ value: String) -> Bool {
        if value.count < 20 { return false }
        
        let highConfidencePrefixes = [
            "sk-", "pk_", "sk_", "api_", "AKIA", "ASIA", "ABIA",
            "ghp_", "gho_", "ghu_", "ghs_", "ghr_", "glpat-",
            "xox", "Bearer", "npm_", "pypi-", "SG.", "AC"
        ]
        
        if highConfidencePrefixes.contains(where: { value.hasPrefix($0) }) {
            return true
        }
        
        let lower = value.lowercased()
        let falsePositives = [
            "example", "sample", "placeholder", "your_", "my_",
            "test", "demo", "localhost", "undefined", "null",
            "xxxx", "0000", "1234", "abcd", "function", "return",
            "const", "import", "export", "class", "interface"
        ]
        
        if falsePositives.contains(where: { lower.contains($0) }) {
            return false
        }
        
        // Digits required
        if value.first(where: { $0.isNumber }) == nil { return false }
        
        // Entropy (simplified: just unique chars count)
        let uniqueChars = Set(value).count
        if uniqueChars < 12 { return false }
        
        return true
    }
    
    private func isSensitiveUrl(_ url: String) -> Bool {
        let indicators = [
            "token=", "key=", "api_key=", "apikey=", "secret=",
            "password=", "pwd=", "auth=", "access_token=",
            "client_secret=", "private_key=", "bearer=",
            "/oauth/", "/auth/", "/token/", "/api/v"
        ]
        let lower = url.lowercased()
        if indicators.contains(where: { lower.contains($0) }) {
            return true
        }
        
        // Check for long parts
        let parts = url.components(separatedBy: "/")
        for part in parts {
            if part.count > 30 && isLikelyApiKey(part) {
                return true
            }
        }
        return false
    }
}
