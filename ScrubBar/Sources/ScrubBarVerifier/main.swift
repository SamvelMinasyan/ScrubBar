// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import ScrubBarCore

func assertEqual(_ a: Any?, _ b: Any?, _ message: String = "") {
    let sa = String(describing: a)
    let sb = String(describing: b)
    if sa != sb {
        print("❌ FAIL: \(message) - Expected \(sb), got \(sa)")
        exit(1)
    } else {
        print("✅ PASS: \(message)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "") {
    if !condition {
        print("❌ FAIL: \(message)")
        exit(1)
    } else {
        print("✅ PASS: \(message)")
    }
}

print("Running ScrubBar Verification Suite...")
let detector = PIIDetector()

// 1. Email
let emailText = "Contact test@example.com"
let emailMatches = detector.detect(text: emailText)
assertEqual(emailMatches.count, 1, "Email Count")
assertEqual(emailMatches.first?.entityType, PIIDetector.EMAIL, "Email Type")
assertEqual(emailMatches.first?.value, "test@example.com", "Email Value")

// 2. IP
let ipText = "Server 192.168.1.1"
let ipMatches = detector.detect(text: ipText)
assertEqual(ipMatches.count, 1, "IP Count")
assertEqual(ipMatches.first?.entityType, PIIDetector.IPV4, "IP Type")

// 3. New Patterns - Date
let dateText = "Date: 2023-01-01"
let dateMatches = detector.detect(text: dateText)
assertEqual(dateMatches.count, 1, "Date Count")
assertEqual(dateMatches.first?.entityType, PIIDetector.DATE, "Date Type")

// 4. New Patterns - Passport
let passportText = "PASSPORT: A12345678"
let passportMatches = detector.detect(text: passportText)
assertEqual(passportMatches.count, 1, "Passport Count")

// 5. New Patterns - VIN
let vin = "1M8GDM9AKP0427888" // 17 chars
let vinText = "VIN: \(vin)"
let vinMatches = detector.detect(text: vinText)
assertEqual(vinMatches.count, 1, "VIN Count")

// 6. Custom Patterns
let custom = CustomPattern(name: "EMPLOYEE", regex: #"EMP-\d{6}"#)
let customText = "EMP-123456"
let customMatches = detector.detect(text: customText, customPatterns: [custom])
assertEqual(customMatches.count, 1, "Custom Pattern Count")
assertEqual(customMatches.first?.entityType, "EMPLOYEE", "Custom Type")

// 7. Disabled Types
let disabledMatches = detector.detect(text: emailText, disabledTypes: [PIIDetector.EMAIL])
assertEqual(disabledMatches.count, 0, "Disabled Type Count")

// 8. Clipboard History Monitor
print("\nTesting Clipboard Monitor...")
let monitor = ClipboardMonitor()
let clipboard = ClipboardManager.shared

clipboard.writeText("History Test 123")
Thread.sleep(forTimeInterval: 1.0)

let item1 = HistoryItem(type: .text("A"))
let item2 = HistoryItem(type: .text("A"))
let item3 = HistoryItem(type: .text("B"))

assertEqual(item1.type == item2.type, true, "HistoryItem Type Equality")
assertEqual(item1.type == item3.type, false, "HistoryItem Type Inequality")

print("\n🎉 ALL TESTS PASSED!")
