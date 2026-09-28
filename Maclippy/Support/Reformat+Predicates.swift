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
        // A box table is something a terminal drew, never source. Its rows are
        // masked from the measurement below, so a stanza that is mostly table has
        // almost nothing left to measure and starves the mean.
        guard !lines.contains(where: isRuleRow) else { return false }
        let measurable = lines.filter { !$0.trimmed.isEmpty && !isTable($0) }
        guard !measurable.isEmpty else { return true }
        let words = measurable.reduce(0) { $0 + $1.split(separator: " ").count }
        return Double(words) / Double(measurable.count) < minWordsPerLine
    }

    /// Lines belonging to a brace- or semicolon-terminated block inside a prose
    /// document — code the §6.1 gate cannot see, because the prose around it
    /// carries the document mean above the threshold.
    ///
    /// Precise, not complete. Whole-document code already has a gate, so this may
    /// miss a language and cost nothing; that is what lets it use the `;{}` signal
    /// §6.1 rejected as a *gate*, where missing Swift and Python was fatal.
    static func codeBlockMembership(_ lines: [String]) -> [Bool] {
        var result = [Bool](repeating: false, count: lines.count)
        var start = 0

        func closeBlock(endingAt end: Int) {
            let block = lines[start..<end]
            guard block.count >= minCodeBlockLines else { return }
            let terminated = block.filter { ";{}".contains($0.trimmed.last ?? " ") }.count
            guard terminated * 2 > block.count else { return }
            for i in start..<end { result[i] = true }
        }

        for (i, line) in lines.enumerated() where line.trimmed.isEmpty {
            closeBlock(endingAt: i)
            start = i + 1
        }
        closeBlock(endingAt: lines.count)
        return result
    }

    /// Marks each line's membership in a run that `opens` starts, ending at the
    /// first blank. The one shape a per-line predicate cannot express, and the
    /// only state anywhere in the pipeline: a list item's continuations carry no
    /// marker of their own (§6.3).
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

// MARK: - Space-aligned tables (§6.3.1)

extension Reformat {

    /// Column a line pads to: the end of its first interior run of 2+ spaces.
    static func padColumn(_ line: String) -> Int? {
        let chars = Array(line)
        var i = 0
        while i < chars.count, chars[i] == " " { i += 1 }
        while i < chars.count {
            guard chars[i] == " " else { i += 1; continue }
            var j = i
            while j < chars.count, chars[j] == " " { j += 1 }
            if j - i >= 2, j < chars.count { return j }
            i = j
        }
        return nil
    }

    /// Rows of a table the terminal drew with spaces: one padded line is an
    /// accident, two adjacent ones padding to the same column are alignment.
    static func alignedRowStarts(_ lines: [String]) -> Set<Int> {
        var starts: Set<Int> = []
        for i in 0..<max(0, lines.count - 1) {
            guard let col = padColumn(lines[i]), padColumn(lines[i + 1]) == col,
                  lines[i].indentWidth == lines[i + 1].indentWidth else { continue }
            starts.insert(i)
            starts.insert(i + 1)
        }
        return starts
    }
}
