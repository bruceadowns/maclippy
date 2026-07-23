import AppKit
import SwiftUI

struct ClipMenu: View {
    let monitor: ClipboardMonitor

    @Environment(\.openSettings) private var openSettings

    // Hard-coded until a user preference exists; documented in the README.
    static let maxItemLength = 36

    var body: some View {
        Button("Clear Formatting") { monitor.clearFormatting() }
        Button(monitor.isPaused ? "Resume Maclippy" : "Pause Maclippy") {
            monitor.isPaused.toggle()
        }
        Divider()
        if monitor.pinned.isEmpty, monitor.recent.isEmpty {
            Text("No clips yet")
        }
        ForEach(monitor.pinned) { clip in
            Button { monitor.paste(clip) } label: { menuLabel(for: clip) }
        }
        if !monitor.pinned.isEmpty {
            Divider()
        }
        ForEach(monitor.recent) { clip in
            Button(label(for: clip)) { monitor.paste(clip) }
        }
        Divider()
        // No ellipsis: Apple convention for "About <App>" (unlike Preferences…).
        Button("About Maclippy") { ClipActions.showAbout() }
        Button("Preferences…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Button("Quit Maclippy") { NSApplication.shared.terminate(nil) }
    }

    @ViewBuilder
    private func menuLabel(for clip: Clip) -> some View {
        if clip.customLabel != nil {
            Label(label(for: clip), systemImage: "key.fill")
        } else {
            Text(label(for: clip))
        }
    }

    private func label(for clip: Clip) -> String {
        // A custom name cloaks the content, so show it verbatim (no
        // whitespace-reveal, which only helps disambiguate raw clips).
        if let custom = clip.customLabel { return truncated(custom) }
        return truncated(clip.revealedPlain)
    }

    private func truncated(_ title: String) -> String {
        guard title.count > Self.maxItemLength else { return title }
        return String(title.prefix(Self.maxItemLength - 1)) + "…"
    }
}
