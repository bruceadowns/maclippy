import AppKit
import SwiftUI

struct ClipMenu: View {
    let monitor: ClipboardMonitor

    @Environment(\.openSettings) private var openSettings

    // Hard-coded until a user preference exists; documented in the README.
    static let maxItemLength = 36

    var body: some View {
        if monitor.pinned.isEmpty, monitor.recent.isEmpty {
            Text("No clips yet")
        }
        ForEach(monitor.pinned) { clip in
            Button(label(for: clip)) { monitor.paste(clip) }
        }
        if !monitor.pinned.isEmpty {
            Divider()
        }
        ForEach(monitor.recent) { clip in
            Button(label(for: clip)) { monitor.paste(clip) }
        }
        Divider()
        Button(monitor.isPaused ? "Resume Maclippy" : "Pause Maclippy") {
            monitor.isPaused.toggle()
        }
        Button("Clear Unpinned History...") {
            ClipActions.confirmClearHistory(monitor)
        }
        Button("Preferences...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Button("Quit Maclippy") { NSApplication.shared.terminate(nil) }
    }

    private func label(for clip: Clip) -> String {
        truncated(revealWhitespace(clip.plain))
    }

    private func truncated(_ title: String) -> String {
        guard title.count > Self.maxItemLength else { return title }
        return String(title.prefix(Self.maxItemLength - 1)) + "…"
    }

    /// Makes leading/trailing whitespace visible so verbatim-distinct clips
    /// (e.g. "foobar" vs " foobar ") don't render identically. Interior spaces
    /// stay literal; newlines collapse to a glyph to keep the item one line.
    private func revealWhitespace(_ plain: String) -> String {
        let chars = Array(plain)
        guard let first = chars.firstIndex(where: { !$0.isWhitespace }),
              let last = chars.lastIndex(where: { !$0.isWhitespace }) else {
            return plain
        }
        var out = ""
        for (i, char) in chars.enumerated() {
            let edge = i < first || i > last
            switch char {
            case "\n", "\r": out.append("⏎")
            case "\t": out.append(edge ? "⇥" : "\t")
            case " ": out.append(edge ? "·" : " ")
            default: out.append(char)
            }
        }
        return out
    }
}
