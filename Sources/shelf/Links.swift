// The links on a shelf, kept in its domain's userInfo as newline-joined absolute paths, in the order shelved
// (specs/004-shelves/data-model.md). Shared by the command, the shelf's host and its extension.
import Foundation

let linksKey = "links"
// Each link's alias (bookmark data), made by the shelf's app, which may read the targets; the extension may not.
func aliasKey(_ target: String) -> String { "alias:\(target)" }

struct Link: Equatable {
  let target: String // the real item's absolute path; also the link's identifier on the shelf
  let name: String // its name in the shelf
}

func parseLinks(_ joined: String?) -> [String] { (joined ?? "").split(separator: "\n").map(String.init) }
func joinLinks(_ targets: [String]) -> String { targets.joined(separator: "\n") }

// Each link is named after its item; the second and later of the same name get " 2", " 3", in shelving order.
func shelfLinks(_ targets: [String]) -> [Link] {
  var seen: [String: Int] = [:]
  return targets.map { target in
    let base = (target as NSString).lastPathComponent
    seen[base, default: 0] += 1
    return Link(target: target, name: seen[base]! == 1 ? base : "\(base) \(seen[base]!)")
  }
}

// The sync anchor is the list itself, so the changes since any anchor can be worked out without a store, plus a
// stamp of the aliases' bytes after "#": new aliases for the same list must reach Finder too.
func anchorData(_ targets: [String], stamp: String = "") -> Data { Data((joinLinks(targets) + "\n#" + stamp).utf8) }
func targets(fromAnchor data: Data) -> [String] { parseLinks(String(decoding: data, as: UTF8.self)).filter { !$0.hasPrefix("#") } }
func stamp(fromAnchor data: Data) -> String {
  parseLinks(String(decoding: data, as: UTF8.self)).last { $0.hasPrefix("#") }.map { String($0.dropFirst()) } ?? ""
}

// Since `old`: the links that are new or renamed (a suffix may have moved), and the targets no longer there.
// Reporting an unchanged link makes the system rewrite it, which reports a change again: a loop.
func linkChanges(from old: [String], to new: [String]) -> (changed: [Link], removed: [String]) {
  let before = shelfLinks(old)
  return (shelfLinks(new).filter { !before.contains($0) }, old.filter { !new.contains($0) })
}
