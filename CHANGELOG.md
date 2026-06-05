# Changelog

All notable changes to this repository will be documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Versioning is semver on the reusable-workflow/composite-action contract:
input/output rename or removal is a breaking change, additions are not.

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
