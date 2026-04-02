// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import XCTest
@testable import ScrubBarCore

final class PIIDetectorTests: XCTestCase {
    
    var detector: PIIDetector!
    
    override func setUp() {
        super.setUp()
        detector = PIIDetector()
    }
    
    func testEmails() {
        let text = "Contact me at test@example.com or user.name+tag@gmail.com"
        let matches = detector.detect(text: text)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].entityType, "EMAIL")
        XCTAssertEqual(matches[0].value, "test@example.com")
        XCTAssertEqual(matches[1].value, "user.name+tag@gmail.com")
    }
    
    func testIPs() {
        let text = "Server is at 192.168.1.1 and 10.0.0.5"
        let matches = detector.detect(text: text)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].entityType, "IP")
    }
    
    func testCreditCards() {
        let text = "Visa: 4111-1111-1111-1111"
        let matches = detector.detect(text: text)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entityType, "CC")
    }
    
    func testAPIKeys() {
        let text = "Key: sk-test-1234567890abcdef12345678"
        let matches = detector.detect(text: text)
        // Note: isLikelyApiKey might filter simple strings if they lack digits or entropy
        // The pattern for SK is specific, so it should pass if it matches the prefix logic.
        // Let's ensure the test string matches the heuristics (some digits, length)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entityType, "APIKEY")
    }
    
    func testNewPatterns() {
        // VIN (must be exactly 17 alphanumeric characters, excluding I, O, Q)
        let vin = "1M8GDM9AKP0427889"
        let text = "My VIN is \(vin)"
        var matches = detector.detect(text: text)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entityType, "VIN")
        
        // Date
        let dateText = "Born on 1990-01-01"
        matches = detector.detect(text: dateText)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entityType, "DATE")
        
        // Passport
        let passportText = "PASSPORT: A12345678"
        matches = detector.detect(text: passportText)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entityType, "PASSPORT")
    }
    
    func testDisabledTypes() {
        let text = "test@example.com"
        let matches = detector.detect(text: text, disabledTypes: ["EMAIL"])
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testCustomPatterns() {
        let text = "Employee ID: EMP-123456"
        let custom = CustomPattern(name: "EMPLOYEE", regex: #"EMP-\d{6}"#)
        let matches = detector.detect(text: text, customPatterns: [custom])
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entityType, "EMPLOYEE")
        XCTAssertEqual(matches[0].value, "EMP-123456")
    }
}
