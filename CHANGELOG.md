# Changelog

All notable changes to this repository will be documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Versioning is semver on the reusable-workflow/composite-action contract:
input/output rename or removal is a breaking change, additions are not.

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
