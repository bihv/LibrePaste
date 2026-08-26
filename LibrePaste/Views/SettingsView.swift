//
//  SettingsView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct SettingsView: View {
    @Bindable public var store: ClipboardStore
    public var state: SettingsState = SettingsState.shared
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Group {
            switch state.activeTab {
            case .general:
                GeneralSettingsTab(store: store)
            case .storage:
                StorageSettingsTab(store: store)
            case .privacy:
                PrivacySettingsTab(store: store)
            case .about:
                AboutSettingsTab(store: store)
            }
        }
        .frame(width: 520, height: 490)
    }
}
