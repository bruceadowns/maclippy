import Foundation

/// Rewrites CLI-shaped text into something that pastes cleanly: strips gutter
/// markers, rejoins hard-wrapped paragraphs, converts box tables to Markdown,
/// and flattens typographic punctuation to ASCII.
///
/// Pure `String -> String`. Every constant here is calibrated against
/// `docs/fixtures/`; see `docs/reformat.md` for why each rule exists and which
/// paste forced it. The stage order below is the specification.
enum Reformat {

    // MARK: - Calibrated constants (docs/reformat.md §10)

    /// Line lengths within this many characters of each other are one cluster.
    static let clusterGap = 8
    /// Slack in the forced-break test; absorbs prose that only approximates a column.
    static let breakTolerance = 8
    /// A cluster smaller than this is coincidence, not evidence of a wrap column.
    static let minClusterLines = 3
    /// Above this share of lines exceeding W, the estimate is an artifact.
    static let maxExceedingW = 0.25
    /// Below this, the text is code rather than wrapped prose (§6.1).
    static let minWordsPerLine = 8.0

    // MARK: - Tables (§7)

    /// Gutter glyph → replacement of exactly the gutter's column width, so
    /// content keeps its column and every indent comparison still holds.
    static let markers: [Character: String] = [
        "⏺": "  ", "●": "  ", "✻": "  ", "✽": "  ", "✶": "  ",
        "⎿": "|_ "   // visible: "this is command output" survives the paste
    ]

    /// Reverses typographic substitution. Only characters with an unambiguous
    /// ASCII ancestor appear here — `✓`, `✗` and `§` deliberately do not.
    static let flatten: [Character: String] = [
        "\u{201C}": "\"", "\u{201D}": "\"",      // “ ”
        "\u{2018}": "'", "\u{2019}": "'",        // ‘ ’
        "\u{2033}": "\"", "\u{2032}": "'",       // ″ ′
        "\u{2026}": "...",                       // …
        "\u{2013}": "-", "\u{2014}": "-",        // – —
        "\u{2192}": "->", "\u{2190}": "<-",      // → ←
        "\u{2264}": "<=", "\u{2265}": ">=",      // ≤ ≥
        "\u{00D7}": "x",                         // ×
        "\u{00B7}": "*"                          // ·
    ]

    static let boxChars = Set("│┌├└┬┴┼─╭╰┏┗┣┃┐┤┘╮╯┓┛┫|")
    private static let cellSeparators = Set("│┃|")

    // MARK: - Entry point

    /// Runs the full pipeline. Returns the input unchanged when the text is code
    /// (§6.1) — Reformat does not reformat code.
    static func apply(_ input: String) -> String {
        var text = stripEscapes(input)                                  // 1
        text = text.replacingOccurrences(of: "\r\n", with: "\n")        // 2
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")

        var lines = text.components(separatedBy: "\n").map(substituteGutter)  // 3
        lines = lines.map { String($0.reversed().drop { $0 == " " || $0 == "\t" }.reversed()) }  // 4

        // Code guardrail: the whole pipeline is a no-op, not just unwrapping.
        let measurable = lines.filter { !$0.trimmed.isEmpty && !isTable($0) && !isQuote($0) }
        let wordsPerLine = measurable.isEmpty ? 0
            : Double(measurable.reduce(0) { $0 + $1.split(separator: " ").count }) / Double(measurable.count)
        guard wordsPerLine >= minWordsPerLine else { return input }  // verbatim

        let width = estimateWidth(lines)                                // 5
        let joins = width.map { forcedBreaks(lines, width: $0) } ?? []  // 6
        lines = performJoins(lines, at: Set(joins))
        lines = dedent(lines)                                           // 7
        lines = convertTables(lines)                                    // 8
        lines = lines.map(flattenPunctuation)                           // 9
        let body = trimBlanks(collapseBlankRuns(lines)).joined(separator: "\n")  // 10, 11

        // Output always terminates with a line feed, whether or not the input
        // did. Runs of trailing blank lines have already collapsed, so this is
        // exactly one. Code takes the guardrail's early return above and is not
        // given one — that path is byte-identical by contract.
        return body + "\n"
    }
}

// MARK: - Stages

private extension Reformat {

    /// Drops CSI sequences (`ESC [ … final`) and OSC strings (`ESC ] … BEL/ST`).
    /// Hand-rolled rather than a regex: the grammar is two small cases, and this
    /// keeps the file free of runtime-constructed patterns.
    static func stripEscapes(_ s: String) -> String {
        guard s.contains("\u{1B}") else { return s }
        var out = ""
        var rest = Substring(s)
        while let esc = rest.firstIndex(of: "\u{1B}") {
            out += rest[rest.startIndex..<esc]
            rest = rest[endOfEscape(rest, at: esc)...]
        }
        return out + rest
    }

