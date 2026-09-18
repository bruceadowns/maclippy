# Feature spec — Reformat (menu action)

**Status:** implemented. Per-feature spec; extends [`SPEC.md`](SPEC.md), where
section references (§) point unless noted. Prior art and inspiration credited in
§2.

`SPEC.md` does **not** yet carry this feature. Landing it requires edits to §1
(the user-initiated carve-out), a new §4.9, §5 (menu row, top-block rationale,
ellipsis list), §7 (*Not exposed* and *Limits*), and §10.

## 0. Domain

Reformat is calibrated against **one Claude CLI response stanza, copied from a
terminal session.** Every rule in this document assumes that input.

This is a precondition, not a check. Nothing in the pipeline detects a paste that
violates it and Reformat will still transform one — what the constraint governs
is which pastes earn a rule.

### What a stanza is

It opens with a `⏺` response marker and runs to the status line that closes it:

```
✻ Cogitated for 49s · done 1:37 PM
```

The glyph cycles: `✻`, `✽` and `✶` are animation frames, and a paste captures
whichever was showing. The `· done <time>` suffix is what marks completion — a
bare `✻ Worked for 1m 43s` is the same line mid-flight, and `✻ Waiting for 1
background agent to finish` ends nothing. For trimming, the first status line
after the marker is the cut in all three cases.

### What is excluded

Claude's internal working — everything `ctrl+o` expands — together with the
chrome that frames it:

| Shape | Example |
|---|---|
| Tool calls | `⏺ Bash(python3 - <<'PY'` |
| Tool results | `⎿  === 466c108fd files ===` |
| Elided output | `… +38 lines (ctrl+o to expand)` |
| Prompts | `❯ the latest CL version is deployed in UDEV` |
| Status lines | `✻ Crunched for 56s · done Thursday 3:48 PM` |
| Mode footers | `⏵⏵ auto mode on (shift+tab to cycle) · ← for agents` |

A tool call opens with the same `⏺` as a response, so the boundary is what the
line *is*, not which glyph starts it.

Content **inside** a stanza stays in domain whatever it looks like. A `▎` quote
block is text Claude wrote; a box-drawing table is output Claude rendered; an
embedded code block is part of the answer. The distinction is authorship, not
shape — a `▎` gutter is content, a `⎿` gutter is the terminal reporting on
itself.

### Where the output goes

A Jira ticket, an email, a Teams thread, an MR description, a commit message.
**Most of these do not render Markdown**, and those that do disagree on dialect.
The output is plain text and is read as plain text. That is the whole of what the
plurality implies — not that Reformat should tailor itself to any of them.

One rule follows, and it constrains the *choice of replacement* rather than
licensing renderer-specific behaviour: a transform may not introduce a character
that is markup where the input's was inert. `·` → `*` failed this and was the
only row in §7 that did; `·` → `-` passes (fixture 24). Nothing here asks what a
particular tool does with the output — the job is to flatten the text properly,
and a destination-shaped fix is not a fix. And a change that helps only a rendering destination
is not an improvement: fencing an embedded code block arrives as three literal
backticks in the majority of these places (§12).

### What this is for

Without a domain, every paste is in scope, every counterexample is a rule, and
the corpus grows linearly with samples. With one, a paste outside it that comes
out wrong is recorded and closed rather than calibrated against.

The concrete gain is that **`W` may be assumed to be a single column.** A
transcript holds several — the response at one width, a tool result at another, a
diff view carrying a third from the file it displays — and one estimate over a
mixture is wrong by construction. Excluding tables from the estimate, and later
diff rows, were both patches over that. One stanza has one wrap regime, and the
estimator's premise stops being an approximation it has to be defended against.

A caution the prune itself produced: a rule can look inert because the corpus
lacks its case, not because it decides nothing. Every `·` in the corpus sat on a
status line, so ablating the `·` → `*` row changed no output — and the first
in-domain stanza carrying a body `·` then broke on it (fixture 24). "Removing it
changes no output" is a statement about the corpus, never about the rule.

A caution in the other direction, and the same one: a sample can come out clean
because it is *inside* the domain, not because the rules generalize. Eight
in-domain stanzas were absorbed without a rule change in one validation pass —
two box tables in one paste, embedded Java, quote gutters, a stanza selected
below its marker — and none became a fixture, by the bar in
[`fixtures/README.md`](fixtures/README.md). That says the rules hold across
*shape*, with provenance held fixed by the constraint above. "It was absorbed"
is a statement about the corpus, never about the rules' reach. §8 reads
absorption as the healthy pattern, which it is; it is not evidence of coverage
the domain was narrowed to stop buying.

**What this deleted.** Four fixtures went out of domain along with the rules they
were the only evidence for: a `⎿` width calibration, the `❯` prompt gutter and
the positional fold that inferred its extent, a listing-row exclusion from the
width estimate, a carried-space rule for gutters wider than two, the `·` → `*`
flatten row, and a run terminator for table rows. Each was ablated against the
narrowed corpus first and found to decide nothing.

## 1. Summary

A **Reformat** menu item rewrites the live pasteboard's plain text: it strips
terminal gutter markers, restores indentation, rejoins hard-wrapped paragraphs,
converts box-drawing tables to Markdown, and flattens typographic punctuation to
ASCII.

The motivating case is CLI output — text wrapped to a terminal column, prefixed
with marker glyphs, that reads as ragged fragments once pasted into a merge
request, a commit message, or a ticket. §0 states which pastes that means. The
rules remain shape-driven — no stage branches on provenance — but they are
calibrated against one input domain rather than against text in general.

**One action, not a submenu.** Reformat runs a fixed pipeline. There is no
"unwrap only" variant, no recipe picker, and no preferences (§2).

## 2. Rationale / KISS fit

### The escalation this represents

§1 states *"No decisions about your content — no transformation, no
interpretation."* §4.8 already carves out Clear Formatting on the grounds that a
user-initiated action is not the *automatic* behavior §4.2 governs.

Reformat rides that carve-out but goes further, and the spec should say so
plainly: Clear Formatting drops *representations* and leaves every byte of
`plain` untouched. **Reformat interprets content.** It decides that two lines
were one paragraph, that a glyph was a gutter and not text.

This is permitted for three reasons, and only these:

1. **The user asked, every time.** It is never automatic, never on capture, and
   never applied to stored history. Nothing changes unless a menu item is
   clicked.
2. **The conservative option remains one row above it.** Clear Formatting is
   not replaced (§3). A user who wants "same text, no styling" still has exactly
   that. Reformat is free to be aggressive precisely *because* it is not the
   only choice.
3. **It is undoable in one click.** The result is captured as a new clip, so the
   original sits directly below it in Recent (§3).

### Why no configuration

Per §1's *hardcode over configure*: every constant here (wrap-cluster gap,
forced-break tolerance, the flatten table) is a calibration value derived from
measured samples (§8), not a matter of taste. A user cannot meaningfully tune
"cluster gap = 8". Exposing these would be a footgun, and a user-editable rule
file would make Maclippy a rule engine — squarely §9 territory.

### Why text pruning, not markdown conversion

Converting to a document model and re-rendering markdown was considered and
rejected:

- It **does not remove the hard problem.** Deciding whether a line break was
  forced by wrapping or intended by the author is required either way; markdown
  conversion adds a renderer on top of that work rather than replacing it.
- **The safe defaults run opposite.** Pruning's fallback is "leave the line
  alone" — unrecognized content survives byte-identical. A parser must classify
  everything, and its default classification is "paragraph", i.e. unwrapped. The
  failure mode changes from an invisible missed join to a corrupted code block.
- **Markdown is only conditionally correct.** Emitting `| a | b |` into a commit
  message or a plain-text field is noise.

**Box-drawing tables are the one deliberate exception** (§5.1), and the reasoning
above is what scopes it. The argument against markdown is that pruned text is
*universally* correct while markdown is only *conditionally* correct — true of
prose, false of a box table, which renders as garbage in every destination
including a plain-text one. A Markdown table is strictly better than
`┌──┬──┐` everywhere: it renders in GitLab and Jira, and reads fine unrendered.

That exception does not generalize. It applies to a block kind that is
unambiguously identified by its own delimiters, converted by a total function
with a bail-out, and never inferred from prose.

### Prior art

