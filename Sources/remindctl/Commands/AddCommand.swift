import Commander
import Foundation
import RemindCore

enum AddCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "add",
      abstract: "Add a reminder",
      discussion: "Provide a title as an argument or via --title.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "title", help: "Reminder title", isOptional: true)
          ],
          options: [
            .make(label: "title", names: [.long("title")], help: "Reminder title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "List name", parsing: .singleValue),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Due date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Notes", parsing: .singleValue),
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
              label: "parent",
              names: [.long("parent")],
              help: "Parent reminder ID",
              parsing: .singleValue
            ),
            .make(
              label: "tags",
              names: [.long("tags")],
              help: "Comma-separated tags",
              parsing: .singleValue
            ),
            .make(
              label: "assign",
              names: [.long("assign")],
              help: "Assign to person (prepends @Name: to title)",
              parsing: .singleValue
            ),
          ]
        )
      ),
      usageExamples: [
        "remindctl add \"Buy milk\"",
        "remindctl add --title \"Call mom\" --list Personal --due tomorrow",
        "remindctl add \"Review docs\" --priority high",
      ]
    ) { values, runtime in
      let titleOption = values.option("title")
      let titleArg = values.argument(0)
      if titleOption != nil && titleArg != nil {
        throw RemindCoreError.operationFailed("Provide title either as argument or via --title")
      }

      var title = titleOption ?? titleArg
      if title == nil {
        if runtime.noInput || !Console.isTTY {
          throw RemindCoreError.operationFailed("Missing title. Provide it as an argument or via --title.")
        }
        title = Console.readLine(prompt: "Title:")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if title?.isEmpty == true { title = nil }
      }

      guard var title else {
        throw RemindCoreError.operationFailed("Missing title.")
      }

      if let assignee = values.option("assign") {
        title = "@\(assignee): \(title)"
      }

      let listName = values.option("list")
      let notes = values.option("notes")
      let dueValue = values.option("due")
      let priorityValue = values.option("priority")

      let dueDate = try dueValue.map(CommandHelpers.parseDueDate)
      let priority = try priorityValue.map(CommandHelpers.parsePriority) ?? .none

      let repeatValue = values.option("repeat")
      let alarmValue = values.option("alarm")
      let urlValue = values.option("url")
      let parentValue = values.option("parent")
      let tagsValue = values.option("tags")

      let recurrenceRule = try repeatValue.map(CommandHelpers.parseRecurrence)
      let alarmDate = try alarmValue.map(CommandHelpers.parseDueDate)
      let tags = tagsValue.map { $0.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } } ?? []

      let store = RemindersStore()
      try await store.requestAccess()

      let targetList: String?
      if let listName {
        targetList = listName
      } else {
        targetList = await store.defaultListName()
      }
      guard let targetList else {
        throw RemindCoreError.operationFailed("No default list found. Specify --list.")
      }

      let draft = ReminderDraft(
        title: title,
        notes: notes,
        dueDate: dueDate,
        priority: priority,
        recurrenceRule: recurrenceRule,
        alarmDate: alarmDate,
        url: urlValue,
        parentID: parentValue,
        tags: tags
      )
      let reminder = try await store.createReminder(draft, listName: targetList)
      OutputRenderer.printReminder(reminder, format: runtime.outputFormat)
    }
  }
}
