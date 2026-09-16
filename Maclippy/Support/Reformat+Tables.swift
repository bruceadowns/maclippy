import Foundation

// MARK: - Stage 8 — box-drawing tables → Markdown (§5.1)

extension Reformat {

    static let cellSeparators = Set("│┃|")

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
        let segments = block.split(whereSeparator: isRuleRow).map { $0.map(cells) }

        let rows: [[String]]
        if rulesBetweenRows(block) >= 2 {
            var merged: [[String]] = []
            for segment in segments {
                guard let row = mergeRow(segment) else { return block }  // ragged: bail out
                merged.append(row)
            }
            rows = merged
        } else {
            rows = segments.flatMap { $0 }
        }

        // A row with nothing in any cell carries nothing. Dropping it before the
        // header is chosen is what §5.1's "first surviving row" means: the source
        // had no header, and Markdown has no headerless table.
        let populated = rows.filter { row in row.contains { !$0.isEmpty } }

        guard let first = populated.first else { return block }
        guard populated.allSatisfy({ $0.count == first.count }) else { return block }  // ragged: bail out

        let delimiter = Array(repeating: "---", count: first.count)
        return ([first, delimiter] + populated.dropFirst()).map { "| " + $0.joined(separator: " | ") + " |" }
    }

    /// Rule rows with a data row on both sides. Two of them prove the table rules
    /// between its *data* rows, which is what licenses treating a rule-delimited
    /// segment as one logical row. One proves nothing: it is the header separator,
    /// and Reformat's own Markdown output has exactly one — reading that as a row
    /// boundary would merge every row of it on a second pass.
    static func rulesBetweenRows(_ block: [String]) -> Int {
        let isRule = block.map(isRuleRow)
        return isRule.indices.filter {
            isRule[$0] && isRule[..<$0].contains(false) && isRule[($0 + 1)...].contains(false)
        }.count
    }

    /// Folds a segment's physical rows into one logical row, joining each column's
    /// fragments. A cell too wide for its column wraps down the segment, and the
    /// other columns are blank on those lines — or not: this table centers its
    /// cells vertically, so the file name sits on the *middle* line of three.
    /// Position carries no meaning, only the column does. Nil if ragged.
    static func mergeRow(_ physical: [[String]]) -> [String]? {
        guard let width = physical.first?.count,
              physical.allSatisfy({ $0.count == width }) else { return nil }
        return (0..<width).map { column in
            physical.map { $0[column] }.filter { !$0.isEmpty }.joined(separator: " ")
        }
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
        // The horizontal run is what makes it a rule. Without this a row whose
        // cells are all empty is nothing but borders and spaces, and splitting on
        // it drops the row and promotes the next one to header.
        if line.allSatisfy({ boxChars.contains($0) || $0.isWhitespace }),
           line.contains("\u{2500}") || line.contains("-") { return true }
        let c = cells(line)
        return !c.isEmpty && c.allSatisfy { cell in
            let core = cell.drop { $0 == ":" }.reversed().drop { $0 == ":" }
            return !core.isEmpty && core.allSatisfy { $0 == "-" }
        }
    }
}
