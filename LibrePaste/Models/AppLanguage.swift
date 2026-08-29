//
//  AppLanguage.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SwiftUI

/// Supported application display languages
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case english = "en"
    case vietnamese = "vi"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system:
            return L10n.tr("System Default", comment: "System language option")
        case .english:
            return "English"
        case .vietnamese:
            return "Tiếng Việt"
        }
    }
    
    public var nativeName: String {
        switch self {
        case .system:
            return L10n.tr("System", comment: "Short system label")
        case .english:
            return "English"
        case .vietnamese:
            return "Tiếng Việt"
        }
    }
    
    public var flag: String {
        switch self {
        case .system:
            return "🌐"
        case .english:
            return "🇺🇸"
        case .vietnamese:
            return "🇻🇳"
        }
    }
    
    public var locale: Locale {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
            if preferred.lowercased().starts(with: "vi") {
                return Locale(identifier: "vi_VN")
            } else {
                return Locale(identifier: "en_US")
            }
        case .english:
            return Locale(identifier: "en_US")
        case .vietnamese:
            return Locale(identifier: "vi_VN")
        }
    }
    
    public var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .vietnamese:
            return "vi"
        }
    }
}
