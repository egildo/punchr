// The checks: one per requirement or outcome they prove, run in a fresh temporary folder that is deleted after.
import Foundation

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("punchr-checks-\(getpid())").path
try! fm.createDirectory(atPath: root, withIntermediateDirectories: true)
var failures = 0

struct CheckFailed: Error, CustomStringConvertible { let description: String }
func expect(_ ok: Bool, _ what: @autoclosure () -> String) throws { if !ok { throw CheckFailed(description: what()) } }

func check(_ name: String, _ body: () throws -> Void) {
  do { try body(); print("✓ \(name)") } catch { failures += 1; print("✗ \(name): \(error)") }
}

var serial = 0
func folder(_ name: String = "f") -> String {
  serial += 1
  let p = "\(root)/\(serial)-\(name)"
  try! fm.createDirectory(atPath: p, withIntermediateDirectories: true)
  return p
}

func punch(_ name: String, _ source: String) throws -> Punch {
  let p = "\(root)/\(name).json5"
  try source.write(toFile: p, atomically: true, encoding: .utf8)
  return try readPunch(URL(fileURLWithPath: p))
}

// Every attribute of a path, byte for byte.
func attrs(_ path: String) throws -> [String: Data] {
  var all: [String: Data] = [:]
  for name in try listAttrs(path) { all[name] = try getAttr(path, name) }
  return all
}

func strike(_ paths: [String], _ p: Punch, _ look: String) throws -> [FolderPlan] {
  let l = p.looks[look]!
  let fork = try l.icon.map(iconFork)
  return carryOut(paths.map { planStrike($0, p, l, fork: fork) })
}

// Quotes, a backslash, an accent (Finder stores it decomposed) and a line break, as JSON5 source.
let zenteComment = #"Zente "client" \\ caffè\ntwo"#
let standin = URL(fileURLWithPath: "experiments/standin.svg").path
let client = """
  {
    owns: { tags: ['client', 'done'], stamp: true, icon: true, comment: true },
    looks: {
      zente: { tags: [{ client: 'grey' }], stamp: { sym: 'star' }, icon: '\(standin)', comment: '\(zenteComment)' },
      plain: { tags: [{ client: 'blue' }] },
      ahead: { badge: 'ahead.svg' },
    },
  }
  """

check("refuse-a-broken-punch") {
  do {
    _ = try punch("broken", "{ owns: { tags: ['a'] }, looks: { x: { tags: [{ a: 'pink' }, { b: 'red' }], stamp: { sym: 'star' }, size: 3 } } }")
    throw CheckFailed(description: "accepted")
  } catch let r as Refused {
    let at = r.problems.map(\.at).sorted()
    try expect(at == ["looks.x.size", "looks.x.stamp", "looks.x.tags[0]", "looks.x.tags[1]"], "problems at \(at)")
  }
}

check("dress round trip, set-only-the-icon-bit") {
  let f = folder()
  try writeTags(f, [Tag(name: "a", colour: .red).entry, Tag(name: "b", colour: .none).entry])
  try writeStamp(f, .emoji("ZENTE"))
  var info = Data(count: 32); info[0] = 0x41; info[9] = 0x0c; info[31] = 0x7f
  try setAttr(f, Attr.finderInfo, info)
  try setFinderBit(f, 0x04, true)
  let d = try readDress(f)
  try expect(d.tags == [Tag(name: "a", colour: .red), Tag(name: "b", colour: .none)], "tags \(d.tags)")
  try expect(d.stamp == .emoji("ZENTE") && !d.icon, "stamp \(String(describing: d.stamp)), icon \(d.icon)")
  try setFinderBit(f, 0x04, false)
  try expect(try getAttr(f, Attr.finderInfo) == info, "Finder information changed beyond the icon bit")
}

check("a stamp shows only with the custom-icon bit") {
  let p = try punch("stamped", "{ owns: { tags: ['s'], stamp: true }, looks: { on: { stamp: { sym: 'star' } }, off: { tags: [{ s: 'red' }] } } }")
  let f = folder()
  _ = try strike([f], p, "on")
  try expect(try getAttr(f, Attr.finderInfo).map { $0[8] & 0x04 != 0 } == true, "bit not set")
  try expect(try readDress(f).stamp == .sym("star"), "stamp not read")
  _ = try strike([f], p, "off")
  try expect(try getAttr(f, Attr.finderInfo) == nil && getAttr(f, Attr.stamp) == nil, "stamp or bit left behind")
}

