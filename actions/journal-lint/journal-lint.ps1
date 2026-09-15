#requires -Version 7
<#
.SYNOPSIS
  Check a process journal's live window against the one VION journal grammar.

.DESCRIPTION
  The grammar is owned by architecture's plugins/vion-improve/templates/journal.md:

    YYYY-MM-DD · <where> · <topic or —> · <what happened> [ (second ask)] [ (self)] [ → codified: <path>]

  A journal is a file or a folder. In a file the live window is everything after the last
  `<!-- retro-N marker -->` line, or, with no marker, everything after the `## Entries` heading.
  Lines above it are not read. Inside it every physical line is an entry's first line, a
  continuation (directly after an entry or another continuation), a blank line, or a one-line HTML
  comment. `where` is one of review, gate, brief, decision, manual; dates never decrease; an entry,
  its lines joined with single spaces, is at most -MaxChars characters.

  A folder (docs/process-journal/) holds a README.md header, which must exist and is not read, and
  one fragment per branch named YYYY-MM-DD-<branch>.md: <branch> of a-z, 0-9 and '-', neither
  starting nor ending with '-', the name at most 80 characters and its date a real one. No
  subfolders; hidden entries are checked too. Each fragment is a window of its own, the whole file,
  held to the line checks above; it has no marker, so a retro marker in it is just an HTML comment.
  In a fragment no entry is dated earlier than the file name's date. A folder holding only
  README.md passes.

  -Path names the file or the folder. When it ends in .md, does not exist, and the same path
  without .md is a folder, that folder is linted, so the default finds a migrated journal.

  Prints one `file:line: message` per finding, sorted by file then line; line 0 means the file (or
  the folder) as a whole. Exits 1 on any finding, 0 when clean. Reports only; never changes a file.

.EXAMPLE
  pwsh -NoProfile -File actions/journal-lint/journal-lint.ps1 -Path docs/process-journal.md

.EXAMPLE
  pwsh -NoProfile -File actions/journal-lint/journal-lint.ps1 -Path docs/process-journal
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

$findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding([string]$file, [int]$line, [string]$message) {
    $findings.Add([pscustomobject]@{ File = $file; Line = $line; Seq = $findings.Count; Text = "${file}:${line}: $message" })
}

function Measure-Chars([string]$text) { @($text.EnumerateRunes()).Count }

function Read-Lines([string]$file) {
    # ReadAllLines detects a UTF-8 BOM and splits on LF and CRLF alike.
    [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $file).ProviderPath, [System.Text.Encoding]::UTF8)
}

function Test-Date([string]$date, [ref]$parsed) {
    $date -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' -and
        [datetime]::TryParseExact($date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, 'None', $parsed)
}

# The line checks, from index $start to the end. Every piece of state lives here, so it starts
# afresh for each file: the latest date, whether an entry was seen, and the open entry.
function Test-Lines([string]$file, [string[]]$lines, [int]$start, $notBefore) {
    $latest = $null
    $seenEntry = $false
    # The entry the next continuation line belongs to: its first line number and its text so far.
    $state = @{ Entry = $null }
    $complete = {
        if ($null -ne $state.Entry -and $state.Entry.Chars -gt $MaxChars) {
            Add-Finding $file $state.Entry.Line "entry is $($state.Entry.Chars) characters; the limit is $MaxChars"
        }
        $state.Entry = $null
    }

    for ($i = $start; $i -lt $lines.Count; $i++) {
        $n = $i + 1
        $line = $lines[$i].TrimEnd()

        if ($line.Trim() -eq '') { & $complete; continue }

        if ($line.TrimStart().StartsWith('<!--')) {
            & $complete
            if ($line.Trim() -notmatch '^<!--.*-->$') {
                Add-Finding $file $n "HTML comment does not close on the same line"
            }
            continue
        }

        # Anything shaped like a date opens an entry, well-formed or not, so its wrapped lines are not
        # reported a second time as orphans.
        if ($line -match '^\d+-\d+-\d+') {
            & $complete
            $seenEntry = $true
            $state.Entry = [pscustomobject]@{ Line = $n; Chars = (Measure-Chars $line) }

            $m = [regex]::Match($line, '^(?<date>\d+-\d+-\d+)(?<rest>.*)$')
            $date = $m.Groups['date'].Value
            $parsed = [datetime]::MinValue
            if (-not (Test-Date $date ([ref]$parsed))) {
                Add-Finding $file $n "'$date' is not a date in the form YYYY-MM-DD"
                continue
            }
            if (-not $m.Groups['rest'].Value.StartsWith($sep)) {
                Add-Finding $file $n "the date is not followed by ' · ' (space, U+00B7, space)"
                continue
            }
            $fields = $m.Groups['rest'].Value.Substring($sep.Length) -split [regex]::Escape($sep), 3
            if ($fields.Count -lt 3 -or $fields[1].Trim() -eq '' -or $fields[2].Trim() -eq '') {
                Add-Finding $file $n "an entry is 'YYYY-MM-DD · <where> · <topic or —> · <what happened>', four fields separated by ' · '"
                continue
            }
            if ($fields[0] -cnotin $wheres) {
                Add-Finding $file $n "where is '$($fields[0])'; it must be one of $($wheres -join ', ')"
            }
            elseif ($null -ne $latest -and $parsed -lt $latest) {
                Add-Finding $file $n "dated $date below an entry dated $($latest.ToString('yyyy-MM-dd')); entries are appended newest last"
            }
            elseif ($null -ne $notBefore -and $parsed -lt $notBefore) {
                Add-Finding $file $n "dated $date, earlier than the file name's date $($notBefore.ToString('yyyy-MM-dd'))"
            }
            if ($null -eq $latest -or $parsed -gt $latest) { $latest = $parsed }
            continue
        }

        if ($null -ne $state.Entry) {
            $state.Entry.Chars += 1 + (Measure-Chars $line.Trim())
            continue
        }

        if (-not $seenEntry) {
            Add-Finding $file $n "continuation line with no entry above it"
        }
        else {
            Add-Finding $file $n "not an entry, a continuation, a blank line or an HTML comment; a continuation must directly follow its entry"
        }
    }
    & $complete
}

