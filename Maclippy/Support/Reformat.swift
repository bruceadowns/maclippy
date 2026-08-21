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
    static let minClusterLines = 2
    /// A line-initial token longer than this is a path, URL or identifier sitting
    /// on its own line, never a word the wrapper pushed down. Absolute rather than
    /// relative to `W`, because `W` grows once lines are joined — a `W`-relative
    /// bound stops holding on a second pass.
    static let maxAbsorbableToken = 100
    /// Above this share of lines exceeding W, the estimate is an artifact.
    static let maxExceedingW = 0.25
    /// A run of this many interior spaces is a row boundary the terminal wrote as
    /// padding, not alignment. Real column gutters in the corpus reach 26; padding
    /// artifacts start at 148. Absolute rather than relative to `W`, for the same
    /// reason as `maxAbsorbableToken`.
    static let minPadRun = 32
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

    /// Gutters that mean "quoted", all normalizing to `> `.
    static let quoteGlyphs: Set<Character> = ["▎", "┃", ">", "❯"]
    static let boxChars = Set("│┌├└┬┴┼─╭╰┏┗┣┃┐┤┘╮╯┓┛┫|")

    // MARK: - Entry point

    /// Runs the full pipeline. Returns the input unchanged when the text is code
    /// (§6.1) — Reformat does not reformat code.
    static func apply(_ input: String) -> String {
        var text = stripEscapes(input)                                  // 1
        text = text.replacingOccurrences(of: "\r\n", with: "\n")        // 2
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")

        // Padding closes *after* stage 3, so its table exemption sees a marker-led
        // row (`⏺ │ a │ b │`) as the table it is.
        var lines = substituteGutters(text.components(separatedBy: "\n")).map(closePadding)  // 3, 3b
        lines = lines.map { $0.trimmedTrailing }                         // 4

        guard !isCode(lines) else { return input }   // verbatim (§6.1)

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

    // MARK: - Stage 2b — padding as a row boundary

    /// Closes a long run of interior spaces to the single space a wrap join uses.
    /// A terminal pads a row out to its own width, so a wrapped row can reach the
    /// clipboard as `text` + padding + the next row's first words, with the break
    /// expressed as spaces rather than a newline. Content *after* the padding is
    /// what says the row continued — padding at the end of a line means the row
    /// ended there, and stage 4 already drops that.
    ///
    /// Not routed through the forced-break rule, which reads pre-join lengths and
    /// would see the tail as a short line that no wrapper had to break.
    static func closePadding(_ line: String) -> String {
        guard !isTable(line) else { return line }   // cells pad to align
        // Split the indent off first: it is the one leading run that may legitimately
        // be this long, and collapsing it would flatten deeply nested output.
        let body = line.drop { $0 == " " || $0 == "\t" }
        guard body.contains(String(repeating: " ", count: minPadRun)) else { return line }
        var result = ""
        var run = 0
        for character in body {
            guard character != " " else { run += 1; continue }
            result += run >= minPadRun ? " " : String(repeating: " ", count: run)
            result.append(character)
            run = 0
        }
        // A run with nothing after it is trailing, not a break; stage 4 drops it.
        return line[..<body.startIndex] + result + String(repeating: " ", count: run)
    }

    // MARK: - Stage 5 — wrap width (§6.1)

    /// Gap-clusters line lengths and returns the **highest** cluster holding at
    /// least `minClusterLines` **and** survives the exceed check. Highest rather
    /// than most populous: a wrapper puts lines *at* its column and never above
    /// it, while short lines (headers, labels, tails) outnumber wrapped ones in
    /// any structured document.
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
        // Walk candidates highest-first and take the first that survives both
        // checks. Picking one and giving up when it fails loses the real column
        // whenever short lines happen to form a bigger cluster than the wrapped
        // ones — which is common when only a couple of lines actually wrapped.
        // `clusters` is already ordered highest-first: it is built by walking the
        // distinct lengths downward, so each new cluster holds smaller values.
        var lonely: Int?
        for cluster in clusters {
            guard let hi = cluster.first, let lo = cluster.last else { continue }
            guard Double(lengths.filter { $0 > hi }.count)
                <= maxExceedingW * Double(lengths.count) else { continue }
            guard lengths.filter({ $0 >= lo && $0 <= hi }).count >= minClusterLines else {
                lonely = lonely ?? hi   // highest-first, so the first one seen is the highest
                continue
            }
            return hi
        }
        // A paragraph wrapped N times puts only N-1 lines at the column, so a
        // single wrap can never form a cluster. Trust the lone candidate only when
        // no populated one exists anywhere below it — that is what separates the
        // one-wrap paragraph from a stray long line above a real column.
        return lonely
    }

    // MARK: - Stage 6 — unwrapping (§6.2, §6.3)

    /// Indices `i` where line `i` should absorb line `i+1`.
    static func forcedBreaks(_ lines: [String], width: Int) -> [Int] {
        let inList = runMembership(lines, openedBy: startsListItem)
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
            guard nextWord.count <= maxAbsorbableToken else { continue }
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
        // Quote lines and table rules keep their own margin, so they must not
        // set the one for prose — a `>` line at column 0 would otherwise pin the
        // common prefix to zero and leave every paragraph indented.
        let indents = lines
            .filter { !$0.trimmed.isEmpty && !isQuote($0) && !isTable($0) }
            .map(\.indentWidth)
        guard let smallest = indents.min() else { return lines }
        let unique = Set(indents).sorted()
        let amount = (unique.count > 1 && indents.filter { $0 == smallest }.count == 1)
            ? unique[1] : smallest
        return lines.map { line in
            line.trimmed.isEmpty ? "" : String(line.dropFirst(min(line.indentWidth, amount)))
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
