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
}
