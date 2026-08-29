//
//  SettingsWindowController.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import AppKit
import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case storage = "Storage"
    case privacy = "Privacy"
    case about = "About"
    
    public var id: String { rawValue }
    
    public var title: String {
        L10n.tr(rawValue)
    }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .storage: return "cylinder.split.1x2"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
    
    public var toolbarId: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("SettingsTab_\(rawValue)")
    }
}

@MainActor
@Observable
public final class SettingsState {
    public static let shared = SettingsState()
    public var activeTab: SettingsTab = .general
}
