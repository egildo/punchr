// Shelves: sidebar rows of links, one small app per shelf, generated from the template inside Punchr.app
// (specs/004-shelves). A shelf writes nothing on the items it links to (a-shelf-owns-no-attributes).
import Foundation

struct ShelfError: Error, CustomStringConvertible { let description: String }

struct ShelfIDs { let app: String, provider: String, group: String, domain: String }

// Bundle identifiers take letters, digits, hyphens and dots; a punch's name may hold anything a file name can.
func shelfIDs(_ punch: String, _ key: String) -> ShelfIDs {
  let safe = String(punch.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" })
  let base = "local.punchr.shelf.\(safe).\(key)"
  return ShelfIDs(app: base, provider: "\(base).provider", group: "group.\(base)", domain: "\(punch).\(key)")
}

var shelvesFolder: URL {
  FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/punchr/Shelves")
}

// The template travels inside Punchr.app, beside the command (which may be reached through a symbolic link).
var shelfTemplate: URL {
  Bundle.main.executableURL!.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Shelf.app")
}

func shelfApp(_ d: ShelfDecl, in folder: URL = shelvesFolder) -> URL { folder.appendingPathComponent("\(d.name).app") }
private func providerOf(_ app: URL) -> URL { app.appendingPathComponent("Contents/PlugIns/ShelfProvider.appex") }

let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

@discardableResult
func tool(_ path: String, _ args: [String]) throws -> String {
  let p = Process(), out = Pipe(), err = Pipe()
  p.executableURL = URL(fileURLWithPath: path); p.arguments = args; p.standardOutput = out; p.standardError = err
  try p.run()
  let o = out.fileHandleForReading.readDataToEndOfFile(), e = err.fileHandleForReading.readDataToEndOfFile()
  p.waitUntilExit()
  guard p.terminationStatus == 0 else {
    let why = String(decoding: e, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    throw ShelfError(description: "\((path as NSString).lastPathComponent) \(args.first ?? ""): \(why)")
  }
  return String(decoding: o, as: UTF8.self)
}

private func editPlist(_ url: URL, _ edit: (inout [String: Any]) -> Void) throws {
  var d = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
  edit(&d)
  try PropertyListSerialization.data(fromPropertyList: d, format: .xml, options: 0).write(to: url)
}

func shelfEntitlements(_ group: String, sandboxed: Bool) throws -> Data {
  var e: [String: Any] = ["com.apple.security.application-groups": [group]]
  if sandboxed { e["com.apple.security.app-sandbox"] = true }
  return try PropertyListSerialization.data(fromPropertyList: e, format: .xml, options: 0)
}

// Copies the template and gives it the shelf's identifiers, name and symbol; signing and registering come after.
// The app also records which punch and shelf it serves, so `punchr shelves` can find its punch again.
func makeShelfApp(_ punch: String, _ d: ShelfDecl, punchFile: String = "", template: URL, at app: URL) throws {
  let ids = shelfIDs(punch, d.key), fm = FileManager.default
  try fm.createDirectory(at: app.deletingLastPathComponent(), withIntermediateDirectories: true)
  if fm.fileExists(atPath: app.path) { try fm.removeItem(at: app) }
  try fm.copyItem(at: template, to: app)
  try editPlist(app.appendingPathComponent("Contents/Info.plist")) {
    $0["CFBundleIdentifier"] = ids.app; $0["CFBundleName"] = d.name; $0["CFBundleDisplayName"] = d.name
    $0["PunchrPunch"] = punch; $0["PunchrPunchFile"] = punchFile; $0["PunchrShelf"] = d.key; $0["PunchrSymbol"] = d.symbol
  }
  try editPlist(providerOf(app).appendingPathComponent("Contents/Info.plist")) {
    $0["CFBundleIdentifier"] = ids.provider
    $0["CFBundleIcons"] = ["CFBundlePrimaryIcon": ["CFBundleSymbolName": d.symbol]]
    var ext = $0["NSExtension"] as? [String: Any] ?? [:]
    ext["NSExtensionFileProviderDocumentGroup"] = ids.group
    $0["NSExtension"] = ext
  }
}

// Signs the extension, then the app, ad hoc with the shelf's group, and registers the app with the system.
func signAndRegister(_ app: URL, _ ids: ShelfIDs) throws {
  let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("punchr-shelf-\(getpid())")
  try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tmp) }
  let ext = tmp.appendingPathComponent("provider.entitlements"), own = tmp.appendingPathComponent("app.entitlements")
  try shelfEntitlements(ids.group, sandboxed: true).write(to: ext)
  try shelfEntitlements(ids.group, sandboxed: false).write(to: own)
  try tool("/usr/bin/codesign", ["-f", "-s", "-", "--entitlements", ext.path, providerOf(app).path])
  try tool("/usr/bin/codesign", ["-f", "-s", "-", "--entitlements", own.path, app.path])
  try tool(lsregister, ["-f", "-R", app.path])
  try tool("/usr/bin/pluginkit", ["-a", providerOf(app).path])
}

