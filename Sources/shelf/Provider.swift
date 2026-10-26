// A shelf's File Provider extension: one domain whose items are Finder aliases of the shelved folders and files
// (specs/004-shelves). Symbolic links made the system's daemon try to read every target, which its sandbox refuses,
// forever (notes/2026-10-26-shelves-by-eye.md); an alias is a small file the daemon has no reason to go through.
import FileProvider
import UniformTypeIdentifiers
import os

let log = Logger(subsystem: "local.punchr", category: "shelf")

final class Item: NSObject, NSFileProviderItem {
  let itemIdentifier: NSFileProviderItemIdentifier
  let parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer
  let filename: String
  let contentType: UTType
  let documentSize: NSNumber?
  let typeAndCreator: NSFileProviderTypeAndCreator
  let contentPolicy: NSFileProviderContentPolicy
  let contentVersion: Data
  var capabilities: NSFileProviderItemCapabilities { [.allowsReading, .allowsContentEnumerating] }
  var itemVersion: NSFileProviderItemVersion {
    NSFileProviderItemVersion(contentVersion: contentVersion, metadataVersion: Data(filename.utf8))
  }
  init(id: NSFileProviderItemIdentifier, name: String, type: UTType, size: Int? = nil,
       typeAndCreator: NSFileProviderTypeAndCreator = .init(type: 0, creator: 0), policy: NSFileProviderContentPolicy = .inherited,
       version: Data = Data()) {
    itemIdentifier = id; filename = name; contentType = type; documentSize = size.map { NSNumber(value: $0) }
    self.typeAndCreator = typeAndCreator; contentPolicy = policy; contentVersion = version
  }
  // The root keeps every link downloaded, so Finder shows no cloud on them.
  static let root = Item(id: .rootContainer, name: "shelf", type: .folder, policy: .downloadEagerlyAndKeepDownloaded)
  // An alias file, as Finder writes one: type 'fdrp' for a folder (Finder resolves either kind), creator 'MACS'.
  convenience init(_ link: Link, _ alias: Data?) {
    self.init(id: NSFileProviderItemIdentifier(link.target), name: link.name, type: .aliasFile, size: alias?.count ?? 0,
              typeAndCreator: .init(type: 0x6664_7270, creator: 0x4D41_4353), version: fingerprint(alias ?? Data()))
  }
}

// A short fingerprint of an alias's bytes (FNV-1a): new bytes make a new content version, so the system fetches them.
func fingerprint(_ d: Data) -> Data {
  var h: UInt64 = 0xcbf2_9ce4_8422_2325
  for b in d { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
  return withUnsafeBytes(of: h.bigEndian) { Data($0) }
}

// The domain's current list and aliases: the host adds the domain again with a new userInfo, so read afresh each time.
func current(_ domain: NSFileProviderDomain, _ done: @escaping ([String], [String: Any]) -> Void) {
  NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
    let info = (domains.first { $0.identifier == domain.identifier } ?? domain).userInfo as? [String: Any] ?? [:]
    done(parseLinks(info[linksKey] as? String), info)
  }
}
func items(_ links: [Link], _ info: [String: Any]) -> [Item] { links.map { Item($0, info[aliasKey($0.target)] as? Data) } }
func aliasStamp(_ targets: [String], _ info: [String: Any]) -> String {
  fingerprint(targets.reduce(into: Data()) { $0.append(info[aliasKey($1)] as? Data ?? Data()) }).map { String(format: "%02x", $0) }.joined()
}

final class Lister: NSObject, NSFileProviderEnumerator {
  let domain: NSFileProviderDomain
  init(_ domain: NSFileProviderDomain) { self.domain = domain }
  func invalidate() {}
  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    current(domain) { targets, info in
      observer.didEnumerate(items(shelfLinks(targets), info)); observer.finishEnumerating(upTo: nil)
    }
  }
  func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    let before = targets(fromAnchor: anchor.rawValue), beforeStamp = stamp(fromAnchor: anchor.rawValue)
    current(domain) { now, info in
      let changes = linkChanges(from: before, to: now), nowStamp = aliasStamp(now, info)
      let changed = nowStamp == beforeStamp ? changes.changed : shelfLinks(now) // new aliases: every link is new content
      if !changed.isEmpty { observer.didUpdate(items(changed, info)) }
      if !changes.removed.isEmpty { observer.didDeleteItems(withIdentifiers: changes.removed.map { NSFileProviderItemIdentifier($0) }) }
      observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(anchorData(now, stamp: nowStamp)), moreComing: false)
    }
  }
  func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
    current(domain) { targets, info in completionHandler(NSFileProviderSyncAnchor(anchorData(targets, stamp: aliasStamp(targets, info)))) }
  }
}

final class Provider: NSObject, NSFileProviderReplicatedExtension {
  let domain: NSFileProviderDomain
  required init(domain: NSFileProviderDomain) {
    self.domain = domain
    log.notice("shelf \(domain.identifier.rawValue, privacy: .public) started")
    super.init()
  }
  func invalidate() {}
  let excluded = NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.Code.excludedFromSync.rawValue)

  func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest,
            completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
    if identifier == .rootContainer { completionHandler(Item.root, nil); return Progress() }
    current(domain) { targets, info in
      if let link = shelfLinks(targets).first(where: { $0.target == identifier.rawValue }) {
        completionHandler(Item(link, info[aliasKey(link.target)] as? Data), nil)
      } else { completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)) }
    }
    return Progress()
  }
  // An alias's contents are its bookmark data, written to a file the system then moves into place.
  func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?,
                     request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
    current(domain) { targets, info in
      guard let link = shelfLinks(targets).first(where: { $0.target == itemIdentifier.rawValue }) else {
        completionHandler(nil, nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: itemIdentifier)); return
      }
      let alias = info[aliasKey(link.target)] as? Data ?? Data()
      let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      do { try alias.write(to: file); completionHandler(file, Item(link, alias), nil) } catch { completionHandler(nil, nil, error) }
    }
    return Progress()
  }
  // Quiet writes (no-error-marks): what Finder changes on a link is accepted and ignored; drops and deletions stay out.
  func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields,
                  contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest,
                  completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
    completionHandler(item, [], false, nil); return Progress()
  }
  func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?,
                  options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest,
                  completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
    completionHandler(nil, [], false, excluded); return Progress()
  }
  func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion,
                  options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest,
                  completionHandler: @escaping (Error?) -> Void) -> Progress {
    completionHandler(excluded); return Progress()
  }
  func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
    Lister(domain)
  }
}
