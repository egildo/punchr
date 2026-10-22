// The first test of the Finder Sync extension: watches the user's home, puts one badge on any folder named lean-a.
import Cocoa
import FinderSync
import os

let log = Logger(subsystem: "local.punchr", category: "badge")

class FinderSync: FIFinderSync {
  // The real home, not the sandbox container that NSHomeDirectory() returns here.
  // ponytail: one fixed root; declared roots come with the feed file.
  let root = URL(fileURLWithPath: String(cString: getpwuid(getuid())!.pointee.pw_dir))

  override init() {
    super.init()
    let c = FIFinderSyncController.default()
    c.directoryURLs = [root]
    let badge = NSImage(size: NSSize(width: 320, height: 320), flipped: false) { r in
      NSColor.systemOrange.setFill()
      NSBezierPath(ovalIn: r.insetBy(dx: 10, dy: 10)).fill()
      let arrow = NSBezierPath()
      arrow.move(to: NSPoint(x: 160, y: 250)); arrow.line(to: NSPoint(x: 250, y: 150)); arrow.line(to: NSPoint(x: 190, y: 150))
      arrow.line(to: NSPoint(x: 190, y: 70)); arrow.line(to: NSPoint(x: 130, y: 70)); arrow.line(to: NSPoint(x: 130, y: 150))
      arrow.line(to: NSPoint(x: 70, y: 150)); arrow.close()
      NSColor.white.setFill(); arrow.fill()
      return true
    }
    c.setBadgeImage(badge, label: "Ahead", forBadgeIdentifier: "ahead")
    log.notice("watching \(self.root.path, privacy: .public)")
  }

  override func beginObservingDirectory(at url: URL) { log.notice("observing \(url.path, privacy: .public)") }

  override func requestBadgeIdentifier(for url: URL) {
    log.notice("asked for \(url.path, privacy: .public)")
    if url.lastPathComponent == "lean-a" { FIFinderSyncController.default().setBadgeIdentifier("ahead", for: url) }
  }
}
