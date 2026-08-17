import SwiftData
import SwiftUI

struct ClipsSettingsView: View {
    /// Owned by `SettingsView` so its Esc handler can cancel a rename before
    /// falling through to closing the window.
    @Binding var editingID: UUID?

    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Clip> { $0.pinned }, sort: \Clip.pinnedOrder, order: .forward)
    private var pinned: [Clip]
    @Query(filter: #Predicate<Clip> { !$0.pinned }, sort: \Clip.dateRecorded, order: .reverse)
    private var recent: [Clip]

    @State private var draft = ""
    @State private var editingSeed = ""
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
                    .onChange(of: fieldFocused) { _, focused in if !focused { commit(clip) } }
                    .onChange(of: draft) { _, new in
                        if new.count > Clip.maxLabelLength { draft = String(new.prefix(Clip.maxLabelLength)) }
                    }
            } else {
                Text(clip.customLabel ?? clip.revealedPlain).lineLimit(1)
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

    /// Abandoning an edit is just clearing `editingID` — `customLabel` is only
    /// ever mutated on commit, so there is nothing to revert. `SettingsView`
    /// does that directly from its Esc handler.
    private func beginEditing(_ clip: Clip) {
        draft = clip.customLabel ?? clip.displayTitle  // seed with the current label
        editingSeed = draft  // committing this unchanged is a no-op, same as Esc
        editingID = clip.id
    }

    private func commit(_ clip: Clip) {
        guard editingID == clip.id else { return }  // ignore stray blur after a prior commit / cancel
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        editingID = nil
        // Unchanged from the seeded value → same as Esc. Compared against the seed,
        // not customLabel, so leaving an unnamed clip's displayTitle in place stays nil.
        guard trimmed != editingSeed.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        // Empty, or a name equal to the real content, cloaks nothing → uncloak.
        let newLabel = (trimmed.isEmpty || trimmed == clip.plain) ? nil : String(trimmed.prefix(Clip.maxLabelLength))
        // A duplicate name makes two cloaked clips indistinguishable — reject (revert, nothing saved).
        if let newLabel,
           pinned.contains(where: { $0.id != clip.id && $0.customLabel?.caseInsensitiveCompare(newLabel) == .orderedSame }) {
            return
        }
        clip.customLabel = newLabel
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
