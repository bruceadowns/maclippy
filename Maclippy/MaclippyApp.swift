import AppKit
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
            // MenuBarExtra renders SwiftUI Image as a template and drops
            // foregroundStyle, so hand it a pre-colored, non-template NSImage.
            Image(nsImage: Self.menuBarIcon(paused: monitor.isPaused))
        }
        .menuBarExtraStyle(.menu)
        .modelContainer(container)

        Settings {
            SettingsView(monitor: monitor)
        }
        .modelContainer(container)
    }

    private static func menuBarIcon(paused: Bool) -> NSImage {
        let teal = NSColor(srgbRed: 0.059, green: 0.710, blue: 0.682, alpha: 1.0)
        // Front doc gets the accent; back clipboard keeps the default label color.
        let front: NSColor = paused ? .systemGray : teal
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [front, .labelColor]))
        let symbol = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Maclippy")!
            .withSymbolConfiguration(config)!

        // Non-template images draw at natural size; the symbol is taller than the
        // menu bar's drawable area and clips. Rescale to a fitting height.
        let height: CGFloat = 18
        let size = NSSize(width: symbol.size.width / symbol.size.height * height, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)
            return true
        }
        image.isTemplate = false  // keep our colors instead of the menu bar tinting it
        return image
    }
}