private func host(_ app: URL) -> String { app.appendingPathComponent("Contents/MacOS/Shelf").path }

// What the system holds for a set-up shelf: whether it is enabled, and its links; nil when it has no domain.
func shelfStatus(_ app: URL, _ ids: ShelfIDs) throws -> (enabled: Bool, links: [String])? {
  let out = try tool(host(app), ["status", ids.domain])
  guard let d = try JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any], d["name"] != nil else { return nil }
  return (d["enabled"] as? Bool ?? false, d["links"] as? [String] ?? [])
}

func setLinks(_ app: URL, _ ids: ShelfIDs, _ d: ShelfDecl, _ targets: [String]) throws {
  let file = FileManager.default.temporaryDirectory.appendingPathComponent("punchr-links-\(getpid())")
  try joinLinks(targets).write(to: file, atomically: true, encoding: .utf8)
  defer { try? FileManager.default.removeItem(at: file) }
  try tool(host(app), ["add", ids.domain, d.name, file.path])
}

struct ShelfPlan {
  let punch: String
  var punchFile = ""
  let shelf: ShelfDecl
  let app: URL
  var setUp = false // the shelf's app must be generated and registered first
  var before: [String] = []
  var after: [String] = []
  var error: String?
  var enabled: Bool?
  var changes: Bool { setUp || before != after }
  var removed: [String] { before.filter { !after.contains($0) } }
}

// Paths as given, made absolute against the current folder; `.` and `..` folded, links and /private never resolved.
func absolute(_ path: String) -> String {
  URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).absoluteURL.standardized.path
}

// The lists alone: shelving appends what is not there yet, in the order given; unshelving drops what is named.
func shelved(_ before: [String], _ items: [String]) -> [String] {
  items.map(absolute).reduce(into: before) { if !$0.contains($1) { $0.append($1) } }
}
func unshelved(_ before: [String], _ items: [String]) -> [String] {
  let gone = Set(items.map(absolute)); return before.filter { !gone.contains($0) }
}

// What the system holds for the shelf now; a shelf whose app or domain is missing must be set up first.
private func startPlan(_ punch: Punch, _ d: ShelfDecl, _ folder: URL) -> ShelfPlan {
  var p = ShelfPlan(punch: punch.name, punchFile: punch.file, shelf: d, app: shelfApp(d, in: folder))
  if FileManager.default.fileExists(atPath: p.app.path) {
    do {
      if let s = try shelfStatus(p.app, shelfIDs(punch.name, d.key)) { p.before = s.links; p.enabled = s.enabled } else { p.setUp = true }
    } catch { p.error = "\(d.name): \(error)" }
  } else { p.setUp = true }
  return p
}

// Shelve: the items not on the shelf yet go to its end, in the order given; an item already on it stays where it is.
func planShelve(_ punch: Punch, _ d: ShelfDecl, _ items: [String], in folder: URL = shelvesFolder) -> ShelfPlan {
  var p = startPlan(punch, d, folder)
  p.after = shelved(p.before, items)
  return p
}

// Unshelve: the items named leave the shelf; one not on it changes nothing. A shelf never set up has nothing to take off.
func planUnshelve(_ punch: Punch, _ d: ShelfDecl, _ items: [String], in folder: URL = shelvesFolder) -> ShelfPlan {
  var p = startPlan(punch, d, folder)
  if p.setUp { p.setUp = false; return p }
  p.after = unshelved(p.before, items)
  return p
}

