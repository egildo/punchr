// A punch: a JSON5 file naming looks and what the punch owns (specs/001-punch-and-strike/data-model.md).
import Cocoa

enum Colour: Int, CaseIterable {
  case none, grey, green, purple, blue, yellow, red, orange
  var name: String { "\(self)" }
  init?(name: String) { guard let c = Colour.allCases.first(where: { $0.name == name }) else { return nil }; self = c }
}

struct Tag: Equatable {
  let name: String
  let colour: Colour
  // Finder's own form: "name\nN".
  var entry: String { "\(name)\n\(colour.rawValue)" }
  init(name: String, colour: Colour) { self.name = name; self.colour = colour }
  init(entry: String) {
    let parts = entry.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
    name = String(parts[0])
    colour = parts.count > 1 ? Colour(rawValue: Int(parts[1]) ?? 0) ?? .none : .none
  }
}

enum Stamp: Equatable {
  case sym(String), emoji(String)
  case raw(String) // a stamp in a shape punchr does not know, kept as found
  var text: String {
    switch self { case .sym(let s): "sym \(s)"; case .emoji(let s): "emoji \(s)"; case .raw(let s): s }
  }
}

struct Look {
  let name: String
  let tags: [Tag]
  let stamp: Stamp?
  let icon: URL?
  let comment: String?
  let isBadge: Bool
}

struct Punch {
  let name: String
  let ownedTags: Set<String>
  let ownsStamp: Bool
  let ownsIcon: Bool
  let ownsComment: Bool
  let looks: [String: Look]
}

struct Problem { let at: String; let problem: String }
struct Refused: Error { let problems: [Problem] }

// The punch folder: $XDG_CONFIG_HOME/punchr, by default ~/.config/punchr.
var punchFolder: URL {
  let env = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
  let base = env.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
  return base.appendingPathComponent("punchr")
}

// A name means <name>.json5 in the punch folder; anything with a slash or ending in .json5 is a path.
func punchURL(_ arg: String) -> URL {
  arg.contains("/") || arg.hasSuffix(".json5")
    ? URL(fileURLWithPath: arg) : punchFolder.appendingPathComponent("\(arg).json5")
}

