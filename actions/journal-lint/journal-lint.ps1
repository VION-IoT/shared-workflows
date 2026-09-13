#requires -Version 7
<#
.SYNOPSIS
  Check a process journal's live window against the one VION journal grammar.

.DESCRIPTION
  The grammar is owned by architecture's plugins/vion-improve/templates/journal.md:

    YYYY-MM-DD · <where> · <topic or —> · <what happened> [ (second ask)] [ (self)] [ → codified: <path>]

  The live window is everything after the last `<!-- retro-N marker -->` line, or, with no marker,
  everything after the `## Entries` heading. Lines above it are not read. Inside it every physical
  line is an entry's first line, a continuation (directly after an entry or another continuation),
  a blank line, or a one-line HTML comment. `where` is one of review, gate, brief, decision, manual;
  dates never decrease; an entry, its lines joined with single spaces, is at most -MaxChars
  characters.

  Prints one `file:line: message` per finding; line 0 means the file as a whole. Exits 1 on any
  finding, 0 when clean. Reports only; never changes the file.

.EXAMPLE
  pwsh -NoProfile -File actions/journal-lint/journal-lint.ps1 -Path docs/process-journal.md
#>
[CmdletBinding()]
param(
    [string]$Path = 'docs/process-journal.md',
    [int]$MaxChars = 400
)
$ErrorActionPreference = 'Stop'
# Findings quote ' · '; a Windows console otherwise prints it in its legacy code page.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$wheres = @('review', 'gate', 'brief', 'decision', 'manual')
$sep = ' · '

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Output "${Path}:0: file not found"
    exit 1
}

# ReadAllLines detects a UTF-8 BOM and splits on LF and CRLF alike.
$lines = [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).ProviderPath, [System.Text.Encoding]::UTF8)

$start = -1
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if ($lines[$i].Trim() -match '^<!-- retro-\d+ marker -->$') { $start = $i + 1; break }
}
if ($start -lt 0) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '## Entries') { $start = $i + 1; break }
    }
}
if ($start -lt 0) {
    Write-Output "${Path}:0: no '<!-- retro-N marker -->' line and no '## Entries' heading; the live window cannot be found"
    exit 1
}

$findings = [System.Collections.Generic.List[object]]::new()
$latest = $null
$seenEntry = $false
# The entry the next continuation line belongs to: its first line number and its text so far.
$entry = $null

function Add-Finding([int]$line, [string]$message) {
    $findings.Add([pscustomobject]@{ Line = $line; Text = "${Path}:${line}: $message" })
}

function Complete-Entry {
    if ($null -ne $script:entry -and $script:entry.Chars -gt $MaxChars) {
        Add-Finding $script:entry.Line "entry is $($script:entry.Chars) characters; the limit is $MaxChars"
    }
    $script:entry = $null
}

function Measure-Chars([string]$text) { @($text.EnumerateRunes()).Count }

for ($i = $start; $i -lt $lines.Count; $i++) {
    $n = $i + 1
    $line = $lines[$i].TrimEnd()

    if ($line.Trim() -eq '') { Complete-Entry; continue }

    if ($line.TrimStart().StartsWith('<!--')) {
        Complete-Entry
        if ($line.Trim() -notmatch '^<!--.*-->$') {
            Add-Finding $n "HTML comment does not close on the same line"
        }
        continue
    }

    # Anything shaped like a date opens an entry, well-formed or not, so its wrapped lines are not
    # reported a second time as orphans.
    if ($line -match '^\d+-\d+-\d+') {
        Complete-Entry
        $seenEntry = $true
        $entry = [pscustomobject]@{ Line = $n; Chars = (Measure-Chars $line) }

        $m = [regex]::Match($line, '^(?<date>\d+-\d+-\d+)(?<rest>.*)$')
        $date = $m.Groups['date'].Value
        $parsed = [datetime]::MinValue
        if ($date -notmatch '^\d{4}-\d{2}-\d{2}$' -or
            -not [datetime]::TryParseExact($date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', [ref]$parsed)) {
            Add-Finding $n "'$date' is not a date in the form YYYY-MM-DD"
            continue
        }
        if (-not $m.Groups['rest'].Value.StartsWith($sep)) {
            Add-Finding $n "the date is not followed by ' · ' (space, U+00B7, space)"
            continue
        }
        $fields = $m.Groups['rest'].Value.Substring($sep.Length) -split [regex]::Escape($sep), 3
        if ($fields.Count -lt 3 -or $fields[1].Trim() -eq '' -or $fields[2].Trim() -eq '') {
            Add-Finding $n "an entry is 'YYYY-MM-DD · <where> · <topic or —> · <what happened>', four fields separated by ' · '"
            continue
        }
        if ($fields[0] -cnotin $wheres) {
            Add-Finding $n "where is '$($fields[0])'; it must be one of $($wheres -join ', ')"
        }
        elseif ($null -ne $latest -and $parsed -lt $latest) {
            Add-Finding $n "dated $date below an entry dated $($latest.ToString('yyyy-MM-dd')); entries are appended newest last"
        }
        if ($null -eq $latest -or $parsed -gt $latest) { $latest = $parsed }
        continue
    }

    if ($null -ne $entry) {
        $entry.Chars += 1 + (Measure-Chars $line.Trim())
        continue
    }

    if (-not $seenEntry) {
        Add-Finding $n "continuation line with no entry above it"
    }
    else {
        Add-Finding $n "not an entry, a continuation, a blank line or an HTML comment; a continuation must directly follow its entry"
    }
}
Complete-Entry

$findings | Sort-Object Line | ForEach-Object Text
exit ($findings.Count -gt 0 ? 1 : 0)
