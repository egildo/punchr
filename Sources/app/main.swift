// The punchr command (specs/001-punch-and-strike/contracts/cli.md). The app's executable; it also hosts the extension.
import Foundation

let usage = """
  usage: punchr strike <punch> <look> <folder>... [--force] [--live] [--json]
         punchr read <folder>... [--punch <punch>]... [--json]
         punchr clear <punch> <folder>... [--force] [--live] [--json]
  """

var args = Array(CommandLine.arguments.dropFirst())
let force = args.contains("--force"), json = args.contains("--json"), live = args.contains("--live")
args.removeAll { $0 == "--force" || $0 == "--json" || $0 == "--live" }

func emit(_ obj: Any) {
  let data = try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
  print(String(decoding: data, as: UTF8.self))
}

func fail(_ message: String, problems: [Problem] = []) -> Never {
  if json {
    emit(["problems": problems.isEmpty ? [["at": "", "problem": message]] : problems.map { ["at": $0.at, "problem": $0.problem] }])
  } else {
    FileHandle.standardError.write(Data("punchr: \(message)\n".utf8))
    for p in problems { FileHandle.standardError.write(Data("  \(p.at.isEmpty ? "" : "\(p.at): ")\(p.problem)\n".utf8)) }
  }
  exit(2)
}

func load(_ arg: String) -> Punch {
  let url = punchURL(arg)
  do { return try readPunch(url) } catch let r as Refused { fail("punch \(url.path) refused", problems: r.problems) } catch { fail("\(error)") }
}

// A punch for strike or clear; under --live it must own only live parts (live-owns-only-comments).
func loadToWrite(_ arg: String) -> Punch {
  let punch = load(arg), problems = live ? liveProblems(punch) : []
  if !problems.isEmpty { fail("punch \(punchURL(arg).path) refused under --live", problems: problems) }
  return punch
}

func nullable(_ s: String?) -> Any { s ?? NSNull() }

func stampJSON(_ s: Stamp?) -> Any {
  switch s { case nil: NSNull(); case .sym(let t): ["sym": t]; case .emoji(let t): ["emoji": t]; case .raw(let t): ["raw": t] }
}

func partsJSON(_ p: Parts) -> [String: Any] {
  ["tags": p.tags.map { ["name": $0.name, "colour": $0.colour.name] }, "stamp": stampJSON(p.stamp), "icon": p.icon,
   "comment": nullable(p.comment)]
}

