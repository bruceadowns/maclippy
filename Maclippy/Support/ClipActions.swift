import AppKit

enum ClipActions {
    /// Confirms, then clears recent clips (pinned items are kept).
    static func confirmClearHistory(_ monitor: ClipboardMonitor) {
        let alert = NSAlert()
        alert.messageText = "Clear recent clips?"
        alert.informativeText = "Pinned items are kept."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        // Agent apps get a blank default alert icon, so draw our own to match the
        // teal app icon (asset-catalog icons aren't reliably loadable at runtime).
        alert.icon = appIcon()
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            monitor.clearHistory()
        }
    }

    private static func appIcon(size: CGFloat = 128) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let teal = NSColor(srgbRed: 0.059, green: 0.710, blue: 0.682, alpha: 1.0)
            let margin = size * 0.08
            let square = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
            let radius = square.width * 0.2237
            teal.setFill()
            NSBezierPath(roundedRect: square, xRadius: radius, yRadius: radius).fill()

            let glyphPt = square.width * 0.46
            let config = NSImage.SymbolConfiguration(pointSize: glyphPt, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            if let glyph = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let s = glyph.size
                glyph.draw(at: NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2),
                           from: .zero, operation: .sourceOver, fraction: 1.0)
            }
            return true
        }
    }
}
