---
slug: dotnet-aot-app
status: archived
areas: [dotnet-aot-app, proofs]
author: Justin Thiede
created: 2026-10-09
updated: 2026-10-09
---

# One reusable workflow for NativeAOT app pipelines

## At a glance

### Summary

A .NET NativeAOT app shipped as a container image needs the same pipeline every time: read the SDK
from `global.json`, build and test, publish NativeAOT for musl x64 and arm64 and optionally
win-x64, push a multi-arch image, delete the artifacts. `dotnet-aot-app.yml` runs that pipeline from
typed inputs, and `proof-dotnet-aot-app.yml` exercises it on GitHub-hosted runners before it is
released.

### Decisions

- **D1 —** One reusable workflow with one boolean per target (`linux-x64`, `linux-arm64`,
  `win-x64`).
- **D2 —** Every job declares `permissions: contents: read` except `release-win-x64`, which inherits
  the caller's grant, and there is no workflow-level `permissions:`: the Linux publishes run the
  pull request's MSBuild as root in a container, so a caller's `contents: write` must not reach them.
- **D3 —** `github-hosted-runners`, `global-json` and `run-style` let the proof run the workflow on
  GitHub's runners over a fixture; each job's self-hosted label set is written once, in a `runs-on`
  expression.
- **D4 —** The two Linux publish jobs are written out, differing only in their target: an internal
  action would load at `@v1` and so could not be proven before release.
- **D5 —** `check-dependency-majors` defaults to `true`, unlike on `dotnet-ci.yml`, where `false`
  kept existing callers unchanged; this workflow has none, and every intended caller turns it on.
  `dependency-majors-allow-list` stays `''`, so a caller names its allow-list at the call site.
- **D6 —** `cleanup` deletes this call's artifacts by name, never every artifact of the run, so two
  calls in one run do not delete each other's.

### Reviewer's questions

1. `[resolved]` Does `github.workflow_ref` in a called workflow name the caller's file? — **A:** yes;
   the proof asserts `decide-publish`'s `workflow-file` output reads
   `.github/workflows/proof-dotnet-aot-app.yml` for both calls.
2. `[resolved]` Does a read-only caller start? — **A:** yes; the proof's second call grants only
   `contents: read`, and the run starts.
3. `[deferred]` Do `push-linux-image`, `release-win-x64` and the file filter work? — **Owner:** the
   first caller on `@v1` · **Trigger:** its first pull request, its first push to `main`, and its
   first `v*` tag.

---

## Full design

The job table and the input contract are in the workflow; its header says what a caller provides.
Points settled here:

- **The workflow-file output** is named `workflow-file` on `decide-publish` and on the workflow.
  It is `github.workflow_ref` with the `<owner>/<repo>/` prefix and the `@<ref>` suffix cut, and
  `decide-publish` fails when the result does not start with `.github/workflows/`. The filter
  matches it as a fixed string, not inside the regular expression, so a dot in a file name stays a
  dot.
- **The executable `file` reports** is `<publish-project>`'s file name without `.csproj`; the
  summary fails when the publish holds no file of that name.
- **Action versions** follow this repository for checkout and the artifact actions (`checkout@v7`,
  `upload-artifact@v7`, `download-artifact@v8`). The Docker actions and `delete-artifact@v5` keep
  the versions already in production use, since `push-linux-image` cannot run before a caller's
  first push to `main`.
- **`cleanup`** deletes in one step per target, each run only when that target's publish succeeded,
  so a failed publish does not leave the delete failing on a missing artifact.
- **`release-win-x64`** names the results it needs with `!cancelled()`: the implicit `success()`
  also counts a skipped job further up the chain, which would skip the release behind a green run.

## Drift checkpoints

- 2026-10-09: `cleanup` deletes this call's artifacts by name, not every artifact of the run.
- 2026-10-09: `check-dependency-majors` defaults to `true`, not `false` as first designed (decided on
  review of the pull request).

## Tasks

- **T-001** — the fixture `tests/fixtures/dotnet-aot-app/`.
- **T-002** — `dotnet-aot-app.yml`.
- **T-003** — `proof-dotnet-aot-app.yml`.
- **T-004** — README, CHANGELOG, and the private-feed note in `dotnet-win-x64.yml`.
