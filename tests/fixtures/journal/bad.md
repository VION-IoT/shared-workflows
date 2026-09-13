# Process journal

Fixture for `actions/journal-lint`: each numbered case below the marker is exactly one finding, and
the proof asserts the line numbers. Moving a line here means updating the proof.

## Entries

<!-- retro-3 marker -->
A continuation line with no entry above it.
2026-09-01 · review · — · A valid entry that the cases below are measured against.
2026-09-02 · incident · — · An unknown where.
2026-08-15 · gate · — · A date earlier than the entry above it.
2026-09-03 · review · — · An entry over the limit: its first line starts short and its continuation carries the rest.
This continuation pushes the entry past four hundred characters. Lorem ipsum dolor sit amet, consectetur
adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

A line after a blank line, so it continues nothing.
2026-09-04 - gate - — - A hyphen in place of the separator.
2026-09-04 | gate | — | A pipe in place of the separator.
2026-9-5 · review · — · A malformed date.
