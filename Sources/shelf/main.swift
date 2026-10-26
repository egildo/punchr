// A shelf's own app: punchr runs it to add, remove or report the one domain its extension serves.
//   Shelf add <id> <name> <links-file>   add the domain, or add it again with a new list, and tell Finder
//   Shelf remove <id>
//   Shelf status <id>                    the domain's name, whether it is enabled, and its links, as JSON
import FileProvider

let args = Array(CommandLine.arguments.dropFirst())
var done = false, failed = false
func finish(_ error: Error?) {
  if let error { FileHandle.standardError.write(Data("\(error)\n".utf8)); failed = true }
  done = true
}
func wait() -> Never {
  while !done { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1)) }
  exit(failed ? 1 : 0)
}
// The bytes of an alias file as Finder writes one: the bookmark wrapped in the file's own header, which only
// writeBookmarkData adds, so it is written to a temporary file and read back.
func aliasFileBytes(_ target: String) -> Data? {
  let file = FileManager.default.temporaryDirectory.appendingPathComponent("punchr-alias-\(getpid())")
  defer { try? FileManager.default.removeItem(at: file) }
  guard let bookmark = try? URL(fileURLWithPath: target).bookmarkData(options: .suitableForBookmarkFile,
                                                                      includingResourceValuesForKeys: nil, relativeTo: nil),
        (try? URL.writeBookmarkData(bookmark, to: file)) != nil else { return nil }
  return try? Data(contentsOf: file)
}
func domain(_ id: String, _ name: String = "") -> NSFileProviderDomain {
  NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(id), displayName: name)
}

switch (args.first, args.count) {
case ("add", 4):
  let d = domain(args[1], args[2])
  guard let joined = try? String(contentsOfFile: args[3], encoding: .utf8) else { finish(CocoaError(.fileReadNoSuchFile)); wait() }
  // userInfo takes plain strings and data only. A target that cannot be found gets no alias and opens nothing.
  var info: [String: Any] = [linksKey: joined]
  for t in parseLinks(joined) { info[aliasKey(t)] = aliasFileBytes(t) }
  d.userInfo = info
  NSFileProviderManager.add(d) { error in
    guard error == nil, let manager = NSFileProviderManager(for: d) else { finish(error); return }
    manager.signalEnumerator(for: .workingSet) { _ in manager.signalEnumerator(for: .rootContainer) { finish($0) } }
  }
case ("remove", 2):
  NSFileProviderManager.remove(domain(args[1])) { finish($0) }
case ("status", 2):
  NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
    if let d = domains.first(where: { $0.identifier.rawValue == args[1] }) {
      let doc: [String: Any] = ["name": d.displayName, "enabled": d.userEnabled,
                                "links": parseLinks(d.userInfo?[linksKey] as? String)]
      print(String(decoding: try! JSONSerialization.data(withJSONObject: doc, options: [.sortedKeys]), as: UTF8.self))
    } else if error == nil { print("{}") }
    finish(error)
  }
default:
  FileHandle.standardError.write(Data("usage: Shelf add <id> <name> <links-file> | remove <id> | status <id>\n".utf8)); exit(2)
}
wait()
