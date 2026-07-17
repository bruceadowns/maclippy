import Foundation
import SwiftData

@Model
final class Clip {
    var id: UUID
    var dateRecorded: Date
    var pinned: Bool
    var pinnedOrder: Int
    var displayTitle: String
    var plain: String
    var rtf: Data?
    var html: String?

    init(plain: String, rtf: Data? = nil, html: String? = nil, dateRecorded: Date = .now) {
        self.id = UUID()
        self.dateRecorded = dateRecorded
        self.pinned = false
        self.pinnedOrder = 0
        self.displayTitle = Clip.makeTitle(from: plain)
        self.plain = plain
        self.rtf = rtf
        self.html = html
    }

    static func makeTitle(from plain: String) -> String {
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return String(firstLine.prefix(80))
    }
}
