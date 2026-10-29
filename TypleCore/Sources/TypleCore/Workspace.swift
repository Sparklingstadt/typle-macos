import Foundation

/// The lists this device starts with: those of the official packs (catalog.json), each with its pack's category and
/// tags. They are shown until the first save, which keeps them as this device's own lists.
public func initialLists() -> [WordList] {
  officialPacks().flatMap { entry in
    entry.lists.map { item in
      WordList(id: item.id, name: item.name, words: item.words, createdAt: item.createdAt,
               category: entry.pack.category, tags: entry.pack.tags, levels: (item.levels ?? []).isEmpty ? nil : item.levels)
    }
  }
}

/// The local workspace file, in the shape of the web app's browser storage (`typle-r:guest-workspace:v1`).
public struct WorkspaceFile: Codable, Equatable, Sendable {
  public var version: Int
  public var accountId: String
  public var revision: Int
  public var lists: [WordList]
  public var devices: [PracticeDevice]

  public init(accountId: String, revision: Int, document: WorkspaceDocument) {
    version = 1
    self.accountId = accountId
    self.revision = revision
    lists = document.lists
    devices = document.devices
  }

  public var document: WorkspaceDocument { WorkspaceDocument(lists: lists, devices: devices) }
}

/// A saved workspace may hold up to 1 MiB of lists, like an account.
public let maxWorkspaceBytes = 1024 * 1024

public func decodeWorkspaceFile(_ data: Data, accountId: String) throws -> WorkspaceFile {
  let file: WorkspaceFile
  do { file = try JSONDecoder().decode(WorkspaceFile.self, from: data) } catch { throw TypleError("savedDataUnreadable") }
  guard file.version == 1, file.accountId == accountId, file.revision >= 0 else { throw TypleError("savedDataUnreadable") }
  try validateLists(file.lists)
  var decoded = file
  decoded.devices = try decodeDevices(file.devices)
  return decoded
}

public func encodeWorkspaceFile(_ file: WorkspaceFile) throws -> Data {
  try validateLists(file.lists)
  _ = try decodeDevices(file.devices)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.withoutEscapingSlashes]
  if try encoder.encode(file.lists).count > maxWorkspaceBytes { throw TypleError("guestQuotaExceeded") }
  return try encoder.encode(file)
}
