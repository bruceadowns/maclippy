import Foundation

// MARK: - Stage 3 — markers, quote gutters and list markers (§5.2, §7)

extension Reformat {

    /// Per-line, because every in-domain gutter marks each of its own lines: a
    /// `▎` block repeats its bar, and an `⏺` opens a response whose body prose
    /// must not be quoted at all. Inferring a gutter's extent was only ever needed
    /// for the `❯` prompt, which §0 puts out of domain.
    static func substituteGutters(_ lines: [String]) -> [String] {
        lines.map(substituteGutter)
    }

    /// True when the line already opens with a marker or quote glyph of its own.
    static func isGutter(_ line: String) -> Bool {
        guard let first = line.drop(while: { $0 == " " }).first else { return false }
        return quoteGlyphs.contains(first) || markers[first] != nil
    }

    /// Replaces a leading marker or quote gutter. Quote gutters normalize to
    /// `> `; markers become an equal-width replacement so columns are preserved.
    ///
    /// Every glyph here was a rendered blockquote in the terminal, so the
    /// substitution restores markup rather than inventing it (§5.2).
    static func substituteGutter(_ line: String) -> String {
        let pad = String(repeating: " ", count: line.indentWidth)
        let body = line.drop { $0 == " " }
        guard let first = body.first else { return line }

        let rest = body.dropFirst().drop { $0 == " " }

        if quoteGlyphs.contains(first) {
            return rest.isEmpty ? pad + ">" : pad + "> " + rest
        }
        if let replacement = markers[first] {
            // Recurse, because a response marker is chrome and what follows it may
            // be a real gutter: `⏺ ▎ quoted` leaves the `▎` behind otherwise, which
            // a second pass then converts — an idempotency break (fixture 17).
            // Quote gutters deliberately do not recurse: `> > x` is a nested
            // blockquote, and collapsing it would drop a level.
            return pad + replacement + substituteGutter(String(rest))
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