**[removeclaudewhitespace.com](https://removeclaudewhitespace.com)**
([coeymusa/removeclaudewhitespace](https://github.com/coeymusa/removeclaudewhitespace))
is a web tool solving the same problem — cleaning messy output copied from Claude
Code and terminals. It was found after this design was drafted, and reading its
`lib/clean.ts` was useful precisely because it arrived independently at the same
shape: unify line endings, strip ANSI, normalize NBSP and ZWSP, strip gutters and
markers, rstrip, dedent by common indent, unwrap, collapse blank runs to one,
trim the ends. Two designs converging on that order is better evidence for the
line-oriented architecture (§2) than either one alone.

Where the two differ is instructive rather than competitive:

- It **deletes** box-drawing characters; we convert them to Markdown (§5.1).
  Deleting turns `│ a │ b │` into ` a  b `, losing the column boundaries.
- Its box range covers the Arrows block, so `→` is dropped rather than
  converted — the argument for our explicit flatten table over broad ranges.
- It has **no punctuation handling at all**, which is an entire category here
  (§7).
- Its unwrap ships **default-off**, and its default-on `markdownMode` joins every
  line of a blank-delimited paragraph with no wrap-column inference. Independent
  confirmation that unwrapping is the dangerous stage.
- It exposes eleven boolean options; this is one fixed pipeline. That is a
  product difference more than a design one — a web page with checkboxes and a
  live preview can afford aggressive defaults because a bad result is visible and
  one click from fixed. A menu-bar action with no preview cannot.

Nothing was taken from it directly. Reading it did surface two candidates —
line-number gutter stripping and tab expansion in indent arithmetic — both
currently out of scope (§12).

The older lineage is worth knowing too, since it solved the prefix problem long
ago: `par`(1), Emacs `fill-paragraph` with `adaptive-fill-mode`, and vim's
`formatlistpat`. All of them are *told* the wrap column; inferring it (§6.1) is
the part with thin precedent. **RFC 3676 `format=flowed`** is the standardized
answer — the producer marks soft breaks so the consumer can unwrap losslessly —
and its absence from terminal output is why any of this is heuristic.

## 3. Behavior (proposed SPEC §4.9)

- **Menu position: top block, second of three** — `Clear Formatting`, `Reformat`,
  `Pause` (§5). Settled. The two transforming commands sit adjacent and ordered
  least-to-most invasive, so the conservative option is always the one you reach
  first; `Pause` stays last as the only command that doesn't touch the
  pasteboard's contents.
- Acts on the **live pasteboard**, never on stored history. There is no per-clip
  Reformat in the Clips tab.
- **Emits plain text only.** Rich (rtf/html) flavors are dropped, so Reformat
  strictly subsumes Clear Formatting's effect. Both items remain (§5) — they
  express different intent, and the conservative one must stay available.
- **The result is captured.** Unlike `clearFormatting()`, Reformat does *not*
  suppress self-capture: `lastChangeCount` is left alone, the next poll (§4.1)
  picks the rewritten text up as a new clip, and the original remains one row
  below it in Recent. This is the undo story, and it is the reason unwrapping —
  the transform most likely to guess wrong — is acceptable as a default.
  - Capture dedupes by verbatim `plain` (§4.1), so a second Reformat on
    already-reformatted text is a no-op that bumps `dateRecorded` rather than inserting
    a duplicate. Idempotency (§9) makes this free.
- **No-op when the output equals the input.** The pasteboard is not written and
  no history churn occurs.
- **No-op when the pasteboard holds no text**, matching §4.8.
- Immediate action, no confirmation. Not destructive in the §5 sense — the
  original is recoverable from Recent.

## 4. Pipeline

An ordered list of stages. The array **is** the specification; it is declared
once as `Reformat.apply` (`Maclippy/Support/Reformat.swift`) and mirrored here.
Two stages are large enough to own a file — stage 3 in `Reformat+Gutters.swift`
and stage 8 in `Reformat+Tables.swift` — and the predicates plus the code
guardrail live in `Reformat+Predicates.swift`.

| # | Stage | Notes |
|---|---|---|
| 1 | Strip ANSI/OSC escapes, zero-width characters | `\u{1B}[…m`, `\u{200B}` |
| 2 | Normalize line endings, NBSP → space | CRLF/CR → LF |
| 3 | Marker → fixed-width replacement | §7 marker table; also normalizes quote gutters to `> `, and recurses after a marker so `⏺ ▎` yields both (§5.2) |
| 3b | Close a run of ≥ `minPadRun` interior spaces to one space | §6.1.1; terminal row padding standing in for a wrap, tables exempt |
| 3c | Line-initial `•` or circled numeral → `- ` / `N. ` | a list marker, not punctuation — see below for why it is not stage 9 |
| 4 | Strip trailing whitespace from every line | |
| 5 | Estimate wrap width | §6.1; tables excluded |
| 6 | Unwrap forced breaks | §6.2 |
| 7 | Dedent by common leading whitespace | **after** unwrap — see below |
| 8 | Convert box-drawing tables to Markdown | §5.1 |
| 9 | Flatten punctuation | §7 flatten table; an embedded code block is exempt (§6.1) |
| 10 | Collapse any run of blank lines to 1 | whitespace-only counts as blank |
| 11 | Trim leading/trailing blank lines | output always ends with exactly one line feed |

**Order carries three real constraints**, which a flat list makes look
interchangeable when it is not:

- **Stage 3 must precede everything.** A marker *deleted* rather than replaced
  leaves its line at indent 0 while continuation lines sit deeper, corrupting
  every subsequent indent comparison. The replacement is always exactly as wide
  as the gutter it replaces, so columns are preserved whether it is spaces
  (`⏺`). Every sample in §8 depends on this.
- **Stage 3 must precede 5.** Width estimation measures text, not gutters, and
  must not measure table rows.
- **Stage 3c must precede 6.** Rewriting `①` to `1.` makes the line a list
  start, which `startsListItem` reads and `terminalPunctuation` is relaxed by. Do
  it at stage 9 and pass 1 decides joins on text without the marker while pass 2
  decides them with it — an idempotency break, reproduced on a constructed case
  before the move: a `①` item ending in a period keeps its wrapped tail on pass 1
  and absorbs it on pass 2.

  The cost is that `W` is measured on `1. text` rather than `① text`, one column
  wider than the terminal saw. Every other stage-3 replacement is width-preserving
  on purpose (§7), and this one cannot be — no two-character ASCII form of "item
  one" carries its own separator. One character against a `breakTolerance` of 8 is
  noise, and being *consistent across passes* is worth more than being right to
  the column. Fixture 22's `W` is 237 either way, since its marker lines are
  41–150 characters against a 237 column.

  The inline case is different and stays at stage 9: a circled numeral mid-
  sentence is a cross-reference, flattens to a bare digit, and is therefore
  width-preserving. `the two additions in ④ and ⑤` reads worse as `in 4. and 5.`.
- **Stage 3b sits between 3 and 5, and both sides matter.** It must precede 5
  because a padded line is an outlier — 356 characters where the column is 171
  (fixture 19) — and two of them are enough to form a cluster at the top of the
  distribution and be taken for the wrap column. It must *follow* 3 because its
  table exemption reads the line: run earlier, a marker-led row (`⏺ │ a │ b │`)
  is not yet a table, and its cell padding collapses while its unmarked siblings
  keep theirs. No fixture carries that shape; it was found by inspection.
- **Stage 4 must precede 6.** Width estimation and the forced-break arithmetic
  both measure line length, and trailing spaces would inflate it.

  Reformat removes trailing whitespace and **never removes content**: no stage
  drops a line, a paragraph, or a trailing section. One consequence worth naming:
  trailing double-spaces are a Markdown hard-break marker, so stripping them
  means a destination that renders Markdown treats that break as soft. The
  visible text is identical either way.
- **Dedent must follow unwrap, not precede it.** When a terminal hard-wraps, the
  overflow lands at **column 0** regardless of the block's logical indent
  (sample 6). Those fragments drag the common prefix to `""`, so a dedent run
  before unwrapping silently does nothing — and then a *second* pass over the
  same text, with the fragments now absorbed, finds a uniform indent and strips
  it. That is an idempotency violation (§9), and sample 6 exhibits it.

  Dedent is not needed earlier, because **join decisions are invariant under a
  uniform indent shift.** Adding *k* columns to every line shifts both `len(N)`
  and `W` by *k*, and the forced-break test

  ```
  (len(N) + k) + 1 + len(firstWord) > (W + k) - tolerance
  ```

  reduces to the unshifted form. Nothing upstream of stage 7 can tell the
  difference.

One golden fixture (§9) exists solely to fail if this order changes.

## 5. Line predicates

There is no segmentation pass and no block objects. Line kind is decided by five
independent predicates, each a pure function of one line. The unwrapper consults
them at each candidate join.

`inList` is the exception and the pipeline's **only** state: membership in a run
that a predicate opens and the first line unable to belong to it closes — a
blank, or a table row. One fold expresses it, and two callers share it — list
continuations here, which have the same
shape for the same reason (the opening line carries the marker and the rest carry
nothing).

| Predicate | True when | Effect on a join |
|---|---|---|
| `isTable` | trimmed line starts with `│┌├└┬┴┼─╭╰┏┗┣` or `\|` **and** ends with the mirror set | never joins, either side (§5.1) |
| `isQuote` | line opens with `>` — stage 3 has already normalized `▎` and `┃` to it | never joins, either side (§5.2) |
| `isHeader` | ALL-CAPS after stripping a trailing parenthetical, **and** not ending in `.?!` | never joins, either side |
| `isListStart` | line begins `- `, `* `, `+ `, `N. `, `N) ` | never joined *into* |
| `inList` | line is a list item, or follows one without an intervening blank | relaxes `terminalPunctuation` (§6.3) |

Everything else is ordinary prose and is eligible to join, subject to §6.

**Why predicates rather than a block model.** An earlier draft of this section
described segmenting once into `table` / `quote` / `header` / `listItem` /
`paragraph` and hanging unwrap policy off the kind. It reads well
and it was never built: the implementation these fixtures validate is the five
predicates above. Specifying an architecture that had never run, in order to
replace one that demonstrably works, is the wrong trade — and "segment once,
dispatch on kind" earns its keep in a parser with ten block types, not in five
line tests.

The practical difference is small. A predicate cannot express "this region is
one unit", but nothing here needs that: table conversion (§5.1) gathers its own
run of adjacent rows at stage 8, and quote handling (§5.2) is per-line by
design.

**Unrecognized content is prose**, where every join is still gated by the
forced-break test (§6.2). That gate is necessary but **not sufficient** — bare
source code falls through to prose and the arithmetic happily joins it, which is
why the code guardrail in §6.1 exists as a separate document-level check.

**The `.?!` clause on `isHeader` is not cosmetic.** Ticket IDs and constant names
are all-uppercase: `AFDL-66180.` classifies as a header without it, and fixture 3
loses its final paragraph join. Real headers do not end in sentence punctuation.

### 5.1 Box-drawing tables → Markdown

A `table` block is **converted**, not passed through. Markdown is the target
because it renders in GitLab merge requests, is auto-converted by Jira Cloud's
editor on paste, and stays readable as plain text where nothing renders it. Jira
wiki markup (`||header||`) is deliberately not used — it works in exactly one
destination.

0. **The block must contain a rule row**, or it is not a table and passes through
   untouched. A single line that happens to open and close with `|` is far more
   often ASCII art than a table — fixture 14 holds a side-by-side diff whose lines
   do exactly that, and without this check each was "converted" into a two-line
   table with an invented header and delimiter, turning a 4-line display into 6.
   Every real table carries a rule: `├─┼─┤`, `┌─┬─┐`, or `| --- |`.

1. **Separator rows are dropped**, in *both* dialects:
   - box rules — any row that is nothing but box glyphs and whitespace
     (`├──┼──┤`, `┌──┬──┐`, `└──┴──┘`). A row whose cells are all empty is one
     of these, and is consumed with them — fixture 27's table has a blank header
     row and loses it, which is the intended trade at step 4 below;
   - **Markdown delimiter rows** — every cell matching `:?-+:?`
     (`| --- | --- |`, `| :--- | ---: |`).

   The second is not optional, and omitting it makes the stage **destructive on
   repeat**. A converted Markdown row starts and ends with `|`, which is in the
   box-glyph set, so a second pass re-detects the table — and if the ASCII
   delimiter is not recognized as a separator it is kept as *data* and a fresh
   delimiter is emitted above it. Every Reformat click then adds a `| --- |`
   row. Verified: with the rule, sample 3 is stable across three passes;
   without it, it grows one row per pass.
2. **Remaining rows split on vertical rules** (`│`, `┃`, `|`). The empty cells
   the outer border produces are discarded; each cell is trimmed of its padding.
3. **`|` in cell content is escaped** as `\|`.
4. **The first surviving row becomes the header**, whether or not a separator
   followed it in the source — Markdown has no headerless table. A table with a
   blank header row therefore promotes its first data row; fixture 27 is that
   table, and the alternative — emitting `|  |  |` to keep the row count — was
   tried and rejected as inventing a header cell the source never had.
5. **A `| --- |` delimiter row is emitted per column.** Alignment is *not*
   inferred from source padding: box renderers centre-pad headers regardless of
   intent, so the padding carries no signal, and Markdown alignment is cosmetic.
6. **Ragged bail-out** — if the rows disagree on cell count, the block is emitted
   **unchanged**. An ugly box table beats a mangled Markdown one.

Verified against sample 3: the 11-row block becomes a 6-line Markdown table,
cells intact.

7. **Wrapped cells are reassembled.** A cell too wide for its column continues
   on the next physical line, so a rule-delimited segment holding several lines
   is *one* logical row: each column's fragments join with a space, empties
   dropped. Fixture 21 centers its cells vertically — the file name sits on the
   middle line of three — so position within the segment carries no meaning and
   only the column does.

   This is licensed by the table's own convention, not guessed. Every box table
   in the corpus rules between every row (fixture 3: 5 data rows and 4 interior
   rules; 10: 10 and 9; 14: 5 and 4; 20: 6 and 5), and fixture 21's 5 physical
   data rows against 2 interior rules is what marks the extras as continuations.

   **The test is two interior rules, not one.** A rule with a data row on each
   side proves the table separates *data* from data. A single interior rule
   proves nothing — it is the header separator, and Reformat's own Markdown
   output has exactly one, so reading it as a row boundary would fold that whole
   table into one row on a second pass. With one rule the physical rows are
   emitted as they stand, which is the old conservative behavior.

### 5.2 Quote blocks

A line opening with `▎`, `┃` or `>` is a quote line. The gutter is normalized
to `> ` and **the content is not unwrapped** — quote lines are excluded from
every join.

They are **not** excluded from either measurement, and the distinction matters: a
quote line is still prose, wrapped by the same terminal at the same column as
everything around it.

- **Width estimation.** Excluding them cost fixture 11 all five of its joins —
  strip the quote lines out of a quote-heavy paste and no cluster survives, so no
  column can be established at all.
- **The code guardrail (§6.1).** Excluding them made fixture 18 read as code. It
  is a `Draft reply:` label above four quoted lines, so the only measurable line
  was two words long; the guardrail called the paste code and returned it
  verbatim, gutters and em dashes intact.

Both were the same mistake made twice: treating *not unwrapped* as *not
evidence*. A quote is exempt from being **joined**, not from being **counted**.

`▎` is the CLI's rendering of a Markdown blockquote, so emitting `> ` restores
the source markup rather than inventing it — the same argument §5.1 makes for
tables. Recognizing `>` on input as well as output is what keeps the stage
idempotent, and it handles email-style quoting for free.

An earlier draft ended the run at a blank alone, on the claim that a real
transcript always puts one between a prompt and what follows. That is false, and
fixture 22 is the counter-example: the CLI brackets its prompt in `─` rules with
no blank anywhere near it, so the closing rule and the status footer beneath it
were both quoted as though the user had typed them. A table row cannot be a
prompt continuation, so it closes the run.

**A marker and a gutter can open the same line**, and the substitution has to
consume both. `⏺ ▎ text` is one line of quoted assistant output: replacing only
the leading `⏺` leaves the `▎` sitting in the text, where it fails the §9
no-marker-survives invariant, keeps the line out of `isQuote` while its
continuations are in, and — because a second pass sees the `▎` at the front and
converts it — **breaks idempotency**. So a *marker* replacement recurses on what
follows it. A *quote gutter* does not: `> > x` is a nested blockquote, and
recursing would silently drop a level. Fixture 17 is the case; it changes no other
fixture.

**Not unwrapping is what makes this cheap.** An earlier design substituted the
gutter and let the unwrapper run, which welded the marker into the middle of
sentences (`…consults the geography fields > in order and takes…`) and needed a
strip-process-reapply block to avoid. Leaving quote content alone reduces the
whole feature to a per-line substitution.

It is also the better output. Markdown treats consecutive `>` lines as one
paragraph with soft breaks, so the quote renders as flowing text regardless — the
renderer does the unwrapping, while the plain-text form keeps the line structure
the author saw.

This is **not** the code rationale (§6.1). Code must not be unwrapped because
joining statements produces invalid syntax; quoted prose stays valid either way.
The reason here is that unwrapping buys nothing a Markdown renderer does not
already do.

## 6. Unwrapping

### 6.1 Wrap width

Greedy wrappers break a line only when the next word will not fit, so the
break-was-forced question needs the column. It is estimated per clipboard — the
corpus spans 93 to 242 (§8), so no constant is possible.

1. Collect lengths of non-blank, non-table lines, measured in **characters** —
   Swift's `String.count`, never `utf8.count`. `—`, `§` and box-drawing glyphs
   are multi-byte, and byte counts inflate every measurement.

   `String.count` counts grapheme clusters where the reference implementation's
   `len()` counts code points, so the two could in principle disagree and
   invalidate the calibration. Checked: they do not. All 26 distinct non-ASCII
   characters in the corpus are one code point and one grapheme — no combining
   marks, ZWJ sequences, variation selectors, regional indicators or skin-tone
   modifiers anywhere. Every measured width holds under either scheme.

   **Known limitation: character count is not display width.** Terminals wrap on
   columns, and East Asian Wide characters — CJK, most emoji — occupy two. The
   corpus contains two (📝, ✨), both inside table cells, which are masked from
   estimation, so nothing is affected today. CJK or emoji in *prose* would make
   lengths understate the true column and smear the cluster. The fix is a
   `wcwidth` table: real complexity for a case no fixture exhibits.
2. Sort descending, group where the gap between adjacent distinct values is
   ≤ **8**.
3. Walk groups **highest first** and take the first that holds at least 3 lines
   *and* survives the exceed check below — not the group with the most lines.
4. `W` = that group's maximum. When no group holds 3, fall back in descending
   order of evidence: the **highest** group holding 2 that passed the exceed
   check, and only if none does, the highest that passed it at all, however few
   lines it has. A paragraph wrapped *N* times leaves only *N-1* lines at the
   column, so a paragraph wrapped exactly once can never form a group — and that
   is the most ordinary paste there is (fixture 20). A single wrapped list item
   leaves two when a long token forces its first break early (fixture 26). Both
   rungs apply only when nothing better-populated exists anywhere below, which is
   what separates a real column from a stray long line sitting above one: in
   fixture 1 a lone 120-character line loses to the 31-line column at 95, as it
   must.

   What keeps this safe is `terminalPunctuation` (§6.3). The fallback's exposure
   is a long line followed by a short one, and when the long line ends a sentence
   the join is already declined — so the shape it can act on is a line that
   breaks mid-sentence, which is a wrap by definition.
5. **Reject the estimate entirely** — skip unwrapping — if either check fails:
   - more than **25%** of measurable lines exceed `W`. A greedy wrapper never
     emits a line longer than its column, so a document where many lines do was
     not wrapped at `W` and the estimate is an artifact.
   - **mean words per line < 8** — the code guardrail (below).

   An earlier draft also rejected `W < 40` as implausibly narrow. Ablation shows
   it never fires: reaching 8 words per line takes roughly 40 characters, so the
   code guardrail already excludes every document a narrow `W` could come from.
   Removed.

### The code guardrail

Nothing else in this spec stops bare source code from being unwrapped,
and unwrapping it produces syntactically broken output. `ClipboardMonitor.swift`
run through the pipeline without this gate yields 7 joins, every one of them
welding two statements into one line.

The gate is a single document-level measurement, and it disables the **whole
pipeline**, not just unwrapping:

```
contains a rule row (§5.1)                      ->   never code
mean(words per non-blank, non-table line) < 8   ->   return the input unchanged
```

The table exemption is not a softening of the gate. A box table is something a
terminal drew and source code does not contain one, so its presence settles the
question the mean is trying to answer. It has to be stated separately because
table rows are *masked* from the measurement — the same "not unwrapped, therefore
not evidence" mistake that quote lines made at fixture 18 — which leaves a stanza
that is mostly table with almost nothing to measure. Fixture 27 is one prose line
above a nine-row table: the mean is 6.0 over that single line and the whole paste
came back byte-identical, marker included.

Reformat does not reformat code. Dedenting a pasted method or flattening an em
dash inside a comment is still an edit to source, so once the text is judged code
every stage is skipped and the output is byte-identical to the input — which then
trips the "no-op when output equals input" rule in §3, so the pasteboard is never
written. Paste code, hit Reformat, nothing happens.

**Why words per line and not something cleverer.** A wrapper *fills* a line to
the column with as many words as fit, and prose words are short — so wrapped
prose is dense in space-separated tokens. A code line ends where its statement
ends, however few tokens that took. The measure is a direct consequence of what
wrapping *is*, which is why it separates cleanly where surface heuristics do not:

| Signal | Prose range | Code range | Separates? |
|---|---|---|---|
| **Words per line** | **8.9 – 19.2** | **1.5 – 7.4** | **yes** |
| Symbol density (`(){}[];=<>`) | 0.00 – 0.36 | 0.29 – 0.86 | no — overlaps |
| Mean word length | 5.10 – 7.06 | 5.36 – 24.75 | no — overlaps |
| Alphabetic + space fraction | 0.89 – 0.97 | 0.85 – 0.93 | no — overlaps |

Measured over the eleven prose fixtures (§8) and seven code files — hand-written
Java, Python and YAML, plus the four real Swift sources in this repository. At
threshold 8 every prose fixture keeps **all** of its joins and every code file is
returned untouched. The code files are not kept as fixtures: with the pipeline a
no-op on them, a fixture pair would be a file diffed against itself.

Two honest limitations:

- **The margin is 1.5 words** — sample 1 sits at 8.9, the Java fixture at 7.4.
  Narrow, but it holds across seventeen files of very different shape, and both
  extremes are the hard cases (sample 1 is the most list-heavy prose; the Java
  fixture was hand-written to be worst-case).
- **The gate is whole-document, and cannot usefully be made per-block.** Measured
  at block granularity the signal collapses: twelve *prose* blocks in the corpus
  fall below the threshold — `SCOPE` at 7.3, `CALLERS` at 3.7, `RELATED TICKETS`
  at 7.0 — because headers and short-line lists look exactly like code by this
  measure, while the Java fixture sits at 7.4 and would pass. There is no
  threshold that separates them. Block-level gating would also lose a real join
  inside sample 1's `SCOPE` block.

  So a paste mixing prose and code takes the majority verdict, and the document
  reads as prose. Fixture 23 is that paste, and it narrows the consequence rather
  than removing it — see *Embedded code* below.

### Embedded code

Fixture 23 is prose wrapping a four-line Java method. The document mean sits well
above 8, so the gate above correctly reads it as prose and the pipeline runs —
through the method as well. Only one stage did damage: flattening turned the em
dash in `// untouched — the filter never runs` into a hyphen, an edit to source.

The other two stages that could have reached it did not, and not by luck. A join
requires a line sitting at the wrap column, and a code line ends where its
statement ends — the same fact the words-per-line measure rests on. Dedent removed
the 2-space margin the *terminal* added, shared by every line in the paste; the
`if`/`return`/`}` nesting the author wrote is untouched. Leaving code at its
captured indent would preserve an artifact of the capture, not a property of the
source.

So the rule is narrow: **a code block inside a prose document is exempt from
stage 9, and from nothing else.**

```
>= 2 consecutive non-blank lines, a majority ending in `;` `{` `}`
```

This is the `;{}` signal rejected just above, and the difference is what it has to
do. As a gate it had to catch every language, and missing Swift and Python was
fatal. As a supplement under a gate that already handles whole-document code, it
only has to be **precise** — a language it misses costs exactly what the status
quo costs, while a block it recognizes is one it will not mangle. Incompleteness
is affordable here and was not there.

Membership is computed immediately before stage 9 rather than with the other
predicates: joins and table conversion both change the line count, so an index
taken earlier is stale.

**The threshold rests on one sample.** `minWordsPerLine` was calibrated against
seven code files; the majority rule here has fixture 23 and the neutrality of
every other fixture behind it, which is thinner. It is recorded as such rather
than dressed up. A rule resting on one sample is held only until a second
disagrees with it.

Approaches tried and rejected, each defeated by real data rather than reasoning:
`;` `{` `}` as unconditional terminators (fixes C-family only — Swift and Python
lack them); symbol density (overlaps); requiring line *N* to be filled to the
column (costs 10 prose joins and still leaves 24 code joins).

**Both sanity checks are load-bearing, and idempotency is what needs them.**
Re-running the pipeline on its own output re-estimates `W` against a document
that is now a handful of very long joined lines plus short residue — labels,
bullets, rules. On sample 7's second pass the short residue is the densest
cluster and yields `W = 21`, which then admits `Amplifying Detail(s):` as
wrapper output and welds it onto the paragraph below. The 25% check rejects that
estimate outright: with `W = 21`, most lines exceed it.

**Highest, not most populous.** A greedy wrapper puts lines *at* its column and
never above it, so the wrap column belongs at the top of the length distribution.
Selecting the most populous cluster instead systematically picks short lines,
because headers, labels, list items and paragraph tails outnumber wrapped lines
in any structured document. Fixture 12's true column is a 3-line cluster at
201–202; the most-populous rule picked a 6-line cluster at 29–46 and the sanity
checks then rejected it, so nothing unwrapped at all. Fixtures 1–11 are
prose-dense enough that the two criteria agree.

**Two lines, and each candidate is tested rather than the first one taken.** A
3-line minimum reads safer but discards the real column whenever only a couple of
lines happened to wrap — fixture 15 has exactly two at 241–242 and every other
bullet ends naturally, so a 3-line rule estimates nothing at all and unwraps
nothing. Testing candidates in descending order matters for the same reason:
picking one and giving up when it fails the exceed check loses the column
whenever short lines form a larger cluster than the wrapped ones.

Lowering the minimum to 2 also recovered joins in fixtures 8 and 14 that had
been recorded as conservative misses. It was rejected once before, because it
broke idempotency on fixture 1 — that turned out to be a weak guard the 3-line
minimum was masking rather than a reason to keep it (§6.2).

**The maximum line length is not usable as `W`.** Sample 1's longest line is an
unwrapped 174-character paragraph against a true column of 93. Sample 3's
tightest cluster is eleven box-table rows at exactly 108 characters against a
true column of 210 — masking tables (step 1) is what prevents the estimator
being hijacked by a table's uniform padding.

Taking the cluster *maximum* rather than its centre is deliberate. The ceiling
`len(N) ≤ W` (§6.2) must admit every line in the cluster, since by construction
they are all wrapper output. Centring `W` in the band rejects the upper half of
its own cluster and needs a slack constant to claw them back. The maximum needs
none.

### 6.1.1 When the wrap arrives as padding

A terminal pads a row out to its own width. Usually that padding is trailing, and
stage 4 drops it — fixtures 11 and 17 each carry a line padded with 191 and 148
spaces and neither needed a rule. Fixture 19 is the same artifact with the next
row's first word appended to the same buffer line:

```
Lead with the lease benefits — … benefits are cheap: you're[183 spaces]not
```

170 characters of text, the padding, then `not`. **Content after the padding is
what says the row continued**; padding at the end of a line says it ended. So the
run is a line break written as spaces, and closing it to the single space a wrap
join uses is the whole rule.

It is *not* routed through §6.2 by splitting the line at the run. That reads well
— hand the break to the rule that already decides breaks — but `forcedBreaks`
measures pre-join lengths, so the 3-character tail `not` looks like a line no
wrapper was ever forced to break. The join stops there on pass 1 and happens on
pass 2, which is an idempotency violation.

Table rows are exempt: cells pad to align, and fixtures 3, 10 and 13 lose their
tables without the exemption.

**Why a threshold at all**, rather than collapsing every run of two or more? Prose
has no use for a second space, so the simpler rule is tempting — and it was tried.
It destroys fixture 14, whose side-by-side ASCII diff carries its two columns on
one line (`pass 1:  | … |      pass 2:  | … |`) and does not match `isTable`,
which wants a box glyph at both ends. Collapsing runs the columns together, which
is the one thing this feature must never do.

Nor can tuning save both: fixture 14's alignment runs reach **11** spaces and
fixture 19's `file:line` listing uses 10 and 11. The two are indistinguishable by
run length, so any threshold that spares the diff also spares the listing. The
listing keeping alignment it does not need is the cheaper error.

Interior runs across the corpus are 2–11 (alignment) and 183 (padding), so 32
sits between them with room on both sides. It is absolute rather than a fraction
of `W`, for the same reason as `maxAbsorbableToken`: `W` grows once lines are
joined, so a `W`-relative bound stops holding on a second pass.

Trailing runs are a separate population and need no rule — fixture 11 carries
192 and fixture 13 carries 115, both dropped by stage 4.

The stage runs after marker substitution so that its table exemption sees a
marker-led row as the table it is (§4).

### 6.2 The forced-break test

Join line *N* with *N+1* when

```
len(N) + 1 + len(firstWord(N+1)) > W - tolerance
```

with **tolerance = 8**, subject to one precondition: the next line's first token
must be at most **100 characters**. A token that long is a path, URL or
identifier sitting on its own line, never a word the wrapper pushed down — this
is what stops fixture 1's list item 1 from swallowing a 113-character file path.
Dropping it costs a wrong join immediately, so it stays.

**The bound is absolute, not relative to `W`.** It was `len(firstWord) ≤ W`
originally, which holds on a first pass and fails on a second: joining lines
raises `W`, so the same path stops exceeding it and gets absorbed. That is an
idempotency break the 3-line cluster minimum was accidentally hiding. The corpus
separates cleanly — of 257 non-table lines only two open with a token over 40
characters, and the longest legitimately joined one is 77 against the path's
110.

An earlier draft also required `len(N) ≤ W`. It was removed as redundant: every
case it caught (sample 1's `RELATED TICKETS` entries) is already caught by
`terminalPunctuation`. Its presence had also forced a workaround: a cluster-size
fallback in §6.1 existed purely because the ceiling blocked sample 8's only join,
and removing the ceiling removed that need.

The fallback is back, for an unrelated reason — a paragraph wrapped once cannot
form a cluster at all (§6.1 step 4, fixture 20). Worth recording as a caution
about ablation: "removing it changes no output" proves the corpus lacks the case,
not that the rule is unnecessary.

The tolerance exists because a fixed-column wrapper does not leave a fixed-column
*trace*. Under §0 every paste came from one, but only lines long enough to reach
the column were broken by it — a stanza of short bullets, labels and headers ends
its lines on its own, and its spread reflects sentence lengths rather than a
boundary. The corpus shows the two plainly (§8):

| Lines | Samples | Cluster span |
|---|---|---|
| Filled — long enough that the wrapper broke them | 2, 3, 6, 7, 8 | 6–16 chars |
| Short — ending before the column, spread by their own content | 1, 5 | 25–43 chars |

(Sample 4 is three lines total — too short for its spread to classify anything.)

A tight cluster means every line stopped at the same boundary; a smeared one means
most of them stopped somewhere else. Tolerance 8 lets a short-lined stanza still
register the forced breaks it does have, and the guards below absorb the false
joins it would otherwise admit.

### 6.2.1 A break inside a token

A join normally inserts a space, because the wrapper removed one. Sometimes it
removed nothing: a token wider than the column cannot be placed on a line at all,
so the wrapper splits it. Rejoining those fragments with a space corrupts the
token — for a URL, the difference between a link and a dead string:

```
...bluestaq-udl-common/src/main/ja        <- the wrapper had no choice
va/com/.../HistoryUtils.java#L410-437
```

**The test is that the two fragments together exceed `W`.** A word-wrapping
renderer breaks a token only when the token cannot fit alone, so `len(tail) +
len(head) > W` is not a heuristic about URLs — it is the definition of the
situation, and it needs no constant.

Line length is *not* the test, which is what fixture 25 is for. Two of its lines
sit at exactly `W` = 208: one is the split URL, the other ends `…identically
across` with `all nine operators.` below it, a perfectly ordinary space break
where the last word happened to fit exactly. Length cannot tell them apart; the
fragment sum can, and does — one hit in the fixture, and none anywhere in the
corpus that a guard does not already exclude.

Such a join is made with **no separator**. Declining it instead would leave the
URL split across two lines, which is the input's problem rather than a repair.

### 6.3 Join guards

All must pass. Declared as a named table so each is individually testable.

| Guard | Blocks a join when |
|---|---|
| `blankNext` | the next line is blank (whitespace-only counts) |
| `intoListItem` | the next line starts a list item |
| `header` | either line is a header |
| `terminalPunctuation` | the current line ends in `.` `?` `!` — **unless** the current line is inside a list item and the next is not, **or** the next line is itself ≥ `W - tolerance` |

**`terminalPunctuation` is the highest-value guard.** It is what keeps sample 1's
two `CALLERS` entries apart — 86 + `udl-aodr` = 95 > 85 would otherwise join two
unrelated facts. A missed join is invisible; a wrong join corrupts meaning.

**Its list-item exemption is what makes it affordable.** Inside a list, sibling
items always carry a marker, so `intoListItem` already separates them — the
punctuation guard is redundant there and only causes damage. A non-marker line at
an allowed indent following a list item is a continuation *by construction*.
Suppressing the guard inside lists gains three joins in sample 1 (including both
of its previously-known misses) and one in sample 6, with no false join anywhere
in the corpus.

The ambiguity it resolves is genuine and cannot be settled by proximity to `W`:
sample 1's `CALLERS` line sits 7 columns short of the wrap column and must *not*
join; sample 6's TLS bullet sits 6 short and must. Only list membership
distinguishes them.

**A colon is not a terminator and is excluded.** `.?!` close a thought; `:`
promises that what follows belongs with it. Sample 7's `…keyed on collection
name instead:` wraps at 216 against `W = 232` with a 27-character next word that
plainly could not fit — an unambiguous forced break that the guard blocked purely
because the wrap point landed on a colon. Removing `:` changes no join in samples
1–6 and recovers that one.

Label headers (`Body:`, `Acceptance Criteria:`, `Dependencies:`) were the reason
`:` was originally included, and they do not need it: they are short, so the
forced-break test declines them on length alone — `Dependencies:` is 13
characters against a threshold of 224. Protection comes from the arithmetic, not
the punctuation.

**Its second exemption — next line at the wrap column — resolves the period
case.** A line ending in `.` right at the wrap column is genuinely ambiguous, and
proximity to `W` cannot settle it (above). What *can*: whether the **next** line
is itself wrapper output. If it reaches `W - tolerance` the wrapper produced it,
so the pair sits mid-run and the period is coincidental. If it is short, it is a
standalone item.

- Sample 9, join wanted: `…COUNT_MAX_LIMIT guard.` (227) → next line 232 ≥ 224 →
  exempt, joins.
- Sample 1, join refused: `…both same file.` (86) → next line 82 < 85 → guard
  holds, the two `CALLERS` entries stay apart.
- Sample 1, join refused: `…can run in parallel.` (77) → next line 39 → guard
  holds.

Across nine samples this adds exactly one join — the one a hand-written expected
output called for — and blocks the two it must.

**Two guards were removed as redundant**, verified by ablation across all eleven
prose fixtures and the seven code files of §6.1 — neither changed a single join, in
either direction, nor broke idempotency:

- `hardBreak` (line ended in 2+ spaces before rstrip). No sample exercises it,
  and stage 4 destroys the marker regardless, so it protected nothing while
  costing a pre-pass and an ordering constraint.
- `indentMismatch` (next line's indent must match the current indent, the hanging
  column, 0, or the document's modal indent). This one grew to four alternatives
  chasing samples 2, 6 and 9 — and then turned out never to be the deciding
  factor, because `intoListItem` and `header` already catch
  every case it would have. Four alternatives that between them permitted
  everything is a guard that guards nothing.

### 6.4 Dedent

Stage 7 removes the common leading indent, stripping `min(lineIndent, amount)` so
no line ever loses whitespace it does not have. Two rules keep the margin honest,
each forced by a real paste.

**A minimum held by exactly one line is a paste artifact, not a margin.** Terminal
selections routinely miss the first line's indent, leaving it flush while
everything below sits at 2. Fixture 9 opens that way. Dedent ignores a
single-line minimum and uses the next smallest.

**Only lines dedent can act on are measured.** Quote lines and table rules keep
their own margin, so they are excluded from the computation entirely. Fixture 16
is why: an already-reformatted transcript containing `> shorten sentences`,
`> exit` and two horizontal rules has *four* lines at column 0 — neither a lone
artifact nor a genuine margin. They pinned the common prefix to zero and left
every paragraph indented by 2.

Note the interaction: the first rule requires *exactly one* line at the minimum,
so it cannot cover the second case. They are separate rules because they fail in
separate ways.

## 7. Substitution tables

### Markers

Each glyph maps to a **fixed-width replacement string** (§4 stage 3). The
replacement's length equals the gutter's column width, so content stays where it
was and every downstream indent comparison still holds.

The rule is **positional, not frequency-based**: any glyph in this table is
replaced wherever it opens a line. That is why a once-per-response marker (`⏺`)
and a per-line quote gutter (`▎`, sample 11) share one mechanism and need no
separate gutter rule — and why the substitution must pad rather than delete,
since deleting a per-line gutter leaves the quoted block ragged against its
surroundings.

Left unstripped, a quote gutter is not merely cosmetic. Unwrapping welds it into
the middle of a sentence — `…consults the geography fields ▎ in order and takes…`
— which is content corruption, not a formatting miss.

| Glyph | Gutter | Replacement | Validated |
|---|---|---|---|
| `⏺` | 2 | two spaces | yes — every sample carrying a marker |
| `●` | 2 | two spaces | no |

### Flatten

Codepoints are given because several of these are visually indistinguishable
from their ASCII targets in source.

| From | | To |
|---|---|---|
| `“` `”` | U+201C, U+201D | `"` |
| `‘` `’` | U+2018, U+2019 | `'` |
| `″` `′` | U+2033, U+2032 | `"` `'` |
| `…` | U+2026 | `...` |
| `–` `—` | U+2013, U+2014 | `-` (single hyphen, both) |
| `→` `←` | U+2192, U+2190 | `->` `<-` |
| `≤` `≥` | U+2264, U+2265 | `<=` `>=` |
| `×` | U+00D7 | `x` |
| `·` | U+00B7 | `-` |
| `•` at line start | U+2022 | `- ` (stage 3c) |
| `①`–`⑳`, `⓪` at line start | U+2460–U+2473, U+24EA | `1. `–`20. `, `0. ` (stage 3c) |

**What belongs here, and what the replacement may cost.** The table takes
*typographic punctuation* — glyphs that are a typesetter's rendering of something
ASCII already expresses. Content glyphs do not qualify and are passed through:
`§`, `é`, `✓`, `✗` and emoji all survive, and emoji specifically must, because a
replacement would change the line's display width and the spacing a table or a
diagram depends on would stop being truthful (§12).

Prefer a replacement of the same width. `·` → `-` is width-preserving; `…` →
`...` and `→` → `->` are not, and the resulting skew in ASCII art is an accepted
cost recorded in §12 — tolerated only because those glyphs have no single-column
ASCII equivalent. A replacement must also be inert as markup, which is the whole
of what was wrong with `·` → `*` (fixture 24).
| `①`–`⑳`, `⓪` inline | same | the bare digit — a cross-reference, not a marker |
| `--` between whitespace | (ASCII) | `-` |

**`--` is the one ASCII-to-ASCII entry**, and it is here for consistency rather
than as an exception: `--` is the typewriter convention for an em dash, so
leaving it while mapping `—` to `-` puts two spellings of the same mark in one
document. It collapses only when surrounded by whitespace or ending a line —
`(?<=\s)--(?=\s|$)` — which leaves `---` horizontal rules, `--flag` and `i--`
untouched. Verified against every hyphen run in the corpus: three punctuation
uses collapse, three horizontal rules survive. A spaced SQL comment marker
(`SELECT 1 -- note`) would also collapse, but SQL pasted as code never reaches
this stage (§6.1).

Three other stages also remove non-ASCII, and together with this table they are
the whole of it: **stage 2** maps NBSP (U+00A0) to a space and drops ZWSP
(U+200B); **stage 3** replaces marker glyphs with spaces (§7 markers); **stage 8**
consumes box-drawing characters, mapping `│` to `|` and `─` to `-` and dropping
the corner and junction glyphs (§5.1).

Replacements are not length-preserving (`…`→`...` is +2; `→`, `≤`, `≥` are +1).
That is safe **for the rules**, because flatten is stage 9 — after width
estimation (5), unwrapping (6), dedent (7) and table conversion (8). Nothing
downstream measures columns, so no expansion can shift a wrap decision.

**Known limitation: it skews ASCII art.** Column position carries meaning in
side-by-side displays and hand-aligned diagrams, and an expanding glyph pushes
everything to its right. Fixture 14 measures it — two lines aligned at column 45
in the input come out at 43 and 45, because one contains a `…` whose +2
expansion cancels the dedent applied to the other:

```
INPUT   right-half starts at cols: [11, 45, 45]
OUTPUT  right-half starts at cols: [ 9, 43, 45]
```

Scope is narrow. Prose is reflowed anyway so column position is meaningless;
Markdown table cells need no alignment; quote and code blocks are untouched.
ASCII art is the only content type where position matters and no block kind
protects it — and it is the same content the §5.1 rule-row check exists to
protect from the table converter, damaged here through a different door.

Accepted rather than fixed. The remedy would be an aligned-column block kind,
needing a detector there is no calibration for, against a single instance in the
corpus.

### What is *not* flattened

**The mechanism is simply "not in the table."** There is no separate keep-list —
a character is flattened if and only if it appears above. Three cases are worth
naming because a reader will ask about them:

- `✓` U+2713, `✗` U+2717 — no unambiguous equivalent. `[x]`/`[ ]` is a checkbox
  convention and a `✓` in running prose is not a checkbox; `y`/`n` changes
  meaning; `+`/`-` collides with list and diff markers.
- `§` U+00A7 — **kept**, on the same grounds. `S` is a lossy substitution, not a
  de-prettification, and `#` is disqualified outright because GitLab renders `#6`
  as an issue link and Jira behaves similarly, so `§6` would silently become a
  reference to an unrelated ticket in the exact destination this feature targets.

Everything else follows automatically. Accented Latin (`é`, `ï`), symbols (`°`,
`±`, `µ`, `£`, `€`, `½`), Greek, CJK, and emoji appear in no table and pass
through untouched. Sample 10 carries 📝 and ✨ inside table cells; they survive
three passes verbatim.

That is correct behavior — a clipboard tool that turned `café` into `cafe`, or
ate a CJK paragraph, would be broken — but it means **the guarantee must be
stated as an output property, not an input one**:

> No stage introduces a non-ASCII character, and every non-ASCII character in the
> output was present in the input.

The earlier phrasing ("every non-ASCII input character is either converted or on
the keep-list") was simply false: `é` is neither.

**A useful consequence follows.** The flatten table reverses *typographic
substitution* — every entry has an ASCII ancestor that some editor or renderer
prettified (`--`→`—`, `"`→`“`, `...`→`…`, `->`→`→`, `<=`→`≤`). It does not
translate symbols. `✓` was never an ASCII character that got beautified, which is
why it stays.

`§` is the one entry that breaks that rule — it has no ASCII ancestor, and its
mapping to `S` is a deliberate exception made on destination grounds (above),
not on the typographic principle.

Verified across the corpus (§8): the only non-ASCII characters surviving any
sample are `§` (5 occurrences, samples 2 and 3) and the 📝 / ✨ emoji in sample
10's table cells — all present in the input, none introduced.

## 8. Calibration corpus

Every fixture in [`docs/fixtures/`](fixtures/) is a real paste, and every one is
in the table below, measured at stage 5 — markers substituted, tables masked,
**not yet dedented** (dedent is stage 7). "Lines" says whether the stanza's lines
were long enough for the terminal to break them (§6.2) — not who wrote them; under
§0 a terminal wrapped all of it.

| # | Shape | Count | Lines | `W` | Cluster (span) | Joins |
|---|---|---|---|---|---|---|
| 1 | Handoff brief; ALL-CAPS headers, nested list, file paths | 41 | short | 95 | 52–95, 31 lines (43) | 11 |
| 2 | Completion report; flush continuations | 22 | filled | 209 | 200–209, 9 lines (9) | 8 |
| 3 | Cross-repo review; 11-row box table | 23 | filled | 212 | 201–212, 9 lines (11) | 7 |
| 4 | Single 3-line bullet | 3 | short | 93 | 82–93, 3 lines (11) | 2 |
| 5 | Risks + acceptance criteria; header abutting a list | 21 | short | 95 | 70–95, 16 lines (25) | 7 |
| 6 | Status summary; column-0 hard wraps | 9 | filled | 187 | 181–187, 3 lines (6) | 3 |
| 7 | Ticket draft; label headers, `---` rule, long paragraphs | 26 | filled | 232 | 216–232, 10 lines (16) | 10 |
| 8 | Four bullets, one wrapped | 5 | filled | 181 (pair fallback) | 173–181, 2 lines (8) | 1 |
| 9 | Ticket draft; first line missing its indent | 29 | filled | 232 | 224–232, 8 lines (8) | 10 |
| 10 | Summary + 21-row, 3-column box table with emoji cells | 9 prose (+21 table) | filled | 165 | 160–165, 3 lines (5) | 3 |
| 11 | Push summary + `▎` quote-bar blocks | 17 | filled | 232 | 219–232, 8 lines (13) | 5 |
| 12 | Prose interleaved with indented examples and a `>` quote block | 16 | filled | 202 | 201–202, 3 lines (1) | 3 |
| 13 | Prose + 11-row box table with `✓`/`✗` cells and a blank header cell | 10 prose (+11 table) | filled | 202 | 198–202, 3 lines (4) | 4 |
| 14 | Prose + a side-by-side ASCII diff whose lines open and close with a pipe | 12 | filled | 204 | 199–204, 3 lines (5) | 3 |
| 15 | Bullet summary where only two lines reached the column | 8 | filled | 242 | 241–242, 2 lines (2) | 2 |
| 16 | Already-reformatted transcript: `>` prompts, 250-char rules, `é` | 18 | — | 420 (lone fallback) | every long line is a quote or a rule | 0 |
| 17 | A stanza opening `⏺ ▎` — a marker stacked on a quote gutter | 4 | filled | 164 | 164, 2 lines (1) | 0 |
| 18 | `Draft reply:` label above a four-line quote block, almost no unquoted prose | 5 | filled | 170 | every long line is a quote | 0 |
| 19 | Long argument; two rows where the wrap arrived as 183 interior spaces, aligned `file:line` listings | 28 | filled | 174 | 162–174, 10 lines (12) | 10 |
| 20 | One paragraph, wrapped exactly once | 2 | filled | 233 | 233, 1 line (lone fallback) | 1 |
| 21 | 2-column box table whose cells wrap and are vertically centered, 9 rows for 2 logical | 4 prose (+9 table) | filled | 231 | 231, 1 line (lone fallback) | 1 |
| 22 | Ticket-edit sheet: `①`–`⑯` reference labels, `▎` blocks | 59 | filled | 238 | 214–237, 14 lines (10) | 4 |
| 23 | Prose analysis wrapping a four-line Java method, plus a `▎` block | 25 prose (+4 code) | filled | 208 | 201–208, 9 lines (5) | 5 |
| 24 | Spec discussion quoting a flatten rule — `·` and `→` inside body prose | 12 | filled | 208 | 201–208, 8 lines (5) | 8 |
| 25 | A 231-character URL the wrapper split mid-token, a short URL inside a normal wrap as control, and a space break that lands on `W` by coincidence | 20 | filled | 208 | 200–208, 10 lines (6) | 10 |
| 26 | One wrapped list item below an unwrapped 184-character paragraph; only two lines reach the column | 7 | short | 96 (pair fallback) | 93–96, 2 lines (3) | 3 |
| 27 | One prose line above a box table with an all-blank header row | 1 prose (+9 table) | — | none (one measurable line) | no estimate | 0 |

Measuring before dedent raises `W` by exactly the dedent amount and **changes no
join decision** — checked directly, both orderings produce identical join sets.
That is the shift-invariance argument of §4, confirmed empirically rather than
only proved.

**Zero false joins across the corpus, and no known misses** — the conservative
miss recorded here was fixture 12, which §0 put out of domain.

**The `W` column is measured, not asserted** — it is what `estimateWidth` returns
at stage 5, re-measured whenever the estimator changes. Every row was
re-measured after the §0 prune — row 22 was missed then and corrected in #12 —
and again after fixture 26 added the two-line rung, which moved row 8 from `223`
to `181`, its real column. That `223` was itself called drift once, when it was
simply what the estimator returned with the cluster minimum at 3: `W` is a
function of the configuration, so re-measure the column rather than reasoning
about it.

**Fixture 17's zero joins are not a miss.** Its width estimate is correct and
every long line is a quote line, which §5.2 declines to unwrap; the four
non-quote lines are short and blank-separated, so there is nothing left to join.
A paste whose substance sits entirely inside a `▎` block reformats to a `>` block
and otherwise stands still — which is the specified behavior, and worth having a
fixture pin down before someone reads it as a bug.

### Is this over-fitted?

A fair question — the corpus is not much larger than the rule set. The check is
**ablation**: delete each rule, re-run the whole corpus, and see whether anything
changes. Re-run after fixture 14, every rule but one alters at least one
fixture's output, breaks idempotency, or lets code through — the table above
records which. The one that did not, `W < 40`, was removed.

That is the strongest evidence available that the rules are load-bearing rather
than accumulated. It is not proof. Two things are worth watching:

- **Seven tunable thresholds** — cluster gap 8, minimum cluster 3, forced-break
  tolerance 8, absorbable token 100, 25% exceed, 8 words per line, padding run
  32. An earlier count here said six and omitted the token cap, which is the
  wrong direction for a number whose whole purpose is to be watched. Each is
  calibrated and none is arbitrary, but seven is past the point where the next
  one gets refused rather than debated.
- **Two compound guards.** `terminalPunctuation` carries two exemptions and
  `header` three conditions. Both are the fuzziest things here, and both earn
  their place on separate fixtures — but a third exemption on either would be a
  signal to redesign rather than extend.

**The governance rule going forward:** a new sample should be absorbed by
existing rules, or expose a *bug* in one. A rule is admitted only when a fixture
fails without it — a corner case argued from reasoning alone is not admitted, and
the cost of the 1% case is that Reformat leaves it alone. Fixtures 5, 10 and 13 moved nothing;
13 revealed a flaw in the estimator. That is the healthy pattern. If three
consecutive samples each require a *new* rule, the design is over-fitting and the
right response is to simplify, not to keep adding.

**That rule fired at fixture 21**, and this is what the audit found. Fixtures 19,
22 and 23 each added a rule, so all three were tested for removal rather than
argued about:

| Rule | Test | Verdict |
|---|---|---|
| Padding run (19) | delete the stage | fixture 19 stops being idempotent — **load-bearing** |
| Lone-candidate fallback (20) | drop it, or allow any 1-line cluster | without it a once-wrapped paragraph cannot be measured; allowing every lone cluster costs fixture 1 its joins — **load-bearing, and adds no constant** |
| Wrapped cells (21) | require one interior rule instead of two | a converted Markdown table folds into a single row on pass 2 — **load-bearing, and adds no constant** |
| Token-split join (25) | join with a space, as before | fixture 25's URL gains a space mid-path and stops being a link — **load-bearing, no constant** |
| `·` → `-` (24) | target `*` instead | fixture 24's body `·` becomes `*`, which reads as emphasis rather than a separator — **load-bearing, no constant** |
| Table exemption (27) | delete it | fixture 27 returns byte-identical, marker included — **load-bearing, and adds no constant** |
| Two-line rung (26) | drop it, leaving the lone candidate | fixture 26 loses all 3 joins: the unwrapped 184-character paragraph above the list is taken for the column — **load-bearing, and adds no constant** |
| Code block exemption (23) | delete it | the em dash in fixture 23's comment flattens — output is still idempotent, so only the fixture catches it — **load-bearing, one constant** |

All three survive, but the audit did find one redundancy: fixture 15's lowering
of the cluster minimum to 2 was subsumed by the fallback, so it went back to 3
with the whole corpus still passing. Two of the three additions cost no new
constant, and the one that did (padding) is the one to remove first if a later
sample shows a cheaper way to reach the same output.

Each sample forced a rule that no amount of reasoning had produced:

| Sample | What it forced |
|---|---|
| 1 | Marker → spaces (not deletion); the `header` block kind; `len(firstWord) ≤ W` |
| 2 | Width clamp must exceed 200 (and flush continuations, which drove `indentMismatch` before it was removed) |
| 3 | Table masking before width estimation; character vs. byte measurement |
| 4 | Both continuation shapes are real; tie-break toward larger `W` |
| 5 | Nothing — first sample to move no rule |
| 6 | Dedent must follow unwrap; `terminalPunctuation` needs a list exemption |
| 7 | `:` is not a terminator; the 25%-exceed sanity check, without which it is **not idempotent** |
| 8 | A cluster under 3 lines is coincidence, not evidence — fall back to the longest line |
| 9 | The `terminalPunctuation` wrap-column exemption; dedent must ignore a lone-minimum indent |
| 10 | Nothing — 3-column tables and emoji cells pass through unchanged |
| — | **Simplification pass:** ablation removed `hardBreak`, `indentMismatch`, the `len(N) ≤ W` ceiling and the cluster-size fallback with zero behavioral change (the fallback came back at fixture 20, on evidence the corpus did not then contain) |
| 11 | `▎` quote-bar gutters — one marker-table row, no new rule |
| 12 | **Highest cluster, not most populous** — the estimator was picking short-line clusters in any document with headers and examples |
| 13 | Nothing — empty header cells, `✓`/`✗` in cells, and a row with 110 trailing spaces all pass through unchanged |
| 14 | A table block must contain a **rule row** — a lone pipe-delimited line is ASCII art, and converting it invented header and delimiter rows |
| 15 | Tested highest-first; the token cap must be absolute, not `W`-relative. It also forced the cluster minimum down to 2, which was **put back to 3** at fixture 20 once the lone-candidate fallback covered this case — one rule replacing a calibration tweak |
| 16 | Dedent must ignore quote lines and table rules when computing the margin |
| 17 | Marker substitution must **recurse** into a gutter behind it (`⏺ ▎`), or the `▎` survives and a second pass converts it |
| 18 | Quote lines must count toward the code guardrail, not just the width estimate |
| 19 | A long run of interior spaces is a wrap the terminal wrote as padding (§6.1.1) — left alone it is both an outlier that hijacks `W` and a canyon in the output |
| 20 | The cluster minimum needs a lone-candidate fallback: a paragraph wrapped once leaves one line at the column, so the most ordinary paste of all could not be measured. Reinstates a rule ablation had removed as inert |
| 21 | Wrapped cells reassemble, delimited by the rules the table already carries (§5.1) — closing a Deferred item. Two interior rules are required, because one is the header separator and Reformat's own output has exactly one |
| 22 | Circled numerals flatten, and the rewrite has to happen before the join decisions rather than at stage 9, or the marker changes `startsListItem` between passes. Also: a run ends at a table row, not only at a blank. §5.2's premise that a blank always follows a prompt is false: the CLI brackets its prompt in `─` rules, and the closing rule and the status footer below it were being quoted as though typed |
| 23 | A code block inside a prose document is exempt from flattening. The §6.1 gate is whole-document by necessity, which leaves embedded code unprotected; the fix is a precise supplement, not a second gate — it may miss a language without costing anything |
| 24 | `·` flattens to `-`, not `*`. Every earlier `·` sat on a status line, so the wrong target looked harmless and its ablation looked inert — both because the corpus held no in-domain instance. A stanza discussing the rule supplied one. `*` is markup where `·` was inert; `-` is inert and the same width |
| 27 | A box table means the document is not code, which has to be said outright because table rows are masked from the words-per-line measurement — a stanza that is mostly table starves the mean and the guardrail eats the whole paste, marker included. One rule, no constant. Two further rules were written for the blank header row this table also carries and both were reverted: §5.1 already handled it, and neither changed a fixture |
| 26 | The lone-candidate fallback needs a rung above it — two lines agreeing on a column beat one line agreeing with nothing. A list item wrapped four times left only two lines at the column, because a long backticked token forced its first break early and the tail is short, so an unwrapped 184-character paragraph above it won the estimate and nothing joined. The same item joins as soon as a second item follows it, which is what shows the estimate rather than the join rules to be at fault |
| 25 | A break inside a token rejoins with no separator. The wrapper splits a token only when it cannot fit a line, so the fragments sum to more than `W` — the test is the definition, not a heuristic. Length at `W` is *not* the test: the fixture holds a coincidental space break at the same length |

**The corpus keeps disproving convergence.** Sample 5 moved no rule, which looked
like the rules had settled; sample 6 then broke two at once. Samples 7 and 8
broke three more, and sample 7 exposed an idempotency failure of a kind the
existing property test *did* catch but the six previous samples never triggered.

Two of these were only visible because the corpus is diverse in *shape*, not just
in size: sample 7 is the first with many short lines beside a few long ones,
which is what corrupts a second-pass width estimate; sample 8 is the first where
only a single line ever reached the wrap column. Neither is rare in practice.

Sample 5 additionally demonstrates that a header immediately abutting a list
(`Risks…:` followed by `- `) is caught by `intoListItem` — and, since `:` left
the terminator set, is now caught by that guard alone.

## 9. Fixtures

No test target — this is a small app and the feedback loop is running it. What
exists instead is [`docs/fixtures/`](fixtures/): real pastes with their
expected output, and **`make check`**, a script that runs `Reformat` over all of
them and prints what differs.

```
$ make check
ok       01-handoff-brief  (11 lines joined away)
...
<n> fixtures pass, all idempotent
```

It reports the join count per fixture, not just pass/fail. That matters: when
quote blocks were added, a check of *which fixtures changed* passed while fixture
11 silently went from five joins to zero. Counting joins catches that; comparing
file lists does not.

**Run it twice on anything suspicious.** Three of the four defects found while
writing this spec produced correct-looking first-pass output and only appeared on
a second run — dedent ordering (§4), a collapsed wrap-width estimate (§6.1), and
a Markdown table that gained a `| --- |` row per pass (§5.1). Idempotency is the
property this design fails at, and it is invisible to a single reformat.

The invariants worth checking by hand, should something look wrong:

| Property | Note |
|---|---|
| `apply(apply(x)) == apply(x)` | the one above; holds on every fixture |
| Word multiset preserved | assert **after** stage 3 — markers are intentionally consumed. A token split by the wrapper is rejoined into one word (§6.2.1), so the count drops by one per such join |
| Line count never increases | |
| A converted `table` has uniform column count, or is byte-identical | §5.1; ragged input must bail out, never half-convert |
| No marker, box-drawing glyph, or flatten-table left-column character survives | |
| Every non-ASCII character in the output was present in the input | §7 — no stage may *introduce* one |

## 10. Constants

| Constant | Value | Rationale |
|---|---|---|
| Wrap-cluster gap | 8 | §6.1 grouping threshold |
| Forced-break tolerance | 8 | §6.2; absorbs the spread of a short-lined stanza |
| Minimum cluster size | 3 lines | §6.1; candidates are tested highest-first, falling back to the highest 2-line group and then to a lone candidate when no group reaches 3. The corpus passes at 2 as well, so the value has slack |
| Max absorbable token | 100 chars | §6.2; longer means path/identifier, not a wrapped word |
| Code guardrail | mean < 8 words/line | §6.1; below this the text is code, not wrapped prose |
| Min padding run | 32 chars | §6.1.1; a run this long is a row boundary, not alignment |
| Max fraction exceeding `W` | 25% | above this the estimate is rejected and unwrapping is skipped (§6.1) |
| Blank-run collapse | any run → 1 | see below |
| Marker widths | §7 | |

All hardcoded, per §1 and §7 *Not exposed*.

**On blank-run collapse:** exactly one blank line separates blocks. A "3 or more"
rule would leave runs of 2 intact, permitting two different spacings in the same
output — not normalized, and not idempotent in spirit. This constant is
**uncalibrated**: every blank run in the corpus is already 1, so the stage never
fires on any sample.

## 11. Deferred

- **Jira wiki-markup tables** (`||header||`) as an alternative emitter. Markdown
  covers GitLab and Jira Cloud both (§5.1); wiki markup would only pay off for a
  legacy Jira text field, and a second emitter means a second output format to
  test.
- **Per-clip Reformat** in the Clips tab. Live pasteboard only for now.
- **Keyboard shortcut.** §4.7 / §9 — no hotkeys in v1.
- **Sentence-case header detection.** Every header across ten samples has had a
  trailing colon, a blank line after it, or a list beneath it, so all are already
  caught. The uncovered shape — sentence-case, no colon, immediately followed by
  non-list prose — has not been observed. Not worth a heuristic until it is.

## 12. Open items

- **The name is `Reformat`.** Settled after weighing `Tidy Text` (adopted
  briefly, then reverted), `Reflow Text`, `Unwrap Text`, `Clean Up Text`,
  `Normalize Text` and `Fix Wrapping`.

  The known objection, recorded so it isn't rediscovered: `Reformat` shares the
  word "format" with `Clear Formatting` directly above it in the menu, which can
  read as two variants of one operation when in fact one drops styling and the
  other rewrites text. §5's ordering note — least to most invasive — is what
  carries that distinction instead. Behavior does not depend on the label; it
  appears only in `ClipMenu` and SPEC §5.
- **Embedded code is protected from flattening only** (§6.1, fixture 23). Joins
  and dedent were measured not to harm it; every other stage is unexamined against
  a code block, because one sample is all the corpus has. A second mixed paste is
  what would either widen the exemption or confirm its edge.
- **Fenced code: closed, will not do.** An earlier draft specified a `fence`
  predicate passing ` ``` ` regions through byte-identical, and fixture 23 later
  made the case sharper — an embedded block comes out at column 0 under a blank
  line, so a Markdown renderer collapses its four lines into one paragraph. A
  fence is the only thing that would survive rendering. §0 settles it against:
  most destinations do not render Markdown, and there a fence arrives as three
  literal backticks. It would help the minority and disfigure the majority.
- **ASCII art skews by a few columns** when it contains expanding glyphs (§7).
  Accepted; a fix means a new block kind and a detector with no supporting data.
- **Aligned columns are unprotected on the join path too** — §7 records only the
  flatten side. A borderless table, fields lined up by padding with no `|` or box
  glyph, matches no predicate in §5, so it is prose, and only the forced-break
  arithmetic keeps it intact. A narrow block is safe because it is short; rows
  reaching `W - tolerance` would be joined into one line. The signal, should one
  ever be needed, is that field *start* columns coincide across consecutive lines
  — a run-based test misses a row whose gap is a single space — and it costs no
  constant. Not added: no paste has exhibited the wide case, and §8 refuses a
  rule for an unobserved shape.
- **Character count is not display width** (§6.1). Wide characters — CJK, most
  emoji — take two terminal columns but count as one. No fixture is affected; a
  `wcwidth` table is the fix if one ever is.
- **A status line's `·` flattens to `-`**, where it read as a separator and now
  reads as a range (`1m 30s - done`). Out of domain by §0 — the stanza ends at
  that line — so it is recorded, not fixed. Exempting it would mean exempting the
  whole chrome category (`… +38 lines (ctrl+o to expand)`, the `⏵⏵` mode footer's
  `·` and `←`), which is the detection the §0 prune deleted; and no fixture
  carries the glyph, so `make check` cannot tell the exemption right from wrong.
- Tabs are left as-is; no sample contained them. If tab-indented input appears,
  dedent's common-prefix arithmetic needs revisiting for mixed tabs and spaces.
