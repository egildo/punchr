// What strike will change on each folder, computed from its dress before anything is written, and doing it.
import Foundation

// What is added, removed or left, for reporting.
struct Parts: Equatable {
  var tags: [Tag] = []
  var stamp: Stamp?
  var icon = false
  var isEmpty: Bool { tags.isEmpty && stamp == nil && !icon }
}

enum Action<T: Equatable>: Equatable { case leave, set(T), remove }

struct FolderPlan {
  let path: String
  var add = Parts(), remove = Parts(), keep = Parts()
  var entries: [String]? // the folder's whole new tag list, when its tags change
  var stamp: Action<Stamp> = .leave
  var icon: Action<Data> = .leave // the resource fork to write
  var error: String?
  var changes: Bool { !add.isEmpty || !remove.isEmpty }
}

// Strike of look `look` of `punch`: everything the punch owns becomes what the look puts there, the rest stays
// (keep-unowned-tags, one-look-per-punch). `fork` is the look's icon, rendered once by the caller.
func planStrike(_ path: String, _ punch: Punch, _ look: Look, fork: Data?) -> FolderPlan {
  var p = FolderPlan(path: path)
  let dress: Dress
  do { dress = try readDress(path) } catch { p.error = "\(error)"; return p }

  var entries: [String] = [], kept = Set<String>()
  for entry in dress.entries {
    let tag = Tag(entry: entry)
    guard punch.ownedTags.contains(tag.name) else { entries.append(entry); continue }
    if look.tags.contains(tag) && !kept.contains(tag.name) {
      kept.insert(tag.name); p.keep.tags.append(tag); entries.append(entry)
    } else { p.remove.tags.append(tag) }
  }
  for tag in look.tags where !kept.contains(tag.name) { p.add.tags.append(tag); entries.append(tag.entry) }
  if !p.add.tags.isEmpty || !p.remove.tags.isEmpty { p.entries = entries }

  if punch.ownsStamp {
    if dress.stamp == look.stamp { p.keep.stamp = look.stamp } else {
      p.remove.stamp = dress.stamp
      p.add.stamp = look.stamp
      p.stamp = look.stamp.map(Action.set) ?? .remove
    }
  }

  if punch.ownsIcon {
    let current = dress.icon ? (try? readIcon(path)) ?? nil : nil
    let hasFile = FileManager.default.fileExists(atPath: iconFile(path))
    if let fork {
      if current == fork { p.keep.icon = true } else {
        p.remove.icon = dress.icon
        p.add.icon = true
        p.icon = .set(fork)
      }
    } else if dress.icon || hasFile {
      p.remove.icon = true
      p.icon = .remove
    }
  }
  return p
}

// Writes each plan; a folder that fails is reported and the others go on (fail-per-folder).
func carryOut(_ plans: [FolderPlan]) -> [FolderPlan] {
  var shared: [dev_t: String] = [:]
  for p in plans where p.error == nil && p.keep.icon {
    if let dev = deviceOf(p.path) { shared[dev] = shared[dev] ?? iconFile(p.path) }
  }
  return plans.map { p in
    guard p.error == nil, p.changes else { return p }
    var p = p
    do {
      if let entries = p.entries { try writeTags(p.path, entries) }
      switch p.stamp { case .leave: break; case .set(let s): try writeStamp(p.path, s); case .remove: try writeStamp(p.path, nil) }
      switch p.icon { case .leave: break; case .set(let fork): try putIcon(p.path, fork, &shared); case .remove: try removeIcon(p.path) }
    } catch { p.error = "\(error)" }
    return p
  }
}
