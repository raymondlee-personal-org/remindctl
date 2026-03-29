import Foundation

public enum ReminderPriority: String, Codable, CaseIterable, Sendable {
  case none
  case low
  case medium
  case high

  public init(eventKitValue: Int) {
    switch eventKitValue {
    case 1...4:
      self = .high
    case 5:
      self = .medium
    case 6...9:
      self = .low
    default:
      self = .none
    }
  }

  public var eventKitValue: Int {
    switch self {
    case .none:
      return 0
    case .high:
      return 1
    case .medium:
      return 5
    case .low:
      return 9
    }
  }
}

public struct ReminderList: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
  case daily
  case weekly
  case monthly
  case yearly
}

public struct RecurrenceRule: Codable, Sendable, Equatable {
  public let frequency: RecurrenceFrequency
  public let interval: Int

  public init(frequency: RecurrenceFrequency, interval: Int = 1) {
    self.frequency = frequency
    self.interval = interval
  }
}

public struct ReminderItem: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let notes: String?
  public let isCompleted: Bool
  public let completionDate: Date?
  public let priority: ReminderPriority
  public let dueDate: Date?
  public let listID: String
  public let listName: String
  public let creationDate: Date?
  public let recurrenceRule: RecurrenceRule?
  public let alarmDate: Date?
  public let parentID: String?
  public let tags: [String]
  public let url: String?
  public let sectionName: String?
  public let assigneeName: String?

  public init(
    id: String,
    title: String,
    notes: String?,
    isCompleted: Bool,
    completionDate: Date?,
    priority: ReminderPriority,
    dueDate: Date?,
    listID: String,
    listName: String,
    creationDate: Date? = nil,
    recurrenceRule: RecurrenceRule? = nil,
    alarmDate: Date? = nil,
    parentID: String? = nil,
    tags: [String] = [],
    url: String? = nil,
    sectionName: String? = nil,
    assigneeName: String? = nil
  ) {
    self.id = id
    self.title = title
    self.notes = notes
    self.isCompleted = isCompleted
    self.completionDate = completionDate
    self.priority = priority
    self.dueDate = dueDate
    self.listID = listID
    self.listName = listName
    self.creationDate = creationDate
    self.recurrenceRule = recurrenceRule
    self.alarmDate = alarmDate
    self.parentID = parentID
    self.tags = tags
    self.url = url
    self.sectionName = sectionName
    self.assigneeName = assigneeName
  }
}

public struct ReminderDraft: Sendable {
  public let title: String
  public let notes: String?
  public let dueDate: Date?
  public let priority: ReminderPriority
  public let recurrenceRule: RecurrenceRule?
  public let alarmDate: Date?
  public let url: String?
  public let parentID: String?
  public let tags: [String]

  public init(
    title: String,
    notes: String?,
    dueDate: Date?,
    priority: ReminderPriority,
    recurrenceRule: RecurrenceRule? = nil,
    alarmDate: Date? = nil,
    url: String? = nil,
    parentID: String? = nil,
    tags: [String] = []
  ) {
    self.title = title
    self.notes = notes
    self.dueDate = dueDate
    self.priority = priority
    self.recurrenceRule = recurrenceRule
    self.alarmDate = alarmDate
    self.url = url
    self.parentID = parentID
    self.tags = tags
  }
}

public struct ReminderUpdate: Sendable {
  public let title: String?
  public let notes: String?
  public let dueDate: Date??
  public let priority: ReminderPriority?
  public let listName: String?
  public let isCompleted: Bool?
  public let recurrenceRule: RecurrenceRule??
  public let alarmDate: Date??
  public let url: String??
  public let tags: [String]?

  public init(
    title: String? = nil,
    notes: String? = nil,
    dueDate: Date?? = nil,
    priority: ReminderPriority? = nil,
    listName: String? = nil,
    isCompleted: Bool? = nil,
    recurrenceRule: RecurrenceRule?? = nil,
    alarmDate: Date?? = nil,
    url: String?? = nil,
    tags: [String]? = nil
  ) {
    self.title = title
    self.notes = notes
    self.dueDate = dueDate
    self.priority = priority
    self.listName = listName
    self.isCompleted = isCompleted
    self.recurrenceRule = recurrenceRule
    self.alarmDate = alarmDate
    self.url = url
    self.tags = tags
  }
}
