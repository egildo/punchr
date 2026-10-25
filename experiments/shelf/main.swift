// Spike host: adds, lists or removes the test domain. `shelf add <target>...`, `shelf list`, `shelf remove`.
import FileProvider

let args = Array(CommandLine.arguments.dropFirst())
let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("punchr-test"), displayName: "punchr test")
var done = false
func finish(_ what: String, _ error: Error?) { print(error.map { "✗ \(what): \($0)" } ?? "✓ \(what)"); done = true }

switch args.first {
case "add":
  domain.userInfo = ["targets": args.dropFirst().joined(separator: "\n")] // values must be plain strings
  NSFileProviderManager.add(domain) { finish("added", $0) }
case "remove":
  NSFileProviderManager.remove(domain) { finish("removed", $0) }
case "list":
  NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
    domains.forEach { print("  \($0.identifier.rawValue): \($0.displayName)") }; finish("listed", error)
  }
default:
  print("usage: shelf add <target>... | list | remove"); exit(2)
}
while !done { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1)) }
