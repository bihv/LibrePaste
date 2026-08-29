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
        ZStack {
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
            
            if store.isLocked {
                LockOverlayView(store: store) {
                    store.unlockApp()
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .frame(width: 520, height: 490)
        .preferredColorScheme(store.appAppearance.colorScheme)
    }
}
