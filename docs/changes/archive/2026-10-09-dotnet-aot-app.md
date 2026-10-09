---
slug: dotnet-aot-app
status: archived
areas: [dotnet-aot-app, proofs]
author: Justin Thiede
created: 2026-10-09
updated: 2026-10-09
---

# One reusable workflow for the four NativeAOT app pipelines

## At a glance

### Summary

mesh, thingsboard-service-provider, hal-raspberry and hal-waveshare-ipcbox each carry a copy of the
same pipeline: read the SDK from `global.json`, build and test, publish NativeAOT for musl x64 and
arm64 (mesh also win-x64), push a multi-arch image, delete the artifacts. `dotnet-aot-app.yml` runs
that pipeline from typed inputs, and `proof-dotnet-aot-app.yml` exercises it on GitHub-hosted
runners before it is released. Written from the cross-repo spec
`specs/in-flight/2026-10-09-dotnet-aot-app.md`, whose design is settled; the four repos switch only
after `v1` moves.

### Decisions

- **D1 —** One reusable workflow with one boolean per target (`linux-x64`, `linux-arm64`,
  `win-x64`); the input names are the spec's contract with the four callers.
- **D2 —** Every job declares `permissions: contents: read` except `release-win-x64`, which inherits
  the caller's grant, and there is no workflow-level `permissions:`: the Linux publishes run the
  pull request's MSBuild as root in a container, so a caller's `contents: write` must not reach them.
- **D3 —** `github-hosted-runners`, `global-json` and `run-style` exist for the proof only; each
  job's self-hosted label set is written once, in a `runs-on` expression.
- **D4 —** The two Linux publish jobs are written out, differing only in their target: an internal
  action would load at `@v1` and so could not be proven before release.
- **D5 —** `cleanup` deletes this call's artifacts by name, never every artifact of the run, so two
  calls in one run do not delete each other's.

### Reviewer's questions

1. `[resolved]` Does `github.workflow_ref` in a called workflow name the caller's file? — **A:** the
   proof asserts it: `decide-publish`'s `workflow-file` output must read
   `.github/workflows/proof-dotnet-aot-app.yml` for both calls.
2. `[resolved]` Does a read-only caller start? — **A:** the proof's second call grants only
   `contents: read`; a run that starts at all shows it.
3. `[deferred]` Do `push-linux-image`, `release-win-x64` and the file filter work? — **Owner:**
   the mesh switch-over · **Trigger:** mesh's first pull request on `@v1`, its first push to
   `main`, and its first `v*` tag.

---

## Full design

The job table, the input contract and the five rules (runners, permissions, skipped-is-not-failed,
drafts, no new internal action) are the brief's and the spec's; the workflow's header comment
restates what a caller must provide. Points the spec leaves open and this change settles:

- **The workflow-file output** is named `workflow-file` on `decide-publish` and on the workflow.
  It is `github.workflow_ref` with the `<owner>/<repo>/` prefix and the `@<ref>` suffix cut, and
  `decide-publish` fails when the result does not start with `.github/workflows/`. The filter
  matches it as a fixed string, not inside the regular expression, so a dot in a file name stays a
  dot.
- **The executable `file` reports** is `<publish-project>`'s file name without `.csproj`, the
  assembly name all four callers use; the summary fails when the publish holds no file of that name.
- **Action versions** follow this repository for checkout and the artifact actions (`checkout@v7`,
  `upload-artifact@v7`, `download-artifact@v8`) and mesh for the Docker actions and
  `delete-artifact@v5`, since `push-linux-image` cannot run before mesh's first push to `main`.
- **`cleanup`** deletes in one step per target, each run only when that target's publish succeeded,
  so a failed publish does not leave the delete failing on a missing artifact.

## Drift checkpoints

- 2026-10-09: `cleanup` deletes this call's artifacts by name, not every artifact of the run (the
  coordinator recorded it against the spec).

## Tasks

- **T-001** — the fixture `tests/fixtures/dotnet-aot-app/`.
- **T-002** — `dotnet-aot-app.yml`.
- **T-003** — `proof-dotnet-aot-app.yml`.
- **T-004** — README, CHANGELOG, and the private-feed note in `dotnet-win-x64.yml`.
