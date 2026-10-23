// What strike will change on each folder, computed from its dress before anything is written, and doing it.
import Foundation

// What is added, removed or left, for reporting.
struct Parts: Equatable {
  var tags: [Tag] = []
  var stamp: Stamp?
  var icon = false
  var comment: String?
  var isEmpty: Bool { tags.isEmpty && stamp == nil && !icon && comment == nil }
}

enum Action<T: Equatable>: Equatable { case leave, set(T), remove }

struct FolderPlan {
  let path: String
  var add = Parts(), remove = Parts(), keep = Parts()
  var entries: [String]? // the folder's whole new tag list, when its tags change
  var stamp: Action<Stamp> = .leave
  var icon: Action<Data> = .leave // the resource fork to write
  var comment: Action<String> = .leave
  var error: String?
  var changes: Bool { !add.isEmpty || !remove.isEmpty }
}

// Strike of look `look` of `punch`: everything the punch owns becomes what the look puts there, the rest stays
// (keep-unowned-tags, one-look-per-punch). `fork` is the look's icon, rendered once by the caller.
func planStrike(_ path: String, _ punch: Punch, _ look: Look, fork: Data?) -> FolderPlan {
  var p = FolderPlan(path: path)
  let dress: Dress
  do { dress = try readDress(path) } catch { p.error = "\(error)"; return p }
  if dress.isFile && (look.stamp != nil || look.icon != nil) {
    p.error = "\(FolderError(path, "a file wears no stamp or icon"))"; return p
  }

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

  if punch.ownsStamp && !dress.isFile {
    if dress.stamp == look.stamp { p.keep.stamp = look.stamp } else {
      p.remove.stamp = dress.stamp
      p.add.stamp = look.stamp
      p.stamp = look.stamp.map(Action.set) ?? .remove
    }
  }

  if punch.ownsIcon && !dress.isFile {
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

  // The punch owns the comment whole: one written by hand goes too (own-the-comment-whole).
  if punch.ownsComment {
    if dress.comment == look.comment { p.keep.comment = look.comment } else {
      p.remove.comment = dress.comment
      p.add.comment = look.comment
      p.comment = look.comment.map(Action.set) ?? .remove
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
      switch p.comment { case .leave: break; case .set(let c): try writeComment(p.path, c); case .remove: try writeComment(p.path, nil) }
    } catch { p.error = "\(error)" }
    return p
  }
}

// Clear of `punch`: everything it owns goes, the rest stays.
func planClear(_ path: String, _ punch: Punch) -> FolderPlan {
  var p = FolderPlan(path: path)
  let dress: Dress
  do { dress = try readDress(path) } catch { p.error = "\(error)"; return p }
  let entries = dress.entries.filter { !punch.ownedTags.contains(Tag(entry: $0).name) }
  p.remove.tags = dress.tags.filter { punch.ownedTags.contains($0.name) }
  if !p.remove.tags.isEmpty { p.entries = entries }
  if punch.ownsStamp, let s = dress.stamp { p.remove.stamp = s; p.stamp = .remove }
  if punch.ownsIcon && !dress.isFile && (dress.icon || FileManager.default.fileExists(atPath: iconFile(path))) {
    p.remove.icon = true; p.icon = .remove
  }
  if punch.ownsComment, let c = dress.comment { p.remove.comment = c; p.comment = .remove }
  return p
}

// The look of `punch` the dress matches: everything the punch owns is exactly what the look puts there
// (read-which-look-matches). `fork` gives a look's rendered icon; it is asked only when a folder has an icon.
func match(_ dress: Dress, _ path: String, _ punch: Punch, fork: (Look) -> Data?) -> String? {
  let owned = dress.tags.filter { punch.ownedTags.contains($0.name) }
  for look in punch.looks.values.sorted(by: { $0.name < $1.name }) where !look.isBadge {
    guard owned.count == look.tags.count, owned.allSatisfy(look.tags.contains) else { continue }
    if punch.ownsStamp && dress.stamp != look.stamp { continue }
    if punch.ownsComment && dress.comment != look.comment { continue }
    if punch.ownsIcon {
      if look.icon == nil {
        if dress.icon { continue }
      } else {
        let current = dress.icon ? (try? readIcon(path)) ?? nil : nil
        if current == nil || current != fork(look) { continue }
      }
    }
    return look.name
  }
  return nil
}
