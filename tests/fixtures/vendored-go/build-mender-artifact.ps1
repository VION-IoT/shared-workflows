#Requires -Version 7.0
<#
.SYNOPSIS
    Fixture: builds upstream `mender-artifact` the way a consuming repo does, so that
    `.github/workflows/vendored-go-build.yml` has a real vendored-Go build to prove itself against.

.DESCRIPTION
    Deliberately the same recipe as vion-agent-windows/build/build-mender-artifact.ps1 — pinned
    tag, `nopkcs11`, `CGO_ENABLED=0`, version stamp checked against the pin — and deliberately NOT
    a copy of it: the patch set that repo carries is its own, and this fixture exists to exercise
    the CI environment, not to re-vendor the tool.

    Two things it does that a production vendor script would not, both so that the workflow is
    actually being tested rather than merely invoked:

    1. **It does not set `core.longpaths` itself.** vion-agent-windows' script passes
       `-c core.longpaths=true` on its own clone; this one relies entirely on the workflow having
       set it globally. If the workflow stops doing that, this fixture fails.

    2. **It clones into a deliberately long base path.** Upstream's deepest `vendor/` entry is a
       132-character relative path, so on a shallow workspace the total stays under Windows'
       260-character MAX_PATH and the setting is a silent no-op that proves nothing. Padding the
       base to $MinimumClonePathLength puts the deepest file past MAX_PATH, which is where the
       failure actually lives: without the setting, `git clone` reports
       `Clone succeeded, but checkout failed` and leaves a tree with 8 of 2282 vendor files —
       present-looking, and uncompilable. Measured on 4.4.1, 2026-08-12.

    GOOS/GOARCH/CGO_ENABLED/GOFLAGS come from the environment (the workflow's inputs) rather than
    being pinned here, so the same fixture builds the windows/amd64 tool the Windows lane needs
    and the linux/amd64 tool the signing proof runs.
#>
[CmdletBinding()]
param(
    # Where the built executable is written. Relative paths resolve against the repo root.
    [string] $OutputDirectory = 'artifacts/mender-artifact'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Pin -------------------------------------------------------------------------------------
# Same tag vion-agent-windows pins in third-party/mender-artifact/VENDOR.md.
$UpstreamRepository = 'https://github.com/mendersoftware/mender-artifact.git'
$UpstreamTag        = '4.4.1'
$VersionSymbol      = 'github.com/mendersoftware/mender-artifact/cli.Version'

# --- Long-path exercise --------------------------------------------------------------------
$WindowsMaxPath           = 260   # the limit git works around when core.longpaths is set
$MinimumClonePathLength   = 170   # + upstream's 132-char deepest entry clears MAX_PATH

$goos       = if ($env:GOOS) { $env:GOOS } else { 'windows' }
$outputName = if ($goos -eq 'windows') { 'mender-artifact.exe' } else { 'mender-artifact' }

foreach ($tool in @('git', 'go')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool '$tool' is not on PATH."
    }
}

$cloneRoot = Join-Path ([IO.Path]::GetTempPath()) 'vendored-go-fixture'
$shortfall = $MinimumClonePathLength - (Join-Path $cloneRoot 'src').Length
if ($shortfall -gt 0) {
    $cloneRoot = Join-Path $cloneRoot ('_' * $shortfall)
}
$sourceDirectory = Join-Path $cloneRoot 'src'
if (Test-Path -LiteralPath $sourceDirectory) {
    # Deleting the tree runs into the same MAX_PATH wall that created it; the \\?\ prefix is how
    # Win32 is told to skip the check.
    $removalPath = if ($IsWindows) { "\\?\$sourceDirectory" } else { $sourceDirectory }
    Remove-Item -Recurse -Force -LiteralPath $removalPath
}
New-Item -ItemType Directory -Force -Path $cloneRoot | Out-Null
Write-Host "Clone target is $($sourceDirectory.Length) characters long (MAX_PATH is $WindowsMaxPath)"

Write-Host "Cloning $UpstreamRepository at tag $UpstreamTag"
& git clone --depth 1 --branch $UpstreamTag $UpstreamRepository $sourceDirectory
if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE." }

# The checkout half-failure leaves the top level intact, so assert on the deep end of the tree.
$vendorDirectory = Join-Path $sourceDirectory 'vendor'
if (-not (Test-Path $vendorDirectory)) { throw "Upstream vendor/ tree is missing at $vendorDirectory." }
$vendorFiles = @(Get-ChildItem -Path $vendorDirectory -Recurse -File)
$deepest = ($vendorFiles | ForEach-Object { $_.FullName.Length } | Measure-Object -Maximum).Maximum
Write-Host "vendor/ checked out: $($vendorFiles.Count) files; deepest path $deepest characters"
if ($deepest -le $WindowsMaxPath) {
    throw ("The deepest checked-out path is only $deepest characters, so this run did not " +
           "exercise the MAX_PATH condition core.longpaths exists for. Raise " +
           "MinimumClonePathLength (currently $MinimumClonePathLength).")
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputPath = Join-Path ((Resolve-Path $OutputDirectory).Path) $outputName

# -s -w strip the symbol table and DWARF; the Version stamp is what `--version` reports. Build
# tags are NOT passed here — GOFLAGS from the workflow supplies `nopkcs11`, and without it the
# build pulls in the openssl cgo binding and fails under CGO_ENABLED=0. That is the point.
$linkerFlags = "-s -w -X $VersionSymbol=$UpstreamTag"

Write-Host "Building $outputName for $($env:GOOS)/$($env:GOARCH) (GOFLAGS=$($env:GOFLAGS), CGO_ENABLED=$($env:CGO_ENABLED))"
Push-Location $sourceDirectory
try {
    & go build -mod=vendor -ldflags $linkerFlags -o $outputPath .
    if ($LASTEXITCODE -ne 0) { throw "go build failed with exit code $LASTEXITCODE." }
}
finally {
    Pop-Location
}

Write-Host "Built $outputPath"
if ($goos -eq (& go env GOHOSTOS)) {
    $reported = & $outputPath --version
    Write-Host "  reports: $reported"
    if ($reported -notmatch [regex]::Escape($UpstreamTag)) {
        throw "Built binary reports '$reported', which does not carry the pinned tag '$UpstreamTag'."
    }
}
else {
    Write-Host "  cross-compiled for $goos; skipping the --version check on a $(& go env GOHOSTOS) host"
}
