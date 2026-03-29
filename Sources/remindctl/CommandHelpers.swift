import Foundation
import RemindCore

enum CommandHelpers {
  static func parsePriority(_ value: String) throws -> ReminderPriority {
    switch value.lowercased() {
    case "none":
      return .none
    case "low":
      return .low
    case "medium", "med":
      return .medium
    case "high":
      return .high
    default:
      throw RemindCoreError.operationFailed("Invalid priority: \"\(value)\" (use none|low|medium|high)")
    }
  }

  static func parseDueDate(_ value: String) throws -> Date {
    guard let date = DateParsing.parseUserDate(value) else {
      throw RemindCoreError.invalidDate(value)
    }
    return date
  }

  static func parseRecurrence(_ value: String) throws -> RecurrenceRule {
    guard let freq = RecurrenceFrequency(rawValue: value.lowercased()) else {
      throw RemindCoreError.operationFailed(
        "Invalid recurrence: \"\(value)\" (use daily|weekly|monthly|yearly)"
      )
    }
    return RecurrenceRule(frequency: freq)
  }
}
