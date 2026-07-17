import SwiftUI

struct SettingsView: View {
    let monitor: ClipboardMonitor

    var body: some View {
        TabView {
            GeneralSettingsView(monitor: monitor)
                .tabItem { Label("General", systemImage: "gearshape") }
            ClipsSettingsView()
                .tabItem { Label("Clips", systemImage: "list.bullet") }
        }
        .frame(width: 480, height: 360)
    }
}
