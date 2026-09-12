# Reformat fixtures

Real pastes and what [`Reformat`](../reformat.md) should turn them into.

`<name>.in.txt` is a verbatim clipboard capture. `<name>.out.txt` is the expected
output. Nothing runs these automatically — they exist so a change in behavior is
a **diff you can read** rather than something you have to notice by eye.

> **The `.out.txt` files are not authoritative yet.** They were produced by the
> reference implementation, so they currently record what it *does*, not what it
> *should* do. Edit any that are wrong. A hand-corrected expected output is the
> only thing that can catch an implementation which is confidently wrong — one
> that generates both the question and the answer proves nothing.

## Using them

```sh
make check
```

Runs `Reformat` over every fixture and prints the join count for each, or the
first differing lines when one fails. Exits non-zero on failure.

To check the real app rather than the transform, copy a fixture to the clipboard,
hit Reformat in the menu bar, and paste:

```sh
pbcopy < docs/fixtures/01-handoff-brief.in.txt
# Reformat from the menu bar, then:
pbpaste | diff - docs/fixtures/01-handoff-brief.out.txt
```

**`make check` already runs each fixture twice** — output fed back in must not
change. Three of the four defects found while writing the spec produced
correct-looking output on the first pass and only showed up on the second:
dedent ordering, a collapsed wrap-width estimate, and a Markdown table that grew
a `| --- |` row on every run.

## What they cover

Each one earned its place by breaking a rule that reasoning had not predicted;
§8 of the spec records which. Between them they cover terminal wrapping at
columns from 93 to 232, authored prose that only approximates a column,
box-drawing tables, quote-bar gutters, ALL-CAPS and label-style headers, nested
and flush-continued lists, emoji in table cells, a first line that lost its
indent to the selection, a response marker stacked on top of a quote gutter, and
a wrap that arrived as 183 interior spaces instead of a newline, a
paragraph wrapped exactly once, a table whose cells wrap across three physical
rows and sit vertically centered, a prompt bracketed by rules with no blank line
to end it, and a Java method embedded in prose.

There is no *whole-document* code fixture. Reformat leaves such a paste
byte-identical (§6.1), so the pair would be a file diffed against itself — the
calibration that established the guardrail lives in the spec, not on disk. Code
embedded in prose is a different case and fixture 25 covers it.

## Adding one

When Reformat gets something wrong, the paste that broke it is worth more than
any synthetic case. Save it as the next `.in.txt`, write the `.out.txt` by hand,
and the rule change follows from the pair. Every rule in the spec was derived
this way; several were removed the same way once a fixture proved they never
decided anything.

**A sample has to advance Reformat to become a fixture.** Run it first: if it
comes out clean and idempotent under the rules as they stand, it moved nothing,
and it belongs in the scratch pile rather than on disk. Coverage is not the
argument for a pair — a rule it forced, or a rule it pins against regression, is.
Samples 5, 10 and 14 predate this bar and §8 records them as moving no rule; they
are history, not precedent.