check("nothing-unowned-changes, keep-unowned-tags") {
  let p = try punch("client", client), f = folder()
  try writeTags(f, ["red-team\n6", "draft"])
  try setAttr(f, "org.example.note", Data("keep me".utf8))
  var info = Data(count: 32); info[0] = 0x41; info[20] = 0x99
  try setAttr(f, Attr.finderInfo, info)
  let plans = try strike([f], p, "zente")
  try expect(plans[0].error == nil, "\(plans[0].error!)")
  let d = try readDress(f)
  try expect(d.entries == ["red-team\n6", "draft", "client\n1"], "tags \(d.entries)")
  try expect(try getAttr(f, "org.example.note") == Data("keep me".utf8), "foreign attribute changed")
  var now = try getAttr(f, Attr.finderInfo)!; now[8] &= ~0x04
  try expect(now == info, "Finder information changed beyond the icon bit")
}

check("plan-matches-write, strike-twice-changes-nothing") {
  let p = try punch("client", client), f = folder()
  try writeTags(f, ["client\n4", "other\n2"])
  let plan = planStrike(f, p, p.looks["zente"]!, fork: try iconFork(URL(fileURLWithPath: standin)))
  _ = carryOut([plan])
  let d = try readDress(f)
  try expect(d.entries == plan.entries, "tags \(d.entries), planned \(String(describing: plan.entries))")
  try expect(d.stamp == plan.add.stamp && d.icon == plan.add.icon, "stamp or icon not as planned")
  try expect(d.comment == "Zente \"client\" \\ caffè\ntwo" && d.comment == plan.add.comment, "comment \(d.comment ?? "none")")
  let before = try attrs(f), icon = try attrs(iconFile(f))
  let again = try strike([f], p, "zente")
  try expect(!again[0].changes, "second plan not empty: \(again[0].add) \(again[0].remove)")
  try expect(try attrs(f) == before && attrs(iconFile(f)) == icon, "a second strike wrote")
}

check("one-look-per-punch") {
  let p = try punch("client", client), f = folder()
  _ = try strike([f], p, "zente")
  _ = try strike([f], p, "plain")
  let d = try readDress(f)
  try expect(d.entries == ["client\n4"] && d.stamp == nil && !d.icon && d.comment == nil, "dress \(d)")
  try expect(!fm.fileExists(atPath: iconFile(f)), "Icon\\r left behind")
}

check("share-one-icon-per-volume, icon-costs-kilobytes") {
  let p = try punch("client", client)
  let folders = (1...12).map { folder("shared\($0)") }
  let plans = try strike(folders, p, "zente")
  try expect(plans.allSatisfy { $0.error == nil }, "a folder failed")
  var inodes = Set<ino_t>(), links = Set<UInt16>()
  for f in folders { var st = stat(); lstat(iconFile(f), &st); inodes.insert(st.st_ino); links.insert(st.st_nlink) }
  try expect(inodes.count == 1 && links == [12], "inodes \(inodes.count), links \(links)")
  let size = try getAttr(iconFile(folders[0]), Attr.fork)!.count
  try expect(size < 25_000, "icon \(size) bytes")
  print("    icon: \(size) bytes, shared by 12 folders")
}

check("fail-per-folder, folders-and-files") {
  let p = try punch("client", client)
  let good = (1...3).map { folder("good\($0)") }
  let file = "\(root)/a-file"; fm.createFile(atPath: file, contents: nil)
  let target = folder("target"), link = "\(root)/a-link"
  try fm.createSymbolicLink(atPath: link, withDestinationPath: target)
  let untouched = try attrs(target) // macOS gives new folders com.apple.provenance
  let locked = folder("locked"); chmod(locked, 0o555)
  defer { chmod(locked, 0o755) }
  let plans = try strike([good[0], file, good[1], link, locked, good[2]], p, "plain")
  let failed = plans.filter { $0.error != nil }.map(\.path)
  try expect(failed == [link, locked], "failed \(failed)")
  for g in good + [file] { try expect(try readDress(g).entries == ["client\n4"], "\(g) not struck") }
  try expect(try attrs(target) == untouched, "the link was followed")
}