    /// Index just past the escape sequence starting at `esc`.
    static func endOfEscape(_ s: Substring, at esc: Substring.Index) -> Substring.Index {
        var i = s.index(after: esc)
        guard i < s.endIndex else { return i }
        let kind = s[i]
        i = s.index(after: i)
        switch kind {
        case "[":
            while i < s.endIndex, !("\u{40}"..."\u{7E}").contains(s[i]) { i = s.index(after: i) }
            return i < s.endIndex ? s.index(after: i) : i
        case "]":
            return endOfString(s, from: i)
        default:
            return i
        }
    }

    /// Index just past an OSC string body, which ends at BEL or at ST (`ESC \`).
    static func endOfString(_ s: Substring, from start: Substring.Index) -> Substring.Index {
        var i = start
        while i < s.endIndex, s[i] != "\u{07}", s[i] != "\u{1B}" { i = s.index(after: i) }
        guard i < s.endIndex else { return i }
        let terminator = s[i]
        i = s.index(after: i)
        if terminator == "\u{1B}", i < s.endIndex, s[i] == "\\" { i = s.index(after: i) }
        return i
    }

    // MARK: - Stage 3

    /// Replaces a leading marker or quote gutter. Quote gutters normalize to
    /// `> `; markers become an equal-width replacement so columns are preserved.
    static func substituteGutter(_ line: String) -> String {
        let pad = String(repeating: " ", count: line.indentWidth)
        let body = line.drop { $0 == " " }
        guard let first = body.first else { return line }

        if first == "▎" || first == "┃" || first == ">" {
            let rest = body.dropFirst().drop { $0 == " " }
            return rest.isEmpty ? pad + ">" : pad + "> " + rest
        }
        if let replacement = markers[first] {
            return pad + replacement + body.dropFirst().drop { $0 == " " }
        }
        return line
    }

    // MARK: - Stage 5 — wrap width (§6.1)

    /// Gap-clusters line lengths and returns the **highest** cluster holding at
    /// least `minClusterLines`. Highest rather than most populous: a wrapper puts
    /// lines *at* its column and never above it, while short lines (headers,
    /// labels, tails) outnumber wrapped ones in any structured document.
    static func estimateWidth(_ lines: [String]) -> Int? {
        let lengths = lines.filter { !$0.trimmed.isEmpty && !isTable($0) }.map(\.count)
        guard lengths.count >= 2 else { return nil }

        var clusters: [[Int]] = []
        for value in Set(lengths).sorted(by: >) {
            if let last = clusters.last?.last, last - value <= clusterGap {
                clusters[clusters.count - 1].append(value)
            } else {
                clusters.append([value])
            }
        }
        let populated = clusters.filter { cluster in
            let lo = cluster.min()!, hi = cluster.max()!
            return lengths.filter { $0 >= lo && $0 <= hi }.count >= minClusterLines
        }
        guard let best = populated.map({ $0.max()! }).max() else { return nil }
        guard Double(lengths.filter { $0 > best }.count) <= maxExceedingW * Double(lengths.count)
        else { return nil }
        return best
    }

    // MARK: - Stage 6 — unwrapping (§6.2, §6.3)

    /// Indices `i` where line `i` should absorb line `i+1`.
    static func forcedBreaks(_ lines: [String], width: Int) -> [Int] {
        let inList = listMembership(lines)
        var result: [Int] = []

        for i in 0..<max(0, lines.count - 1) {
            let a = lines[i], b = lines[i + 1]
            guard !a.trimmed.isEmpty, !b.trimmed.isEmpty else { continue }
            guard !isTable(a), !isTable(b), !isQuote(a), !isQuote(b) else { continue }
            guard !startsListItem(b) else { continue }
            guard !isHeader(a), !isHeader(b) else { continue }

            // A sentence end usually means the break was authored — unless we are
            // inside a list (siblings carry markers, so `startsListItem` already
            // separates them) or the next line is itself at the wrap column.
            if let last = a.last, ".?!".contains(last), !inList[i], b.count < width - breakTolerance {
                continue
            }

            let nextWord = b.trimmed.split(separator: " ").first.map(String.init) ?? ""
            guard nextWord.count <= width else { continue }   // a token that fits nowhere proves nothing
            if a.count + 1 + nextWord.count > width - breakTolerance { result.append(i) }
        }
        return result
    }

    static func performJoins(_ lines: [String], at joins: Set<Int>) -> [String] {
        guard !lines.isEmpty else { return lines }
        var result: [String] = []
        var current = lines[0]
        for i in 1..<lines.count {
            if joins.contains(i - 1) {
                current = current.trimmedTrailing + " " + lines[i].trimmed
            } else {
                result.append(current)
                current = lines[i]
            }
        }
        result.append(current)
        return result
    }

