// A shelf's File Provider extension: one domain whose items are symbolic links to the shelved folders and files
// (specs/004-shelves, notes/2026-10-25-shelf-spike.md). It holds no contents and accepts Finder's writes quietly.
import FileProvider
import UniformTypeIdentifiers
import os

let log = Logger(subsystem: "local.punchr", category: "shelf")

final class Item: NSObject, NSFileProviderItem {
  let itemIdentifier: NSFileProviderItemIdentifier
  let parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer
  let filename: String
  let contentType: UTType
  let symlinkTargetPath: String?
  var capabilities: NSFileProviderItemCapabilities { [.allowsReading, .allowsContentEnumerating] }
  var itemVersion: NSFileProviderItemVersion {
    NSFileProviderItemVersion(contentVersion: Data((symlinkTargetPath ?? "").utf8), metadataVersion: Data(filename.utf8))
  }
  init(id: NSFileProviderItemIdentifier, name: String, type: UTType, target: String? = nil) {
    itemIdentifier = id; filename = name; contentType = type; symlinkTargetPath = target
  }
  static let root = Item(id: .rootContainer, name: "shelf", type: .folder)
  convenience init(_ link: Link) {
    self.init(id: NSFileProviderItemIdentifier(link.target), name: link.name, type: .symbolicLink, target: link.target)
  }
}

// The domain's current list: the host adds the domain again with a new userInfo, so it is read afresh each time.
func currentTargets(_ domain: NSFileProviderDomain, _ done: @escaping ([String]) -> Void) {
  NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
    let now = domains.first { $0.identifier == domain.identifier } ?? domain
    done(parseLinks(now.userInfo?[linksKey] as? String))
  }
}

final class Lister: NSObject, NSFileProviderEnumerator {
  let domain: NSFileProviderDomain
  init(_ domain: NSFileProviderDomain) { self.domain = domain }
  func invalidate() {}
  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    currentTargets(domain) { targets in
      observer.didEnumerate(shelfLinks(targets).map(Item.init)); observer.finishEnumerating(upTo: nil)
    }
  }
  func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    let before = targets(fromAnchor: anchor.rawValue)
    currentTargets(domain) { now in
      let changes = linkChanges(from: before, to: now)
      observer.didUpdate(changes.current.map(Item.init))
      if !changes.removed.isEmpty { observer.didDeleteItems(withIdentifiers: changes.removed.map { NSFileProviderItemIdentifier($0) }) }
      observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(anchorData(now)), moreComing: false)
    }
  }
  func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
    currentTargets(domain) { completionHandler(NSFileProviderSyncAnchor(anchorData($0))) }
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
    currentTargets(domain) { targets in
      if let link = shelfLinks(targets).first(where: { $0.target == identifier.rawValue }) { completionHandler(Item(link), nil) }
      else { completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)) }
    }
    return Progress()
  }
  // A link has no contents of its own.
  func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?,
                     request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
    completionHandler(nil, nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError)); return Progress()
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
