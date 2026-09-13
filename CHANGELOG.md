# Changelog

All notable changes to this repository will be documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Versioning is semver on the reusable-workflow/composite-action contract:
input/output rename or removal is a breaking change, additions are not.

## Unreleased

### Added

- **`actions/journal-lint`** — new composite action that checks the live window of a process
  journal against the one VION journal grammar, owned by `plugins/vion-improve/templates/journal.md`
  in the architecture repo. Below the last `<!-- retro-N marker -->` (or `## Entries` when there is
  none) every entry is `YYYY-MM-DD · <where> · <topic or —> · <what happened>` with `where` one of
  `review`, `gate`, `brief`, `decision`, `manual`; dates never decrease; an entry is at most
  `max-chars` characters (default `400`) with its wrapped lines joined; and every other line is a
  continuation, a blank line or a one-line HTML comment. A missing journal fails. Inputs `path`
  (default `docs/process-journal.md`) and `max-chars`; output `findings`, the same
  `file:line: message` lines it prints. It reports and never rewrites.

  Why here: `dale-sdk` and `dashboard` each carry their own linter with their own `where`
  vocabulary, and the other journals have none. One grammar needs one gate, and a repo opts in by
  adding one step (`specs/in-flight/2026-09-12-process-unification.md` § 8). The script runs the
  same way locally — `pwsh -NoProfile -File actions/journal-lint/journal-lint.ps1 -Path <file>` —
  so a journal can be checked before a push. `proof-journal-lint.yml` runs it on a valid fixture,
  as committed and as BOM + CRLF, and on an invalid one whose every case must be reported on its
  own line.

  Non-breaking: a new action; nothing existing changed.

### Changed

