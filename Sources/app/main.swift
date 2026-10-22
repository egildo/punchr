// The punchr command (specs/001-punch-and-strike/contracts/cli.md). The app's executable; it also hosts the extension.
import Foundation

let usage = """
  usage: punchr strike <punch> <look> <folder>... [--force] [--json]
         punchr read <folder>... [--json]
         punchr clear <punch> <folder>... [--force] [--json]
  """

var args = Array(CommandLine.arguments.dropFirst())
let force = args.contains("--force"), json = args.contains("--json")
args.removeAll { $0 == "--force" || $0 == "--json" }

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

func stampJSON(_ s: Stamp?) -> Any {
  switch s { case nil: NSNull(); case .sym(let t): ["sym": t]; case .emoji(let t): ["emoji": t]; case .raw(let t): ["raw": t] }
}

func partsJSON(_ p: Parts) -> [String: Any] {
  ["tags": p.tags.map { ["name": $0.name, "colour": $0.colour.name] }, "stamp": stampJSON(p.stamp), "icon": p.icon]
}

func planLines(_ p: FolderPlan) {
  if let e = p.error { print("✗ \(e)"); return }
  if !p.changes { print("✓ \(p.path): nothing to change"); return }
  print("· \(p.path)")
  for t in p.remove.tags { print("    − tag \(t.name) (\(t.colour.name))") }
  for t in p.add.tags { print("    + tag \(t.name) (\(t.colour.name))") }
  if let s = p.remove.stamp { print("    − stamp \(s.text)") }
  if let s = p.add.stamp { print("    + stamp \(s.text)") }
  if p.remove.icon { print("    − icon") }
  if p.add.icon { print("    + icon") }
}

// Plans, then writes with --force, asks at a terminal, stops at the plan otherwise (ask-at-a-terminal).
func run(_ verb: String, _ header: [String: Any], _ plans: [FolderPlan]) -> Never {
  var plans = plans
  let anything = plans.contains { $0.error == nil && $0.changes }
  if !json { plans.forEach(planLines) }
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
  let punch = load(args[1])
  guard let look = punch.looks[args[2]] else { fail("punch \(punch.name) has no look \(args[2])") }
  if look.isBadge { fail("\(look.name) is a badge look: badges are drawn live, not struck") }
  let fork: Data?
  do { fork = try look.icon.map(iconFork) } catch { fail("\(error)") }
  let plans = args.dropFirst(3).map { planStrike($0, punch, look, fork: fork) }
  run("strike", ["punch": punch.name, "look": look.name], plans)
case "read", "clear":
  fail("\(args[0]) is not built yet")
default:
  print(usage)
  exit(args.isEmpty ? 0 : 2)
}
