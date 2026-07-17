import AppKit

enum ClipActions {
    /// Confirms, then clears recent clips (pinned items are kept).
    static func confirmClearHistory(_ monitor: ClipboardMonitor) {
        let alert = NSAlert()
        alert.messageText = "Clear recent clips?"
        alert.informativeText = "Pinned items are kept."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            monitor.clearHistory()
        }
    }
}
