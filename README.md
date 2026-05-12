# VION-IoT shared workflows

Private repository hosting reusable GitHub Actions workflows and composite
actions consumed by VION-IoT repos. Centralizes pipeline logic so that
release, deploy, and policy concerns evolve in one place.

See [`../architecture/concepts/`](https://github.com/VION-IoT/architecture)
for the cross-repo context this fits into.

## How to consume

### Reusable workflows

Call a reusable workflow from a consuming repo with `uses:`:

```yaml
jobs:
  publish:
    uses: VION-IoT/shared-workflows/.github/workflows/<name>.yml@v1
    with:
      # workflow-specific inputs
    secrets: inherit
```

Pin to a floating major tag (`@v1`) for low-friction updates, or to an
exact tag (`@v1.2.3`) for production-critical pipelines.

### Composite actions

Composite actions live under `actions/<name>/action.yml` and are referenced as:

```yaml
- uses: VION-IoT/shared-workflows/actions/<name>@v1
  with:
    # action-specific inputs
```

## Versioning

- Annotated semver tags: `v1.0.0`, `v1.1.0`, ...
- Floating major tag (`v1`) moved forward on each non-breaking release.
- Breaking changes bump the major version and are documented in `CHANGELOG.md`.

## Access

Repository Actions access is set to "Accessible from repositories in the
`VION-IoT` organization." Both public and private VION-IoT repos can invoke
the workflows defined here. Secrets stay with the caller (per-repo), passed
in via `secrets: inherit`.
