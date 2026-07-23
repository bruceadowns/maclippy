import Foundation
import SwiftData

@Model
final class Clip {
    var id: UUID
    var dateRecorded: Date
    var pinned: Bool
    var pinnedOrder: Int
    var displayTitle: String
    /// User-set name that cloaks a pinned clip's content: when set, the menu and
    /// clips list show this instead of the plaintext (e.g. so a stored password
    /// never appears in the menu bar). Only set on pinned clips; cleared on
    /// unpin. nil = show the content-derived label. Capped at `maxLabelLength`.
    var customLabel: String?
    var plain: String
    var rtf: Data?
    var html: String?

    static let maxLabelLength = 80

    // Only a short prefix is ever shown (menu label 36, tooltip peek 500), so
    // reveal never processes more than this — a 2 MB clip must not be fully
    // materialized and scanned just to render a label. Kept comfortably above
    // the 500-char peek so the peek's own "…" cue still triggers.
    static let maxRevealChars = 1024

    init(plain: String, rtf: Data? = nil, html: String? = nil, dateRecorded: Date = .now) {
        self.id = UUID()
        self.dateRecorded = dateRecorded
        self.pinned = false
        self.pinnedOrder = 0
        self.displayTitle = Clip.makeTitle(from: plain)
        self.customLabel = nil
        self.plain = plain
        self.rtf = rtf
        self.html = html
    }

    static func makeTitle(from plain: String) -> String {
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return String(firstLine.prefix(maxLabelLength))
    }

    /// `plain` with edge whitespace made visible, so verbatim-distinct clips
    /// (e.g. "foobar" vs " foobar ") don't render identically. Interior spaces
    /// stay literal; newlines collapse to a glyph to keep the label one line.
    /// Shared by the menu and the Clips tab so the two never drift.
    ///
    /// Bounded to `maxRevealChars`: only a short prefix is ever displayed, so a
    /// huge clip is never fully scanned. `more` means content continues past the
    /// slice, so the slice has no *trailing* edge, and an all-whitespace slice is
    /// all *leading* edge (capture rejects all-whitespace clips — SPEC §4.1 — so
    /// real content must follow).
    var revealedPlain: String {
        let end = plain.index(plain.startIndex, offsetBy: Self.maxRevealChars, limitedBy: plain.endIndex)
        let more = end != nil && end != plain.endIndex
        let slice = end.map { String(plain[..<$0]) } ?? plain
        let chars = Array(slice)

        let firstNonWS = chars.firstIndex(where: { !$0.isWhitespace })
        if firstNonWS == nil && !more { return slice }  // degenerate: whole clip is whitespace
        let first = firstNonWS ?? chars.count
        let last = more ? chars.count : (chars.lastIndex(where: { !$0.isWhitespace }) ?? chars.count)

        var out = ""
        out.reserveCapacity(chars.count)
        for (i, char) in chars.enumerated() {
            let edge = i < first || i > last
            switch char {
            case "\n", "\r": out.append("⏎")
            case "\t": out.append(edge ? "⇥" : "\t")
            case " ": out.append(edge ? "·" : " ")
            default: out.append(char)
            }
        }
        return out
    }
}
