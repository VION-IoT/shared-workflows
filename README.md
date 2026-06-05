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
| `publish-nuget.yml` | .NET build + pack + push to private feed and (on stable tag) nuget.org with API key |
| `dotnet-ci.yml` | .NET build + test + verify code style (ReSharper cleanupcode via the caller's `scripts/cleanup-code.ps1`) on PRs |
| `deploy-aks.yml` | OIDC Azure login → AKS context → `kubectl set image` → rollout wait |
| `close-external-prs.yml` | Auto-close PRs from forks (source-available repos) |

### Composite actions (`actions/`)

| Action | Purpose |
|--------|---------|
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