// What Finder itself shows as the folder's comment.
func finderComment(_ path: String) throws -> String {
  var error: NSDictionary?
  let r = NSAppleScript(source: "tell application \"Finder\" to get comment of (POSIX file \"\(path)\" as alias)")?
    .executeAndReturnError(&error)
  guard let text = r?.stringValue else { throw CheckFailed(description: "Finder: \(error ?? [:])") }
  return text
}

check("own-the-comment-whole, write-the-comment-through-finder") {
  let p = try punch("client", client), f = folder()
  try writeComment(f, "by hand")
  try expect(try readDress(f).comment == "by hand", "hand-written comment not read")
  let plan = planStrike(f, p, p.looks["plain"]!, fork: nil)
  try expect(plan.remove.comment == "by hand" && plan.add.comment == nil && plan.comment == .remove, "plan \(plan.remove)")
  _ = carryOut([plan])
  try expect(try getAttr(f, Attr.comment) == nil, "an empty comment attribute left behind")
  try expect(try finderComment(f) == "", "Finder still shows a comment")
  _ = try strike([f], p, "zente")
  let shown = try finderComment(f)
  try expect(shown == "Zente \"client\" \\ caffè\ntwo", "Finder shows \(shown)")
  try expect(fm.fileExists(atPath: "\(root)/.DS_Store"), "no .DS_Store: not written through Finder")
}

check("live-owns-only-comments") {
  let p = try punch("client", client)
  try expect(liveProblems(p).map(\.at) == ["owns.tags", "owns.stamp", "owns.icon"], "\(liveProblems(p).map(\.at))")
  let state = try punch("state", "{ owns: { comment: true }, looks: { ahead: { comment: 'AHEAD' }, clean: { comment: 'CLEAN' } } }")
  try expect(liveProblems(state).isEmpty, "a comments-only punch refused")
  do {
    _ = try punch("nocomment", "{ owns: { stamp: true }, looks: { a: { comment: '' }, b: { stamp: { sym: 'star' }, comment: 'x' } } }")
    throw CheckFailed(description: "accepted")
  } catch let r as Refused {
    try expect(r.problems.map(\.at) == ["looks.a.comment", "looks.a.comment", "looks.b.comment"], "\(r.problems.map(\.at))")
  }
  // The command itself: status 2, the problems as JSON, nothing written.
  let f = folder(), before = try attrs(f), run = Process(), out = Pipe()
  run.executableURL = URL(fileURLWithPath: "build/punchr")
  run.arguments = ["strike", "\(root)/client.json5", "plain", f, "--live", "--force", "--json"]
  run.standardOutput = out
  try run.run(); run.waitUntilExit()
  let doc = try JSONSerialization.jsonObject(with: out.fileHandleForReading.readDataToEndOfFile()) as? [String: Any]
  let problems = (doc?["problems"] as? [[String: String]] ?? []).map { "\($0["at"]!): \($0["problem"]!)" }
  try expect(run.terminationStatus == 2, "status \(run.terminationStatus)")
  try expect(problems.first == "owns.tags: a live punch owns only comments" && problems.count == 3, "\(problems)")
  try expect(try attrs(f) == before, "a refused live strike wrote")
}

