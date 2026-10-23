// What a folder wears, read from and written to its extended attributes (formats in notes/2026-10-22-findings.md).
import Foundation

enum Attr {
  static let tags = "com.apple.metadata:_kMDItemUserTags"
  static let stamp = "com.apple.icon.folder#S"
  static let finderInfo = "com.apple.FinderInfo"
  static let fork = "com.apple.ResourceFork"
  static let comment = "com.apple.metadata:kMDItemFinderComment"
}

struct FolderError: Error, CustomStringConvertible {
  let description: String
  init(_ path: String, _ what: String = String(cString: strerror(errno))) { description = "\(path): \(what)" }
}

func getAttr(_ path: String, _ name: String) throws -> Data? {
  let size = getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)
  if size < 0 { if errno == ENOATTR { return nil }; throw FolderError(path) }
  var data = Data(count: size)
  let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, XATTR_NOFOLLOW) }
  if read < 0 { throw FolderError(path) }
  return data.prefix(read)
}

func setAttr(_ path: String, _ name: String, _ data: Data) throws {
  let r = data.withUnsafeBytes { setxattr(path, name, $0.baseAddress, data.count, 0, XATTR_NOFOLLOW) }
  if r < 0 { throw FolderError(path) }
}

func removeAttr(_ path: String, _ name: String) throws {
  if removexattr(path, name, XATTR_NOFOLLOW) < 0 && errno != ENOATTR { throw FolderError(path) }
}

func listAttrs(_ path: String) throws -> [String] {
  let size = listxattr(path, nil, 0, XATTR_NOFOLLOW)
  if size < 0 { throw FolderError(path) }
  if size == 0 { return [] }
  var buf = [CChar](repeating: 0, count: size)
  if listxattr(path, &buf, size, XATTR_NOFOLLOW) < 0 { throw FolderError(path) }
  return buf.split(separator: 0).map { String(decoding: $0.map { UInt8(bitPattern: $0) }, as: UTF8.self) }
}

// Folders and regular files; links are never followed (folders-and-files). True for a folder.
func isFolder(_ path: String) throws -> Bool {
  var st = stat()
  if lstat(path, &st) < 0 { throw FolderError(path) }
  switch st.st_mode & S_IFMT {
  case S_IFDIR: return true
  case S_IFREG: return false
  case S_IFLNK: throw FolderError(path, "a link: links are not followed")
  default: throw FolderError(path, "not a folder or a file")
  }
}

struct Dress: Equatable {
  var entries: [String] = [] // the tags as Finder wrote them, "name\nN" or "name"
  var stamp: Stamp?
  var icon = false
  var comment: String?
  var isFile = false // a file wears no stamp or icon (a-file-wears-no-stamp-or-icon)
  var tags: [Tag] { entries.map(Tag.init(entry:)) }
}

func readDress(_ path: String) throws -> Dress {
  var d = Dress()
  d.isFile = try !isFolder(path)
  if let data = try getAttr(path, Attr.tags) {
    d.entries = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String] ?? []
  }
  if let data = try getAttr(path, Attr.comment) {
    let text = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? String
    d.comment = text?.isEmpty == false ? text : nil
  }
  if d.isFile { return d }
  if let data = try getAttr(path, Attr.stamp) {
    let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
    d.stamp = obj?["sym"].map(Stamp.sym) ?? obj?["emoji"].map(Stamp.emoji)
      ?? .raw(String(decoding: data, as: UTF8.self))
  }
  // The custom-icon bit shows both the stamp and the icon; without it Finder draws a plain folder.
  let bit = try getAttr(path, Attr.finderInfo).map { $0.count > 8 && $0[$0.startIndex + 8] & 0x04 != 0 } ?? false
  if !bit { d.stamp = nil }
  d.icon = bit && FileManager.default.fileExists(atPath: iconFile(path))
  return d
}

// Sets the comment through Finder itself, so it lands in the attribute and in the parent's .DS_Store and Finder
// shows it at once; nil removes it, and the empty attribute Finder leaves behind (notes/2026-10-23-comments.md).
func writeComment(_ path: String, _ text: String?) throws {
  func literal(_ s: String) -> String {
    "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
  }
  let full = URL(fileURLWithPath: path).path
  let source = "tell application \"Finder\" to set comment of (POSIX file \(literal(full)) as alias) to \(literal(text ?? ""))"
  var error: NSDictionary?
  if NSAppleScript(source: source)?.executeAndReturnError(&error) == nil {
    let n = error?[NSAppleScript.errorNumber] as? Int ?? 0
    throw FolderError(path, n == -1743
      ? "macOS does not let punchr control Finder: allow it in System Settings → Privacy & Security → Automation"
      : "Finder could not set the comment (\(n)): \(error?[NSAppleScript.errorMessage] ?? "")")
  }
  if text == nil { try removeAttr(path, Attr.comment) }
}

// Every tag written carries its colour number (write-the-colour-number); the caller passes entries it keeps as found.
func writeTags(_ path: String, _ entries: [String]) throws {
  if entries.isEmpty { return try removeAttr(path, Attr.tags) }
  try setAttr(path, Attr.tags, PropertyListSerialization.data(fromPropertyList: entries, format: .binary, options: 0))
}

// A stamp shows only with the custom-icon bit, which it shares with the icon: removing it keeps the bit for an icon.
func writeStamp(_ path: String, _ stamp: Stamp?) throws {
  switch stamp {
  case nil: try removeAttr(path, Attr.stamp)
  case .sym(let s): try setAttr(path, Attr.stamp, JSONSerialization.data(withJSONObject: ["sym": s]))
  case .emoji(let s): try setAttr(path, Attr.stamp, JSONSerialization.data(withJSONObject: ["emoji": s]))
  case .raw(let s): try setAttr(path, Attr.stamp, Data(s.utf8))
  }
  try setFinderBit(path, 0x04, stamp != nil || FileManager.default.fileExists(atPath: iconFile(path)))
}

// Sets or clears one bit of byte 8 of the Finder information, every other byte as found (set-only-the-icon-bit).
func setFinderBit(_ path: String, _ bit: UInt8, _ on: Bool) throws {
  var info = try getAttr(path, Attr.finderInfo) ?? Data(count: 32)
  if info.count < 32 { info.append(Data(count: 32 - info.count)) }
  let i = info.startIndex + 8
  info[i] = on ? info[i] | bit : info[i] & ~bit
  if info.allSatisfy({ $0 == 0 }) { try removeAttr(path, Attr.finderInfo) } else { try setAttr(path, Attr.finderInfo, info) }
}
