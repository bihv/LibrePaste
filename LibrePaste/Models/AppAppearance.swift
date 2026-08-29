//
//  AppAppearance.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI
import AppKit

/// Application appearance and color scheme mode
public enum AppAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    public var description: String {
        switch self {
        case .system:
            return "Automatically adapt to macOS appearance"
        case .light:
            return "Always use light appearance"
        case .dark:
            return "Always use dark appearance"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}
