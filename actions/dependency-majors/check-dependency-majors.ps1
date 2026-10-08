#!/usr/bin/env pwsh

# .SYNOPSIS
#   Fail when a package or project resolves a dependency at a higher major version than the one it declares.
#
# .DESCRIPTION
#   NuGet resolves each dependency to the lowest version that every request in the graph allows. When another package or project requests a higher major than one declares, the one
#   declaring the lower major gets the higher one, and NuGet reports nothing. That package or project then runs against a dependency major it was not compiled against, and a break
#   only shows at run time. This script reads every committed packages.lock.json under -RepoRoot and compares, for each dependency of a package or project, the declared version with
#   the one resolved for the whole graph. Below 1.0 the minor version counts as the major, since such a version may break on any minor.
#
#   An edge reviewed and found compatible is listed in the -AllowList JSON file with the declared and resolved major and the reason. An entry that no longer matches any edge fails as
#   well, so that the list holds only exceptions that still apply. Without -AllowList there are no exceptions. A dependency of a package or project that has no resolved version in
#   the lock file fails too, since its major cannot be checked; only a project reference has none by design. The script fails as well when git cannot list the committed lock files or
#   lists none, since the run would otherwise pass without checking anything.
#
#   A relative -RepoRoot or -AllowList is resolved against GITHUB_WORKSPACE, or the current directory where that is not set.
#
# .EXAMPLE
#   pwsh actions/dependency-majors/check-dependency-majors.ps1 -RepoRoot ../mesh -AllowList ../mesh/scripts/dependency-majors-allowed.json
[CmdletBinding()]
param(
    [string]$RepoRoot = $env:GITHUB_WORKSPACE,
    [string]$AllowList = ''
)

$ErrorActionPreference = 'Stop'

$workspace = $env:GITHUB_WORKSPACE ? $env:GITHUB_WORKSPACE : $PWD.Path
$repoRoot = [System.IO.Path]::Combine($workspace, $RepoRoot)
$allowedPath = $AllowList ? [System.IO.Path]::Combine($workspace, $AllowList) : ''

function Get-Major([string]$version) {
    $parts = ($version -split '[-+]')[0].Split('.')
    if ($parts[0] -eq '0') { return "0.$($parts[1])" }
    return $parts[0]
}

# In a workflow log, the ::error:: prefix turns the line into an annotation. Elsewhere it prints as plain text.
$lockFiles = @(git -C $repoRoot ls-files '*packages.lock.json')
if ($LASTEXITCODE -ne 0) {
    Write-Host "::error::git ls-files failed under $repoRoot."
    exit 1
}
if ($lockFiles.Count -eq 0) {
    Write-Host "::error::No committed packages.lock.json under $repoRoot."
    exit 1
}

$failed = $false
$edges = @{}
foreach ($lockFile in $lockFiles) {
    $lock = Get-Content (Join-Path $repoRoot $lockFile) -Raw | ConvertFrom-Json -AsHashtable
    foreach ($sectionName in $lock.dependencies.Keys) {
        $section = $lock.dependencies[$sectionName]

        # NuGet package IDs are case-insensitive, and a dependency may be spelled with other casing than the entry of the package it resolves to. A runtime section such as
        # `net10.0/linux-musl-x64` does not repeat all the packages of its framework section and can hold packages that section lacks. Where both hold a package, the runtime
        # section's entry is the one for that runtime, so the lookup lays the runtime section over the framework section.
        $entriesById = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
        if ($sectionName.Contains('/')) {
            $frameworkSection = $lock.dependencies[$sectionName.Split('/')[0]]
            foreach ($id in $frameworkSection.Keys) { $entriesById[$id] = $frameworkSection[$id] }
        }
        foreach ($id in $section.Keys) { $entriesById[$id] = $section[$id] }

        foreach ($package in $section.Keys) {
            $entry = $section[$package]
            if (-not $entry.dependencies) { continue }

            foreach ($dependency in $entry.dependencies.Keys) {
                $target = $entriesById[$dependency]
                if ($target.type -eq 'Project') { continue }

                $resolved = $target.resolved
                if (-not $resolved) {
                    $failed = $true
                    Write-Host "::error::$package depends on $dependency, which has no resolved version in $lockFile."
                    continue
                }

                # A declared version is a range, `[1.2.3, )`, `[1.2.3]` or a bare lower bound `1.2.3`; its lower bound is the version the package was built against. A range with
                # only an upper bound states none, so it has no major to compare.
                $declared = ($entry.dependencies[$dependency] -replace '[\[\]\(\)\s]', '').Split(',')[0]
                if (-not $declared) { continue }
                $declaredMajor = Get-Major $declared
                $resolvedMajor = Get-Major $resolved
                if ($declaredMajor -eq $resolvedMajor) { continue }

                $key = "$package|$dependency|$declaredMajor|$resolvedMajor"
                if (-not $edges.ContainsKey($key)) {
                    $edges[$key] = [pscustomobject]@{
                        Package    = $package
                        Dependency = $dependency
                        Declared   = $declaredMajor
                        Resolved   = $resolvedMajor
                        LockFiles  = [System.Collections.Generic.SortedSet[string]]::new()
                    }
                }
                [void]$edges[$key].LockFiles.Add($lockFile)
            }
        }
    }
}

# A path that names no file fails rather than passing as "no exceptions", since a mistyped path would otherwise turn every listed exception into a finding with no hint why.
$allowed = @()
if ($allowedPath) {
    if (-not (Test-Path -LiteralPath $allowedPath -PathType Leaf)) {
        Write-Host "::error::The allow-list $AllowList does not exist."
        exit 1
    }
    $allowed = @(Get-Content $allowedPath -Raw | ConvertFrom-Json)
}
$allowedKeys = @{}
foreach ($entry in $allowed) { $allowedKeys["$($entry.package)|$($entry.dependency)|$($entry.declared)|$($entry.resolved)"] = $true }
$allowListName = $AllowList ? $AllowList : 'an allow-list'

foreach ($edge in $edges.GetEnumerator() | Sort-Object Key) {
    if ($allowedKeys.ContainsKey($edge.Key)) { continue }

    $failed = $true
    $value = $edge.Value
    $allowedEntry = [ordered]@{
        package    = $value.Package
        dependency = $value.Dependency
        declared   = $value.Declared
        resolved   = $value.Resolved
        reason     = '<why it is compatible>'
    } | ConvertTo-Json -Compress
    Write-Host ("::error::$($value.Package) declares $($value.Dependency) at major $($value.Declared) but resolves major $($value.Resolved) " +
        "($($value.LockFiles -join ', ')). If it is compatible, add to ${allowListName}: $allowedEntry")
}

foreach ($key in $allowedKeys.Keys | Sort-Object) {
    if ($edges.ContainsKey($key)) { continue }

    $failed = $true
    $parts = $key.Split('|')
    Write-Host "::error::$($parts[0]) -> $($parts[1]) ($($parts[2]) to $($parts[3])) in $AllowList matches no edge any more; remove the entry."
}

if ($failed) { exit 1 }
Write-Host "Dependency majors: every package and project resolves the major it declares, or an allowed one."
