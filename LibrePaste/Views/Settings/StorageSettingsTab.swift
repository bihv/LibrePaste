//
//  StorageSettingsTab.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import SwiftUI

public struct StorageSettingsTab: View {
    @Bindable public var store: ClipboardStore
    
    @State private var maxItems: String = "500"
    @State private var historyDays: String = "30"
    @State private var showCleanAlert: Bool = false
    @State private var isPerformingMaintenance: Bool = false
    
    public init(store: ClipboardStore) {
        self.store = store
    }
    
    public var body: some View {
        Form {
            Section(L10n.tr("Limits & Retention")) {
                Picker(L10n.tr("Maximum clips kept"), selection: $maxItems) {
                    Text(L10n.tr("100 clips")).tag("100")
                    Text(L10n.tr("200 clips")).tag("200")
                    Text(L10n.tr("500 clips (Default)")).tag("500")
                    Text(L10n.tr("1,000 clips")).tag("1000")
                    Text(L10n.tr("2,000 clips")).tag("2000")
                    Text(L10n.tr("5,000 clips")).tag("5000")
                }
                .pickerStyle(.menu)
                .onChange(of: maxItems) { _, val in
                    store.saveSetting(key: "maxItems", value: val)
                }
                
                Picker(L10n.tr("History retention"), selection: $historyDays) {
                    Text(L10n.tr("7 days")).tag("7")
                    Text(L10n.tr("14 days")).tag("14")
                    Text(L10n.tr("30 days (Default)")).tag("30")
                    Text(L10n.tr("90 days")).tag("90")
                    Text(L10n.tr("1 year")).tag("365")
                    Text(L10n.tr("Keep Forever")).tag("0")
                }
                .pickerStyle(.menu)
                .onChange(of: historyDays) { _, val in
                    store.saveSetting(key: "historyDays", value: val)
                }
            }
            
            Section(L10n.tr("Storage Overview")) {
                if let stats = store.storageStats {
                    LabeledContent(L10n.tr("Total Clips"), value: L10n.tr("%lld (%lld pinned)", stats.totalClips, stats.pinnedClips))
                    LabeledContent(L10n.tr("Clips Breakdown"), value: L10n.tr("%lld text, %lld link, %lld image", stats.textClips, stats.linkClips, stats.imageClips))
                    LabeledContent(L10n.tr("Database Size"), value: stats.formattedDbSize)
                    LabeledContent(L10n.tr("Images Cache Size"), value: stats.formattedImagesSize)
                    LabeledContent(L10n.tr("Total Disk Usage"), value: stats.formattedTotalSize)
                } else {
                    ProgressView()
                }
            }
            
            Section(L10n.tr("Maintenance")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Button(L10n.tr("Clean Unpinned Clips Now...")) {
                            showCleanAlert = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingMaintenance)
                        
                        Button(L10n.tr("Vacuum Database")) {
                            performVacuum()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingMaintenance)
                        
                        if isPerformingMaintenance {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    
                    Text(L10n.tr("Cleaning removes expired unpinned clips to free up storage space. Vacuum defragments the SQLite database file."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .alert(L10n.tr("Clean Unpinned Clips?"), isPresented: $showCleanAlert) {
            Button(L10n.tr("Cancel"), role: .cancel) {}
            Button(L10n.tr("Clean All Unpinned"), role: .destructive) {
                performClean()
            }
        } message: {
            Text(L10n.tr("This will permanently delete all unpinned clips from your clipboard history. Pinned clips will remain safe."))
        }
        .onAppear {
            loadSettings()
            store.reloadStats()
        }
    }
    
    private func loadSettings() {
        maxItems = store.settings["maxItems"] ?? "500"
        historyDays = store.settings["historyDays"] ?? "30"
    }
    
    private func performClean() {
        isPerformingMaintenance = true
        Task {
            await Task.detached(priority: .userInitiated) {
                _ = DatabaseManager.shared.cleanUnpinnedClips()
            }.value
            store.reloadClips()
            store.reloadStats()
            isPerformingMaintenance = false
        }
    }
    
    private func performVacuum() {
        isPerformingMaintenance = true
        Task {
            await Task.detached(priority: .userInitiated) {
                _ = DatabaseManager.shared.vacuumDatabase()
            }.value
            store.reloadStats()
            isPerformingMaintenance = false
        }
    }
}