// A shelf set up on this Mac, as `punchr shelves` reports it.
struct ShelfListing {
  let app: URL
  let punch: String, punchFile: String, key: String, name: String, symbol: String
  var enabled: Bool?
  var links: [String] = []
  var declared = false
  var error: String?
}

// Every shelf's app in the shelves folder, what the system holds for it, and whether its punch still declares it.
func listShelves(in folder: URL = shelvesFolder) -> [ShelfListing] {
  let apps = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension == "app" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  return apps.map { app in
    let info = Bundle(url: app)?.infoDictionary ?? [:]
    func s(_ k: String) -> String { info[k] as? String ?? "" }
    var l = ShelfListing(app: app, punch: s("PunchrPunch"), punchFile: s("PunchrPunchFile"), key: s("PunchrShelf"),
                         name: s("CFBundleName"), symbol: s("PunchrSymbol"))
    if l.punch.isEmpty || l.key.isEmpty { l.error = "made before shelves recorded their punch: set it up again"; return l }
    do {
      if let st = try shelfStatus(app, shelfIDs(l.punch, l.key)) { l.enabled = st.enabled; l.links = st.links }
      else { l.error = "the system has no shelf for it" }
    } catch { l.error = "\(error)" }
    let file = l.punchFile.isEmpty ? punchURL(l.punch) : URL(fileURLWithPath: l.punchFile)
    l.declared = (try? readPunch(file))?.shelves[l.key] != nil
    return l
  }
}

// Generates and registers the shelf when needed, then gives its domain the new list.
func carryOut(_ p: ShelfPlan, template: URL = shelfTemplate) -> ShelfPlan {
  guard p.error == nil, p.changes else { return p }
  var p = p
  let ids = shelfIDs(p.punch, p.shelf.key)
  do {
    if p.setUp {
      if let other = Bundle(url: p.app)?.bundleIdentifier, other != ids.app {
        throw ShelfError(description: "\(p.app.path) belongs to another shelf (\(other))")
      }
      try makeShelfApp(p.punch, p.shelf, punchFile: p.punchFile, template: template, at: p.app)
      try signAndRegister(p.app, ids)
    }
    try setLinks(p.app, ids, p.shelf, p.after)
    p.enabled = try shelfStatus(p.app, ids)?.enabled
  } catch { p.error = "\(p.shelf.name): \(error)" }
  return p
}

// Takes a shelf's app off the system's books and deletes it. Unregistering first matters: a bundle replaced in
// place is forgotten by the system (notes/2026-10-25-shelf-spike.md). Either step may find nothing to do.
private func unregister(_ app: URL) throws {
  _ = try? tool("/usr/bin/pluginkit", ["-r", providerOf(app).path])
  _ = try? tool(lsregister, ["-u", app.path])
  try FileManager.default.removeItem(at: app)
}

// Tidy: the shelf's row and folder go (the system removes both with the domain), then its app (take-a-shelf-away).
// macOS keeps the extension's empty sandbox container, which a shell may not delete.
func removeShelf(_ l: ShelfListing) throws {
  try tool(host(l.app), ["remove", shelfIDs(l.punch, l.key).domain])
  try unregister(l.app)
}

// The shelf as its punch declares it now, so a new name or symbol reaches the row; as recorded when the punch is gone.
func currentDecl(_ l: ShelfListing) -> ShelfDecl {
  let file = l.punchFile.isEmpty ? punchURL(l.punch) : URL(fileURLWithPath: l.punchFile)
  return (try? readPunch(file))?.shelves[l.key] ?? ShelfDecl(key: l.key, name: l.name, symbol: l.symbol)
}

// Refresh: the shelf's app is made again from the current template, under its punch's current name and symbol
// when the punch still declares it, and given its links again (shelves-survive-a-rebuild).
// The domain stays, and with it the user's enabling.
func refreshShelf(_ l: ShelfListing, template: URL = shelfTemplate, in folder: URL = shelvesFolder) throws -> URL {
  let d = currentDecl(l)
  let ids = shelfIDs(l.punch, l.key), app = shelfApp(d, in: folder)
  try unregister(l.app)
  try makeShelfApp(l.punch, d, punchFile: l.punchFile, template: template, at: app)
  try signAndRegister(app, ids)
  try setLinks(app, ids, d, l.links)
  return app
}
