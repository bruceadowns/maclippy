import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    let monitor: ClipboardMonitor

    /// Registered with `SettingsView` so its Esc monitor can offer the keystroke
    /// here first. Returns true when it consumed one.
    @Binding var onEscape: (() -> Bool)?

    @AppStorage(Preferences.historySizeKey) private var historySize = Preferences.defaultHistorySize
    @AppStorage(Preferences.ignoreConcealedKey) private var ignoreConcealed = Preferences.defaultIgnoreConcealed
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    /// The typed text, held apart from `historySize` until the edit finishes.
    /// Binding the field straight to the preference trimmed on every keystroke —
    /// editing 12 to 13 passes through 1 and deleted the history down to one clip.
    ///
    /// Text rather than `Int`: an emptied field has no number to hold, so a
    /// numeric binding keeps its stale value while the field shows blank, and
    /// re-assigning that same number later is a no-op that never redraws it.
    @State private var sizeText = ""
    @FocusState private var sizeFocused: Bool

    var body: some View {
        Form {
            LabeledContent("History size") {
                HStack(spacing: 4) {
                    TextField("", text: $sizeText)
                        .labelsHidden()
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .focused($sizeFocused)
                        .onSubmit { commitSize() }
                        .onChange(of: sizeFocused) { _, focused in if !focused { commitSize() } }
                    // The stepper applies immediately: each click is a complete,
                    // deliberate change, and its range makes an invalid one impossible.
                    Stepper("", value: $historySize, in: Preferences.minHistorySize...Preferences.maxHistorySize)
                        .labelsHidden()
                }
            }
            .onChange(of: historySize) { _, newValue in
                sizeText = String(newValue)  // keep the field showing what the stepper did
                monitor.enforceHistoryLimit()
            }
            Text("0 means unlimited.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Ignore concealed items", isOn: $ignoreConcealed)
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.isEnabled = newValue
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            Button("Clear Unpinned History…") {
                ClipActions.confirmClearHistory(monitor)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            sizeText = String(historySize)  // discard any half-finished edit from last time
            focusAndSelectSize()
            onEscape = revertSizeEdit
        }
    }

    /// Esc undoes an in-progress size edit, matching how it abandons a rename in
    /// the Clips tab: the typed text reverts and the field gives up focus, so a
    /// second Esc closes the window.
    ///
    /// Keyed on the text actually differing rather than on focus alone. The field
    /// is focused the moment the dialog opens, so treating focus as "editing"
    /// would cost every close a wasted first keystroke.
    ///
    /// The blur this triggers runs `commitSize()`, which is harmless — the text
    /// already matches the stored value, so it writes nothing and trims nothing.
    private func revertSizeEdit() -> Bool {
        guard sizeFocused, sizeText != String(historySize) else { return false }
        sizeText = String(historySize)
        sizeFocused = false
        return true
    }

    /// Opens with the size field focused and its text selected, so typing
    /// replaces the number outright.
    ///
    /// Two deferrals, and both are load-bearing. The window restores its own
    /// first responder *after* the view appears, so focus set inline is
    /// overwritten; and the field editor only becomes the responder once focus
    /// has settled, so there is nothing to select until the turn after that.
    /// Queued rather than nested — main-queue blocks run in submission order.
    private func focusAndSelectSize() {
        DispatchQueue.main.async { sizeFocused = true }
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
        }
    }

    /// Applies the typed value once the edit is finished — on Enter or on blur.
    /// Clamping here rather than in `onChange` means an out-of-range number is
    /// corrected without an intermediate write, so nothing is trimmed to it first.
    ///
    /// Empty or unparseable reverts to the stored value rather than committing.
    /// An accidentally cleared field would otherwise read as 0, which means
    /// *unlimited* — the opposite of what emptying it looks like it should do.
    private func commitSize() {
        let typed = Int(sizeText.trimmingCharacters(in: .whitespaces))
        let value = typed.map { min(max($0, Preferences.minHistorySize), Preferences.maxHistorySize) }
            ?? historySize
        sizeText = String(value)
        if value != historySize { historySize = value }
    }
}