    // MARK: - Stage 7 — dedent

    /// Removes the common leading indent. A minimum held by exactly one line is
    /// a paste artifact — terminal selections routinely miss the first line's
    /// indent — so the next smallest is used instead.
    static func dedent(_ lines: [String]) -> [String] {
        let indents = lines.filter { !$0.trimmed.isEmpty }.map(\.indentWidth)
        guard let smallest = indents.min() else { return lines }
        let unique = Set(indents).sorted()
        let amount = (unique.count > 1 && indents.filter { $0 == smallest }.count == 1)
            ? unique[1] : smallest
        return lines.map { line in
            line.trimmed.isEmpty ? "" : String(line.dropFirst(min(line.indentWidth, amount)))
        }
    }

    // MARK: - Stage 8 — box tables → Markdown (§5.1)

    static func convertTables(_ lines: [String]) -> [String] {
        var result: [String] = []
        var block: [String] = []
        for line in lines {
            if isTable(line) {
                block.append(line)
            } else {
                if !block.isEmpty { result += convert(block); block = [] }
                result.append(line)
            }
        }
        if !block.isEmpty { result += convert(block) }
        return result
    }

    static func convert(_ block: [String]) -> [String] {
        // Without a rule row it is ASCII art, not a table. Converting a lone
        // pipe-delimited line invents a header and a delimiter for it.
        guard block.contains(where: isRuleRow) else { return block }
        let rows = block.filter { !isRuleRow($0) }.map(cells)
        guard let first = rows.first else { return block }
        guard rows.allSatisfy({ $0.count == first.count }) else { return block }  // ragged: bail out

        let delimiter = Array(repeating: "---", count: first.count)
        return ([first, delimiter] + rows.dropFirst()).map { "| " + $0.joined(separator: " | ") + " |" }
    }

    static func cells(_ line: String) -> [String] {
        var parts = line.trimmed.split(omittingEmptySubsequences: false, whereSeparator: cellSeparators.contains)
            .map { $0.trimmed.replacingOccurrences(of: "|", with: "\\|") }
        if parts.first?.isEmpty == true { parts.removeFirst() }
        if parts.last?.isEmpty == true { parts.removeLast() }
        return parts
    }

    /// A box rule (`├──┼──┤`) or a Markdown delimiter (`| --- | --- |`).
    /// Recognizing the second is what stops a converted table growing a
    /// delimiter row on every run.
    static func isRuleRow(_ line: String) -> Bool {
        guard isTable(line) else { return false }
        if line.allSatisfy({ boxChars.contains($0) || $0.isWhitespace }) { return true }
        let c = cells(line)
        return !c.isEmpty && c.allSatisfy { cell in
            let core = cell.drop { $0 == ":" }.reversed().drop { $0 == ":" }
            return !core.isEmpty && core.allSatisfy { $0 == "-" }
        }
    }

    // MARK: - Stage 9 — flatten (§7)

    static func flattenPunctuation(_ line: String) -> String {
        collapseDoubleDash(rewriteLeadingBullet(line.map { flatten[$0] ?? String($0) }.joined()))
    }

    /// `--` is the typewriter em dash, so it collapses to the same single hyphen
    /// `—` does — but only when it stands alone between whitespace. That leaves
    /// `---` rules, `--flag` and `i--` untouched.
    static func collapseDoubleDash(_ s: String) -> String {
        guard s.contains("--") else { return s }
        var out = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let isolated = chars[i] == "-" && i + 1 < chars.count && chars[i + 1] == "-"
                && i > 0 && chars[i - 1].isWhitespace
                && (i + 2 == chars.count || chars[i + 2].isWhitespace)
            if isolated {
                out.append("-")
                i += 2
            } else {
                out.append(chars[i])
                i += 1
            }
        }
        return out
    }

    static func rewriteLeadingBullet(_ s: String) -> String {
        let indent = s.prefix { $0 == " " || $0 == "\t" }
        let rest = s.dropFirst(indent.count)
        guard rest.first == "\u{2022}" else { return s }
        let body = rest.dropFirst().drop { $0 == " " || $0 == "\t" }
        guard body.count < rest.count - 1 else { return s }   // require a separating space
        return indent + "- " + body
    }

    // MARK: - Stages 10, 11

    static func collapseBlankRuns(_ lines: [String]) -> [String] {
        var result: [String] = []
        var wasBlank = false
        for line in lines {
            if line.trimmed.isEmpty {
                if !wasBlank { result.append("") }
                wasBlank = true
            } else {
                result.append(line)
                wasBlank = false
            }
        }
        return result
    }

    static func trimBlanks(_ lines: [String]) -> [String] {
        var result = lines
        while result.first?.trimmed.isEmpty == true { result.removeFirst() }
        while result.last?.trimmed.isEmpty == true { result.removeLast() }
        return result
    }
}
