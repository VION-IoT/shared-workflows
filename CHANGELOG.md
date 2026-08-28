# Changelog

All notable changes to this repository will be documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Versioning is semver on the reusable-workflow/composite-action contract:
input/output rename or removal is a breaking change, additions are not.

## Unreleased

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
