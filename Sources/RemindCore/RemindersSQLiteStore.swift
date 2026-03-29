import Foundation

#if canImport(SQLite3)
  import SQLite3
#endif

// MARK: - Models

public struct ReminderSection: Codable, Sendable, Equatable {
  public let ckIdentifier: String
  public let displayName: String
  public let listPK: Int64

  public init(ckIdentifier: String, displayName: String, listPK: Int64) {
    self.ckIdentifier = ckIdentifier
    self.displayName = displayName
    self.listPK = listPK
  }
}

public struct SectionMembership: Sendable, Equatable {
  public let groupID: String  // section ZCKIDENTIFIER
  public let memberID: String  // reminder ZDACALENDARITEMUNIQUEIDENTIFIER

  public init(groupID: String, memberID: String) {
    self.groupID = groupID
    self.memberID = memberID
  }
}

public struct ReminderSharee: Codable, Sendable, Equatable {
  public let pk: Int64
  public let ckIdentifier: String
  public let displayName: String?

  public init(pk: Int64, ckIdentifier: String, displayName: String?) {
    self.pk = pk
    self.ckIdentifier = ckIdentifier
    self.displayName = displayName
  }
}

public struct ReminderAssignment: Codable, Sendable, Equatable {
  public let reminderPK: Int64
  public let assigneePK: Int64
  public let ckAssigneeIdentifier: String
  public let assignedDate: Date?

  public init(reminderPK: Int64, assigneePK: Int64, ckAssigneeIdentifier: String, assignedDate: Date?) {
    self.reminderPK = reminderPK
    self.assigneePK = assigneePK
    self.ckAssigneeIdentifier = ckAssigneeIdentifier
    self.assignedDate = assignedDate
  }
}

// MARK: - SQLite Store