// A removed comment no look of the punch writes was written by someone else, by hand most often.
func planLines(_ p: FolderPlan, _ punch: Punch) {
  if let e = p.error { print("✗ \(e)"); return }
  if !p.changes { print("✓ \(p.path): nothing to change"); return }
  print("· \(p.path)")
  for t in p.remove.tags { print("    − tag \(t.name) (\(t.colour.name))") }
  for t in p.add.tags { print("    + tag \(t.name) (\(t.colour.name))") }
  if let s = p.remove.stamp { print("    − stamp \(s.text)") }
  if let s = p.add.stamp { print("    + stamp \(s.text)") }
  if p.remove.icon { print("    − icon") }
  if p.add.icon { print("    + icon") }
  if let c = p.remove.comment {
    print("    − comment \(c)\(punch.looks.values.contains { $0.comment == c } ? "" : " (not this punch's)")")
  }
  if let c = p.add.comment { print("    + comment \(c)") }
}

// Plans, then writes with --force, asks at a terminal, stops at the plan otherwise (ask-at-a-terminal).
func run(_ verb: String, _ punch: Punch, _ header: [String: Any], _ plans: [FolderPlan]) -> Never {
  var plans = plans
  let anything = plans.contains { $0.error == nil && $0.changes }
  if !json { plans.forEach { planLines($0, punch) } }
  var write = force
  if !force && !json && anything && isatty(0) == 1 && isatty(1) == 1 {
    print("\(verb.prefix(1).uppercased() + verb.dropFirst())? [y/N] ", terminator: "")
    write = readLine()?.lowercased() == "y"
  }
  if write && anything {
    plans = carryOut(plans)
    if !json { for p in plans where p.changes { print(p.error.map { "✗ \($0)" } ?? "✓ \(p.path)") } }
  }
  if json {
    var doc = header
    doc["written"] = write && anything
    doc["folders"] = plans.map { p -> [String: Any] in
      if let e = p.error { return ["path": p.path, "error": e] }
      return ["path": p.path, "add": partsJSON(p.add), "remove": partsJSON(p.remove), "keep": partsJSON(p.keep)]
    }
    emit(doc)
  }
  exit(plans.contains { $0.error != nil } ? 1 : 0)
}

switch args.first {
case "strike":
  guard args.count >= 4 else { fail("strike needs a punch, a look and at least one folder\n\(usage)") }
  let punch = loadToWrite(args[1])
  guard let look = punch.looks[args[2]] else { fail("punch \(punch.name) has no look \(args[2])") }
  if look.isBadge { fail("\(look.name) is a badge look: badges are drawn live, not struck") }
  let fork: Data?
  do { fork = try look.icon.map(iconFork) } catch { fail("\(error)") }
  let plans = args.dropFirst(3).map { planStrike($0, punch, look, fork: fork) }
  run("strike", punch, ["punch": punch.name, "look": look.name], plans)
case "clear":
  guard args.count >= 3 else { fail("clear needs a punch and at least one folder\n\(usage)") }
  let punch = loadToWrite(args[1])
  run("clear", punch, ["punch": punch.name], args.dropFirst(2).map { planClear($0, punch) })
case "read":
  var folders = Array(args.dropFirst()), given: [String] = []
  while let i = folders.firstIndex(of: "--punch") {
    guard i + 1 < folders.count else { fail("--punch needs a punch name or path") }
    given.append(folders[i + 1]); folders.removeSubrange(i...i + 1)
  }
  guard !folders.isEmpty else { fail("read needs at least one folder\n\(usage)") }
  // The punches given with --punch (read-a-given-punch), or every punch in the punch folder,
  // where a broken one is reported and left out.
  let files = ((try? FileManager.default.contentsOfDirectory(at: punchFolder, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension == "json5" }.sorted { $0.path < $1.path }
  let punches = !given.isEmpty ? given.map(load) : files.compactMap { url -> Punch? in
    do { return try readPunch(url) } catch let r as Refused {
      FileHandle.standardError.write(Data("punchr: punch \(url.path) refused, left out: \(r.problems.map { "\($0.at) \($0.problem)" }.joined(separator: "; "))\n".utf8))
    } catch {}
    return nil
  }
  var forks: [String: Data?] = [:] // a look's icon, rendered once, only when a folder has an icon
  func fork(_ punch: Punch) -> (Look) -> Data? {
    { look in
      let key = "\(punch.name)/\(look.name)"
      if forks[key] == nil { forks[key] = look.icon.flatMap { try? iconFork($0) } }
      return forks[key]!
    }
  }
  var failed = false, out: [[String: Any]] = []
  for path in folders {
    let dress: Dress
    do { dress = try readDress(path) } catch {
      failed = true
      if json { out.append(["path": path, "error": "\(error)"]) } else { print("✗ \(error)") }
      continue
    }
    let matches = punches.map { ($0.name, match(dress, path, $0, fork: fork($0))) }
    if json {
      out.append(["path": path, "wears": ["tags": dress.tags.map { ["name": $0.name, "colour": $0.colour.name] },
                                         "stamp": stampJSON(dress.stamp), "icon": dress.icon,
                                         "comment": nullable(dress.comment)],
                  "matches": Dictionary(uniqueKeysWithValues: matches.map { ($0.0, $0.1 as Any? ?? NSNull()) })])
    } else {
      print(path)
      for t in dress.tags { print("    tag \(t.name) (\(t.colour.name))") }
      if let s = dress.stamp { print("    stamp \(s.text)") }
      if dress.icon { print("    icon") }
      if let c = dress.comment { print("    comment \(c)") }
      if dress == Dress() { print("    nothing") }
      for (p, l) in matches { print("    \(p): \(l ?? "no look")") }
    }
  }
  if json { emit(["folders": out]) }
  exit(failed ? 1 : 0)
default:
  print(usage)
  exit(args.isEmpty ? 0 : 2)
}
