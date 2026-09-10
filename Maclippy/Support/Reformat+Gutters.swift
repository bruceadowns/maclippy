import Foundation

// MARK: - Stage 3 — markers, quote gutters and list markers (§5.2, §7)

extension Reformat {

    /// A `❯` prompt gutters only its first line, so its extent is inferred: it
    /// runs to the next blank, and those continuations are quoted too.
    ///
    /// Only the prompt needs that. A `▎` block marks every one of its own lines,
    /// and an `⏺` response marker introduces body prose that must *not* be quoted
    /// — the same shape means opposite things depending on the opening glyph, and
    /// the prompt is the only one whose extent position can supply. A line already
    /// carrying a gutter of its own keeps it, which is what stops an `⏺` response
    /// abutting a prompt from being swallowed into the quote.
    static func substituteGutters(_ lines: [String]) -> [String] {
        let prompted = runMembership(lines) { $0.drop { $0 == " " }.first == "❯" }
        return zip(lines, prompted).map { line, isPrompted in
            guard isPrompted, !isGutter(line) else { return substituteGutter(line) }
            return String(repeating: " ", count: line.indentWidth) + "> " + line.trimmed
        }
    }

    /// True when the line already opens with a marker or quote glyph of its own.
    static func isGutter(_ line: String) -> Bool {
        guard let first = line.drop(while: { $0 == " " }).first else { return false }
        return quoteGlyphs.contains(first) || markers[first] != nil
    }

    /// Replaces a leading marker or quote gutter. Quote gutters normalize to
    /// `> `; markers become an equal-width replacement so columns are preserved.
    ///
    /// `❯` is the terminal prompt, not a rendered blockquote, so mapping it to
    /// `> ` does invent markup — the one place §5.2's de-rendering argument does
    /// not apply. It earns the exception structurally: a prompt is a discrete
    /// utterance that must never merge into neighbouring prose, and quote lines
    /// are the only kind the unwrapper will not touch.
    static func substituteGutter(_ line: String) -> String {
        let pad = String(repeating: " ", count: line.indentWidth)
        let body = line.drop { $0 == " " }
        guard let first = body.first else { return line }

        if quoteGlyphs.contains(first) {
            let rest = body.dropFirst().drop { $0 == " " }
            return rest.isEmpty ? pad + ">" : pad + "> " + rest
        }
        if let replacement = markers[first] {
            // Recurse, because a response marker is chrome and what follows it may
            // be a real gutter: `⏺ ▎ quoted` leaves the `▎` behind otherwise, which
            // a second pass then converts — an idempotency break (fixture 18).
            // Quote gutters deliberately do not recurse: `> > x` is a nested
            // blockquote, and collapsing it would drop a level.
            return pad + replacement + substituteGutter(String(body.dropFirst().drop { $0 == " " }))
        }
        return line
    }

    /// 0-20 as circled digits. Computed rather than tabulated: twenty-one rows
    /// saying "the numbers, in order" hides the pattern instead of recording it.
    static func circledNumeral(_ character: Character) -> Int? {
        let scalars = character.unicodeScalars
        guard scalars.count == 1, let value = scalars.first?.value else { return nil }
        switch value {
        case 0x24EA: return 0                          // ⓪
        case 0x2460...0x2473: return Int(value - 0x2460) + 1   // ①-⑳
        default: return nil
        }
    }

    /// A line-initial `•` or circled numeral is a list marker rather than
    /// punctuation, so it becomes one. Inline, the same numeral is a
    /// cross-reference and flattens to a bare digit — `in ④ and ⑤` reads worse as
    /// `in 4. and 5.`.
    static func rewriteLeadingMarker(_ s: String) -> String {
        let indent = s.prefix { $0 == " " || $0 == "\t" }
        let rest = s.dropFirst(indent.count)
        guard let first = rest.first else { return s }
        let marker: String
        if first == "\u{2022}" {
            marker = "-"
        } else if let number = circledNumeral(first) {
            marker = "\(number)."
        } else {
            return s
        }
        let body = rest.dropFirst().drop { $0 == " " || $0 == "\t" }
        guard body.count < rest.count - 1 else { return s }   // require a separating space
        return indent + marker + " " + body
    }
}
