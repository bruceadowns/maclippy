import Foundation

// MARK: - Stage 3 — markers and quote gutters (§5.2, §7)

extension Reformat {

    /// Runs the gutter substitution over every line, carrying one piece of state:
    /// a `❯` prompt has no gutter on its continuation lines, so its extent has to
    /// be inferred. It runs to the next blank line, and those continuations are
    /// quoted too.
    ///
    /// Only the prompt needs this. A `▎` block marks every one of its own lines,
    /// and an `⏺` response marker introduces body prose that should *not* be
    /// quoted — so the same shape means different things depending on which glyph
    /// opened it, and only the prompt can be inferred from position.
    static func substituteGutters(_ lines: [String]) -> [String] {
        var result: [String] = []
        var inPrompt = false
        for line in lines {
            if line.trimmed.isEmpty {
                inPrompt = false
                result.append(line)
                continue
            }
            let opensPrompt = line.drop { $0 == " " }.first == "❯"
            if inPrompt, !isGutter(line) {
                result.append(String(repeating: " ", count: line.indentWidth) + "> " + line.trimmed)
            } else {
                result.append(substituteGutter(line))
                if opensPrompt { inPrompt = true }
            }
        }
        return result
    }

    /// True when the line already opens with a marker or quote glyph of its own.
    static func isGutter(_ line: String) -> Bool {
        guard let first = line.drop(while: { $0 == " " }).first else { return false }
        return first == "▎" || first == "┃" || first == ">" || first == "❯" || markers[first] != nil
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

        if first == "▎" || first == "┃" || first == ">" || first == "❯" {
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
}
