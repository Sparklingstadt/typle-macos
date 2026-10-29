import Foundation

// Word packs (src/core/wordPacks.ts) and the official packs an account follows (src/core/followedPacks.ts and
// server/internal/workspace/follow.go in typle-r). The app shows an account's lists, not its packs: it keeps the packs
// as they were read, so that a save does not change them, puts back the words of the followed packs' lists from the
// catalog, and saves those lists without their words, as the web app does since typle-r v2.1.0.

public let maxPackName = 200

/// Any JSON value, so that a pack is saved with every field it was read with, those Typle does not know included.
public enum JSONValue: Codable, Hashable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() { self = .null }
    else if let value = try? container.decode(Bool.self) { self = .bool(value) }
    else if let value = try? container.decode(Double.self) { self = .number(value) }
    else if let value = try? container.decode(String.self) { self = .string(value) }
    else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
    else { self = .object(try container.decode([String: JSONValue].self)) }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }

  var string: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  var object: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }
}

/// A word pack as saved. Only its id, name and origin are read; the rest stays as it was.
public struct WordPack: Codable, Hashable, Sendable {
  public private(set) var fields: [String: JSONValue]

  public var id: String { fields["id"]?.string ?? "" }
  public var name: String { fields["name"]?.string ?? "" }
  /// The official pack this one follows, when it is a followed pack (isFollowed in src/core/followedPacks.ts).
  public var followedCatalogId: String? {
    guard let origin = fields["origin"]?.object, origin["followed"] == .bool(true) else { return nil }
    return origin["catalogId"]?.string
  }

  public init(from decoder: Decoder) throws {
    fields = try [String: JSONValue](from: decoder)
    guard !id.isEmpty, fields["name"]?.string != nil, fields["createdAt"]?.string != nil else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "A pack needs an id, a name and createdAt"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    try fields.encode(to: encoder)
  }

  init(id: String, name: String, createdAt: String, category: String? = nil, tags: [String]? = nil, description: String? = nil,
       origin: (catalogId: String, version: Int)? = nil) {
    fields = ["id": .string(id), "name": .string(name), "createdAt": .string(createdAt)]
    setLabels(category: category, tags: tags, description: description)
    if let origin {
      fields["origin"] = .object(["catalogId": .string(origin.catalogId), "version": .number(Double(origin.version)), "followed": .bool(true)])
    }
  }

  /// Sets the labels, leaving out those that are empty, as the web app saves them.
  mutating func setLabels(category: String?, tags: [String]?, description: String?) {
    for key in ["description", "category", "tags"] { fields[key] = nil }
    if let description, !description.isEmpty { fields["description"] = .string(description) }
    if let category, !category.isEmpty { fields["category"] = .string(category) }
    if let tags, !tags.isEmpty { fields["tags"] = .array(tags.map { .string($0) }) }
  }
}

/// An official pack as the catalog holds it (officialPacks in src/plugins/packs/catalog.ts): its lists have no records.
public struct OfficialPack: Decodable, Sendable {
  public struct Pack: Decodable, Sendable {
    public var id: String
    public var name: String
    public var description: String?
    public var category: String?
    public var tags: [String]?
    public var createdAt: String
  }

  public struct List: Decodable, Sendable {
    public var id: String
    public var name: String
    public var levels: [String]?
    public var words: [Word]
    public var createdAt: String
  }

  public var catalogId: String
  public var version: Int
  public var pack: Pack
  public var lists: [List]
}

private let catalog: [OfficialPack] = {
  // catalog.json is made from typle-r's src/plugins/packs by scripts/catalog.cjs.
  guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json"), let data = try? Data(contentsOf: url) else {
    fatalError("Missing bundled catalog.json")
  }
  do { return try JSONDecoder().decode([OfficialPack].self, from: data) } catch { fatalError("Unreadable bundled catalog: \(error)") }
}()

public func officialPacks() -> [OfficialPack] { catalog }

