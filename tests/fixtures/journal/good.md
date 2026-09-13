# Process journal

Fixture for `actions/journal-lint`: every line below the marker is valid, and the lint must pass.
Above the marker the entries use an older vocabulary, which the lint does not read.

## Format

```
YYYY-MM-DD · <where> · <topic or —> · <what happened, one line> [ (second ask)] [ (self)] [ → codified: <path>]
```

## Entries

2026-08-01 · agent · dashboard · An entry in a retired vocabulary, above the marker, left unchecked.
2026-08-02 · plugin · vion-dispatch · Another retired where, written before the grammar settled.
2026-07-30 · /implement · spec-slug · Out of date order and in a command vocabulary; still unchecked.
Free prose above the marker is not a finding either.

<!-- retro-0 marker -->
<!-- retro-1 marker -->

2026-09-01 · review · journal-lint · A finding line named the fixture rather than the journal; asked for the path as given.
2026-09-01 · gate · proof-journal-lint · The proof passed while the action printed nothing; asked for an assertion on the output. (self)

2026-09-02 · brief · — · The brief named a marker shape the retro skill does not write; asked to follow the skill. (second ask)
<!-- A one-line HTML comment among entries is allowed. -->
2026-09-03 · decision · grammar · Five where values, no per-repo vocabulary, because a sixth is a topic.
This entry wraps onto a second physical line, which continues it. → codified: actions/journal-lint/journal-lint.ps1

2026-09-04 · manual · — · The operator found two linters with two vocabularies tiresome. (second ask) (self) → codified: README.md
