//
//  PasteQueueItem.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SwiftUI

public enum PasteQueueOrder: String, Codable, CaseIterable, Identifiable {
    case fifo
    case lifo
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .fifo: return "FIFO (First In, First Out)"
        case .lifo: return "LIFO (Last In, First Out)"
        }
    }
    
    public var shortName: String {
        switch self {
        case .fifo: return "FIFO"
        case .lifo: return "LIFO"
        }
    }
}

public enum PasteQueueBehavior: String, Codable, CaseIterable, Identifiable {
    case removeAfterPaste
    case cycle
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .removeAfterPaste: return "Remove After Paste"
        case .cycle: return "Keep in Queue (Loop/Cycle)"
        }
    }
}

public struct PasteQueueItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var clip: ClipRecord
    public var enqueuedAt: Double // epoch milliseconds
    
    public init(id: UUID = UUID(), clip: ClipRecord, enqueuedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.clip = clip
        self.enqueuedAt = enqueuedAt
    }
}