- **Artifact retention is now decided by what the artifact is for, not by one org-wide number.**
  Every `actions/upload-artifact` in this repository is one of two classes, and the class sets the
  default of that workflow's `artifact-retention-days`:

  **Hand-off — 1 day (GitHub's minimum).** The artifact carries data from one job to the next job
  of the same run and nothing reads it afterwards. `publish-nuget.yml`'s `nupkg`,
  `dotnet-win-x64.yml`'s publish output, `vendored-go-build.yml`'s build output. Verified per
  consumer, not assumed: `dale-sdk`'s `verify-packages` and `drift-and-docs` both `needs: publish`
  and download `nupkg` in the same run; `vion-agent-windows`'s nightly conformance hands
  `mender-conformance-round-trip` straight to the next job; the four `proof-*` workflows here do
  the same with `fixture-win-x64-publish`, `conformance-round-trip`,
  `fixture-mender-artifact-win-x64` and `sign-proof-tool`.

  **Deliverable — 30 days, unchanged.** A person reads it, or a step fetches it after a wait.
  `mender-conformance.yml`'s round-trip log is the only record of a nightly failure and nothing
  downloads it; `sign-mender-artifact.yml`'s signed `.mender` is the release product, and a
  caller whose deployment step waits on an environment approval collects it long after the
  signing run.

  Why the class and not a single number: v1.10.0 gave every one of these uploads 30 days, which is
  right for the two a human reads and wrong by a factor of thirty for the four that die with their
  run. The org is on the GitHub **Free** plan — 500 MB of Actions storage, a hard stop that blocks
  every publish in every repository once reached, not a bill. On 2026-09-10 unexpired artifacts
  stood at 2.55 GB and the quota blocked the `cloud-api` publish and the `artifacts-mender` suite
  deploy. Measured against the artifacts and run history that exist today rather than against a
  peak day: `publish-nuget.yml` runs 7.5 times a day for `dale-sdk` at 3.8 MB a run, and
  `dotnet-win-x64.yml` produces 100.6 MB per `vion-agent-windows` CI run and 50.5 MB per nightly
  conformance run. Held for 30 days those three alone settle near **3.8 GB**, seven times a cap
  that is a stop rather than a bill; held for one day they settle near **127 MB**. `mesh` reached
  the same answer on its own uploads before this
  (`retention-days: 1` plus a delete-artifact job); this makes it the shared default so consumers
  inherit it through `@v1` without editing anything.

  Non-breaking: no input is added, renamed or removed, and no upload became conditional. Three
  defaults changed. A caller that passes `artifact-retention-days` explicitly keeps exactly the
  value it passes.

- **`proof-mender-conformance.yml`, `proof-sign-mender-artifact.yml`** — both now pass
  `artifact-retention-days: 1` into the reusable workflow they exercise. In a real caller
  `mender-conformance-logs` and the signed `.mender` are deliverables; in a proof that fires on
  every Windows-lane PR they are scratch that only the next job of the same run reads. The other
  two proofs need no change — they inherit 1 day from the hand-off defaults above.

## v1.10.0 — 2026-09-10

### Added

- **Every reusable workflow that uploads an artifact** — new optional input
  **`artifact-retention-days`** (type `number`, default `30`), passed to that workflow's
  `actions/upload-artifact` step: `dotnet-win-x64.yml`, `mender-conformance.yml`,
  `publish-nuget.yml`, `sign-mender-artifact.yml`, `vendored-go-build.yml`. `dotnet-ci.yml` and
  `deploy-aks.yml` upload nothing and are untouched.

  On 2026-09-09 the org hit its GitHub Actions artifact storage quota — "Artifact storage quota
  has been hit. Unable to upload any new artifacts" — and a `cloud-api` build failed in its
  publish job. 2.39 GB of unexpired artifacts were sitting in the org, and most of it had been
  uploaded by these workflows on behalf of their consumers: `vion-agent-windows` alone accounted
  for 0.63 GB and has no `upload-artifact` step of its own, every one of its uploads coming from
  `dotnet-win-x64.yml` and `mender-conformance.yml` here. GitHub's default retention is 90 days,
  and none of these artifacts are read 90 days later — the publish output, the signed `.mender`,
  the conformance log and the build output are all consumed inside the run that produced them or
  shortly after by a human reading a failure.

  Setting it here rather than in each consumer is the point: the retention travels with the
  `@v1` pin, so a consumer inherits 30 days without editing anything. It is an input rather than
  a literal because the decision is the *default*, not a ceiling — a consumer that genuinely
  needs an artifact to outlive a month (a release binary a later job fetches days after the fact)
  says so explicitly at the call site instead of losing it silently.

  Non-breaking: a new optional input with a default. Existing callers pass nothing and get 30 days.

### Changed

- **`proof-sign-mender-artifact.yml`** — its own `sign-proof-input` staging upload now carries a
  1-day retention. It is not a consumer artifact: it hands the staged `.mender` and the freshly
  built tool from the `stage` job to the signing job inside one run, and the proof fires on every
  PR touching the Windows lane. It is deliberately *not* on the 30-day default the reusable
  workflows now carry.

## v1.9.0 — 2026-09-04

### Added

- **`dotnet-win-x64.yml`** — new optional input **`private-feed`** and optional secret
  **`AZURE_DEVOPS_PAT`**. The lane restored from public feeds only, which its own header called
  out as provisional ("add it when a consumer needs it"); `mesh` is that consumer. Not because the
  packages are unreachable otherwise — `Vion.Contracts` and both `Vion.Telemetry` packages are on
  nuget.org at the versions `mesh` pins — but because `publish-nuget.yml` pushes an intermediate
  package to the private feed on **every** main push and only reaches nuget.org on a stable tag, so
  a consumer building right after a bump resolves from the feed while nuget.org indexes. `mesh`'s
  Linux `ci` gate already passes `private-feed: true` for that reason; without this input the two
  lanes of one repository disagreed about where packages come from. Wired the same way
  `dotnet-ci.yml` does it: the existing
  `actions/setup-nuget-private-feed` composite, guarded by the input, placed after the SDK is on
  PATH and before the build. Additive — `private-feed` defaults to `false`, so `vion-agent-windows`
  and the fixture are untouched, and a caller that passes no secrets keeps working.

  The composite is written `shell: sh` (POSIX, for the Alpine containers on the Linux lanes) and
  had never run on a Windows runner. `proof-dotnet-win-x64.yml` gains a fourth job that runs it on
  `windows-latest` and asserts an enabled `PrivateFeed` source comes out — so the Git-for-Windows
  `sh.exe` this depends on is a tested assumption rather than an inherited one. A restore that
  actually authenticates is not proven here: this repository holds no `AZURE_DEVOPS_PAT`, and
  registering the real feed with an empty credential turns every restore in the job into NU1301.
  That half is exercised by `mesh`'s lane.

- **`dotnet-win-x64.yml`** — new optional input **`restore-locked-mode`**. The Linux publishes in
  `mesh` pass `-p:RestoreLockedMode=true`; the Windows one had no way to, so the same repository
  pinned its package graph on one platform and merely resolved it on the other. Additive, default
  `false`.

  It applies to the **publish only**, which is not an oversight. The SDK injects package references
  during a publish that it does not inject during a build — `Microsoft.DotNet.ILCompiler` for a
  NativeAOT project, `Microsoft.NET.ILLink.Tasks` for a trimmed one — because that injection is
  gated on `_IsPublishing`. A lock file written by `dotnet publish` therefore records direct
  references `dotnet build` never sees, so locked mode on the build step would fail every AOT
  caller with NU1004 for a lock file that is correct.

  The fixture now commits `packages.lock.json` so the input has something to gate, and the proof
  gains a job that moves the fixture off its lock file and asserts the publish refuses — a lane
  that quietly ignored the input would pass the happy path either way.

## v1.8.0 — 2026-08-28

### Changed

- **Every pinned third-party action moved off the deprecated Node 20 runtime.** All the
  `actions/*`, `docker/*` and `azure/*` majors pinned across the reusable workflows, the proofs
  and the composite actions declared `runs.using: node20`, which GitHub currently force-runs on
  Node 24 through a compatibility shim — and when the shim is withdrawn, every `@v1` consumer
  breaks at once. Audited each action's current major for `runs.using: node24` and bumped:
  `actions/checkout` v4→v7, `actions/setup-dotnet` v4→v6, `actions/upload-artifact` v4→v7,
  `actions/download-artifact` v4→v8, `actions/setup-go` v5→v7, `docker/metadata-action` v5→v6,
  `azure/login` v2→v3, `azure/aks-set-context` v4→v5. No input/output/secret contract changes.
  The breaking changes the crossed majors carry sit outside these workflows' usage: artifact
  transfers are by name with default zipping (the storage format is unchanged since v4, so
  mixed-version producers and consumers keep interoperating), nothing checks out a fork PR
  under `pull_request_target` (checkout v7's new guard), and `download-artifact` v8 failing
  hard on a digest mismatch is the default this lane wants. Self-hosted runners must be on
  Actions Runner ≥ 2.327.1 (released 2025-07); auto-updating runners are long past it.

## v1.7.0 — 2026-08-28

### Added

- **`mender-conformance.yml`** — new optional input **`mender-admin-url`**. The Mender
  environments now serve the two halves of a round-trip from two hosts: `mender.<env>` is
  device-only and gated with `RequireAndVerifyClientCert` at the Traefik edge, while the UI,
  `/api/management` and `/api/internal` moved to `mender-admin.<env>` behind the IP-whitelist
  (decision `0116-mender-device-api-mtls-hostname`). The preflight probed both halves from one
  base URL, so no single value was correct any more. `mender-server-url` keeps its meaning and
  is now documented as the **device** host — it is also the URL a caller feeds its round-trip
  executable — and the management half probes `mender-admin-url` when the caller supplies it.
  Omitted, that half reports "not probed" rather than being probed against the device host,
  where it would only measure the client-certificate gate a second time. Additive: existing
  callers keep working.

### Changed

- **`mender-conformance.yml`** — a certificate-less request the device host refuses **below
  HTTP** is now reported as **"reachable and gated"**, not `NO ANSWER`. Under the enforced gate
  that is the healthy outcome: the edge answers the empty `Certificate` message with TLSv1.3
  alert 116 `certificate_required` (curl exit 56), and the old wording read it as an outage. The
  preflight therefore opens a TCP connection before issuing the request — port open with no HTTP
  answer is the gate working, port shut is a genuine no-answer (DNS, routing, a dead edge). The
  underlying transport error is still appended, because it is the only thing separating the
  refusal the row expects from an expired or mis-named *server* certificate, which fails at the
  same layer. Still non-gating: the round-trip executable is the gate.
- **`mender-conformance.yml`** — the management-half probe now targets
  `/api/management/v2/devauth/devices`. The `v1/deviceauth` spelling it used is not a Mender
  route: it answers 404 from Traefik's fallback, which reads as "the management API answered"
  and is not. Measured against the admin host on 2026-08-28 — v1/deviceauth 404, v2/devauth 401.
  The summary table gains a `host` column so each half names the host it actually probed.

## v1.6.0 — 2026-08-12

### Added

The Windows CI lane for the CX5130 gateway platform
(`specs/in-flight/2026-08-06-cx5130-windows-gateway.md`). Four reusable workflows, each with a
`proof-*.yml` caller in this repository exercising it against a fixture under `tests/fixtures/`.
All additive — no existing input, output or secret contract changes.

- **`dotnet-win-x64.yml`** — build a solution, run a **caller-supplied** `test-command`, publish
  one project self-contained for `win-x64`. The test command is an input rather than
  `dotnet test` because `vion-agent-windows`'s MSTest projects run under
  Microsoft.Testing.Platform, where `dotnet test` routes to the legacy VSTest target and fails
  outright; the proof pins that with a job that asserts `dotnet test` still fails on that shape.
  The runtime identifier is a workflow constant, not an input — the fleet is all 64-bit LTSC
  2019/2021 and no `win-x86` path should be reachable by passing a string. Does not wire the VION
  private feed; no Windows consumer needs it yet and the proof could not exercise it.
- **`vendored-go-build.yml`** — run a caller's vendored-Go build script with the three things such
  a build needs and fails opaquely without: `core.longpaths=true` set **globally before checkout**
  (upstream `mender-artifact`'s `vendor/` tree passes MAX_PATH; without it `git clone` reports
  `Clone succeeded, but checkout failed` and leaves 8 of 2282 vendor files behind, which then
  looks like a Go build error), Go on PATH asserted rather than assumed, and `nopkcs11` exported
  through `GOFLAGS` (without it the build pulls the `mendersoftware/openssl` cgo binding and fails
  under `CGO_ENABLED=0`). `goos`/`goarch`/`cgo-enabled`/`build-tags` are inputs defaulting to the
  win-x64 case.
- **`sign-mender-artifact.yml`** — sign a `.mender` with an ECDSA **P-256** key supplied as the
  `ARTIFACT_SIGNING_KEY` secret, then verify with `mender-artifact validate`. The key is parsed
  and its curve checked *before* signing, because `mender-artifact`'s signer is typed `ECDSA256`
  and rejects every other curve with `signer: invalid ecdsa curve size` — a message that never
  mentions curves, next to a P-384 device key that looks interchangeable. Key custody stays with
  the caller: written to `RUNNER_TEMP` owner-only and deleted in an `always()` step.
  **`runs-on` defaults to `ubuntu-latest`**: `mender-artifact sign` does not work on Windows at
  all — `cli.CopyOwner` calls `windows.SetSecurityInfo(..., OWNER_SECURITY_INFORMATION, ...)` on a
  handle `os.CreateTemp` opened without `WRITE_OWNER`, so it always fails with
  `Could not set owner/group of signed artifact (needs root privileges)`. Measured on 4.4.1
  windows-amd64 with both the stock tool and `vion-agent-windows`'s patched build; an upstream
  defect distinct from the two path-separator patches that repo carries.
- **`mender-conformance.yml`** — run a caller-supplied round-trip executable against a live Mender
  server under a dedicated CI device identity, with a preflight that probes the device API and the
  management API separately and records which was reachable. `workflow_call` only; the caller owns
  the `schedule` + `workflow_dispatch` triggers. Conformance means exercising the real endpoints:
  a generated client's *encoding* does not follow from the document it was generated from, and
  `{"status":"Downloading"}` compiles perfectly and returns `400`. **The management API is
  IP-whitelisted** and the runners that pass it are all Linux, so a win-x64 round-trip cannot
  currently stage its own deployment from CI — see the workflow header.

## v1.5.0 — 2026-06-05

### Added

- **`actions/dotnet-gate`** — new composite action holding the .NET gate steps (build → test → verify code style via the caller's `scripts/cleanup-code.ps1 -Verify -NoBuild`). Packaged as a composite (not a second reusable workflow) so the *same* steps can run standalone for PR gates **and** inline before packing, reusing the one build. Inputs: `solution` (required), `configuration` (default `Debug`), `version`, `run-tests` (default `true`), `test-filter` (optional VSTest `--filter`, e.g. `FullyQualifiedName!~IntegrationTest` to keep environment-dependent tests out of the gate).
- **`publish-nuget.yml`** — new optional `gate` input (boolean, default `false`). When `true`, runs `actions/dotnet-gate` (Release) in the pack job before `dotnet pack --no-build`, so a release can't ship with failing tests or style drift and the gate adds no extra build. Requires the caller to provide `scripts/cleanup-code.ps1`, `.config/dotnet-tools.json`, and a `.sln.DotSettings` cleanup profile. A companion `test-filter` input forwards a VSTest `--filter` to the gate. Additive — default-off, existing consumers unaffected.

### Changed

- **`dotnet-ci.yml`** — refactored to a thin wrapper that delegates its build/test/style steps to the new `actions/dotnet-gate` composite. Adds one optional `test-filter` input (forwarded to the composite); otherwise no change to the `on.workflow_call` input/secret contract, so consumers (`dale`) are unaffected. The PR gate and `publish-nuget.yml`'s pre-publish gate now share one definition and can't drift.

## v1.4.0 — 2026-06-05

### Added

- **`dotnet-ci.yml`** — new reusable workflow: build + test a .NET solution and verify code style by running the caller's `scripts/cleanup-code.ps1 -Verify` (ReSharper `cleanupcode` — the single source of truth shared by devs, agents, cleanup-on-save, and CI, so local and CI can't diverge). Inputs: `solution` (required), `dotnet-version`, `private-feed`, `run-tests`; optional `AZURE_DEVOPS_PAT` secret (required when `private-feed: true`). First consumer: `dale`. Additive, backward-compatible.

## v1.3.0 — 2026-05-13

### Changed

- **`publish-nuget.yml`** — nuget.org push switched from Trusted Publishing (OIDC) to a long-lived API key. Trusted Publishing does not currently work with reusable workflows: the OIDC `job_workflow_ref` claim points at this repo, not the caller's, and nuget.org rejects the token exchange with `No matching trust policy owned by user 'X' was found`. See [community discussion #179952](https://github.com/orgs/community/discussions/179952). **Breaking** for the secret contract: callers now pass `NUGET_API_KEY` instead of `NUGET_USER`, and no longer need `id-token: write` permission. Re-evaluate when nuget.org adds reusable-workflow support.

## v1.2.1 — 2026-05-12

### Fixed

- **`actions/setup-nuget-private-feed`** — `shell: bash` → `shell: sh`. Bash isn't installed in Alpine images like `mcr.microsoft.com/dotnet/sdk:10.0-alpine`, which caused `mesh`'s `publish-amd64` job (running with `container:` at job level) to fail with `OCI runtime exec failed: exec: "bash": executable file not found in $PATH`. The script is already POSIX-compliant; only the shell declaration changed.

## v1.2.0 — 2026-05-12

### Added

- **`actions/docker-tags`** — new `release-only` input (default `'false'`). When `'true'`, omits the non-release tags (`main`, `main-{sha7}`, `manual-{sha7}`); only semver + `latest` are emitted. Used for Docker Hub pushes where only released versions should land. Additive, backward-compatible — existing callers default to the full VION scheme.

## v1.1.0 — 2026-05-12

### Added

- **`actions/compute-deploy-tag`** — composite action that derives a tag suitable for AKS deploys from `$GITHUB_REF`. Outputs `tag` = `"X.Y.Z"` on stable tag pushes, `"main-{sha7}"` on main pushes, empty otherwise. Replaces the 7-line bash block currently duplicated in `documentation.yml`, `dashboard.yml`, `website.yml`, and `contact-proxy.yml`. Additive only — existing workflows unaffected.

## v1.0.1 — 2026-05-12

### Changed

- **`deploy-aks.yml`** — input contract simplified. Removed 5 inputs (`azure-client-id`, `azure-tenant-id`, `azure-subscription-id`, `resource-group`, `cluster-name`); the workflow now reads them via `vars.*` from inside the deploy job (which sets `environment:`). The caller can no longer pass them via `with:` because the caller job has no environment set, so env-scoped `vars.*` like `AKS_RESOURCE_GROUP` aren't visible in its context. Net caller surface: 4 required inputs (was 9), 2 optional. Convention: repos provide `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` as repo vars and `AKS_RESOURCE_GROUP` / `AKS_CLUSTER_NAME` as env vars per environment. **Breaking** change to v1.0.0's input contract — v1.0.0 of `deploy-aks.yml` was never successfully invoked by any consumer, so no migration impact.

## v1.0.0 — 2026-05-12

Initial release. Phase 1.A of the source-available rollout.

### Reusable workflows

- `publish-nuget.yml` — .NET build + pack + push to private feed + (on stable tag) nuget.org via Trusted Publishing.
- `deploy-aks.yml` — OIDC Azure login + AKS context + `kubectl set image` + rollout wait. Runs on `[self-hosted, vpn]`.
- `close-external-prs.yml` — auto-close PRs opened from forks. For source-available repos.

### Composite actions

- `actions/compute-version` — derive `version` + `is_release` from `$GITHUB_REF`.
- `actions/setup-nuget-private-feed` — register the VION AzDO NuGet feed (URL hidden inside the action; masked in logs).
- `actions/docker-tags` — wrap `docker/metadata-action` with the VION tag scheme.
- `actions/azure-aks-set-image` — OIDC Azure login + AKS context + `kubectl set image` + rollout wait.

## v0.0.1 — 2026-05-12

Smoke test. Verified that VION-IoT repos (private and, by extension, public) can invoke a reusable workflow from this repository on GitHub Free org tier.
