//
//  DatabaseManager.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import SQLite3

public final class DatabaseManager: @unchecked Sendable {
    public nonisolated static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "bihv.LibrePaste.databaseQueue", qos: .userInitiated)
    
    public let appSupportDir: URL
    public let dataDir: URL
    public let imagesDir: URL
    public let dbPath: URL
    
    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        appSupportDir = appSupport.appendingPathComponent("LibrePaste", isDirectory: true)
        dataDir = appSupportDir.appendingPathComponent("data", isDirectory: true)
        imagesDir = appSupportDir.appendingPathComponent("images", isDirectory: true)
        dbPath = dataDir.appendingPathComponent("librepaste.db")
        
        try? fileManager.createDirectory(at: dataDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        openDatabase()
        initTables()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Open & Init
    
    private func openDatabase() {
        if sqlite3_open_v2(dbPath.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            print("[DatabaseManager] Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        } else {
            // Enable WAL mode
            _ = executeSimple("PRAGMA journal_mode = WAL;")
            _ = executeSimple("PRAGMA synchronous = NORMAL;")
        }
    }
    
    private func executeSimple(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("[DatabaseManager] Exec error: \(String(cString: errMsg)) for SQL: \(sql)")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }
    
    private func initTables() {
        let createTablesSQL = """
        CREATE TABLE IF NOT EXISTS pinboards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL DEFAULT '#6366f1',
            created_at INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
        );
        
        CREATE TABLE IF NOT EXISTS clips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            content BLOB NOT NULL DEFAULT (x''),
            rtf BLOB,
            image_path TEXT,
            preview BLOB NOT NULL DEFAULT (x''),
            hash TEXT NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            source_name TEXT,
            source_icon TEXT,
            pinboard_id INTEGER,
            is_sensitive INTEGER NOT NULL DEFAULT 0,
            sensitive_type TEXT,
            custom_rule_name TEXT,
            title TEXT,
            FOREIGN KEY (pinboard_id) REFERENCES pinboards(id) ON DELETE SET NULL
        );
        
        CREATE UNIQUE INDEX IF NOT EXISTS idx_clips_hash ON clips(hash);
        CREATE INDEX IF NOT EXISTS idx_clips_created ON clips(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_clips_pinboard ON clips(pinboard_id);
        CREATE INDEX IF NOT EXISTS idx_clips_sensitive ON clips(is_sensitive);
        
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
        _ = executeSimple(createTablesSQL)
        
        // Auto-migrate schema for existing databases
        _ = executeSimple("ALTER TABLE clips ADD COLUMN is_sensitive INTEGER NOT NULL DEFAULT 0;")
        _ = executeSimple("ALTER TABLE clips ADD COLUMN sensitive_type TEXT;")
        _ = executeSimple("ALTER TABLE clips ADD COLUMN custom_rule_name TEXT;")
        _ = executeSimple("ALTER TABLE clips ADD COLUMN title TEXT;")
        
        // Default settings
        let defaults: [String: String] = [
            "theme": "system",
            "historyDays": "30",
            "maxItems": "500",
            "pasteTarget": "direct",
            "hideAfterPaste": "true",
            "ignorePasswords": "true",
            "ignoreTransient": "true",
            "playSoundOnPaste": "true",
            "pasteSoundName": "Tink",
            "enableSensitiveMasking": "true",
            "maskApiKeys": "true",
            "maskCreditCards": "true",
            "maskDatabaseUrls": "true",
            "maskPII": "true",
            "requireAuthToReveal": "false",
            "autoPurgeSensitiveHours": "0",
            "customSensitiveRules": "[]"
        ]
        
        for (k, v) in defaults {
            let sql = "INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (k as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (v as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        // Migrate legacy setting values if needed
        _ = executeSimple("UPDATE settings SET value = 'direct' WHERE key = 'pasteTarget' AND value = 'active';")
    }
    
    // MARK: - Crypto & BLOB Binding Helpers
    
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private func bindEncryptedBlob(stmt: OpaquePointer?, index: Int32, text: String?) {
        guard let text = text, !text.isEmpty else {
            sqlite3_bind_null(stmt, index)
            return
        }
        if let encryptedData = CryptoService.shared.encryptString(text) {
            _ = encryptedData.withUnsafeBytes { rawBuffer in
                sqlite3_bind_blob(stmt, index, rawBuffer.baseAddress, Int32(rawBuffer.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
    
    private func bindEncryptedRequiredBlob(stmt: OpaquePointer?, index: Int32, text: String) {
        if let encryptedData = CryptoService.shared.encryptString(text) {
            _ = encryptedData.withUnsafeBytes { rawBuffer in
                sqlite3_bind_blob(stmt, index, rawBuffer.baseAddress, Int32(rawBuffer.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_blob(stmt, index, nil, 0, SQLITE_TRANSIENT)
        }
    }
    
    private func extractData(from stmt: OpaquePointer, column: Int32) -> Data? {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL else { return nil }
        if let bytes = sqlite3_column_blob(stmt, column) {
            let count = sqlite3_column_bytes(stmt, column)
            return Data(bytes: bytes, count: Int(count))
        }
        return nil
    }
    
    private func extractDecryptedString(from stmt: OpaquePointer, column: Int32) -> String {
        guard let data = extractData(from: stmt, column: column) else { return "" }
        return CryptoService.shared.decryptString(from: data) ?? ""
    }
    
    private func extractDecryptedOptionalString(from stmt: OpaquePointer, column: Int32) -> String? {
        guard let data = extractData(from: stmt, column: column) else { return nil }
        return CryptoService.shared.decryptString(from: data)
    }
    
    // MARK: - Clips Operations
    
    public func upsertClip(_ clip: ClipRecord) -> (record: ClipRecord, isNew: Bool) {
        return queue.sync {
            let now = Date().timeIntervalSince1970 * 1000
            
            // Check existing by hash
            let checkSQL = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips WHERE hash = ?;"
            var stmt: OpaquePointer?
            var existing: ClipRecord?
            
            if sqlite3_prepare_v2(db, checkSQL, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt {
                sqlite3_bind_text(stmt, 1, (clip.hash as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    existing = extractClip(from: stmt)
                }
            }
            sqlite3_finalize(stmt)
            
            if var existing = existing {
                let updateSQL = "UPDATE clips SET created_at = ?, source_name = ?, source_icon = ?, is_sensitive = ?, sensitive_type = ?, custom_rule_name = ? WHERE id = ?;"
                var updateStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK {
                    sqlite3_bind_double(updateStmt, 1, now)
                    if let src = clip.sourceName {
                        sqlite3_bind_text(updateStmt, 2, (src as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(updateStmt, 2)
                    }
                    if let icon = clip.sourceIcon {
                        sqlite3_bind_text(updateStmt, 3, (icon as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(updateStmt, 3)
                    }
                    sqlite3_bind_int(updateStmt, 4, clip.isSensitive ? 1 : 0)
                    if let sType = clip.sensitiveType?.rawValue {
                        sqlite3_bind_text(updateStmt, 5, (sType as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(updateStmt, 5)
                    }
                    if let ruleName = clip.customRuleName {
                        sqlite3_bind_text(updateStmt, 6, (ruleName as NSString).utf8String, -1, nil)
                    } else {
                        sqlite3_bind_null(updateStmt, 6)
                    }
                    sqlite3_bind_int64(updateStmt, 7, existing.id)
                    sqlite3_step(updateStmt)
                }
                sqlite3_finalize(updateStmt)
                
                existing.createdAt = now
                existing.sourceName = clip.sourceName
                existing.sourceIcon = clip.sourceIcon
                existing.isSensitive = clip.isSensitive
                existing.sensitiveType = clip.sensitiveType
                existing.customRuleName = clip.customRuleName
                return (existing, false)
            }
            
            // Insert new
            let insertSQL = """
            INSERT INTO clips (type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title)
            VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var insertStmt: OpaquePointer?
            var newId: Int64 = 0
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStmt, 1, (clip.type.rawValue as NSString).utf8String, -1, nil)
                bindEncryptedRequiredBlob(stmt: insertStmt, index: 2, text: clip.content)
                bindEncryptedBlob(stmt: insertStmt, index: 3, text: clip.rtf)
                if let path = clip.imagePath {
                    sqlite3_bind_text(insertStmt, 4, (path as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStmt, 4)
                }
                bindEncryptedRequiredBlob(stmt: insertStmt, index: 5, text: clip.preview)
                sqlite3_bind_text(insertStmt, 6, (clip.hash as NSString).utf8String, -1, nil)
                sqlite3_bind_double(insertStmt, 7, now)
                if let src = clip.sourceName {
                    sqlite3_bind_text(insertStmt, 8, (src as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStmt, 8)
                }
                if let icon = clip.sourceIcon {
                    sqlite3_bind_text(insertStmt, 9, (icon as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStmt, 9)
                }
                if let pId = clip.pinboardId {
                    sqlite3_bind_int64(insertStmt, 10, pId)
                } else {
                    sqlite3_bind_null(insertStmt, 10)
                }
                sqlite3_bind_int(insertStmt, 11, clip.isSensitive ? 1 : 0)
                if let sType = clip.sensitiveType?.rawValue {
                    sqlite3_bind_text(insertStmt, 12, (sType as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStmt, 12)
                }
                if let ruleName = clip.customRuleName {
                    sqlite3_bind_text(insertStmt, 13, (ruleName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStmt, 13)
                }
                if let title = clip.title {
                    sqlite3_bind_text(insertStmt, 14, (title as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(insertStmt, 14)
                }
                
                if sqlite3_step(insertStmt) == SQLITE_DONE {
                    newId = sqlite3_last_insert_rowid(db)
                }
            }
            sqlite3_finalize(insertStmt)
            
            pruneOldInternal()
            
            var insertedRecord = clip
            insertedRecord.id = newId
            insertedRecord.createdAt = now
            return (insertedRecord, true)
        }
    }
    
    public func listClips(limit: Int = 200) -> [ClipRecord] {
        return queue.sync {
            let sql = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips ORDER BY pinned DESC, created_at DESC LIMIT ?;"
            var stmt: OpaquePointer?
            var result: [ClipRecord] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let clip = extractClip(from: stmt) {
                        result.append(clip)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    public func searchClips(query: String, limit: Int = 200) -> [ClipRecord] {
        return queue.sync {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            
            let sql = """
            SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title
            FROM clips
            ORDER BY pinned DESC, created_at DESC;
            """
            var stmt: OpaquePointer?
            var result: [ClipRecord] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let clip = extractClip(from: stmt) {
                        if (clip.title?.localizedStandardContains(trimmed) == true) ||
                           clip.content.localizedStandardContains(trimmed) ||
                           clip.preview.localizedStandardContains(trimmed) ||
                           (clip.sourceName?.localizedStandardContains(trimmed) == true) {
                            result.append(clip)
                            if result.count >= limit {
                                break
                            }
                        }
                    }
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    public func getClip(id: Int64) -> ClipRecord? {
        return queue.sync {
            let sql = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips WHERE id = ?;"
            var stmt: OpaquePointer?
            var result: ClipRecord?
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt {
                sqlite3_bind_int64(stmt, 1, id)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    result = extractClip(from: stmt)
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    public func deleteClip(id: Int64) {
        queue.sync {
            // Delete image file if exists
            let selectSQL = "SELECT image_path FROM clips WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, id)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let pathPtr = sqlite3_column_text(stmt, 0) {
                        let path = String(cString: pathPtr)
                        try? FileManager.default.removeItem(atPath: path)
                        ThumbnailManager.shared.deleteThumbnail(for: path)
                    }
                }
            }
            sqlite3_finalize(stmt)
            
            let deleteSQL = "DELETE FROM clips WHERE id = ?;"
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(delStmt, 1, id)
                sqlite3_step(delStmt)
            }
            sqlite3_finalize(delStmt)
        }
    }
    
    public func setPinned(id: Int64, pinned: Bool) {
        queue.sync {
            let sql = "UPDATE clips SET pinned = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
                sqlite3_bind_int64(stmt, 2, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    public func renameClip(id: Int64, title: String?) -> ClipRecord? {
        return queue.sync {
            let sql = "UPDATE clips SET title = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let trimmed = trimmed, !trimmed.isEmpty {
                    sqlite3_bind_text(stmt, 1, (trimmed as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 1)
                }
                sqlite3_bind_int64(stmt, 2, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            
            let selectSQL = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips WHERE id = ?;"
            var selectStmt: OpaquePointer?
            var result: ClipRecord?
            if sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK, let selectStmt = selectStmt {
                sqlite3_bind_int64(selectStmt, 1, id)
                if sqlite3_step(selectStmt) == SQLITE_ROW {
                    result = extractClip(from: selectStmt)
                }
            }
            sqlite3_finalize(selectStmt)
            return result
        }
    }
    
    public func updateClip(id: Int64, content: String, preview: String, rtf: String? = nil, title: String? = nil) -> ClipRecord? {
        let hashSource = (content.contains("<") && content.contains(">")) ? content : (!content.isEmpty ? content : (rtf ?? ""))
        let newHash = HashHelper.sha256(hashSource)
        
        // Check if updated content is sensitive (run outside queue.sync to avoid recursive dispatch deadlocks)
        let matchResult = SensitiveDataService.shared.detectSensitiveData(in: content)
        let isSensitive = matchResult != nil
        let sensitiveType = matchResult?.type
        let customRuleName = matchResult?.customRuleName
        let effectivePreview = matchResult?.maskedPreview ?? preview
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return queue.sync {
            let sql = "UPDATE clips SET content = ?, preview = ?, rtf = ?, hash = ?, is_sensitive = ?, sensitive_type = ?, custom_rule_name = ?, title = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                bindEncryptedRequiredBlob(stmt: stmt, index: 1, text: content)
                bindEncryptedRequiredBlob(stmt: stmt, index: 2, text: effectivePreview)
                bindEncryptedBlob(stmt: stmt, index: 3, text: rtf)
                sqlite3_bind_text(stmt, 4, (newHash as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, isSensitive ? 1 : 0)
                if let sType = sensitiveType?.rawValue {
                    sqlite3_bind_text(stmt, 6, (sType as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }
                if let ruleName = customRuleName {
                    sqlite3_bind_text(stmt, 7, (ruleName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                if let cleanTitle = cleanTitle, !cleanTitle.isEmpty {
                    sqlite3_bind_text(stmt, 8, (cleanTitle as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 8)
                }
                sqlite3_bind_int64(stmt, 9, id)
                let stepRes = sqlite3_step(stmt)
                if stepRes != SQLITE_DONE {
                    // Fallback to update without changing hash if another clip has this unique hash
                    let fallbackSql = "UPDATE clips SET content = ?, preview = ?, rtf = ?, is_sensitive = ?, sensitive_type = ?, custom_rule_name = ?, title = ? WHERE id = ?;"
                    var fallbackStmt: OpaquePointer?
                    if sqlite3_prepare_v2(db, fallbackSql, -1, &fallbackStmt, nil) == SQLITE_OK {
                        bindEncryptedRequiredBlob(stmt: fallbackStmt, index: 1, text: content)
                        bindEncryptedRequiredBlob(stmt: fallbackStmt, index: 2, text: effectivePreview)
                        bindEncryptedBlob(stmt: fallbackStmt, index: 3, text: rtf)
                        sqlite3_bind_int(fallbackStmt, 4, isSensitive ? 1 : 0)
                        if let sType = sensitiveType?.rawValue {
                            sqlite3_bind_text(fallbackStmt, 5, (sType as NSString).utf8String, -1, nil)
                        } else {
                            sqlite3_bind_null(fallbackStmt, 5)
                        }
                        if let ruleName = customRuleName {
                            sqlite3_bind_text(fallbackStmt, 6, (ruleName as NSString).utf8String, -1, nil)
                        } else {
                            sqlite3_bind_null(fallbackStmt, 6)
                        }
                        if let cleanTitle = cleanTitle, !cleanTitle.isEmpty {
                            sqlite3_bind_text(fallbackStmt, 7, (cleanTitle as NSString).utf8String, -1, nil)
                        } else {
                            sqlite3_bind_null(fallbackStmt, 7)
                        }
                        sqlite3_bind_int64(fallbackStmt, 8, id)
                        sqlite3_step(fallbackStmt)
                    }
                    sqlite3_finalize(fallbackStmt)
                }
            }
            sqlite3_finalize(stmt)
            
            let selectSQL = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips WHERE id = ?;"
            var selectStmt: OpaquePointer?
            var result: ClipRecord?
            if sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK, let selectStmt = selectStmt {
                sqlite3_bind_int64(selectStmt, 1, id)
                if sqlite3_step(selectStmt) == SQLITE_ROW {
                    result = extractClip(from: selectStmt)
                }
            }
            sqlite3_finalize(selectStmt)
            return result
        }
    }
    
    public func clearAll() {
        queue.sync {
            // Find and delete unpinned image files
            let selectSQL = "SELECT image_path FROM clips WHERE pinned = 0 AND image_path IS NOT NULL;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let pathPtr = sqlite3_column_text(stmt, 0) {
                        let path = String(cString: pathPtr)
                        try? FileManager.default.removeItem(atPath: path)
                        ThumbnailManager.shared.deleteThumbnail(for: path)
                    }
                }
            }
            sqlite3_finalize(stmt)
            
            ThumbnailManager.shared.clearAllDecryptedTempFiles()
            
            _ = executeSimple("DELETE FROM clips WHERE pinned = 0;")
            _ = executeSimple("VACUUM;")
        }
    }
    
    // MARK: - Pruning
    
    private func pruneOldInternal() {
        // 1. Retention by history days
        let daysSetting = getSettingInternal("historyDays")
        let historyDays = Int(daysSetting ?? "30") ?? 30
        if historyDays > 0 {
            let cutoff = (Date().timeIntervalSince1970 - Double(historyDays * 86400)) * 1000
            
            let selectImagesSQL = "SELECT image_path FROM clips WHERE pinned = 0 AND created_at < ? AND image_path IS NOT NULL;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, selectImagesSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, cutoff)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let pathPtr = sqlite3_column_text(stmt, 0) {
                        let path = String(cString: pathPtr)
                        try? FileManager.default.removeItem(atPath: path)
                        ThumbnailManager.shared.deleteThumbnail(for: path)
                    }
                }
            }
            sqlite3_finalize(stmt)
            
            let deleteSQL = "DELETE FROM clips WHERE pinned = 0 AND created_at < ?;"
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_double(delStmt, 1, cutoff)
                sqlite3_step(delStmt)
            }
            sqlite3_finalize(delStmt)
        }
        
        // 2. Retention by max items
        let maxSetting = getSettingInternal("maxItems")
        let maxItems = max(50, Int(maxSetting ?? "500") ?? 500)
        
        let overflowImagesSQL = """
        SELECT image_path FROM clips WHERE pinned = 0 AND image_path IS NOT NULL AND id NOT IN (
            SELECT id FROM clips WHERE pinned = 0 ORDER BY created_at DESC LIMIT ?
        );
        """
        var imgStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, overflowImagesSQL, -1, &imgStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(imgStmt, 1, Int32(maxItems))
            while sqlite3_step(imgStmt) == SQLITE_ROW {
                if let pathPtr = sqlite3_column_text(imgStmt, 0) {
                    let path = String(cString: pathPtr)
                    try? FileManager.default.removeItem(atPath: path)
                    ThumbnailManager.shared.deleteThumbnail(for: path)
                }
            }
        }
        sqlite3_finalize(imgStmt)
        
        let deleteOverflowSQL = """
        DELETE FROM clips WHERE pinned = 0 AND id NOT IN (
            SELECT id FROM clips WHERE pinned = 0 ORDER BY created_at DESC LIMIT ?
        );
        """
        var delOverStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteOverflowSQL, -1, &delOverStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(delOverStmt, 1, Int32(maxItems))
            sqlite3_step(delOverStmt)
        }
        sqlite3_finalize(delOverStmt)
    }
    
    // MARK: - Pinboards Operations
    
    public func listPinboards() -> [Pinboard] {
        return queue.sync {
            let sql = "SELECT id, name, color, created_at, sort_order FROM pinboards ORDER BY sort_order ASC, created_at DESC;"
            var stmt: OpaquePointer?
            var result: [Pinboard] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = sqlite3_column_int64(stmt, 0)
                    let name = String(cString: sqlite3_column_text(stmt, 1))
                    let color = String(cString: sqlite3_column_text(stmt, 2))
                    let createdAt = sqlite3_column_double(stmt, 3)
                    let sortOrder = Int(sqlite3_column_int(stmt, 4))
                    result.append(Pinboard(id: id, name: name, color: color, createdAt: createdAt, sortOrder: sortOrder))
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    public func createPinboard(name: String, color: String) -> Pinboard {
        return queue.sync {
            let now = Date().timeIntervalSince1970 * 1000
            
            // Get max sort order
            var maxOrder: Int = 0
            var orderStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT MAX(sort_order) FROM pinboards;", -1, &orderStmt, nil) == SQLITE_OK {
                if sqlite3_step(orderStmt) == SQLITE_ROW && sqlite3_column_type(orderStmt, 0) != SQLITE_NULL {
                    maxOrder = Int(sqlite3_column_int(orderStmt, 0)) + 1
                }
            }
            sqlite3_finalize(orderStmt)
            
            let sql = "INSERT INTO pinboards (name, color, created_at, sort_order) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            var newId: Int64 = 0
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (color as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, now)
                sqlite3_bind_int(stmt, 4, Int32(maxOrder))
                if sqlite3_step(stmt) == SQLITE_DONE {
                    newId = sqlite3_last_insert_rowid(db)
                }
            }
            sqlite3_finalize(stmt)
            return Pinboard(id: newId, name: name, color: color, createdAt: now, sortOrder: maxOrder)
        }
    }
    
    public func updatePinboard(id: Int64, name: String, color: String) -> Pinboard? {
        return queue.sync {
            let sql = "UPDATE pinboards SET name = ?, color = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (color as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 3, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            
            let selectSQL = "SELECT id, name, color, created_at, sort_order FROM pinboards WHERE id = ?;"
            var selStmt: OpaquePointer?
            var res: Pinboard?
            if sqlite3_prepare_v2(db, selectSQL, -1, &selStmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(selStmt, 1, id)
                if sqlite3_step(selStmt) == SQLITE_ROW {
                    let pId = sqlite3_column_int64(selStmt, 0)
                    let pName = String(cString: sqlite3_column_text(selStmt, 1))
                    let pColor = String(cString: sqlite3_column_text(selStmt, 2))
                    let pCreated = sqlite3_column_double(selStmt, 3)
                    let pSort = Int(sqlite3_column_int(selStmt, 4))
                    res = Pinboard(id: pId, name: pName, color: pColor, createdAt: pCreated, sortOrder: pSort)
                }
            }
            sqlite3_finalize(selStmt)
            return res
        }
    }
    
    public func deletePinboard(id: Int64) {
        queue.sync {
            let sql = "DELETE FROM pinboards WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    public func reorderPinboards(orderedIds: [Int64]) {
        queue.sync {
            _ = executeSimple("BEGIN TRANSACTION;")
            let sql = "UPDATE pinboards SET sort_order = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                for (index, id) in orderedIds.enumerated() {
                    sqlite3_reset(stmt)
                    sqlite3_bind_int(stmt, 1, Int32(index))
                    sqlite3_bind_int64(stmt, 2, id)
                    sqlite3_step(stmt)
                }
            }
            sqlite3_finalize(stmt)
            _ = executeSimple("COMMIT;")
        }
    }
    
    public func addClipToPinboard(clipId: Int64, pinboardId: Int64?) {
        queue.sync {
            let sql = "UPDATE clips SET pinboard_id = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if let pId = pinboardId {
                    sqlite3_bind_int64(stmt, 1, pId)
                } else {
                    sqlite3_bind_null(stmt, 1)
                }
                sqlite3_bind_int64(stmt, 2, clipId)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    public func getClipsByPinboard(pinboardId: Int64?, limit: Int = 200) -> [ClipRecord] {
        return queue.sync {
            let sql: String
            if pinboardId == nil {
                sql = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips WHERE pinboard_id IS NULL ORDER BY pinned DESC, created_at DESC LIMIT ?;"
            } else {
                sql = "SELECT id, type, content, rtf, image_path, preview, hash, pinned, created_at, source_name, source_icon, pinboard_id, is_sensitive, sensitive_type, custom_rule_name, title FROM clips WHERE pinboard_id = ? ORDER BY pinned DESC, created_at DESC LIMIT ?;"
            }
            var stmt: OpaquePointer?
            var result: [ClipRecord] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt {
                if let pId = pinboardId {
                    sqlite3_bind_int64(stmt, 1, pId)
                    sqlite3_bind_int(stmt, 2, Int32(limit))
                } else {
                    sqlite3_bind_int(stmt, 1, Int32(limit))
                }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let clip = extractClip(from: stmt) {
                        result.append(clip)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    public func getPinboardCounts() -> [Int64: Int] {
        return queue.sync {
            let sql = "SELECT pinboard_id, COUNT(*) FROM clips WHERE pinboard_id IS NOT NULL GROUP BY pinboard_id;"
            var stmt: OpaquePointer?
            var counts: [Int64: Int] = [:]
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let pinboardId = sqlite3_column_int64(stmt, 0)
                    let count = Int(sqlite3_column_int(stmt, 1))
                    counts[pinboardId] = count
                }
            }
            sqlite3_finalize(stmt)
            return counts
        }
    }
    
    // MARK: - Settings Operations
    
    private func getSettingInternal(_ key: String) -> String? {
        let sql = "SELECT value FROM settings WHERE key = ?;"
        var stmt: OpaquePointer?
        var val: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    val = String(cString: ptr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return val
    }
    
    public func getSetting(_ key: String) -> String? {
        return queue.sync {
            getSettingInternal(key)
        }
    }
    
    public func setSetting(key: String, value: String) {
        queue.sync {
            let sql = "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        let currentSettings = getAllSettings()
        SensitiveDataService.shared.updateCachedSettings(currentSettings)
    }
    
    public func getAllSettings() -> [String: String] {
        return queue.sync {
            let sql = "SELECT key, value FROM settings;"
            var stmt: OpaquePointer?
            var dict: [String: String] = [:]
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let k = String(cString: sqlite3_column_text(stmt, 0))
                    let v = String(cString: sqlite3_column_text(stmt, 1))
                    dict[k] = v
                }
            }
            sqlite3_finalize(stmt)
            return dict
        }
    }
    
    // MARK: - Storage & Maintenance
    
    public func getStorageStats() -> StorageStats {
        return queue.sync {
            let fileManager = FileManager.default
            var dbSize: Int64 = 0
            if let attrs = try? fileManager.attributesOfItem(atPath: dbPath.path),
               let size = attrs[.size] as? Int64 {
                dbSize = size
            }
            
            var imagesSize: Int64 = 0
            if let files = try? fileManager.contentsOfDirectory(atPath: imagesDir.path) {
                for file in files {
                    let filePath = imagesDir.appendingPathComponent(file).path
                    if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                       let size = attrs[.size] as? Int64 {
                        imagesSize += size
                    }
                }
            }
            
            func countQuery(_ sql: String) -> Int {
                var s: OpaquePointer?
                var c = 0
                if sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK {
                    if sqlite3_step(s) == SQLITE_ROW {
                        c = Int(sqlite3_column_int(s, 0))
                    }
                }
                sqlite3_finalize(s)
                return c
            }
            
            let total = countQuery("SELECT COUNT(*) FROM clips;")
            let pinned = countQuery("SELECT COUNT(*) FROM clips WHERE pinned = 1;")
            let unpinned = countQuery("SELECT COUNT(*) FROM clips WHERE pinned = 0;")
            let textCount = countQuery("SELECT COUNT(*) FROM clips WHERE type = 'text';")
            let linkCount = countQuery("SELECT COUNT(*) FROM clips WHERE type = 'link';")
            let imageCount = countQuery("SELECT COUNT(*) FROM clips WHERE type = 'image';")
            let richCount = countQuery("SELECT COUNT(*) FROM clips WHERE type = 'richtext';")
            
            return StorageStats(
                totalClips: total,
                pinnedClips: pinned,
                unpinnedClips: unpinned,
                textClips: textCount,
                linkClips: linkCount,
                imageClips: imageCount,
                richTextClips: richCount,
                dbSizeBytes: dbSize,
                imagesSizeBytes: imagesSize,
                totalSizeBytes: dbSize + imagesSize
            )
        }
    }
    
    public func vacuumDatabase() -> StorageStats {
        queue.sync {
            _ = executeSimple("VACUUM;")
        }
        return getStorageStats()
    }
    
    public func cleanUnpinnedClips() -> StorageStats {
        clearAll()
        return getStorageStats()
    }
    
    public func purgeSensitiveClips(olderThanHours: Int) {
        guard olderThanHours > 0 else { return }
        queue.sync {
            let cutoff = (Date().timeIntervalSince1970 - Double(olderThanHours * 3600)) * 1000
            
            // Delete associated images & thumbnails & decrypted temp files for purged sensitive clips
            let selectImagesSQL = "SELECT image_path FROM clips WHERE pinned = 0 AND is_sensitive = 1 AND created_at < ? AND image_path IS NOT NULL;"
            var imgStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, selectImagesSQL, -1, &imgStmt, nil) == SQLITE_OK {
                sqlite3_bind_double(imgStmt, 1, cutoff)
                while sqlite3_step(imgStmt) == SQLITE_ROW {
                    if let pathPtr = sqlite3_column_text(imgStmt, 0) {
                        let path = String(cString: pathPtr)
                        try? FileManager.default.removeItem(atPath: path)
                        ThumbnailManager.shared.deleteThumbnail(for: path)
                    }
                }
            }
            sqlite3_finalize(imgStmt)
            
            let deleteSQL = "DELETE FROM clips WHERE pinned = 0 AND is_sensitive = 1 AND created_at < ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, cutoff)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            
            ThumbnailManager.shared.clearAllDecryptedTempFiles()
        }
    }
    
    // MARK: - Row Extraction Helper
    
    private func extractClip(from stmt: OpaquePointer) -> ClipRecord? {
        let id = sqlite3_column_int64(stmt, 0)
        guard let typePtr = sqlite3_column_text(stmt, 1),
              let hashPtr = sqlite3_column_text(stmt, 6) else {
            return nil
        }
        
        let typeRaw = String(cString: typePtr)
        let type = ClipType(rawValue: typeRaw) ?? .text
        let content = extractDecryptedString(from: stmt, column: 2)
        let preview = extractDecryptedString(from: stmt, column: 5)
        let hash = String(cString: hashPtr)
        let rtf = extractDecryptedOptionalString(from: stmt, column: 3)
        
        var imagePath: String?
        if sqlite3_column_type(stmt, 4) != SQLITE_NULL, let ptr = sqlite3_column_text(stmt, 4) {
            imagePath = String(cString: ptr)
        }
        
        let pinned = sqlite3_column_int(stmt, 7) == 1
        let createdAt = sqlite3_column_double(stmt, 8)
        
        var sourceName: String?
        if sqlite3_column_type(stmt, 9) != SQLITE_NULL, let ptr = sqlite3_column_text(stmt, 9) {
            sourceName = String(cString: ptr)
        }
        
        var sourceIcon: String?
        if sqlite3_column_type(stmt, 10) != SQLITE_NULL, let ptr = sqlite3_column_text(stmt, 10) {
            sourceIcon = String(cString: ptr)
        }
        
        var pinboardId: Int64?
        if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
            pinboardId = sqlite3_column_int64(stmt, 11)
        }
        
        let isSensitive = sqlite3_column_int(stmt, 12) == 1
        
        var sensitiveType: SensitiveDataType?
        if sqlite3_column_type(stmt, 13) != SQLITE_NULL, let ptr = sqlite3_column_text(stmt, 13) {
            sensitiveType = SensitiveDataType(rawValue: String(cString: ptr))
        }
        
        var customRuleName: String?
        if sqlite3_column_type(stmt, 14) != SQLITE_NULL, let ptr = sqlite3_column_text(stmt, 14) {
            customRuleName = String(cString: ptr)
        }
        
        var title: String?
        if sqlite3_column_type(stmt, 15) != SQLITE_NULL, let ptr = sqlite3_column_text(stmt, 15) {
            title = String(cString: ptr)
        }
        
        return ClipRecord(
            id: id,
            type: type,
            content: content,
            rtf: rtf,
            imagePath: imagePath,
            preview: preview,
            hash: hash,
            pinned: pinned,
            createdAt: createdAt,
            sourceName: sourceName,
            sourceIcon: sourceIcon,
            pinboardId: pinboardId,
            isSensitive: isSensitive,
            sensitiveType: sensitiveType,
            customRuleName: customRuleName,
            title: title
        )
    }
}