/// Brings an account's packs and lists in line with the catalog, as followOfficial does when the web app or the Go
/// backend reads them; applying it again changes nothing.
/// 1. Copies from before v0.98.0 are removed with their lists and records: a pack with an origin that is not followed,
///    and a pack without an origin whose id is a catalog id.
/// 2. Each followed pack is made equal to its official pack (removed when the catalog has none), keeping its id, name,
///    createdAt and the records of the lists it keeps. Its lists take the place of its first list.
public func followOfficial(packs: [WordPack], lists: [WordList], official: [OfficialPack] = officialPacks()) -> (packs: [WordPack], lists: [WordList]) {
  let entries = Dictionary(official.map { ($0.catalogId, $0) }, uniquingKeysWith: { first, _ in first })
  var kept: [WordPack] = []
  for var pack in packs {
    if pack.fields["origin"] != nil {
      guard let catalogId = pack.followedCatalogId, let entry = entries[catalogId] else { continue }
      pack.setLabels(category: entry.pack.category, tags: entry.pack.tags, description: entry.pack.description)
    } else if entries[pack.id] != nil {
      continue
    }
    kept.append(pack)
  }
  var synced: [String: [WordList]] = [:]
  for pack in kept {
    guard let catalogId = pack.followedCatalogId, let entry = entries[catalogId] else { continue }
    let mine = lists.filter { $0.packId == pack.id }
    synced[pack.id] = entry.lists.map { item in
      // The id comes from the official list's, so that the app and Go make the same list.
      var list = mine.first { $0.origin?.listId == item.id } ??
        WordList(id: "\(pack.id):\(item.id)", name: item.name, words: [], createdAt: item.createdAt, packId: pack.id,
                 origin: ListOrigin(listId: item.id))
      list.name = item.name
      list.levels = (item.levels ?? []).isEmpty ? nil : item.levels
      list.words = item.words
      return list
    }
  }
  let byId = Dictionary(kept.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  var placed = Set<String>()
  let result = lists.flatMap { list -> [WordList] in
    guard let packId = list.packId, let pack = byId[packId] else { return [] }
    guard let items = synced[pack.id] else { return pack.followedCatalogId == nil ? [list] : [] }
    if placed.contains(pack.id) { return [] }
    placed.insert(pack.id)
    return items
  }
  return (kept, result)
}

/// What an account that has saved nothing starts with: every official pack followed, in the order of the catalog, as
/// the interests of a new account choose them all (DEFAULT_INTERESTS). The first save keeps them.
public func startingLibrary(now: Date = Date(), newId: () -> String = randomId) -> (packs: [WordPack], lists: [WordList]) {
  let created = isoString(now)
  var packs: [WordPack] = []
  var lists: [WordList] = []
  for entry in officialPacks() {
    let id = newId()
    packs.append(WordPack(id: id, name: entry.pack.name, createdAt: created, category: entry.pack.category, tags: entry.pack.tags,
                          description: entry.pack.description, origin: (entry.catalogId, entry.version)))
    lists += entry.lists.map { item in
      WordList(id: "\(id):\(item.id)", name: item.name, words: item.words, createdAt: created,
               levels: (item.levels ?? []).isEmpty ? nil : item.levels, packId: id, origin: ListOrigin(listId: item.id))
    }
  }
  return (packs, lists)
}

/// The packs and lists a save sends with each other, in the shape validateLibrary (src/core/wordPacks.ts) takes: every
/// list in one of the packs and every pack with a list. A list the app made, or copied, gets a pack of its own named
/// after it, as the web app makes one; the labels a list still has move to that pack, which repairLibrary does too.
/// The lists of followed packs go without their words, which the catalog has.
public func libraryToSave(packs: [WordPack], lists: [WordList]) -> (packs: [WordPack], lists: [WordList]) {
  var packs = packs
  var ids = Set(packs.map(\.id))
  var names = Set(packs.map { $0.name.trimmed.lowercased() })
  let followed = Set(packs.filter { $0.followedCatalogId != nil }.map(\.id))
  let saved = lists.map { list -> WordList in
    var list = list
    if list.packId.map({ !ids.contains($0) }) ?? true {
      let id = ids.contains("pack-\(list.id)") ? randomId() : "pack-\(list.id)"
      let labels = normalizeLabels(category: list.category, tags: list.tags)
      packs.append(WordPack(id: id, name: unique(&names, list.name.trimmed, limit: maxPackName), createdAt: list.createdAt,
                            category: labels.category, tags: labels.tags.map { Array($0.prefix(maxTags)) }))
      ids.insert(id)
      list.packId = id
    }
    list.group = nil
    list.category = nil
    list.tags = nil
    if followed.contains(list.packId!) && list.origin != nil { list.words = [] }
    return list
  }
  let used = Set(saved.compactMap(\.packId))
  return (packs.filter { used.contains($0.id) }, saved)
}

/// unique (src/core/workspaceDocument.ts): wanted, or the first of wanted（2）, wanted（3）… whose lowercase is not taken.
func unique(_ taken: inout Set<String>, _ wanted: String, limit: Int) -> String {
  var value = wanted
  var count = 2
  while taken.contains(value.lowercased()) {
    value = fit(wanted, "（\(count)）", limit: limit)
    count += 1
  }
  taken.insert(value.lowercased())
  return value
}

/// fit (src/core/workspaceDocument.ts): name and then suffix, the name cut so that the whole stays within limit UTF-16
/// code units, without the spaces the cut leaves at its end. A character of two code units is not split.
func fit(_ name: String, _ suffix: String, limit: Int) -> String {
  var units = Array(name.utf16)
  let keep = limit - suffix.jsLength
  if units.count > keep {
    units = Array(units.prefix(max(keep, 0)))
    if let last = units.last, UTF16.isLeadSurrogate(last) { units.removeLast() }
  }
  let cut = String(decoding: units, as: UTF16.self)
  return String(cut.reversed().drop { $0.isWhitespace }.reversed()) + suffix
}