function Test-File([string]$file) {
    $lines = @(Read-Lines $file)

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
        Add-Finding $file 0 "no '<!-- retro-N marker -->' line and no '## Entries' heading; the live window cannot be found"
        return
    }
    Test-Lines $file $lines $start $null
}

function Test-Folder([string]$folder) {
    $trimmed = $folder.TrimEnd('/', '\')
    if ($trimmed -eq '') { $trimmed = $folder }

    # Ordinal by name, as the window's order is defined; Get-ChildItem's own order differs by file system.
    $byName = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    foreach ($child in Get-ChildItem -LiteralPath $folder -Force) { $byName[$child.Name] = $child }
    [string[]]$names = @($byName.Keys)
    [System.Array]::Sort($names, [System.StringComparer]::Ordinal)

    if (-not $byName.ContainsKey('README.md') -or $byName['README.md'].PSIsContainer) {
        Add-Finding $trimmed 0 "no README.md; the folder's header must exist"
    }

    foreach ($name in $names) {
        $child = $byName[$name]
        if ($child.PSIsContainer) {
            Add-Finding $trimmed 0 "'$name' is a subfolder; a journal folder holds only README.md and fragments"
            continue
        }
        if ($name -ceq 'README.md') { continue }

        $file = "$trimmed/$name"
        $notBefore = $null
        if ($name -cnotmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+\.md$') {
            Add-Finding $file 0 "'$name' does not match YYYY-MM-DD-<branch>.md, with <branch> of a-z, 0-9 and '-'"
        }
        elseif ($name.Substring(11, $name.Length - 14) -cmatch '^-|-$') {
            Add-Finding $file 0 "the branch part of '$name' starts or ends with '-'"
        }
        if ($name.Length -gt 80) {
            Add-Finding $file 0 "'$name' is $($name.Length) characters; a fragment's file name is at most 80"
        }
        if ($name -cmatch '^(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})-') {
            $parsed = [datetime]::MinValue
            if (Test-Date $Matches['date'] ([ref]$parsed)) { $notBefore = $parsed }
            else { Add-Finding $file 0 "'$name' is dated $($Matches['date']), which is not a real date" }
        }

        Test-Lines $file @(Read-Lines $child.FullName) 0 $notBefore
    }
}

if (Test-Path -LiteralPath $Path -PathType Container) {
    Test-Folder $Path
}
elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
    Test-File $Path
}
elseif ($Path.EndsWith('.md', [System.StringComparison]::Ordinal) -and
        (Test-Path -LiteralPath $Path.Substring(0, $Path.Length - 3) -PathType Container)) {
    Test-Folder $Path.Substring(0, $Path.Length - 3)
}
else {
    Write-Output "${Path}:0: file not found"
    exit 1
}

$findings.Sort([System.Comparison[object]] {
        param($a, $b)
        $c = [string]::CompareOrdinal($a.File, $b.File)
        if ($c -eq 0) { $c = $a.Line.CompareTo($b.Line) }
        if ($c -eq 0) { $c = $a.Seq.CompareTo($b.Seq) }
        $c
    })
$findings | ForEach-Object Text
exit ($findings.Count -gt 0 ? 1 : 0)
