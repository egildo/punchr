// The links on a shelf, kept in its domain's userInfo as newline-joined absolute paths, in the order shelved
// (specs/004-shelves/data-model.md). Shared by the command, the shelf's host and its extension.
import Foundation

let linksKey = "links"

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

// The sync anchor is the list itself, so the changes since any anchor can be worked out without a store.
func anchorData(_ targets: [String]) -> Data { Data(joinLinks(targets).utf8) }
func targets(fromAnchor data: Data) -> [String] { parseLinks(String(decoding: data, as: UTF8.self)) }

// Since `old`: every current link is reported (a suffix may have moved), and the targets no longer there are gone.
func linkChanges(from old: [String], to new: [String]) -> (current: [Link], removed: [String]) {
  (shelfLinks(new), old.filter { !new.contains($0) })
}
