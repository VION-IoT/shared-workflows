# Changelog

All notable changes to this repository will be documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
Versioning is semver on the reusable-workflow/composite-action contract:
input/output rename or removal is a breaking change, additions are not.

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
