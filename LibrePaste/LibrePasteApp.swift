//
//  LibrePasteApp.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

@main
struct LibrePasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store)
                .preferredColorScheme(appDelegate.store.appAppearance.colorScheme)
                .environment(\.locale, appDelegate.store.appLanguage.locale)
        }
    }
}