// Reads and checks a punch; every problem is collected before refusing (refuse-a-broken-punch).
func readPunch(_ url: URL) throws -> Punch {
  var problems: [Problem] = []
  func problem(_ at: String, _ p: String) { problems.append(Problem(at: at, problem: p)) }
  func unknownKeys(_ d: [String: Any], _ known: Set<String>, _ at: String) {
    for k in d.keys.sorted() where !known.contains(k) { problem(at.isEmpty ? k : "\(at).\(k)", "unknown key") }
  }

  let top: [String: Any]
  do {
    let data = try Data(contentsOf: url)
    guard let d = try JSONSerialization.jsonObject(with: data, options: .json5Allowed) as? [String: Any] else {
      throw Refused(problems: [Problem(at: "", problem: "not an object")])
    }
    top = d
  } catch let r as Refused {
    throw r
  } catch {
    throw Refused(problems: [Problem(at: "", problem: "\(url.path): \(error.localizedDescription)")])
  }
  unknownKeys(top, ["owns", "looks"], "")

  let owns = top["owns"] as? [String: Any] ?? [:]
  if top["owns"] != nil && top["owns"] as? [String: Any] == nil { problem("owns", "must be an object") }
  unknownKeys(owns, ["tags", "stamp", "icon", "comment"], "owns")
  let ownedTags = owns["tags"] as? [String] ?? []
  if owns["tags"] != nil && owns["tags"] as? [String] == nil { problem("owns.tags", "must be a list of tag names") }
  func flag(_ k: String) -> Bool {
    guard let v = owns[k] else { return false }
    guard let b = v as? Bool else { problem("owns.\(k)", "must be true or false"); return false }
    return b
  }
  let ownsStamp = flag("stamp"), ownsIcon = flag("icon"), ownsComment = flag("comment")

  var looks: [String: Look] = [:]
  guard let rawLooks = top["looks"] as? [String: Any], !rawLooks.isEmpty else {
    problem("looks", "must name at least one look")
    throw Refused(problems: problems)
  }
  for name in rawLooks.keys.sorted() {
    let at = "looks.\(name)"
    guard let l = rawLooks[name] as? [String: Any] else { problem(at, "must be an object"); continue }
    unknownKeys(l, ["tags", "stamp", "icon", "comment", "badge"], at)

    var tags: [Tag] = []
    if let v = l["tags"] {
      if let list = v as? [Any] {
        for (i, item) in list.enumerated() {
          guard let m = item as? [String: Any], m.count == 1, let (tag, c) = m.first, let cname = c as? String else {
            problem("\(at).tags[\(i)]", "must be { name: colour }"); continue
          }
          guard let colour = Colour(name: cname) else {
            problem("\(at).tags[\(i)]", "'\(cname)' is not a colour: \(Colour.allCases.map(\.name).joined(separator: ", "))")
            continue
          }
          if !ownedTags.contains(tag) { problem("\(at).tags[\(i)]", "tag '\(tag)' is not in owns.tags") }
          tags.append(Tag(name: tag, colour: colour))
        }
      } else { problem("\(at).tags", "must be a list") }
    }

    var stamp: Stamp?
    if let v = l["stamp"] {
      if let m = v as? [String: Any], m.count == 1, let (k, s) = m.first, let text = s as? String, k == "sym" || k == "emoji" {
        stamp = k == "sym" ? .sym(text) : .emoji(text)
      } else { problem("\(at).stamp", "must be { sym: name } or { emoji: text }") }
      if !ownsStamp { problem("\(at).stamp", "the punch does not own the stamp (owns.stamp)") }
    }

    var icon: URL?
    if let v = l["icon"] {
      if let p = v as? String {
        let u = URL(fileURLWithPath: p, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
        if !FileManager.default.fileExists(atPath: u.path) { problem("\(at).icon", "\(u.path) does not exist") }
        else if NSImage(contentsOf: u) == nil { problem("\(at).icon", "\(u.path) is not a picture") }
        icon = u
      } else { problem("\(at).icon", "must be a path") }
      if !ownsIcon { problem("\(at).icon", "the punch does not own the icon (owns.icon)") }
    }

    var comment: String?
    if let v = l["comment"] {
      if let text = v as? String, !text.isEmpty { comment = text } else { problem("\(at).comment", "must be text, not empty") }
      if !ownsComment { problem("\(at).comment", "the punch does not own the comment (owns.comment)") }
    }

    let isBadge = l["badge"] != nil
    if isBadge && l["badge"] as? String == nil { problem("\(at).badge", "must be a path") }
    let written = ["tags", "stamp", "icon", "comment"].contains { l[$0] != nil }
    if isBadge && written { problem(at, "a badge look has no written parts") }
    if !isBadge && !written { problem(at, "a written look needs tags, a stamp, an icon or a comment") }
    looks[name] = Look(name: name, tags: tags, stamp: stamp, icon: icon, comment: comment, isBadge: isBadge)
  }

  if !problems.isEmpty { throw Refused(problems: problems) }
  return Punch(name: url.deletingPathExtension().lastPathComponent, ownedTags: Set(ownedTags),
               ownsStamp: ownsStamp, ownsIcon: ownsIcon, ownsComment: ownsComment, looks: looks)
}

// Under --live a punch may own only live parts: the comment, and badges once they exist (live-owns-only-comments).
func liveProblems(_ p: Punch) -> [Problem] {
  [("owns.tags", !p.ownedTags.isEmpty), ("owns.stamp", p.ownsStamp), ("owns.icon", p.ownsIcon)]
    .filter(\.1).map { Problem(at: $0.0, problem: "a live punch owns only comments") }
}
