import Foundation

/// An error that names a message under `errors` instead of carrying text, so the app shows it in the reader's
/// language (as AppError does in src/core/appError.ts). `values` fill `{name}` placeholders in the message.
public struct TypleError: Error, Equatable, Sendable {
  public let key: String
  public let values: [String: String]

  public init(_ key: String, _ values: [String: String] = [:]) {
    self.key = key
    self.values = values
  }
}

public struct Word: Codable, Hashable, Sendable {
  public var display: String
  public var input: String
  public var annotation: String
  /// command, code or word (v0.108.0), kept as saved and left out when the word has none.
  public var inputType: String?

  public init(display: String, input: String, annotation: String = "", inputType: String? = nil) {
    self.display = display
    self.input = input
    self.annotation = annotation
    self.inputType = inputType
  }

  private enum CodingKeys: String, CodingKey {
    case display, input, annotation
    case inputType = "input_type"
  }
}

public struct PracticeDevice: Codable, Hashable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var layout: String

  public init(id: String, name: String, layout: String = "") {
    self.id = id
    self.name = name
    self.layout = layout
  }
}

/// A practice record as stored. Records from older versions may lack every field but `time` and `date`.
public struct StoredRecord: Codable, Hashable, Sendable {
  public var id: String?
  public var time: Double
  public var date: String
  public var mistakes: Int?
  public var accuracy: Double?
  public var device: PracticeDevice?
  public var wordCount: Int?

  public init(id: String? = nil, time: Double, date: String, mistakes: Int? = nil, accuracy: Double? = nil,
              device: PracticeDevice? = nil, wordCount: Int? = nil) {
    self.id = id
    self.time = time
    self.date = date
    self.mistakes = mistakes
    self.accuracy = accuracy
    self.device = device
    self.wordCount = wordCount
  }
}

public struct WordList: Codable, Hashable, Identifiable, Sendable {
  public var id: String
  public var name: String
  /// A broad grouping, such as プログラミング, and what the list is about, such as Kotlin (v0.78.0). Both are left out
  /// of the stored list when it has none, as the web app saves them.
  public var category: String?
  public var tags: [String]?
  /// Lists with the same group, such as Linuxコマンド, are one choice in the web app, which then asks for their levels,
  /// such as 基本 then 初級 (v0.79.0). Kept as saved; a copy leaves them out.
  public var group: String?
  public var levels: [String]?
  public var words: [Word]
  public var records: [StoredRecord]
  public var createdAt: String
  /// The word pack of an account's list (v0.91.0); nil for the lists of this device and of accounts saved before packs.
  public var packId: String?
  /// Set on the lists of a followed official pack: the official list it is kept equal to (src/core/followedPacks.ts).
  public var origin: ListOrigin?

  public init(id: String, name: String, words: [Word], records: [StoredRecord] = [], createdAt: String,
              category: String? = nil, tags: [String]? = nil, group: String? = nil, levels: [String]? = nil,
              packId: String? = nil, origin: ListOrigin? = nil) {
    self.id = id
    self.name = name
    self.category = category
    self.tags = tags
    self.group = group
    self.levels = levels
    self.words = words
    self.records = records
    self.createdAt = createdAt
    self.packId = packId
    self.origin = origin
  }

  /// A list of a followed official pack, which only the catalog changes (the web app refuses to edit it).
  public var isFollowed: Bool { origin != nil }
}

public struct ListOrigin: Codable, Hashable, Sendable {
  public var listId: String

  public init(listId: String) {
    self.listId = listId
  }
}

public struct WorkspaceDocument: Equatable, Sendable {
  public var lists: [WordList]
  public var devices: [PracticeDevice]
  /// The account's word packs as saved (see Packs.swift), or nil when it has none: this device, and accounts whose
  /// lists were saved before packs existed.
  public var packs: [WordPack]?

  public init(lists: [WordList], devices: [PracticeDevice], packs: [WordPack]? = nil) {
    self.lists = lists
    self.devices = devices
    self.packs = packs
  }
}

/// A new random id in the form of `crypto.randomUUID`, as the web app gives records and lists.
public func randomId() -> String {
  UUID().uuidString.lowercased()
}

extension String {
  /// JavaScript's `trim`.
  var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
  /// JavaScript's `length`, which counts UTF-16 code units.
  var jsLength: Int { utf16.count }
  /// JavaScript's `Array.from`, which splits a string into code points.
  var codePoints: [Unicode.Scalar] { Array(unicodeScalars) }
}

extension Sequence {
  /// Array.prototype.sort is stable; this keeps equal elements in their original order as it does.
  func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
    enumerated().sorted { a, b in
      if areInIncreasingOrder(a.element, b.element) { return true }
      if areInIncreasingOrder(b.element, a.element) { return false }
      return a.offset < b.offset
    }.map(\.element)
  }
}
