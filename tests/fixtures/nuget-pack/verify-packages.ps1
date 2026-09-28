#!/usr/bin/env pwsh
# The caller's script in proof-publish-nuget.yml, passed as publish-nuget.yml's `verify-script`.
# It asserts what that input promises the script, rather than exiting 0: a script that only exits 0
# passes just as well when the input is ignored. That the step ran at all is asserted by the proof's
# `verify-step-ran` job.
$ErrorActionPreference = 'Stop'

$dir = $env:PACKAGES_DIR
$version = $env:PACKAGE_VERSION

# The proof passes pack-output: ./out/packages, not the default, so this also shows the directory
# follows the input.
$expectedDir = [System.IO.Path]::GetFullPath((Join-Path $env:GITHUB_WORKSPACE 'out/packages'))
if (-not $dir) { throw 'PACKAGES_DIR is not set.' }
if (-not [System.IO.Path]::IsPathRooted($dir)) { throw "PACKAGES_DIR is not absolute: '$dir'." }
if ($dir.TrimEnd('/', '\') -ne $expectedDir.TrimEnd('/', '\')) {
    throw "PACKAGES_DIR is '$dir', expected pack-output resolved to '$expectedDir'."
}

# What compute-version derives on a ref that is not a vX.Y.Z tag. The proof runs on pull_request only.
$expectedVersion = "0.0.0-ci.$env:GITHUB_RUN_NUMBER"
if ($version -ne $expectedVersion) {
    throw "PACKAGE_VERSION is '$version', expected the job's computed '$expectedVersion'."
}

$packages = @(Get-ChildItem -LiteralPath $dir -Filter '*.nupkg' -File | ForEach-Object Name)
$expectedPackage = "Vion.Fixture.Packable.$version.nupkg"
if ($packages.Count -ne 1 -or $packages[0] -ne $expectedPackage) {
    throw "PACKAGES_DIR holds [$($packages -join ', ')], expected exactly $expectedPackage."
}

# The file name is the pack's choice; the nuspec is what a push publishes.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $dir $expectedPackage))
try {
    $entry = $zip.Entries | Where-Object FullName -eq 'Vion.Fixture.Packable.nuspec'
    if (-not $entry) { throw "$expectedPackage carries no Vion.Fixture.Packable.nuspec." }
    $reader = [System.IO.StreamReader]::new($entry.Open())
    try { [xml]$nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
}
finally {
    $zip.Dispose()
}
if ($nuspec.package.metadata.version -ne $version) {
    throw "The nuspec says version '$($nuspec.package.metadata.version)', expected '$version'."
}

Write-Host "Confirmed: PACKAGES_DIR=$dir holds $expectedPackage, packed as $version."
