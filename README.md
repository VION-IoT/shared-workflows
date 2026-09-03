# VION-IoT shared workflows

Source-available repository (Apache 2.0) hosting reusable GitHub Actions
workflows and composite actions consumed by VION-IoT repos. Centralizes
pipeline logic so release, deploy, and policy concerns evolve in one place.

External contributions are not accepted — see
[CONTRIBUTING.md](CONTRIBUTING.md), [SUPPORT.md](SUPPORT.md), and
[SECURITY.md](SECURITY.md).

For cross-repo context see
[`architecture/systems/shared-workflows.md`](https://github.com/VION-IoT/architecture/blob/main/systems/shared-workflows.md).

## Inventory

### Reusable workflows (`.github/workflows/`)

| Workflow | Purpose |
|----------|---------|
| `publish-nuget.yml` | .NET build + pack + push to private feed and (on stable tag) nuget.org with API key. Optional `gate: true` runs the build/test/style gate before packing (one build) |
| `dotnet-ci.yml` | .NET build + test + verify code style on PRs. Thin wrapper around the `dotnet-gate` composite (the shared gate) |
| `deploy-aks.yml` | OIDC Azure login → AKS context → `kubectl set image` → rollout wait |
| `close-external-prs.yml` | Auto-close PRs from forks (source-available repos) |

#### The Windows lane

Four workflows for the Windows gateway platform
(`specs/in-flight/2026-08-06-cx5130-windows-gateway.md`). They are separate from the Linux .NET
workflows above because the failure modes are different, not because the language is.

| Workflow | Purpose |
|----------|---------|
| `dotnet-win-x64.yml` | Build a solution, run a **caller-supplied** test command, publish one project self-contained for `win-x64`. RID is fixed, not an input — the fleet is all 64-bit. `private-feed: true` (+ `secrets: inherit`) registers the VION feed, as on the Linux lane |
| `vendored-go-build.yml` | Run a caller's vendored-Go build script with `core.longpaths=true` set before checkout, Go on PATH, and `nopkcs11` in `GOFLAGS` |
| `sign-mender-artifact.yml` | Sign a `.mender` with an ECDSA **P-256** key from the caller's secret store, then verify. Defaults to a Linux runner — `mender-artifact sign` is broken on Windows |
| `mender-conformance.yml` | Run a caller-supplied round-trip executable against a live Mender server, with an endpoint-reachability preflight over both halves. Two hosts since the device/admin split: `mender-server-url` is the device host (mTLS-gated) and `mender-admin-url` the admin host (management API, IP-whitelisted). `workflow_call` only; the caller owns the `schedule` / `workflow_dispatch` triggers |

Each has a `proof-*.yml` caller in this repository that exercises it against a fixture under
[`tests/fixtures/`](tests/fixtures/) — a `net10.0-windows` solution shaped like
`vion-agent-windows`, and a vendored-Go build script that uses the same upstream pin. The proofs
are the regression tests for these workflows; read them before changing an input contract.

### Composite actions (`actions/`)

| Action | Purpose |
|--------|---------|
| `dotnet-gate` | The .NET gate (build + test + ReSharper cleanupcode style verify); run standalone by `dotnet-ci.yml` or inline by `publish-nuget.yml` so the one build is reused |
| `compute-version` | Derive `version` + `is_release` from `$GITHUB_REF` |
| `setup-nuget-private-feed` | Register the VION internal NuGet feed; URL hidden inside the action and masked in logs |
| `docker-tags` | Wrap `docker/metadata-action` with the VION tag scheme |
| `azure-aks-set-image` | OIDC Azure login + AKS context + `kubectl set image` + rollout wait |

## How to consume

### Calling a reusable workflow

```yaml
jobs:
  publish:
    uses: VION-IoT/shared-workflows/.github/workflows/publish-nuget.yml@v1
    with:
      solution: Vion.Contracts.sln
    secrets: inherit
```

Pin to a floating major tag (`@v1`) for low-friction updates, or to an
exact tag (`@v1.2.3`) for production-critical pipelines. Major-version
bumps signal breaking changes — see `CHANGELOG.md`.

### Using a composite action

```yaml
- uses: VION-IoT/shared-workflows/actions/compute-version@v1
  id: version
- run: echo "Building ${{ steps.version.outputs.version }}"
```

## Secrets model

Secrets stay with each caller (per-repo, not org-level). Each reusable
workflow declares the secrets it expects under `on.workflow_call.secrets`;
callers pass them via `secrets: inherit`. If a required secret isn't set
in the caller, the workflow fails fast with a clear error.

Per-secret consumer map:

| Secret | Used by |
|--------|---------|
| `AZURE_DEVOPS_PAT` | `publish-nuget.yml`, `dotnet-ci.yml`, `actions/setup-nuget-private-feed` |
| `NUGET_API_KEY` | `publish-nuget.yml` (optional; required only when `push-to-nuget-org: true`) |
| `ARTIFACT_SIGNING_KEY` | `sign-mender-artifact.yml` — PEM EC **P-256** private key. Custody is the artifact pipeline's CI secret store; it is never stored here |
| `DEVICE_ID_OVERRIDE` | `mender-conformance.yml` — identifier of the dedicated CI device identity, never a fleet gateway's |

## Versioning

- Annotated semver tags: `v1.0.0`, `v1.1.0`, …
- Floating major tag (`v1`) moves forward on each non-breaking release.
- Breaking changes bump the major version and are documented in `CHANGELOG.md`.
- Input/output rename or removal is a breaking change; additions are not.

## Access

This repository is **public** because GitHub Free org tier does not
allow public repos to invoke reusable workflows in a private repo. The
public source-available consumers (`dale-sdk`, `vion-contracts`,
`service-provider-sdk-dotnet`, `documentation`) need to call into the
workflows defined here, so visibility had to match.

Going public exposes the workflow and composite-action source — including
the Azure DevOps feed URL referenced in `actions/setup-nuget-private-feed`.
Secrets remain with each caller (per-repo); the PAT and other credentials
are never exposed.
