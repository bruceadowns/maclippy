import AppKit
import SwiftUI

struct SettingsView: View {
    let monitor: ClipboardMonitor

    /// Lives here, not in `ClipsSettingsView`, so the Esc handler can tell a
    /// rename in progress from an idle window.
    @State private var editingID: UUID?
    @State private var window: NSWindow?
    @State private var generalEscape: (() -> Bool)?
    @State private var escapeMonitor: Any?

    var body: some View {
        TabView {
            GeneralSettingsView(monitor: monitor, onEscape: $generalEscape)
                .tabItem { Label("General", systemImage: "gearshape") }
            ClipsSettingsView(editingID: $editingID)
                .tabItem { Label("Clips", systemImage: "list.bullet") }
        }
        .frame(width: 480, height: 360)
        .background(WindowReader { if window !== $0 { window = $0 } })
        .onAppear {
            // The window can be closed mid-rename with the red button or ⌘W,
            // which leaves `editingID` set and reopens straight into edit mode.
            // Clearing on appear rather than on close is deliberate: the field's
            // blur still commits on the way out, so closing keeps the pending
            // name instead of silently discarding it.
            editingID = nil
            installEscapeMonitor()
        }
        .onDisappear(perform: removeEscapeMonitor)
    }

    /// Esc cancels a rename in progress; otherwise it closes the window,
    /// matching the About panel. Nothing is discarded by closing — settings
    /// persist through `@AppStorage` as they change.
    ///
    /// This is an event monitor rather than `onExitCommand` or `onKeyPress`
    /// because both of those are scoped to the focus chain, and Settings has
    /// three places focus can sit: nowhere, a text field, or a tab button. Each
    /// modifier worked from some of those and silently did nothing from the
    /// others. A monitor sees the key press regardless, and scoping it to this
    /// window keeps it from reaching the rest of the app.
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53, event.window === window else { return event }
            // Offer it to the in-progress edits first — a rename in Clips, then
            // a changed size in General — and only close when neither took it.
            if editingID != nil {
                editingID = nil  // abandon the rename; the ensuing blur is a no-op
            } else if generalEscape?() != true {
                window?.performClose(nil)
            }
            return nil  // consumed
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }
}

/// Hands back the `NSWindow` hosting this view, so the Esc monitor can tell
/// Settings' key presses from the rest of the app's.
///
/// Deferred because a view has no window until it is in the hierarchy, and
/// reported on update as well as creation because the Settings window is torn
/// down and rebuilt across launches. Callers must ignore an unchanged window:
/// assigning one to `@State` on every pass would invalidate the view and drive
/// another pass.
private struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }
}
