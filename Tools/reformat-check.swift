import Foundation

// Runs Reformat over docs/fixtures and reports what changed. Not a test target —
// compiled on demand by `make check`. See docs/fixtures/README.md.

@main
enum ReformatCheck {
    static let fixtures = "docs/fixtures"

    static func main() {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: fixtures)) ?? [])
            .filter { $0.hasSuffix(".in.txt") }
            .sorted()

        guard !files.isEmpty else {
            print("no fixtures found in \(fixtures) — run from the repo root")
            exit(2)
        }

        let failures = files.filter { !check($0) }.count

        print("")
        if failures == 0 {
            print("\(files.count) fixtures pass, all idempotent")
        } else {
            print("\(failures) of \(files.count) fixtures failed")
            print("If the new behavior is correct, update the .out.txt files.")
        }
        exit(failures == 0 ? 0 : 1)
    }

    /// Returns true when the fixture matches and is idempotent; prints either a
    /// one-line summary or the first few differing lines.
    static func check(_ name: String) -> Bool {
        let stem = String(name.dropLast(7))
        guard let input = read("\(fixtures)/\(name)"),
              let expected = read("\(fixtures)/\(stem).out.txt") else {
            print("MISSING  \(stem) — no .out.txt")
            return false
        }

        let actual = Reformat.apply(input)
        // Idempotency is the property this design actually fails at, and three of
        // its defects produced correct-looking first-pass output. Check both.
        let idempotent = Reformat.apply(actual) == actual

        if actual == expected && idempotent {
            print("ok       \(stem)  (\(nonBlank(input) - nonBlank(actual)) lines joined away)")
            return true
        }

        print("FAIL     \(stem)\(idempotent ? "" : "  [NOT IDEMPOTENT]")")
        report(got: actual, want: expected)
        return false
    }

    static func report(got: String, want: String) {
        let g = got.components(separatedBy: "\n")
        let w = want.components(separatedBy: "\n")
        var shown = 0
        for i in 0..<max(g.count, w.count) {
            let gl = i < g.count ? g[i] : "<no line>"
            let wl = i < w.count ? w[i] : "<no line>"
            guard gl != wl else { continue }
            print("           line \(i + 1)")
            print("             want: \(wl.prefix(100))")
            print("             got : \(gl.prefix(100))")
            shown += 1
            if shown == 3 {
                print("           …")
                return
            }
        }
    }

    static func read(_ path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    static func nonBlank(_ s: String) -> Int {
        s.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }
}
