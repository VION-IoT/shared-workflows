---
slug: dependency-majors
status: archived
areas: [dotnet-ci, actions]
author: Justin Thiede
created: 2026-10-08
updated: 2026-10-08
---

# A shared major-drift check behind a `dotnet-ci.yml` input

## At a glance

### Summary

mesh's `scripts/check-dependency-majors.ps1` (mesh#40) fails CI when a committed
`packages.lock.json` resolves a dependency at a higher major than a package or project declares.
It moves here as the composite `actions/dependency-majors`, and `dotnet-ci.yml` runs it as an
opt-in job, so mesh, thingsboard-service-provider, hal-raspberry and hal-waveshare-ipcbox turn it
on with one input and mesh deletes its copy. Written from the cross-repo spec
`specs/in-flight/2026-10-08-nuget-lock-determinism.md`, whose design is settled.

### Decisions

- **D1 —** An input on `dotnet-ci.yml`, `check-dependency-majors` (boolean, default `false`) and
  `dependency-majors-allow-list` (string, default `''`), not a caller-facing action; the names are
  the spec's contract with the four callers.
- **D2 —** A second job, `dependency-majors`, beside `build-test-style` on the same `runs-on`, not a
  step after the gate, so a failing gate does not hide a drift result.
- **D3 —** The action is loaded at `VION-IoT/shared-workflows/actions/dependency-majors@v1`, like
  the workflow's other actions, so callers get the action and the inputs together when `v1` moves.
- **D4 —** The proof calls `./actions/dependency-majors` directly; a proof through `dotnet-ci.yml`
  would run the released action.

### Reviewer's questions

1. `[resolved]` A workflow input or a caller-facing action? — **A:** an input (Justin, 2026-10-08,
   in the spec).
2. `[resolved]` Does the SDK version need a `global-json-file` input? — **A:** no; the job restores
   nothing, and the build job keeps the caller's `dotnet-version`.
3. `[deferred]` Does the `@v1` wiring work end to end? — **Owner:** the release follow-up ·
   **Trigger:** mesh's first `dotnet-ci.yml` run with the input on after `v1` moves.

---

## Full design

**The script** moves to `actions/dependency-majors/check-dependency-majors.ps1`. mesh derives the
repository root and the allow-list from `$PSScriptRoot` (`mesh:scripts/check-dependency-majors.ps1:24-25`),
which the action's path cannot supply, so both become parameters: `-RepoRoot` (default
`$env:GITHUB_WORKSPACE`) and `-AllowList` (default `''`), a relative path resolved against
`GITHUB_WORKSPACE`, or the current directory where that is unset. mesh reads the allow-list
unconditionally (`:100`); here an empty `-AllowList` means no exceptions, and a path naming no file
fails. The findings name the allow-list by the path given (`:117`, `:125` used the leaf name).
The rest — `git ls-files` for the lock files, `ConvertFrom-Json -AsHashtable`, the runtime-section
overlay, the 0.x rule, the stale-entry failure — is unchanged.

**The action** takes `root` and `allow-list`, both default `''`, and passes them as `-RepoRoot` and
`-AllowList`. The script writes with `Write-Host`, which goes to the information stream, so the
step collects it with `6>&1`, prints it (the `::error::` lines stay annotations) and sets a
`findings` output: each `::error::` line without its prefix, as `actions/journal-lint` does
(`actions/journal-lint/action.yml:44-47`).

**`dotnet-ci.yml`** gains the two inputs and the job: `if: ${{ inputs.check-dependency-majors }}`,
the `build-test-style` `runs-on` expression, `contents: read`, `actions/checkout@v7`, then the
action with `allow-list`. With the input off the job is skipped and nothing runs.

**The proof**, `proof-dependency-majors.yml`, points `root` at one fixture directory per case,
since `tests/fixtures/dotnet-win-x64/` holds two other lock files: `declared/` passes; `raised/`
fails with its one edge asserted; `raised/` with `raised-allowed.json` passes; `declared/` with the
same allow-list fails with the stale entry asserted. `paths:` covers the action, the fixtures and
the proof.

## Drift checkpoints

## Tasks

- **T-001** — The action, its script and the fixtures.
- **T-002** — The proof workflow.
- **T-003** — The `dotnet-ci.yml` inputs and job, the README inventory and the CHANGELOG line.
- **T-004** — Archive this change doc.
