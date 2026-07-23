import AppKit
import SwiftUI

struct ClipMenu: View {
    let monitor: ClipboardMonitor

    @Environment(\.openSettings) private var openSettings

    // Hard-coded until a user preference exists; documented in the README.
    static let maxItemLength = 36

    // Tooltip cap: a clip can be up to 2 MB (SPEC §4.3); handing that whole
    // string to `.help` janks AppKit's tooltip layout. A peek only needs enough
    // to disambiguate, so cap it well short of the payload.
    static let maxPeekLength = 500

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
                .help(ifPresent: peek(for: clip))
        }
        if !monitor.pinned.isEmpty {
            Divider()
        }
        ForEach(monitor.recent) { clip in
            Button(label(for: clip)) { monitor.paste(clip) }
                .help(ifPresent: peek(for: clip))
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

    // Hover tooltip: peek at a clipped row's content without pasting it. Shows
    // the text *verbatim* — real line breaks and spaces, unlike the one-line
    // glyph-revealed row label — since a tooltip isn't constrained to one line
    // and reads better this way (whitespace-reveal stays the label's job). A
    // cloaked clip peeks its name only — never its hidden payload. nil when the
    // label already fits, so unclipped rows get no redundant tip. Bounded by
    // index math (never `.count`) so a 2 MB clip isn't scanned end-to-end.
    private func peek(for clip: Clip) -> String? {
        let full = clip.customLabel ?? clip.plain
        guard full.index(full.startIndex, offsetBy: Self.maxItemLength + 1, limitedBy: full.endIndex) != nil
        else { return nil }
        let end = full.index(full.startIndex, offsetBy: Self.maxPeekLength - 1, limitedBy: full.endIndex)
        guard let end, end != full.endIndex else { return full }
        return String(full[..<end]) + "…"
    }

    private func truncated(_ title: String) -> String {
        guard title.count > Self.maxItemLength else { return title }
        return String(title.prefix(Self.maxItemLength - 1)) + "…"
    }
}

private extension View {
    @ViewBuilder
    func help(ifPresent text: String?) -> some View {
        if let text { help(text) } else { self }
    }
}
