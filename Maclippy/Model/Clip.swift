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
    var revealedPlain: String {
        let chars = Array(plain)
        guard let first = chars.firstIndex(where: { !$0.isWhitespace }),
              let last = chars.lastIndex(where: { !$0.isWhitespace }) else {
            return plain
        }
        var out = ""
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
