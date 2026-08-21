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
a wrap that arrived as 183 interior spaces instead of a newline, and a
paragraph wrapped exactly once.

There are no code fixtures. Reformat leaves code byte-identical (§6.1), so a
fixture pair would be a file diffed against itself — the calibration that
established the guardrail lives in the spec, not on disk.

## Adding one

When Reformat gets something wrong, the paste that broke it is worth more than
any synthetic case. Save it as the next `.in.txt`, write the `.out.txt` by hand,
and the rule change follows from the pair. Every rule in the spec was derived
this way; several were removed the same way once a fixture proved they never
decided anything.
