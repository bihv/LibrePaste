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
            Section("Limits & Retention") {
                Picker("Maximum clips kept", selection: $maxItems) {
                    Text("100 clips").tag("100")
                    Text("200 clips").tag("200")
                    Text("500 clips (Default)").tag("500")
                    Text("1,000 clips").tag("1000")
                    Text("2,000 clips").tag("2000")
                    Text("5,000 clips").tag("5000")
                }
                .pickerStyle(.menu)
                .onChange(of: maxItems) { _, val in
                    store.saveSetting(key: "maxItems", value: val)
                }
                
                Picker("History retention", selection: $historyDays) {
                    Text("7 days").tag("7")
                    Text("14 days").tag("14")
                    Text("30 days (Default)").tag("30")
                    Text("90 days").tag("90")
                    Text("1 year").tag("365")
                    Text("Keep Forever").tag("0")
                }
                .pickerStyle(.menu)
                .onChange(of: historyDays) { _, val in
                    store.saveSetting(key: "historyDays", value: val)
                }
            }
            
            Section("Storage Overview") {
                if let stats = store.storageStats {
                    LabeledContent("Total Clips", value: "\(stats.totalClips) (\(stats.pinnedClips) pinned)")
                    LabeledContent("Clips Breakdown", value: "\(stats.textClips) text, \(stats.linkClips) link, \(stats.imageClips) image")
                    LabeledContent("Database Size", value: stats.formattedDbSize)
                    LabeledContent("Images Cache Size", value: stats.formattedImagesSize)
                    LabeledContent("Total Disk Usage", value: stats.formattedTotalSize)
                } else {
                    ProgressView()
                }
            }
            
            Section("Maintenance") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Button("Clean Unpinned Clips...") {
                            showCleanAlert = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingMaintenance)
                        
                        Button("Vacuum Database") {
                            performVacuum()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingMaintenance)
                        
                        if isPerformingMaintenance {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    
                    Text("Cleaning removes expired unpinned clips to free up storage space. Vacuum defragments the SQLite database file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
        .alert("Clean Unpinned Clips?", isPresented: $showCleanAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clean All Unpinned", role: .destructive) {
                performClean()
            }
        } message: {
            Text("This will permanently delete all unpinned clips from your clipboard history. Pinned clips will remain safe.")
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
        Task.detached(priority: .userInitiated) {
            _ = DatabaseManager.shared.cleanUnpinnedClips()
            await MainActor.run {
                store.reloadClips()
                store.reloadStats()
                isPerformingMaintenance = false
            }
        }
    }
    
    private func performVacuum() {
        isPerformingMaintenance = true
        Task.detached(priority: .userInitiated) {
            _ = DatabaseManager.shared.vacuumDatabase()
            await MainActor.run {
                store.reloadStats()
                isPerformingMaintenance = false
            }
        }
    }
}
