import Foundation
import RemindCore

enum SQLiteEnricher {
  /// Enrich ReminderItems with section and assignee names from the Reminders SQLite database.
  /// Fails silently — returns original items if the DB can't be read.
  static func enrich(_ reminders: [ReminderItem]) -> [ReminderItem] {
    guard !reminders.isEmpty else { return reminders }

    let sectionMap: [String: String]
    let assigneeMap: [String: String]

    do {
      let sqliteStore = try RemindersSQLiteStore()
      sectionMap = (try? sqliteStore.sectionNamesByReminderID()) ?? [:]
      assigneeMap = (try? sqliteStore.assigneeNamesByReminderID()) ?? [:]
    } catch {
      return reminders
    }

    guard !sectionMap.isEmpty || !assigneeMap.isEmpty else { return reminders }

    return reminders.map { reminder in
      let section = sectionMap[reminder.id]
      let assignee = assigneeMap[reminder.id]
      guard section != nil || assignee != nil else { return reminder }

      return ReminderItem(
        id: reminder.id,
        title: reminder.title,
        notes: reminder.notes,
        isCompleted: reminder.isCompleted,
        completionDate: reminder.completionDate,
        priority: reminder.priority,
        dueDate: reminder.dueDate,
        listID: reminder.listID,
        listName: reminder.listName,
        creationDate: reminder.creationDate,
        recurrenceRule: reminder.recurrenceRule,
        alarmDate: reminder.alarmDate,
        parentID: reminder.parentID,
        tags: reminder.tags,
        url: reminder.url,
        sectionName: section ?? reminder.sectionName,
        assigneeName: assignee ?? reminder.assigneeName
      )
    }
  }
}
