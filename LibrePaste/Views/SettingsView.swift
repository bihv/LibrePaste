//
//  SettingsView.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct SettingsView: View {
    @Bindable public var store: ClipboardStore
    @Bindable public var state: SettingsState = SettingsState.shared
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        TabView(selection: $state.activeTab) {
            GeneralSettingsTab(store: store)
                .tabItem {
                    Label(SettingsTab.general.title, systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)
            
            StorageSettingsTab(store: store)
                .tabItem {
                    Label(SettingsTab.storage.title, systemImage: SettingsTab.storage.icon)
                }
                .tag(SettingsTab.storage)
            
            PrivacySettingsTab(store: store)
                .tabItem {
                    Label(SettingsTab.privacy.title, systemImage: SettingsTab.privacy.icon)
                }
                .tag(SettingsTab.privacy)
            
            AboutSettingsTab(store: store)
                .tabItem {
                    Label(SettingsTab.about.title, systemImage: SettingsTab.about.icon)
                }
                .tag(SettingsTab.about)
        }
        .overlay {
            if store.isLocked {
                LockOverlayView(store: store) {
                    store.unlockApp()
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .frame(width: 540, height: 500)
        .preferredColorScheme(store.appAppearance.colorScheme)
        .environment(\.locale, store.appLanguage.locale)
        .id(store.appLanguage)
        .onAppear {
            AppDelegate.shared?.setSettingsWindowOpen(true)
            AppDelegate.shared?.centerSettingsWindowOnActiveScreen()
        }
        .onDisappear {
            AppDelegate.shared?.setSettingsWindowOpen(false)
        }
    }
}