public final class RemindersSQLiteStore: @unchecked Sendable {
  /// Core Data epoch: 2001-01-01 00:00:00 UTC
  private static let coreDataEpoch: Date = {
    var components = DateComponents()
    components.year = 2001
    components.month = 1
    components.day = 1
    components.hour = 0
    components.minute = 0
    components.second = 0
    components.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: components)!
  }()

  private let dbPath: String

  public init() throws {
    self.dbPath = try Self.findDatabase()
  }

  public init(path: String) {
    self.dbPath = path
  }

  // MARK: - Database Discovery

  private static func findDatabase() throws -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let containerDir =
      "\(home)/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores"

    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(atPath: containerDir) else {
      throw RemindCoreError.operationFailed(
        "Reminders database directory not found at \(containerDir)")
    }

    let sqliteFiles = entries.filter { $0.hasPrefix("Data-") && $0.hasSuffix(".sqlite") }
    guard !sqliteFiles.isEmpty else {
      throw RemindCoreError.operationFailed("No Reminders SQLite database found in \(containerDir)")
    }

    // Find the DB with actual reminder rows
    for file in sqliteFiles {
      let path = "\(containerDir)/\(file)"
      var db: OpaquePointer?
      guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { continue }
      defer { sqlite3_close(db) }

      var stmt: OpaquePointer?
      let sql = "SELECT COUNT(*) FROM ZREMCDREMINDER"
      guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
      defer { sqlite3_finalize(stmt) }

      if sqlite3_step(stmt) == SQLITE_ROW {
        let count = sqlite3_column_int64(stmt, 0)
        if count > 0 {
          return path
        }
      }
    }

    // Fallback: use the first one
    return "\(containerDir)/\(sqliteFiles[0])"
  }

  // MARK: - Connection Helper

  private func openDB(readOnly: Bool = true) throws -> OpaquePointer {
    var db: OpaquePointer?
    let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
    let rc = sqlite3_open_v2(dbPath, &db, flags, nil)
    guard rc == SQLITE_OK, let db else {
      let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
      if let db { sqlite3_close(db) }
      throw RemindCoreError.operationFailed("Failed to open Reminders DB: \(msg)")
    }
    return db
  }

  // MARK: - Core Data Timestamp Conversion

  private static func dateFromCoreData(_ timestamp: Double) -> Date {
    coreDataEpoch.addingTimeInterval(timestamp)
  }

  private static func coreDataTimestamp(from date: Date) -> Double {
    date.timeIntervalSince(coreDataEpoch)
  }

  // MARK: - Read Sections

  public func sections() throws -> [ReminderSection] {
    let db = try openDB()
    defer { sqlite3_close(db) }

    let sql = """
      SELECT ZCKIDENTIFIER, ZDISPLAYNAME, ZLIST
      FROM ZREMCDBASESECTION
      WHERE ZDISPLAYNAME IS NOT NULL
      """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to query sections: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    var results: [ReminderSection] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let ckID = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
      let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
      let listPK = sqlite3_column_int64(stmt, 2)
      results.append(ReminderSection(ckIdentifier: ckID, displayName: name, listPK: listPK))
    }

    return results
  }

  // MARK: - Read Section Memberships

  public func sectionMemberships() throws -> [SectionMembership] {
    let db = try openDB()
    defer { sqlite3_close(db) }

    let sql = """
      SELECT ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA
      FROM ZREMCDBASELIST
      WHERE ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA IS NOT NULL
      """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to query memberships: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    var results: [SectionMembership] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      guard let blob = sqlite3_column_blob(stmt, 0) else { continue }
      let length = sqlite3_column_bytes(stmt, 0)
      let data = Data(bytes: blob, count: Int(length))

      guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let memberships = parsed["memberships"] as? [[String: Any]]
      else { continue }

      for membership in memberships {
        guard let groupID = membership["groupID"] as? String,
          let memberID = membership["memberID"] as? String
        else { continue }
        results.append(SectionMembership(groupID: groupID, memberID: memberID))
      }
    }

    return results
  }

  // MARK: - Read Assignments (Z_ENT = 21)

  public func assignments() throws -> [ReminderAssignment] {
    let db = try openDB()
    defer { sqlite3_close(db) }

    let sql = """
      SELECT ZREMINDER2, ZASSIGNEE, ZCKASSIGNEEIDENTIFIER, ZASSIGNEDDATE
      FROM ZREMCDOBJECT
      WHERE Z_ENT = 21
      """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to query assignments: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    var results: [ReminderAssignment] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let reminderPK = sqlite3_column_int64(stmt, 0)
      let assigneePK = sqlite3_column_int64(stmt, 1)
      let ckAssignee = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
      let assignedDate: Date?
      if sqlite3_column_type(stmt, 3) != SQLITE_NULL {
        assignedDate = Self.dateFromCoreData(sqlite3_column_double(stmt, 3))
      } else {
        assignedDate = nil
      }
      results.append(
        ReminderAssignment(
          reminderPK: reminderPK, assigneePK: assigneePK,
          ckAssigneeIdentifier: ckAssignee, assignedDate: assignedDate))
    }

    return results
  }

  // MARK: - Read Sharees (Z_ENT = 36)

  public func sharees() throws -> [ReminderSharee] {
    let db = try openDB()
    defer { sqlite3_close(db) }

    // Try known columns — the schema may vary across macOS versions.
    // We need Z_PK and some identifier; display name may be ZNAME, ZDISPLAYNAME, or ZFULLNAME.
    let sql = """
      SELECT Z_PK, ZCKIDENTIFIER,
             COALESCE(ZNAME, ZDISPLAYNAME, ZFULLNAME, NULL)
      FROM ZREMCDOBJECT
      WHERE Z_ENT = 36
      """

    var stmt: OpaquePointer?
    // If the COALESCE columns don't exist, fall back to just PK + CKIDENTIFIER
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    if rc != SQLITE_OK {
      sqlite3_finalize(stmt)
      return try shareesMinimal(db: db)
    }
    defer { sqlite3_finalize(stmt) }

    var results: [ReminderSharee] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let pk = sqlite3_column_int64(stmt, 0)
      let ckID = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
      let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
      results.append(ReminderSharee(pk: pk, ckIdentifier: ckID, displayName: name))
    }

    return results
  }

  private func shareesMinimal(db: OpaquePointer) throws -> [ReminderSharee] {
    let sql = """
      SELECT Z_PK, ZCKIDENTIFIER
      FROM ZREMCDOBJECT
      WHERE Z_ENT = 36
      """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to query sharees: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    var results: [ReminderSharee] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let pk = sqlite3_column_int64(stmt, 0)
      let ckID = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
      results.append(ReminderSharee(pk: pk, ckIdentifier: ckID, displayName: nil))
    }

    return results
  }

  // MARK: - Lookup Helpers

  /// Get the Z_PK of a reminder by its EventKit calendarItemIdentifier (ZDACALENDARITEMUNIQUEIDENTIFIER)
  public func reminderPK(forCalendarItemID id: String) throws -> Int64? {
    let db = try openDB()
    defer { sqlite3_close(db) }

    let sql = "SELECT Z_PK FROM ZREMCDREMINDER WHERE ZDACALENDARITEMUNIQUEIDENTIFIER = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to query reminder PK: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
    if sqlite3_step(stmt) == SQLITE_ROW {
      return sqlite3_column_int64(stmt, 0)
    }
    return nil
  }

  /// Find a sharee by name (case-insensitive match on display name or CK identifier)
  public func findSharee(matching name: String) throws -> ReminderSharee? {
    let allSharees = try sharees()
    let lowered = name.lowercased()

    // Try display name first
    if let match = allSharees.first(where: {
      $0.displayName?.lowercased() == lowered
    }) {
      return match
    }

    // Try partial display name match
    if let match = allSharees.first(where: {
      $0.displayName?.lowercased().contains(lowered) == true
    }) {
      return match
    }

    // Try CK identifier
    if let match = allSharees.first(where: {
      $0.ckIdentifier.lowercased().contains(lowered)
    }) {
      return match
    }

    return nil
  }

  // MARK: - Write Assignment

  /// Insert an assignment row into ZREMCDOBJECT with Z_ENT=21
  public func writeAssignment(
    reminderPK: Int64, shareePK: Int64, shareeCKIdentifier: String
  ) throws {
    let db = try openDB(readOnly: false)
    defer { sqlite3_close(db) }

    let now = Self.coreDataTimestamp(from: Date())

    // Get the next Z_PK from Z_PRIMARYKEY table
    let nextPK = try nextPrimaryKey(db: db, entityID: 21)

    let sql = """
      INSERT INTO ZREMCDOBJECT (
        Z_PK, Z_ENT, Z_OPT, ZACCOUNT,
        ZASSIGNEE, ZREMINDER2,
        ZCKASSIGNEEIDENTIFIER, ZASSIGNEDDATE,
        ZCKDIRTYFLAGS
      ) VALUES (?, 21, 1, 1, ?, ?, ?, ?, 1)
      """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to prepare assignment insert: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_int64(stmt, 1, nextPK)
    sqlite3_bind_int64(stmt, 2, shareePK)
    sqlite3_bind_int64(stmt, 3, reminderPK)
    sqlite3_bind_text(stmt, 4, (shareeCKIdentifier as NSString).utf8String, -1, nil)
    sqlite3_bind_double(stmt, 5, now)

    guard sqlite3_step(stmt) == SQLITE_DONE else {
      throw RemindCoreError.operationFailed(
        "Failed to insert assignment: \(String(cString: sqlite3_errmsg(db)))")
    }

    // Update the Z_PRIMARYKEY counter
    try updatePrimaryKeyCounter(db: db, entityID: 21, newMax: nextPK)

    // Also mark the reminder itself as dirty so CloudKit syncs
    try markReminderDirty(db: db, reminderPK: reminderPK)
  }

  private func nextPrimaryKey(db: OpaquePointer, entityID: Int64) throws -> Int64 {
    let sql = "SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_ENT = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to query primary key: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_int64(stmt, 1, entityID)
    if sqlite3_step(stmt) == SQLITE_ROW {
      return sqlite3_column_int64(stmt, 0) + 1
    }

    // If no row exists, find max Z_PK from ZREMCDOBJECT
    return try maxPKFromTable(db: db) + 1
  }

  private func maxPKFromTable(db: OpaquePointer) throws -> Int64 {
    let sql = "SELECT MAX(Z_PK) FROM ZREMCDOBJECT"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      return 0
    }
    defer { sqlite3_finalize(stmt) }
    if sqlite3_step(stmt) == SQLITE_ROW {
      return sqlite3_column_int64(stmt, 0)
    }
    return 0
  }

  private func updatePrimaryKeyCounter(db: OpaquePointer, entityID: Int64, newMax: Int64) throws {
    let sql = "UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_ENT = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      throw RemindCoreError.operationFailed(
        "Failed to update primary key: \(String(cString: sqlite3_errmsg(db)))")
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_int64(stmt, 1, newMax)
    sqlite3_bind_int64(stmt, 2, entityID)
    sqlite3_step(stmt)
  }

  private func markReminderDirty(db: OpaquePointer, reminderPK: Int64) throws {
    let sql = "UPDATE ZREMCDREMINDER SET ZCKDIRTYFLAGS = (ZCKDIRTYFLAGS | 1) WHERE Z_PK = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int64(stmt, 1, reminderPK)
    sqlite3_step(stmt)
  }

  // MARK: - Enrichment

  /// Build a lookup: reminderID (calendarItemIdentifier) → section display name
  public func sectionNamesByReminderID() throws -> [String: String] {
    let allSections = try sections()
    let memberships = try sectionMemberships()

    // Build section CK ID → display name map
    let sectionNameMap = Dictionary(
      allSections.map { ($0.ckIdentifier, $0.displayName) },
      uniquingKeysWith: { first, _ in first })

    var result: [String: String] = [:]
    for m in memberships {
      if let name = sectionNameMap[m.groupID] {
        result[m.memberID] = name
      }
    }
    return result
  }

  /// Build a lookup: reminderID (calendarItemIdentifier) → assignee display name
  public func assigneeNamesByReminderID() throws -> [String: String] {
    let db = try openDB()
    defer { sqlite3_close(db) }

    // Join assignments with sharees and reminders to get displayable names
    // Assignment: Z_ENT=21, ZREMINDER2=reminder Z_PK, ZASSIGNEE=sharee Z_PK
    // We need reminder's ZDACALENDARITEMUNIQUEIDENTIFIER and sharee's display name

    let allSharees = try sharees()
    let shareePKToName = Dictionary(
      allSharees.map { ($0.pk, $0.displayName ?? $0.ckIdentifier) },
      uniquingKeysWith: { first, _ in first })

    // Get assignments with reminder calendar IDs
    let sql = """
      SELECT a.ZASSIGNEE, a.ZREMINDER2, a.ZCKASSIGNEEIDENTIFIER, r.ZDACALENDARITEMUNIQUEIDENTIFIER
      FROM ZREMCDOBJECT a
      JOIN ZREMCDREMINDER r ON r.Z_PK = a.ZREMINDER2
      WHERE a.Z_ENT = 21
      """

    var stmt: OpaquePointer?
    // Re-open for this compound query
    let db2 = try openDB()
    defer { sqlite3_close(db2) }

    guard sqlite3_prepare_v2(db2, sql, -1, &stmt, nil) == SQLITE_OK else {
      // If the join fails (schema mismatch), return empty
      return [:]
    }
    defer { sqlite3_finalize(stmt) }

    var result: [String: String] = [:]
    while sqlite3_step(stmt) == SQLITE_ROW {
      let assigneePK = sqlite3_column_int64(stmt, 0)
      let reminderCalID = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
      if !reminderCalID.isEmpty {
        let name = shareePKToName[assigneePK]
          ?? (sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "")
        if !name.isEmpty {
          result[reminderCalID] = name
        }
      }
    }

    return result
  }

  // MARK: - Trigger Sync

  /// Open Reminders.app briefly to trigger CloudKit sync
  public static func triggerSync() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", "Reminders"]
    try? process.run()
  }
}
