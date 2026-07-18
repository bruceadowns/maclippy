import SwiftUI

struct GeneralSettingsView: View {
    let monitor: ClipboardMonitor

    @AppStorage(Preferences.historySizeKey) private var historySize = Preferences.defaultHistorySize
    @AppStorage(Preferences.ignoreConcealedKey) private var ignoreConcealed = Preferences.defaultIgnoreConcealed
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            LabeledContent("History size") {
                HStack(spacing: 4) {
                    TextField("", value: $historySize, format: .number)
                        .labelsHidden()
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $historySize, in: Preferences.minHistorySize...Preferences.maxHistorySize)
                        .labelsHidden()
                }
            }
            .onChange(of: historySize) { _, newValue in
                let clamped = min(max(newValue, Preferences.minHistorySize), Preferences.maxHistorySize)
                if clamped != newValue {
                    historySize = clamped
                    return
                }
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
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
