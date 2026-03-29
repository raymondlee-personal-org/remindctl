import Commander
import Foundation
import RemindCore

enum EditCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "edit",
      abstract: "Edit a reminder",
      discussion: "Use an index or ID prefix from the show output.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "id", help: "Index or ID prefix", isOptional: false)
          ],
          options: [
            .make(label: "title", names: [.short("t"), .long("title")], help: "New title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "Move to list", parsing: .singleValue),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Set due date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Set notes", parsing: .singleValue),
            .make(
              label: "priority",
              names: [.short("p"), .long("priority")],
              help: "none|low|medium|high",
              parsing: .singleValue
            ),
            .make(
              label: "repeat",
              names: [.long("repeat")],
              help: "daily|weekly|monthly|yearly",
              parsing: .singleValue
            ),
            .make(
              label: "alarm",
              names: [.long("alarm")],
              help: "Alarm date/time",
              parsing: .singleValue
            ),
            .make(
              label: "url",
              names: [.long("url")],
              help: "URL to attach",
              parsing: .singleValue
            ),
            .make(
              label: "tags",
              names: [.long("tags")],
              help: "Comma-separated tags",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "clearDue", names: [.long("clear-due")], help: "Clear due date"),
            .make(label: "clearAlarm", names: [.long("clear-alarm")], help: "Clear alarm"),
            .make(label: "clearRepeat", names: [.long("clear-repeat")], help: "Clear recurrence"),
            .make(label: "clearUrl", names: [.long("clear-url")], help: "Clear URL"),
            .make(label: "complete", names: [.long("complete")], help: "Mark completed"),
            .make(label: "incomplete", names: [.long("incomplete")], help: "Mark incomplete"),
          ]
        )
      ),
      usageExamples: [
        "remindctl edit 1 --title \"New title\"",
        "remindctl edit 4A83 --due tomorrow",
        "remindctl edit 2 --priority high --notes \"Call before noon\"",
        "remindctl edit 3 --clear-due",
      ]
    ) { values, runtime in
      guard let input = values.argument(0) else {
        throw ParsedValuesError.missingArgument("id")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try IDResolver.resolve([input], from: reminders)
      guard let reminder = resolved.first else {
        throw RemindCoreError.reminderNotFound(input)
      }

      let title = values.option("title")
      let listName = values.option("list")
      let notes = values.option("notes")

      var dueUpdate: Date??
      if let dueValue = values.option("due") {
        dueUpdate = try CommandHelpers.parseDueDate(dueValue)
      }
      if values.flag("clearDue") {
        if dueUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --due or --clear-due, not both")
        }
        dueUpdate = .some(nil)
      }

      var priority: ReminderPriority?
      if let priorityValue = values.option("priority") {
        priority = try CommandHelpers.parsePriority(priorityValue)
      }

      var recurrenceUpdate: RecurrenceRule??
      if let repeatValue = values.option("repeat") {
        recurrenceUpdate = try CommandHelpers.parseRecurrence(repeatValue)
      }
      if values.flag("clearRepeat") {
        if recurrenceUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --repeat or --clear-repeat, not both")
        }
        recurrenceUpdate = .some(nil)
      }

      var alarmUpdate: Date??
      if let alarmValue = values.option("alarm") {
        alarmUpdate = try CommandHelpers.parseDueDate(alarmValue)
      }
      if values.flag("clearAlarm") {
        if alarmUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --alarm or --clear-alarm, not both")
        }
        alarmUpdate = .some(nil)
      }

      var urlUpdate: String??
      if let urlValue = values.option("url") {
        urlUpdate = .some(urlValue)
      }
      if values.flag("clearUrl") {
        if urlUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --url or --clear-url, not both")
        }
        urlUpdate = .some(nil)
      }

      let tagsValue = values.option("tags")
      let tags: [String]? = tagsValue.map { $0.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } }

      let completeFlag = values.flag("complete")
      let incompleteFlag = values.flag("incomplete")
      if completeFlag && incompleteFlag {
        throw RemindCoreError.operationFailed("Use either --complete or --incomplete, not both")
      }
      let isCompleted: Bool? = completeFlag ? true : (incompleteFlag ? false : nil)

      if title == nil && listName == nil && notes == nil && dueUpdate == nil && priority == nil
        && isCompleted == nil && recurrenceUpdate == nil && alarmUpdate == nil && urlUpdate == nil && tags == nil
      {
        throw RemindCoreError.operationFailed("No changes specified")
      }

      let update = ReminderUpdate(
        title: title,
        notes: notes,
        dueDate: dueUpdate,
        priority: priority,
        listName: listName,
        isCompleted: isCompleted,
        recurrenceRule: recurrenceUpdate,
        alarmDate: alarmUpdate,
        url: urlUpdate,
        tags: tags
      )

      let updated = try await store.updateReminder(id: reminder.id, update: update)
      OutputRenderer.printReminder(updated, format: runtime.outputFormat)
    }
  }
}
