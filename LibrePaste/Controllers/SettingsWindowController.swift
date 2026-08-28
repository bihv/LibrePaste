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

@Observable
public final class SettingsState {
    public static let shared = SettingsState()
    public var activeTab: SettingsTab = .general
}

public final class SettingsWindowController: NSObject, NSToolbarDelegate {
    public static let shared = SettingsWindowController()
    
    public weak var window: NSWindow?
    
    public func setupToolbar(for window: NSWindow) {
        self.window = window
        let toolbar = NSToolbar(identifier: "LibrePasteSettingsToolbar")
        toolbar.delegate = self
        toolbar.selectedItemIdentifier = SettingsState.shared.activeTab.toolbarId
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.title = SettingsState.shared.activeTab.rawValue
    }
    
    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace] + SettingsTab.allCases.map { $0.toolbarId } + [.flexibleSpace]
    }
    
    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace] + SettingsTab.allCases.map { $0.toolbarId }
    }
    
    public func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return SettingsTab.allCases.map { $0.toolbarId }
    }
    
    public func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab.allCases.first(where: { $0.toolbarId == itemIdentifier }) else {
            return nil
        }
        
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.rawValue
        item.paletteLabel = tab.rawValue
        item.toolTip = tab.rawValue
        item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.rawValue)
        item.target = self
        item.action = #selector(handleToolbarItemClicked(_:))
        return item
    }
    
    @objc private func handleToolbarItemClicked(_ sender: NSToolbarItem) {
        guard !SecurityManager.shared.isLocked else {
            // Keep the selected item indicator on active tab
            sender.toolbar?.selectedItemIdentifier = SettingsState.shared.activeTab.toolbarId
            return
        }
        guard let tab = SettingsTab.allCases.first(where: { $0.toolbarId == sender.itemIdentifier }) else { return }
        SettingsState.shared.activeTab = tab
        window?.title = tab.rawValue
        window?.toolbar?.selectedItemIdentifier = tab.toolbarId
    }
}
