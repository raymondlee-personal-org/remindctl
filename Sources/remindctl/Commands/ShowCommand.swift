import Commander
import Foundation
import RemindCore

enum ShowCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "show",
      abstract: "Show reminders",
      discussion: "Filters: today, tomorrow, week, overdue, upcoming, completed, all, or a date string.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(
              label: "filter",
              help: "today|tomorrow|week|overdue|upcoming|completed|all|<date>",
              isOptional: true
            )
          ],
          options: [
            .make(
              label: "list",
              names: [.short("l"), .long("list")],
              help: "Limit to a specific list",
              parsing: .singleValue
            ),
            .make(
              label: "section",
              names: [.long("section")],
              help: "Filter by section name",
              parsing: .singleValue
            ),
            .make(
              label: "assigned-to",
              names: [.long("assigned-to")],
              help: "Filter by assignee name",
              parsing: .singleValue
            ),
          ]
        )
      ),
      usageExamples: [
        "remindctl",
        "remindctl today",
        "remindctl show overdue",
        "remindctl show 2026-01-04",
        "remindctl show --list Work",
        "remindctl show --section \"In Progress\"",
        "remindctl show --assigned-to Raymond",
        "remindctl show all --list Work --section Design",
      ]
    ) { values, runtime in
      let listName = values.option("list")
      let filterToken = values.argument(0)
      let sectionFilter = values.option("section")
      let assignedToFilter = values.option("assigned-to")

      let filter: ReminderFilter
      if let token = filterToken {
        guard let parsed = ReminderFiltering.parse(token) else {
          throw RemindCoreError.operationFailed("Unknown filter: \"\(token)\"")
        }
        filter = parsed
      } else {
        filter = .today
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: listName)
      let filtered = ReminderFiltering.apply(reminders, filter: filter)

      // Enrich with SQLite data (sections + assignments)
      let enriched = SQLiteEnricher.enrich(filtered)

      // Apply section filter
      var result = enriched
      if let sectionFilter {
        let lowered = sectionFilter.lowercased()
        result = result.filter { $0.sectionName?.lowercased() == lowered }
      }

      // Apply assigned-to filter
      if let assignedToFilter {
        let lowered = assignedToFilter.lowercased()
        result = result.filter {
          $0.assigneeName?.lowercased().contains(lowered) == true
        }
      }

      OutputRenderer.printReminders(result, format: runtime.outputFormat)
    }
  }
}
