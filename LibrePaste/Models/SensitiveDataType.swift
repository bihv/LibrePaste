//
//  SensitiveDataType.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SwiftUI

// MARK: - Mask Strategy

public enum MaskStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case keepPrefixAndSuffix = "keepPrefixAndSuffix"
    case keepSuffixOnly = "keepSuffixOnly"
    case maskAll = "maskAll"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .keepPrefixAndSuffix:
            return L10n.tr("Keep Prefix & Last 4")
        case .keepSuffixOnly:
            return L10n.tr("Keep Last 4 Only")
        case .maskAll:
            return L10n.tr("Mask All (••••)")
        }
    }
    
    public var descriptionText: String {
        switch self {
        case .keepPrefixAndSuffix:
            return "E.g. sk-proj-••••••••••••3aB8"
        case .keepSuffixOnly:
            return "E.g. ••••••••••••1234"
        case .maskAll:
            return "E.g. ••••••••••••••••"
        }
    }
}

// MARK: - Custom Sensitive Rule

public struct CustomSensitiveRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var pattern: String
    public var maskStrategy: MaskStrategy
    public var isEnabled: Bool
    public var isCaseSensitive: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        pattern: String,
        maskStrategy: MaskStrategy = .keepPrefixAndSuffix,
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.maskStrategy = maskStrategy
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
    }
}

// MARK: - Sensitive Data Type

public enum SensitiveDataType: String, Codable, CaseIterable, Identifiable, Sendable {
    case apiKey = "apiKey"
    case privateKey = "privateKey"
    case creditCard = "creditCard"
    case databaseUrl = "databaseUrl"
    case bearerToken = "bearerToken"
    case nationalId = "nationalId"
    case password = "password"
    case custom = "custom"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .apiKey: return L10n.tr("API Key")
        case .privateKey: return L10n.tr("Private Key")
        case .creditCard: return L10n.tr("Payment Card")
        case .databaseUrl: return L10n.tr("Database URL")
        case .bearerToken: return L10n.tr("Auth Token")
        case .nationalId: return L10n.tr("ID / PII")
        case .password: return L10n.tr("Password")
        case .custom: return L10n.tr("Custom Rule")
        }
    }
    
    public var iconName: String {
        switch self {
        case .apiKey: return "key.horizontal.fill"
        case .privateKey: return "lock.doc.fill"
        case .creditCard: return "creditcard.fill"
        case .databaseUrl: return "server.rack"
        case .bearerToken: return "shield.lefthalf.filled"
        case .nationalId: return "person.text.rectangle.fill"
        case .password: return "lock.fill"
        case .custom: return "wrench.and.screwdriver.fill"
        }
    }
    
    public var themeColor: Color {
        switch self {
        case .apiKey: return Color(red: 0.95, green: 0.45, blue: 0.2) // Amber/Orange
        case .privateKey: return Color(red: 0.85, green: 0.25, blue: 0.25) // Red
        case .creditCard: return Color(red: 0.2, green: 0.7, blue: 0.5) // Emerald
        case .databaseUrl: return Color(red: 0.35, green: 0.55, blue: 0.95) // Blue
        case .bearerToken: return Color(red: 0.65, green: 0.4, blue: 0.95) // Purple
        case .nationalId: return Color(red: 0.2, green: 0.75, blue: 0.85) // Cyan
        case .password: return Color(red: 0.9, green: 0.3, blue: 0.4) // Rose
        case .custom: return Color(red: 0.55, green: 0.55, blue: 0.6) // Slate
        }
    }
}

// MARK: - Match Result

public struct SensitiveMatchResult: Sendable, Equatable {
    public let type: SensitiveDataType
    public let matchedSubstring: String
    public let maskedPreview: String
    public let customRuleName: String?
    
    public init(
        type: SensitiveDataType,
        matchedSubstring: String,
        maskedPreview: String,
        customRuleName: String? = nil
    ) {
        self.type = type
        self.matchedSubstring = matchedSubstring
        self.maskedPreview = maskedPreview
        self.customRuleName = customRuleName
    }
}
