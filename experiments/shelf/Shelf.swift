// Spike: a File Provider extension whose domain holds only links, so it shows as a sidebar row with an SF Symbol.
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
  var itemVersion: NSFileProviderItemVersion { NSFileProviderItemVersion(contentVersion: Data("1".utf8), metadataVersion: Data("1".utf8)) }
  init(id: NSFileProviderItemIdentifier, name: String, type: UTType, target: String? = nil) {
    itemIdentifier = id; filename = name; contentType = type; symlinkTargetPath = target
  }
  static let root = Item(id: .rootContainer, name: "punchr test", type: .folder)
  static func link(_ target: String) -> Item {
    Item(id: NSFileProviderItemIdentifier(target), name: (target as NSString).lastPathComponent, type: .symbolicLink, target: target)
  }
}

final class Lister: NSObject, NSFileProviderEnumerator {
  let items: [Item]
  init(_ items: [Item]) { self.items = items }
  func invalidate() {}
  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    observer.didEnumerate(items); observer.finishEnumerating(upTo: nil)
  }
  func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
  }
  func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
    completionHandler(NSFileProviderSyncAnchor(Data("1".utf8)))
  }
}

final class Shelf: NSObject, NSFileProviderReplicatedExtension {
  let links: [Item]
  required init(domain: NSFileProviderDomain) {
    links = (domain.userInfo?["targets"] as? String ?? "").split(separator: "\n").map { Item.link(String($0)) }
    log.notice("shelf for \(domain.identifier.rawValue, privacy: .public): \(self.links.count) links")
    super.init()
  }
  func invalidate() {}
  let refused = NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError)

  func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest,
            completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
    if identifier == .rootContainer { completionHandler(Item.root, nil) }
    else if let i = links.first(where: { $0.itemIdentifier == identifier }) { completionHandler(i, nil) }
    else { completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)) }
    return Progress()
  }
  func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?,
                     request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
    completionHandler(nil, nil, refused); return Progress()
  }
  func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?,
                  options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest,
                  completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
    completionHandler(nil, [], false, refused); return Progress()
  }
  func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields,
                  contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest,
                  completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
    completionHandler(nil, [], false, refused); return Progress()
  }
  func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion,
                  options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest,
                  completionHandler: @escaping (Error?) -> Void) -> Progress {
    completionHandler(refused); return Progress()
  }
  func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
    Lister(containerItemIdentifier == .rootContainer ? links : [])
  }
}
