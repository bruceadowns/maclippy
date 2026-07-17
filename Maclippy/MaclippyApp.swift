import SwiftData
import SwiftUI

@main
struct MaclippyApp: App {
    @State private var monitor: ClipboardMonitor
    private let container: ModelContainer

    init() {
        Preferences.registerDefaults()
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Clip.self)
        } catch {
            fatalError("Failed to create the data store: \(error)")
        }
        self.container = container
        _monitor = State(initialValue: ClipboardMonitor(context: container.mainContext))
    }

    var body: some Scene {
        MenuBarExtra {
            ClipMenu(monitor: monitor)
        } label: {
            Image(systemName: monitor.isPaused ? "doc.on.clipboard" : "doc.on.clipboard.fill")
        }
        .menuBarExtraStyle(.menu)
        .modelContainer(container)

        Settings {
            SettingsView(monitor: monitor)
        }
        .modelContainer(container)
    }
}
