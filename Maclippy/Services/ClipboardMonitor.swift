import AppKit
import Foundation
import Observation
import SwiftData

/// Polls the system pasteboard and records new text clips.
///
/// macOS has no clipboard-change notification, so we poll `changeCount`.
@Observable
final class ClipboardMonitor {
    /// Capturing is paused. Not persisted — always false at launch.
    var isPaused = false

    /// Menu-facing snapshots. The menu bar's own `@Query` never wakes up until
    /// another window touches the SwiftData stack, so the menu reads these instead.
    private(set) var pinned: [Clip] = []
    private(set) var recent: [Clip] = []

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var saveObserver: NSObjectProtocol?

    static let pollInterval: TimeInterval = 0.3
    static let maxClipBytes = 2 * 1024 * 1024

    // Markers cooperating apps set on content that should not be recorded.
    private static let sensitiveTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "com.apple.is-sensitive"
    ]

    init(context: ModelContext) {
        self.context = context
        self.lastChangeCount = NSPasteboard.general.changeCount
        reload()
        start()
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let saveObserver { NotificationCenter.default.removeObserver(saveObserver) }
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        let change = pasteboard.changeCount
        guard change != lastChangeCount else { return }
        lastChangeCount = change
        capture(from: pasteboard)
    }

    private func capture(from pasteboard: NSPasteboard) {
        if Preferences.ignoreConcealed, isSensitive(pasteboard) { return }
        guard let plain = pasteboard.string(forType: .string),
              !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard plain.utf8.count <= Self.maxClipBytes else { return }

        // Keep the list unique: re-copying existing content bumps it instead of
        // adding a duplicate row.
        if let existing = existingClip(with: plain) {
            existing.dateRecorded = .now
            save()
            return
        }

        var rtf = pasteboard.data(forType: .rtf)
        var html = pasteboard.string(forType: .html)
        if exceedsMax(plain: plain, rtf: rtf, html: html) {
            rtf = nil
            html = nil
        }
        context.insert(Clip(plain: plain, rtf: rtf, html: html))
        trim()
        save()
    }

    private func isSensitive(_ pasteboard: NSPasteboard) -> Bool {
        let types = Set(pasteboard.types?.map(\.rawValue) ?? [])
        return !types.isDisjoint(with: Self.sensitiveTypes)
    }

    private func exceedsMax(plain: String, rtf: Data?, html: String?) -> Bool {
        let total = plain.utf8.count + (rtf?.count ?? 0) + (html?.utf8.count ?? 0)
        return total > Self.maxClipBytes
    }

    private func existingClip(with plain: String) -> Clip? {
        var descriptor = FetchDescriptor<Clip>(predicate: #Predicate { $0.plain == plain })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - Paste-back

    /// Writes the clip back to the pasteboard, restoring every stored representation.
    func paste(_ clip: Clip) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(clip.plain, forType: .string)
        if let rtf = clip.rtf { pasteboard.setData(rtf, forType: .rtf) }
        if let html = clip.html { pasteboard.setString(html, forType: .html) }
        lastChangeCount = pasteboard.changeCount  // suppress capturing our own write

        clip.dateRecorded = .now  // reusing a clip bumps it to the top
        save()
    }

    /// Rewrites the current pasteboard to its plain text only, dropping rich
    /// representations so the next paste lands unstyled. Acts on the live
    /// pasteboard, not stored history.
    func clearFormatting() {
        let pasteboard = NSPasteboard.general
        guard let plain = pasteboard.string(forType: .string) else { return }
        pasteboard.clearContents()
        pasteboard.setString(plain, forType: .string)
        lastChangeCount = pasteboard.changeCount  // our own write; don't recapture
    }

    // MARK: - History

    /// Refetches the menu snapshots. Filters/sorts mirror the Settings `@Query`s.
    func reload() {
        let pinnedDescriptor = FetchDescriptor<Clip>(
            predicate: #Predicate { $0.pinned },
            sortBy: [SortDescriptor(\.pinnedOrder, order: .forward)]
        )
        let recentDescriptor = FetchDescriptor<Clip>(
            predicate: #Predicate { !$0.pinned },
            sortBy: [SortDescriptor(\.dateRecorded, order: .reverse)]
        )
        pinned = (try? context.fetch(pinnedDescriptor)) ?? []
        recent = (try? context.fetch(recentDescriptor)) ?? []
    }

    func clearHistory() {
        // Batch delete writes straight to the store without pending changes, so
        // `save()` emits no didSave notification — reload the snapshots directly.
        try? context.delete(model: Clip.self, where: #Predicate { !$0.pinned })
        save()
        reload()
    }

    /// Applies the current history-size limit to already-stored clips, e.g. after
    /// the user lowers the size in Preferences.
    func enforceHistoryLimit() {
        trim()
        save()
    }

    private func trim() {
        let limit = Preferences.historySize
        guard limit > 0 else { return }  // 0 = unlimited
        let descriptor = FetchDescriptor<Clip>(
            predicate: #Predicate { !$0.pinned },
            sortBy: [SortDescriptor(\.dateRecorded, order: .reverse)]
        )
        guard let recent = try? context.fetch(descriptor), recent.count > limit else { return }
        for clip in recent[limit...] { context.delete(clip) }
    }

    private func save() {
        try? context.save()
    }
}
