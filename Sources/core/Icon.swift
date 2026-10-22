// A custom folder icon written by hand: an icns with two PNGs in a resource fork on a hidden Icon\r,
// shared through hard links by the folders of one volume (as experiments/lean-icon.ts measured).
import Cocoa

private func be(_ n: Int, _ len: Int) -> [UInt8] { (0..<len).map { UInt8((n >> (8 * (len - 1 - $0))) & 0xff) } }
private func ascii(_ s: String) -> [UInt8] { Array(s.utf8) }

private func png(_ image: NSImage, _ px: Int) -> Data? {
  guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])
}

// The resource fork for a picture: one 'icns' resource, id -16455, holding ic07 (128 px) and ic09 (512 px).
// ponytail: full-colour PNGs, about 20 KB; a palette PNG encoder would bring it near 5 KB.
func iconFork(_ picture: URL) throws -> Data {
  guard let image = NSImage(contentsOf: picture), let p128 = png(image, 128), let p512 = png(image, 512) else {
    throw FolderError(picture.path, "cannot draw the picture")
  }
  func entry(_ type: String, _ png: Data) -> [UInt8] { ascii(type) + be(8 + png.count, 4) + png }
  let body = entry("ic07", p128) + entry("ic09", p512)
  let icns = ascii("icns") + be(8 + body.count, 4) + body

  let data = be(icns.count, 4) + icns, dataOff = 0x100, mapOff = dataOff + data.count, mapLen = 0x32
  let header = be(dataOff, 4) + be(mapOff, 4) + be(data.count, 4) + be(mapLen, 4)
  let map = header + be(0, 4) + be(0, 2) + be(0, 2) // copy of header, next map, file ref, attributes
    + be(0x1c, 2) + be(mapLen, 2) // type list offset, name list offset (empty, at the end)
    + be(0, 2) + ascii("icns") + be(0, 2) + be(0x0a, 2) // one type, one resource, its reference at +10
    + be(0xbfb9, 2) + be(0xffff, 2) + [0] + be(0, 3) + be(0, 4) // id -16455, no name, data at 0
  return Data(header + [UInt8](repeating: 0, count: dataOff - 16) + data + map)
}

func iconFile(_ folder: String) -> String { (folder as NSString).appendingPathComponent("Icon\r") }

// The fork of the folder's Icon\r, if it has one.
func readIcon(_ folder: String) throws -> Data? {
  let f = iconFile(folder)
  return FileManager.default.fileExists(atPath: f) ? try getAttr(f, Attr.fork) : nil
}

func deviceOf(_ path: String) -> dev_t? {
  var st = stat()
  return lstat(path, &st) == 0 ? st.st_dev : nil
}

// Gives the folder the icon; an Icon\r already written on the same volume is linked, not copied
// (share-one-icon-per-volume). `shared` maps a volume to that Icon\r.
func putIcon(_ folder: String, _ fork: Data, _ shared: inout [dev_t: String]) throws {
  let f = iconFile(folder)
  if FileManager.default.fileExists(atPath: f) && unlink(f) < 0 { throw FolderError(f) }
  guard let dev = deviceOf(folder) else { throw FolderError(folder) }
  if let first = shared[dev] {
    if link(first, f) < 0 { throw FolderError(f) }
  } else {
    guard FileManager.default.createFile(atPath: f, contents: nil) else { throw FolderError(f, "cannot create Icon\\r") }
    try setAttr(f, Attr.fork, fork)
    try setFinderBit(f, 0x40, true) // invisible
    shared[dev] = f
  }
  try setFinderBit(folder, 0x04, true) // has a custom icon
}

// Unlinks only this folder's Icon\r; other folders sharing it keep theirs (clear-one-keeps-the-others).
func removeIcon(_ folder: String) throws {
  let f = iconFile(folder)
  if FileManager.default.fileExists(atPath: f) && unlink(f) < 0 { throw FolderError(f) }
  try setFinderBit(folder, 0x04, false)
}
