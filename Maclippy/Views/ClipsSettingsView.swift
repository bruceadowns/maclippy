import SwiftData
import SwiftUI

struct ClipsSettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Clip> { $0.pinned }, sort: \Clip.pinnedOrder, order: .forward)
    private var pinned: [Clip]
    @Query(filter: #Predicate<Clip> { !$0.pinned }, sort: \Clip.dateRecorded, order: .reverse)
    private var recent: [Clip]

    var body: some View {
        List {
            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { row($0) }
                        .onMove(perform: movePinned)
                }
            }
            Section("Recent") {
                if recent.isEmpty {
                    Text("No clips yet").foregroundStyle(.secondary)
                }
                ForEach(recent) { row($0) }
            }
        }
    }

    private func row(_ clip: Clip) -> some View {
        HStack {
            Text(clip.displayTitle).lineLimit(1)
            Spacer()
            Button(clip.pinned ? "Unpin" : "Pin") { togglePin(clip) }
                .buttonStyle(.borderless)
            Button(role: .destructive) { delete(clip) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func togglePin(_ clip: Clip) {
        clip.pinned.toggle()
        clip.pinnedOrder = clip.pinned ? (pinned.map(\.pinnedOrder).max() ?? -1) + 1 : 0
        try? context.save()
    }

    private func delete(_ clip: Clip) {
        context.delete(clip)
        try? context.save()
    }

    private func movePinned(from offsets: IndexSet, to destination: Int) {
        var items = pinned
        items.move(fromOffsets: offsets, toOffset: destination)
        for (index, clip) in items.enumerated() { clip.pinnedOrder = index }
        try? context.save()
    }
}
