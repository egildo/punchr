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
func domain(_ id: String, _ name: String = "") -> NSFileProviderDomain {
  NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(id), displayName: name)
}

switch (args.first, args.count) {
case ("add", 4):
  let d = domain(args[1], args[2])
  guard let joined = try? String(contentsOfFile: args[3], encoding: .utf8) else { finish(CocoaError(.fileReadNoSuchFile)); wait() }
  d.userInfo = [linksKey: joined] // userInfo takes plain strings only
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