check("a-file-wears-no-stamp-or-icon, file-strike-then-clear-restores") {
  let p = try punch("client", client)
  let file = "\(root)/notes.txt"; fm.createFile(atPath: file, contents: Data("x".utf8))
  try writeTags(file, ["red-team\n6"])
  let before = try attrs(file)
  let refused = try strike([file], p, "zente")[0]
  try expect(refused.error == "\(file): a file wears no stamp or icon", "\(refused.error ?? "no error")")
  try expect(try attrs(file) == before, "a refused file was written")
  let run = Process(), out = Pipe()
  run.executableURL = URL(fileURLWithPath: "build/punchr")
  run.arguments = ["strike", "\(root)/client.json5", "zente", file, "--force", "--json"]
  run.standardOutput = out
  try run.run(); run.waitUntilExit()
  let doc = try JSONSerialization.jsonObject(with: out.fileHandleForReading.readDataToEndOfFile()) as? [String: Any]
  let entry = (doc?["folders"] as? [[String: Any]])?.first
  try expect(run.terminationStatus == 1 && entry?["error"] as? String == "\(file): a file wears no stamp or icon",
             "status \(run.terminationStatus), \(entry ?? [:])")
  try expect(try attrs(file) == before, "the command wrote to a refused file")
  let filed = try punch("filed", "{ owns: { tags: ['untracked'], stamp: true, icon: true, comment: true }, looks: { untracked: { tags: [{ untracked: 'grey' }], comment: 'untracked' } } }")
  try expect(try strike([file], filed, "untracked")[0].error == nil, "strike on a file failed")
  let d = try readDress(file)
  try expect(d.entries == ["red-team\n6", "untracked\n1"] && d.comment == "untracked" && d.stamp == nil && !d.icon, "dress \(d)")
  try expect(try finderComment(file) == "untracked", "Finder shows another comment")
  try expect(try matchOf(file, filed) == "untracked", "the file matches no look")
  try expect(clear([file], filed)[0].error == nil, "clear on a file failed")
  let after = try attrs(file)
  try expect(after == before, "attributes differ: \(after.keys.sorted())")
}

func clear(_ paths: [String], _ p: Punch) -> [FolderPlan] { carryOut(paths.map { planClear($0, p) }) }

func matchOf(_ path: String, _ p: Punch) throws -> String? {
  try match(readDress(path), path, p) { $0.icon.flatMap { try? iconFork($0) } }
}

check("read-which-look-matches, read-writes-nothing") {
  let p = try punch("client", client)
  let struck = folder(), other = folder(), bare = folder()
  _ = try strike([struck], p, "zente")
  try writeTags(other, ["client\n6"])
  let before = try [struck, other, bare].map(attrs)
  let m = try matchOf(struck, p)
  try expect(m == "zente", "struck folder matches \(String(describing: m))")
  try expect(try matchOf(other, p) == nil && matchOf(bare, p) == nil, "a folder matches a look it does not wear")
  try expect(try [struck, other, bare].map(attrs) == before, "reading wrote")
}

check("read-a-thousand") {
  let p = try punch("client", client)
  let folders = (1...1000).map { _ in folder("many") }
  for f in folders { try writeTags(f, ["client\n4"]) }
  let start = Date()
  for f in folders { try expect(try matchOf(f, p) == "plain", "\(f) does not match plain") }
  let seconds = Date().timeIntervalSince(start)
  try expect(seconds < 5, "\(seconds) s")
  print("    1,000 folders read in \(String(format: "%.2f", seconds)) s")
}

check("strike-then-clear-restores") {
  let p = try punch("client", client), f = folder()
  try writeTags(f, ["red-team\n6"])
  try setAttr(f, "org.example.note", Data("keep me".utf8))
  let before = try attrs(f)
  _ = try strike([f], p, "zente")
  try expect(try attrs(f) != before, "the strike wrote nothing")
  let plans = clear([f], p)
  try expect(plans[0].error == nil, "\(plans[0].error!)")
  let after = try attrs(f)
  try expect(after == before, "attributes differ: \(after.keys.sorted())")
  try expect(!fm.fileExists(atPath: iconFile(f)), "Icon\\r left behind")
  try expect(!clear([f], p)[0].changes, "a second clear plans a change")
}

check("clear-one-keeps-the-others") {
  let p = try punch("client", client)
  let folders = (1...3).map { folder("trio\($0)") }
  _ = try strike(folders, p, "zente")
  _ = clear([folders[0]], p)
  for f in folders.dropFirst() {
    var st = stat(); lstat(iconFile(f), &st)
    try expect(st.st_nlink == 2 && readDress(f).icon, "\(f): links \(st.st_nlink)")
  }
  try expect(try !readDress(folders[0]).icon, "the cleared folder kept its icon")
}

try? fm.removeItem(atPath: root)
exit(failures == 0 ? 0 : 1)
