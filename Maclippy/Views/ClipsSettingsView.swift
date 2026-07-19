import SwiftData
import SwiftUI

struct ClipsSettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Clip> { $0.pinned }, sort: \Clip.pinnedOrder, order: .forward)
    private var pinned: [Clip]
    @Query(filter: #Predicate<Clip> { !$0.pinned }, sort: \Clip.dateRecorded, order: .reverse)
    private var recent: [Clip]

    @State private var editingID: UUID?
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

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

    @ViewBuilder
    private func row(_ clip: Clip) -> some View {
        HStack {
            // Reserved slot (empty when unnamed) so a named tag doesn't shift labels.
            Image(systemName: "key.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(clip.customLabel == nil ? 0 : 1)
                .help("Named")
            if editingID == clip.id {
                TextField("", text: $draft, prompt: Text(clip.displayTitle))
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onAppear { fieldFocused = true }
                    .onSubmit { commit(clip) }
                    .onKeyPress(.escape) { cancelEditing(); return .handled }
                    .onChange(of: fieldFocused) { _, focused in if !focused { commit(clip) } }
                    .onChange(of: draft) { _, new in
                        if new.count > Clip.maxLabelLength { draft = String(new.prefix(Clip.maxLabelLength)) }
                    }
            } else {
                Text(clip.customLabel ?? clip.displayTitle).lineLimit(1)
            }
            Spacer()
            Button { togglePin(clip) } label: {
                Image(systemName: clip.pinned ? "pin.slash" : "pin")
            }
            .buttonStyle(.borderless)
            .help(clip.pinned ? "Unpin" : "Pin")
            if clip.pinned {
                Button { beginEditing(clip) } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename")
            }
            Button(role: .destructive) { delete(clip) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
    }

    private func beginEditing(_ clip: Clip) {
        draft = clip.customLabel ?? clip.displayTitle  // seed with the current label
        editingID = clip.id
    }

    /// Esc: abandon the edit, reverting to the stored name. `customLabel` is
    /// only ever mutated on commit, so clearing the draft is the whole undo.
    private func cancelEditing() {
        editingID = nil  // guards the ensuing blur out of commit()
    }

    private func commit(_ clip: Clip) {
        guard editingID == clip.id else { return }  // ignore stray blur after a prior commit / cancel
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        clip.customLabel = trimmed.isEmpty ? nil : String(trimmed.prefix(Clip.maxLabelLength))
        editingID = nil
        try? context.save()
    }

    private func togglePin(_ clip: Clip) {
        if editingID == clip.id { editingID = nil }
        clip.pinned.toggle()
        if clip.pinned {
            clip.pinnedOrder = (pinned.map(\.pinnedOrder).max() ?? -1) + 1
        } else {
            clip.pinnedOrder = 0
            clip.customLabel = nil  // back in Recent: must not carry a cloaking name
            clip.dateRecorded = .now  // re-enter Recent at the top, not at its stale age
        }
        try? context.save()
    }

    private func delete(_ clip: Clip) {
        if editingID == clip.id { editingID = nil }
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
