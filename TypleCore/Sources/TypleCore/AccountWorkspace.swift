import Foundation

/// The account's workspace as `/api/workspace` answers and saves it (src/plugins/storage/cloud/client.ts): the
/// document, and the revision a save must name so that it does not overwrite a change made elsewhere since.
public struct AccountWorkspace: Equatable, Sendable {
  public var accountId: String
  public var revision: Int
  public var document: WorkspaceDocument

  public init(accountId: String, revision: Int, document: WorkspaceDocument) {
    self.accountId = accountId
    self.revision = revision
    self.document = document
  }
}

private struct AccountWorkspaceBody: Codable {
  var lists: [WordList]
  /// Left out of a save for an account whose lists were saved before packs: the backend then makes them.
  var packs: [WordPack]?
  var devices: [PracticeDevice]?
  var revision: Int
  var accountId: String
}

/// Reads an answer of `/api/workspace`. The lists of followed official packs come without their words (typle-r v2.1.0),
/// which the catalog puts back. An account that has saved nothing (revision 0) starts following every official pack,
/// and the first save keeps them.
public func decodeAccountWorkspace(_ data: Data) throws -> AccountWorkspace {
  let body: AccountWorkspaceBody
  do { body = try JSONDecoder().decode(AccountWorkspaceBody.self, from: data) } catch { throw TypleError("invalidServerData") }
  guard body.revision >= 0, !body.accountId.isEmpty else { throw TypleError("invalidServerData") }
  let library: (packs: [WordPack]?, lists: [WordList])
  if body.revision == 0 {
    let start = startingLibrary()
    library = (start.packs, start.lists)
  } else if let packs = body.packs {
    let followed = followOfficial(packs: packs, lists: body.lists)
    library = (followed.packs, followed.lists)
  } else {
    library = (nil, body.lists)
  }
  try validateLists(library.lists)
  return AccountWorkspace(accountId: body.accountId, revision: body.revision,
                          document: WorkspaceDocument(lists: library.lists, devices: try decodeDevices(body.devices ?? []), packs: library.packs))
}

/// The body of a save (`PUT /api/workspace`): the whole document, for the revision it was changed from. The packs go
/// with the lists, so that the backend keeps them; without them it would put each list in a pack of its own.
public func encodeAccountWorkspace(_ workspace: AccountWorkspace) throws -> Data {
  try validateLists(workspace.document.lists)
  _ = try decodeDevices(workspace.document.devices)
  var lists = workspace.document.lists
  var packs = workspace.document.packs
  if let saved = packs {
    (packs, lists) = libraryToSave(packs: saved, lists: lists)
  }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.withoutEscapingSlashes]
  let data = try encoder.encode(AccountWorkspaceBody(lists: lists, packs: packs, devices: workspace.document.devices,
                                                     revision: workspace.revision, accountId: workspace.accountId))
  // The server reads at most 1 MiB.
  if data.count > maxWorkspaceBytes { throw TypleError("workspaceTooLarge") }
  return data
}
