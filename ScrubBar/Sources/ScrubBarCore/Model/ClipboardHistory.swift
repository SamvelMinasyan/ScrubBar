// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import AppKit

public enum HistoryItemType: Equatable {
    case text(String)
    case image(NSImage)
    
    public static func == (lhs: HistoryItemType, rhs: HistoryItemType) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)):
            return a == b
        case (.image, .image):
            return false // Images hard to compare, rely on ID
        default:
            return false
        }
    }
}

public struct HistoryItem: Identifiable, Equatable {
    public let id: UUID
    public let type: HistoryItemType
    public let timestamp: Date
    public let appBundleID: String?
    public let piiMatches: [PIIMatch]
    
    public init(id: UUID = UUID(), type: HistoryItemType, timestamp: Date = Date(), appBundleID: String? = nil, piiMatches: [PIIMatch] = []) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.appBundleID = appBundleID
        self.piiMatches = piiMatches
    }
    
    public static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
        return lhs.id == rhs.id
    }
}
