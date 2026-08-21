import Foundation

// MARK: - Line predicates (§5) and whole-document classification (§6.1)

extension Reformat {

    static func isTable(_ line: String) -> Bool {
        let t = line.trimmed
        guard t.count > 1, let first = t.first, let last = t.last else { return false }
        return boxChars.contains(first) && boxChars.contains(last)
    }

    static func isQuote(_ line: String) -> Bool {
        line.drop { $0 == " " }.first == ">"
    }

    /// ALL-CAPS, ignoring a trailing parenthetical. The `.?!` exclusion is not
    /// cosmetic: ticket IDs and constant names are all-uppercase, so
    /// `AFDL-66180.` reads as a header without it.
    static func isHeader(_ line: String) -> Bool {
        var t = line.trimmed
        if t.hasSuffix(")"), let open = t.lastIndex(of: "(") {
            t = String(t[t.startIndex..<open]).trimmed
        }
        guard let last = t.last, !".?!".contains(last) else { return false }
        let letters = t.filter(\.isLetter)
        return letters.count >= 2 && letters.allSatisfy(\.isUppercase)
    }

    static func startsListItem(_ line: String) -> Bool {
        let t = line.trimmed
        guard let first = t.first else { return false }
        if "-*+".contains(first) {
            return t.dropFirst().first.map { $0 == " " || $0 == "\t" } ?? false
        }
        let digits = t.prefix { $0.isNumber }
        guard !digits.isEmpty else { return false }
        let after = t.dropFirst(digits.count)
        guard let marker = after.first, marker == "." || marker == ")" else { return false }
        return after.dropFirst().first.map { $0 == " " || $0 == "\t" } ?? false
    }

    /// Mean words per line, under which the text is code and the **whole**
    /// pipeline is a no-op, not just unwrapping.
    ///
    /// Quote lines count here even though they are never joined. Their content is
    /// prose and it is evidence the document is prose — excluding them made a
    /// mostly-quoted paste read as code and skipped the pipeline entirely.
    static func isCode(_ lines: [String]) -> Bool {
        let measurable = lines.filter { !$0.trimmed.isEmpty && !isTable($0) }
        guard !measurable.isEmpty else { return true }
        let words = measurable.reduce(0) { $0 + $1.split(separator: " ").count }
        return Double(words) / Double(measurable.count) < minWordsPerLine
    }

    /// Marks each line's membership in a run that `opens` starts and the next
    /// blank line ends — the opening line included. The one shape in this design
    /// that a per-line predicate cannot express, and the only state anywhere in
    /// the pipeline: a list item's continuations carry no marker (§6.3), and
    /// neither do a `❯` prompt's (§5.2). Both are this fold.
    static func runMembership(_ lines: [String], openedBy opens: (String) -> Bool) -> [Bool] {
        var result: [Bool] = []
        var inside = false
        for line in lines {
            if line.trimmed.isEmpty {
                inside = false
            } else if opens(line) {
                inside = true
            }
            result.append(inside)
        }
        return result
    }
}

/// Small shared helpers. Deliberately narrow: `trimmed` is whitespace-only (not
/// newlines), and `indentWidth` counts spaces, matching how the spec measures
/// indentation.
extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
    var trimmedTrailing: String { String(reversed().drop { $0 == " " || $0 == "\t" }.reversed()) }
    var indentWidth: Int { prefix { $0 == " " }.count }
}
